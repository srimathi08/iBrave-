global without sharing class HybridWorkScheduleApprovalController {

    public Hybrid_Work_Schedule__c hybridWorkSchedule { get; set; }
    public String managerComments { get; set; }
    public Boolean showSuccess { get; set; }
    public Boolean showInfo    { get; set; }
    public Boolean showError   { get; set; }
    public String errorMessage { get; set; }
    public String infoMessage  { get; set; }
    public String actionTaken  { get; set; }
    public String rejectionReason { get; set; }

    // Display fields
    public String employeeName  { get; set; }
    public String employeeEmail { get; set; }
    public String wfhDays       { get; set; }
    public String officeDays    { get; set; }
    public String totalDays     { get; set; }
    public String reason        { get; set; }

    private String scheduleId;
    private String managerId;

    public HybridWorkScheduleApprovalController() {
        showSuccess = false;
        showError   = false;
        showInfo    = false;

        scheduleId = ApexPages.currentPage().getParameters().get('id');
        managerId  = ApexPages.currentPage().getParameters().get('mgr');

        if (String.isNotBlank(scheduleId)) {
            loadSchedule();
        } else {
            showError    = true;
            errorMessage = 'Invalid or expired hybrid work schedule request.';
        }
    }

    private void loadSchedule() {
        try {
            List<Hybrid_Work_Schedule__c> schedules = [
                SELECT Id,
                       Employee__c, Employee__r.Name, Employee__r.Email,
                       Schedule_Type__c,
                       WFH_days__c, Office_Days__c,
                       Total_WFH_Days__c, Total_Office_Days__c,
                       Reason__c, Approval_Status__c,
                       Manager__c, Manager_Comments__c
                FROM Hybrid_Work_Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];

            if (!schedules.isEmpty()) {
                Hybrid_Work_Schedule__c rec = schedules[0];

                // Already processed — show info, don't load the form
                if (rec.Approval_Status__c != 'Pending Manager Approval') {
                    showInfo    = true;
                    infoMessage = 'This hybrid work schedule request has already been '
                                  + rec.Approval_Status__c
                                  + ' and cannot be actioned again.';
                    return;
                }

                hybridWorkSchedule = rec;
                employeeName  = hybridWorkSchedule.Employee__r.Name;
                employeeEmail = hybridWorkSchedule.Employee__r.Email;
                wfhDays       = hybridWorkSchedule.WFH_days__c;
                officeDays    = hybridWorkSchedule.Office_Days__c;
                totalDays     = String.valueOf(
                                    hybridWorkSchedule.Total_WFH_Days__c +
                                    hybridWorkSchedule.Total_Office_Days__c);
                reason        = hybridWorkSchedule.Reason__c;

            } else {
                showError    = true;
                errorMessage = 'Hybrid work schedule request not found. The link may be invalid or expired.';
            }

        } catch (Exception e) {
            showError    = true;
            errorMessage = 'Error loading hybrid work schedule: ' + e.getMessage();
        }
    }

    public PageReference approveRequest() {
        return processRequest('Approved');
    }

    public PageReference cancelRequest() {
        return processRequest('Cancelled');
    }

    private PageReference processRequest(String action) {
        try {
            if (hybridWorkSchedule == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }

            hybridWorkSchedule.Approval_Status__c  = action;
            hybridWorkSchedule.Manager_Comments__c = managerComments;

            if (String.isNotBlank(managerId)) {
                hybridWorkSchedule.Manager__c = managerId;
            }

            if (action == 'Approved') {
                hybridWorkSchedule.Approval_Date__c = System.now();
            } else if (action == 'Cancelled') {
                hybridWorkSchedule.Rejected_Date__c = System.now();
            }

            update hybridWorkSchedule;
            sendConfirmationEmail(action);

            showSuccess  = true;
            actionTaken  = action;   // Keep original casing: 'Approved'
            hybridWorkSchedule = null;

            return null;

        } catch (Exception e) {
            showError    = true;
            errorMessage = 'Error processing request: ' + e.getMessage();
            return null;
        }
    }

    public PageReference rejectRequest() {
        try {
            if (String.isBlank(rejectionReason)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Rejection reason is required.'
                ));
                return null;
            }

            if (hybridWorkSchedule == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }

            hybridWorkSchedule.Approval_Status__c  = 'Rejected';
            hybridWorkSchedule.Rejection_Reason__c = rejectionReason;
            hybridWorkSchedule.Manager_Comments__c = rejectionReason;
            hybridWorkSchedule.Rejected_Date__c    = Date.today();

            if (String.isNotBlank(managerId)) {
                hybridWorkSchedule.Manager__c = managerId;
            }

            update hybridWorkSchedule;

            // Set managerComments before clearing so email can use it
            managerComments = rejectionReason;
            sendConfirmationEmail('Rejected');

            showSuccess        = true;
            actionTaken        = 'Rejected';
            hybridWorkSchedule = null;

        } catch (Exception e) {
            showError    = true;
            errorMessage = e.getMessage();
        }
        return null;
    }

    public PageReference doNothing() {
        return null;
    }

    private void sendConfirmationEmail(String action) {
        try {
            String subject = 'Hybrid Work Schedule ' + action;
            String body = '<html><body style="font-family:Arial,sans-serif;color:#333;">';
            body += '<div style="max-width:600px;margin:auto;border:1px solid #e0e0e0;border-radius:10px;overflow:hidden;">';
            body += '<div style="background:#0176d3;padding:25px;text-align:center;">';
            body += '<h2 style="color:white;margin:0;">Hybrid Work Schedule ' + action + '</h2>';
            body += '</div>';
            body += '<div style="padding:30px;">';
            body += '<p>Dear <strong>' + employeeName + '</strong>,</p>';
            body += '<p>Your hybrid work schedule request has been <strong>' + action + '</strong>.</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse:collapse;width:100%;">';
            body += '<tr style="background:#f3f4f6;"><td><strong>WFH Days</strong></td><td>' + wfhDays + '</td></tr>';
            body += '<tr><td><strong>Office Days</strong></td><td>' + officeDays + '</td></tr>';
            body += '<tr style="background:#f3f4f6;"><td><strong>Reason</strong></td><td>' + reason + '</td></tr>';
            if (String.isNotBlank(managerComments)) {
                body += '<tr><td><strong>Manager Comments</strong></td><td>' + managerComments + '</td></tr>';
            }
            body += '</table>';
            body += '<p style="margin-top:20px;">Thank you,<br/><strong>HR Management System</strong></p>';
            body += '</div></div></body></html>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{ employeeEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });

        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}