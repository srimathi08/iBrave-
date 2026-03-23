/**
 * @description Batch Apex - Auto Checkout at 11:59 PM
 * Uses ONLY existing fields: Check_Out_Time__c and Notes__c
 * No new custom fields required.
 */
global class AutoCheckoutBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer totalSuccess = 0;
    private Integer totalFailed  = 0;
    private List<String> processedEmployees = new List<String>();

    // ── 1. QUERY: find all open check-ins for today ──────────────────────────
    global Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== AUTO CHECKOUT BATCH START: ' + DateTime.now() + ' ===');
        Date today = Date.today();

        return Database.getQueryLocator([
            SELECT Id,
                   Employee_Name__c,
                   Employee_Name__r.Name,
                   Employee_Name__r.Email,
                   Check_In_Time__c,
                   Check_Out_Time__c,
                   Work_Location__c,
                   Notes__c
            FROM   Employee_Attendance__c
            WHERE  Date__c            = :today
            AND    Check_In_Time__c  != null
            AND    Check_Out_Time__c  = null
        ]);
    }

    // ── 2. PROCESS: set Check_Out_Time__c = 11:59 PM, update Notes__c ────────
    global void execute(Database.BatchableContext bc, List<Employee_Attendance__c> records) {
        System.debug('Processing ' + records.size() + ' open record(s)...');

        DateTime autoOut = DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 0, 0));
        List<Employee_Attendance__c> toUpdate = new List<Employee_Attendance__c>();

        for (Employee_Attendance__c rec : records) {
            try {
                // Calculate hours from check-in to 11:59 PM
                Decimal hrs = 0;
                if (rec.Check_In_Time__c != null) {
                    Long diff = autoOut.getTime() - rec.Check_In_Time__c.getTime();
                    if (diff > 0) hrs = (diff / (1000.0 * 60 * 60)).setScale(2);
                }

                // Append note to existing Notes__c — no new field needed
                String existing = String.isNotBlank(rec.Notes__c) ? rec.Notes__c + '\n' : '';
                String autoNote = '[AUTO CHECKOUT] System checked out at 11:59 PM on '
                    + Date.today().format()
                    + '. Hours worked: ' + hrs + 'h. Please check out manually next time.';

                toUpdate.add(new Employee_Attendance__c(
                    Id               = rec.Id,
                    Check_Out_Time__c = autoOut,
                    Notes__c         = existing + autoNote
                ));

                String name = rec.Employee_Name__r?.Name != null
                    ? rec.Employee_Name__r.Name
                    : String.valueOf(rec.Employee_Name__c);
                processedEmployees.add(name);

                System.debug('✅ Queued auto-checkout: ' + name
                    + ' | Check-in: ' + rec.Check_In_Time__c
                    + ' | Hours: ' + hrs);

            } catch (Exception e) {
                totalFailed++;
                System.debug('❌ Error on ' + rec.Id + ': ' + e.getMessage());
            }
        }

        // DML update
        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    totalSuccess++;
                } else {
                    totalFailed++;
                    System.debug('❌ Update failed: ' + results[i].getErrors());
                }
            }
        }

        sendEmployeeEmails(records, autoOut);
    }

    // ── 3. FINISH: log summary and email HR admin ─────────────────────────────
    global void finish(Database.BatchableContext bc) {
        System.debug('=== AUTO CHECKOUT DONE | Success: ' + totalSuccess + ' | Failed: ' + totalFailed + ' ===');
        sendAdminSummaryEmail();
    }

    // ── HELPER: email each employee who was auto-checked out ──────────────────
    private void sendEmployeeEmails(List<Employee_Attendance__c> records, DateTime autoOut) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Employee_Attendance__c rec : records) {
            String empEmail = rec.Employee_Name__r?.Email;
            String empName  = rec.Employee_Name__r?.Name != null ? rec.Employee_Name__r.Name : 'Employee';
            if (String.isBlank(empEmail)) continue;

            Decimal hrs = 0;
            if (rec.Check_In_Time__c != null) {
                Long diff = autoOut.getTime() - rec.Check_In_Time__c.getTime();
                if (diff > 0) hrs = (diff / (1000.0 * 60 * 60)).setScale(2);
            }

            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ empEmail });
            m.setSubject('⚠️ Auto Checkout Applied — ' + Date.today().format());
            m.setHtmlBody(
                '<div style="font-family:Arial,sans-serif;max-width:580px;margin:auto">'
              + '<div style="background:#e53935;color:#fff;padding:16px;border-radius:8px 8px 0 0">'
              + '<h2 style="margin:0">⚠️ Automatic Checkout Applied</h2></div>'
              + '<div style="background:#fafafa;padding:20px;border:1px solid #ddd">'
              + '<p>Hi <strong>' + empName + '</strong>,</p>'
              + '<p>You were automatically checked out at <strong>11:59 PM</strong> because '
              + 'a manual checkout was not recorded for today.</p>'
              + '<table style="width:100%;border-collapse:collapse;margin:12px 0">'
              + '<tr style="background:#e3f2fd">'
              + '  <td style="padding:9px;border:1px solid #ccc"><strong>Date</strong></td>'
              + '  <td style="padding:9px;border:1px solid #ccc">' + Date.today().format() + '</td></tr>'
              + '<tr>'
              + '  <td style="padding:9px;border:1px solid #ccc"><strong>Check-In Time</strong></td>'
              + '  <td style="padding:9px;border:1px solid #ccc">' + rec.Check_In_Time__c?.format() + '</td></tr>'
              + '<tr style="background:#e3f2fd">'
              + '  <td style="padding:9px;border:1px solid #ccc"><strong>Auto Check-Out</strong></td>'
              + '  <td style="padding:9px;border:1px solid #ccc">11:59 PM</td></tr>'
              + '<tr>'
              + '  <td style="padding:9px;border:1px solid #ccc"><strong>Hours Worked</strong></td>'
              + '  <td style="padding:9px;border:1px solid #ccc">' + hrs + 'h</td></tr>'
              + '</table>'
              + '<p style="color:#e53935"><strong>Action:</strong> Contact HR if the checkout time is incorrect.</p>'
              + '<p style="color:#999;font-size:11px">HRMS Attendance System — Automated Message</p>'
              + '</div></div>'
            );
            m.setSaveAsActivity(false);
            emails.add(m);
        }

        if (!emails.isEmpty()) {
            try { Messaging.sendEmail(emails); System.debug('✅ Employee emails sent: ' + emails.size()); }
            catch (Exception e) { System.debug('⚠️ Email error: ' + e.getMessage()); }
        }
    }

    // ── HELPER: email HR Admin summary ────────────────────────────────────────
    private void sendAdminSummaryEmail() {
        try {
            List<User> admins = [
                SELECT Email FROM User
                WHERE IsActive = true
                AND Profile.Name IN ('System Administrator', 'HR Admin')
                AND Email != null LIMIT 10
            ];
            if (admins.isEmpty()) return;

            List<String> adminEmails = new List<String>();
            for (User u : admins) adminEmails.add(u.Email);

            String empList = processedEmployees.isEmpty()
                ? '<p>No employees required auto-checkout today.</p>'
                : '<ul><li>' + String.join(processedEmployees, '</li><li>') + '</li></ul>';

            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(adminEmails);
            m.setSubject('📊 Auto Checkout Summary — ' + Date.today().format());
            m.setHtmlBody(
                '<div style="font-family:Arial,sans-serif;max-width:580px;margin:auto">'
              + '<div style="background:#1565c0;color:#fff;padding:16px;border-radius:8px 8px 0 0">'
              + '<h2 style="margin:0">📊 Daily Auto-Checkout Summary</h2>'
              + '<p style="margin:4px 0 0">' + Date.today().format() + '</p></div>'
              + '<div style="background:#fafafa;padding:20px;border:1px solid #ddd">'
              + '<table style="width:100%;border-collapse:collapse;margin-bottom:16px">'
              + '<tr style="background:#e8f5e9">'
              + '  <td style="padding:12px;border:1px solid #ccc">✅ Successfully Auto-Checked Out</td>'
              + '  <td style="padding:12px;border:1px solid #ccc;font-size:22px;font-weight:bold;color:#2e7d32">' + totalSuccess + '</td></tr>'
              + '<tr style="background:#ffebee">'
              + '  <td style="padding:12px;border:1px solid #ccc">❌ Failed</td>'
              + '  <td style="padding:12px;border:1px solid #ccc;font-size:22px;font-weight:bold;color:#c62828">' + totalFailed + '</td></tr>'
              + '</table>'
              + '<h3>Employees Auto-Checked Out:</h3>' + empList
              + '<p style="color:#999;font-size:11px">Checkout time set to 11:59 PM. Employees have been notified by email.</p>'
              + '</div></div>'
            );
            m.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ m });
            System.debug('✅ Admin summary email sent');
        } catch (Exception e) {
            System.debug('⚠️ Admin email error: ' + e.getMessage());
        }
    }
}