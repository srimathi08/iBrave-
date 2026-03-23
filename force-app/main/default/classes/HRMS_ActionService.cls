public without sharing class HRMS_ActionService {

    /**
     * Central dispatcher for all HR intents (Timesheet, Leave, Attendance, and future Performance/Approvals)
     * @param intentData - The JSON-extracted data from AI or WhatsApp
     * @param userId - The Salesforce User ID to act upon
     * @return String confirmation message or error
     */
    public static String executeIntent(Map<String, Object> intentData, Id userId) {
        String rawIntent = (String)intentData.get('intent');
        if (String.isBlank(rawIntent)) {
            return 'No intent recognized.';
        }
        String intent = rawIntent.toLowerCase().replaceAll('[^a-z0-9]', '');
        
        try {
            // EMERGENCY FUZZY OVERRIDE FOR DEMO (Catch common variations that AI might mis-categorize)
            if (intent.contains('leave')) {
                if (intent.contains('cancel') || intent.contains('delete') || intent.contains('remove')) {
                    return handleCancelLeave(intentData, userId);
                }
                if (intent.contains('update') || intent.contains('change') || intent.contains('modify') || intent.contains('edit')) {
                    return handleUpdateLeave(intentData, userId);
                }
                if (intent.contains('balance') || intent.contains('remain') || intent.contains('howmany')) {
                    return handleLeaveBalance(userId);
                }
                if (intent.contains('apply') || intent.contains('request') || intent.contains('sick') || intent.contains('casual') || intent.contains('earned') || intent.contains('marriage') || intent.contains('paternity')) {
                    // If AI returned leave type as intent, move it to data
                    if (!intentData.containsKey('leaveType') && rawIntent.length() > 3 && rawIntent.length() < 25) {
                        intentData.put('leaveType', rawIntent);
                    }
                    return handleLeaveApplication(intentData, userId);
                }
            }
            if (intent.contains('time') || intent.contains('hour') || intent.contains('work') || intent.contains('task')) {
                if (!intent.contains('checkin') && !intent.contains('checkout')) {
                    return handleTimesheet(intentData, userId);
                }
            }

            if (intent.contains('logtimesheet')) {
                return handleTimesheet(intentData, userId);
            }
            if (intent.contains('checkin')) {
                return handleCheckIn(intentData, userId);
            }
            if (intent.contains('checkout')) {
                return handleCheckOut(intentData, userId);
            }
            if (intent.contains('applyleave')) {
                return handleLeaveApplication(intentData, userId);
            }
            if (intent.contains('leavebalance')) {
                return handleLeaveBalance(userId);
            }
            if (intent.contains('attendancesummary')) {
                return handleAttendanceSummary(userId);
            }
            if (intent.contains('projectnotfound')) {
                String msg = (String)intentData.get('message');
                return String.isNotBlank(msg) ? msg : '⚠️ That project is not assigned to you. Please check your assigned projects.';
            }
            if (intent.contains('updateleave')) {
                return handleUpdateLeave(intentData, userId);
            }
            if (intent.contains('cancelleave')) {
                return handleCancelLeave(intentData, userId);
            }
            // Future intents (KRA/Performance/Approvals) will be added here

            // DEEP LOGGING FOR FALLBACK: Find out exactly what's failing!
            try {
                Service__c log = new Service__c();
                log.Name = 'UNHANDLED INTENT ' + Datetime.now().format();
                log.Email_Body__c = 'RAW: ' + rawIntent + '\nNORMALIZED: ' + intent + '\nUSERID: ' + userId + '\nDATA: ' + JSON.serializePretty(intentData);
                log.Whatsapp__c = true;
                insert log;
            } catch(Exception eLog) {}

            return 'Intent "' + rawIntent + '" recognized but no action handler is implemented yet. (Normalized: ' + intent + ')';
        } catch (Exception e) {
            System.debug('HRMS_ActionService Error: ' + e.getMessage());
            // ERROR LOGGING
            try {
                Service__c errLog = new Service__c();
                errLog.Name = 'ACTION ERROR ' + Datetime.now().format();
                errLog.Email_Body__c = 'INTENT: ' + intent + '\nERROR: ' + e.getMessage() + '\nSTACK: ' + e.getStackTraceString();
                errLog.Whatsapp__c = true;
                insert errLog;
            } catch(Exception eLog) {}
            return 'Action failed: ' + e.getMessage();
        }
    }

    private static String handleTimesheet(Map<String, Object> data, Id userId) {
        List<Object> entries = (List<Object>)data.get('entries');
        if (entries == null || entries.isEmpty()) {
            return 'No timesheet entries found to log.';
        }

        // Track overtime alerts across multi-entry logging
        List<String> overtimeDates = new List<String>();
        Map<String, Double> overtimeTotals = new Map<String, Double>();

        for (Object obj : entries) {
            Map<String, Object> entry = (Map<String, Object>)obj;
            String projId    = (String)entry.get('projectId');
            String projName  = (String)entry.get('projectName');

            // ✅ Project Validation
            if (String.isBlank(projId)) {
                if (String.isNotBlank(projName)) {
                    return '⚠️ Project "' + projName + '" is not assigned to you. Please use one of your assigned projects.';
                }
                return '⚠️ No project found. Please specify a project that is assigned to you.';
            }

            String entryDateStr = (String)entry.get('date');
            if (String.isBlank(entryDateStr)) entryDateStr = String.valueOf(Date.today());
            Date entryDate = Date.valueOf(entryDateStr);

            // ✅ No Future Date
            if (entryDate > Date.today()) {
                return '⚠️ Cannot log timesheet for a future date (' + entryDate.format() + '). Please use today or a past date.';
            }

            // ✅ No Timesheet on Approved Leave Dates
            List<Leave_Request__c> approvedLeave = [
                SELECT Id, Leave_Type__r.Leave_Type_Name__c
                FROM Leave_Request__c
                WHERE Employee__c = :userId
                AND Status__c = 'Approved'
                AND Start_Date__c <= :entryDate
                AND End_Date__c   >= :entryDate
                LIMIT 1
            ];
            if (!approvedLeave.isEmpty()) {
                String leaveName = approvedLeave[0].Leave_Type__r != null
                    ? approvedLeave[0].Leave_Type__r.Leave_Type_Name__c : 'Leave';
                return '⛔ Cannot log timesheet for ' + entryDate.format() +
                       ' — you have an approved "' + leaveName + '" leave on this date. ' +
                       'Timesheet logging is not allowed on approved leave days.';
            }

            Double hrs = 8.0;
            if (entry.containsKey('hours')) {
                hrs = Double.valueOf(entry.get('hours'));
            }

            String task = (String)entry.get('task');
            String taskDescription = (String)entry.get('taskDescription');
            if (String.isBlank(taskDescription)) taskDescription = task;
            String statusVal = (String)entry.get('status');
            if (String.isBlank(statusVal)) statusVal = 'In Progress';

            // ─── Daily Hours Cap Check ────────────────────────────────────────
            // Query existing total hours for this user on this date
            List<AggregateResult> dailyAgg = [
                SELECT SUM(Regular_Hours__c) dayTotal
                FROM TimesheetEntry__c
                WHERE Date__c = :entryDate
                AND Timesheet__r.Employee__c = :userId
            ];
            Double existingDayTotal = (dailyAgg.isEmpty() || dailyAgg[0].get('dayTotal') == null)
                ? 0 : (Double) dailyAgg[0].get('dayTotal');

            // Smart Upsert Check — also fetch current hours so update doesn't double-count
            List<TimesheetEntry__c> existing = [
                SELECT Id, Regular_Hours__c FROM TimesheetEntry__c
                WHERE Date__c = :entryDate
                AND Project__c = :projId
                AND Task__c = :task
                AND Timesheet__r.Employee__c = :userId
                LIMIT 1
            ];

            // Projected total: for updates subtract the existing entry's hours first
            Double existingEntryHrs = (!existing.isEmpty() && existing[0].Regular_Hours__c != null)
                ? existing[0].Regular_Hours__c : 0;
            Double projectedDayTotal = existing.isEmpty()
                ? existingDayTotal + hrs                      // New entry
                : existingDayTotal - existingEntryHrs + hrs;  // Update: replace hours

            // ⛔ Hard Block: > 12 hours per day (AI-imposed limit via Voice/WhatsApp)
            if (projectedDayTotal > 12) {
                return '⛔ Cannot log ' + hrs + ' hrs for ' + entryDate.format() +
                       '. Daily total would reach ' + String.valueOf(projectedDayTotal.intValue()) + ' hrs, exceeding the 12-hour daily limit for voice/WhatsApp logging.' +
                       ' Already logged: ' + String.valueOf(existingDayTotal.intValue()) + ' hrs. Please contact HR to correct entries in Salesforce directly.';
            }

            // ⚠️ Soft Alert: > 10 hours per day
            if (projectedDayTotal > 10) {
                String dateKey = entryDateStr;
                overtimeTotals.put(dateKey, projectedDayTotal);
                if (!overtimeDates.contains(dateKey)) overtimeDates.add(dateKey);
            }

            // ─── Smart Upsert ─────────────────────────────────────────────────
            if (!existing.isEmpty()) {
                TimesheetEntry__c updateTe = new TimesheetEntry__c(Id = existing[0].Id);
                updateTe.Regular_Hours__c = hrs;
                updateTe.Total_Hours__c   = hrs;
                updateTe.Status__c        = statusVal;
                updateTe.Description__c   = taskDescription;
                update updateTe;
            } else {
                Map<String, Object> payload = new Map<String, Object>{
                    'Project__c'       => projId,
                    'Date__c'          => entryDateStr,
                    'Regular_Hours__c' => hrs,
                    'Total_Hours__c'   => hrs,
                    'Task__c'          => task,
                    'Description__c'   => taskDescription,
                    'Status__c'        => statusVal
                };
                TimesheetController.createMultipleTimesheetEntriesWithUser(new List<Map<String, Object>>{payload}, userId);
            }
        }

        // ─── Post-Loop: Send Overtime Alert if any date exceeded 10 hrs ──────
        String resultMsg = (String)data.get('message') != null ? (String)data.get('message') : 'Timesheet records processed successfully.';
        if (!overtimeDates.isEmpty()) {
            String alertInfo = '';
            for (String d : overtimeDates) {
                Double tot = overtimeTotals.get(d);
                alertInfo += d + ' (' + tot.intValue() + ' hrs) ';
            }
            resultMsg += '\n⚠️ Overtime Alert: You have logged more than 10 hours on ' + alertInfo.trim() + '. Your Reporting Manager and HR have been notified.';
            sendOvertimeAlertEmail(userId, overtimeDates, overtimeTotals);
        }
        return resultMsg;
    }

    /**
     * Sends overtime alert email to Reporting Manager and HR Admin users.
     * ✅ Deduplicated: sends at most ONCE per user per date using Service__c as a log.
     */
    private static void sendOvertimeAlertEmail(Id userId, List<String> overtimeDates, Map<String, Double> overtimeTotals) {
        try {
            // 1. Get employee name + manager
            List<User> empList = [SELECT Id, Name, Email, ManagerId FROM User WHERE Id = :userId LIMIT 1];
            if (empList.isEmpty()) return;
            User emp = empList[0];

            // 2. Filter to dates NOT already alerted today (deduplication via Service__c)
            List<String> newAlertDates = new List<String>();
            for (String d : overtimeDates) {
                String alertKey = 'OT-ALERT-' + String.valueOf(userId).left(15) + '-' + d;
                List<Service__c> already = [
                    SELECT Id FROM Service__c
                    WHERE Name = :alertKey AND CreatedDate = TODAY
                    LIMIT 1
                ];
                if (already.isEmpty()) {
                    newAlertDates.add(d);
                } else {
                    System.debug('ℹ️ Overtime alert already sent today for ' + d + ', skipping.');
                }
            }
            if (newAlertDates.isEmpty()) return; // All dates already alerted today

            List<String> toAddresses = new List<String>();

            // Reporting Manager
            if (emp.ManagerId != null) {
                List<User> managers = [SELECT Email FROM User WHERE Id = :emp.ManagerId AND IsActive = true LIMIT 1];
                if (!managers.isEmpty() && String.isNotBlank(managers[0].Email)) {
                    toAddresses.add(managers[0].Email);
                }
            }

            // HR Admin — users with the 'HR Admin' role
            for (User hrUser : [
                SELECT Email FROM User
                WHERE UserRole.Name = 'HR Admin' AND IsActive = true LIMIT 5
            ]) {
                if (String.isNotBlank(hrUser.Email) && !toAddresses.contains(hrUser.Email)) {
                    toAddresses.add(hrUser.Email);
                }
            }

            if (toAddresses.isEmpty()) {
                System.debug('⚠️ Overtime alert: no manager/HR email addresses found for user ' + userId);
                return;
            }

            // 3. Build email content
            String dateDetails = '';
            for (String d : newAlertDates) {
                dateDetails += '  • ' + d + ' — ' + overtimeTotals.get(d).intValue() + ' hours\n';
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject('⚠️ HRMS Overtime Alert — ' + emp.Name + ' logged 10+ hours');
            mail.setPlainTextBody(
                'This is an automated alert from the HRMS Voice Assistant.\n\n' +
                'Employee : ' + emp.Name + '\n' +
                'Overtime Dates:\n' + dateDetails +
                '\nThe employee has logged more than 10 hours on the above date(s) via the HRMS Voice/WhatsApp Assistant.\n' +
                'Please review if appropriate action is needed.\n\n' +
                '— HRMS Automated Notification'
            );
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('✅ Overtime alert email sent to: ' + String.join(toAddresses, ', '));

            // 4. Log sent alerts to Service__c to prevent duplicates today
            List<Service__c> alertLogs = new List<Service__c>();
            for (String d : newAlertDates) {
                String alertKey = 'OT-ALERT-' + String.valueOf(userId).left(15) + '-' + d;
                Service__c log = new Service__c();
                log.Name         = alertKey;
                log.Email_Body__c = 'Overtime alert sent for ' + emp.Name + ' on ' + d + ' (' + overtimeTotals.get(d).intValue() + ' hrs). Sent to: ' + String.join(toAddresses, ', ');
                log.Whatsapp__c  = true;
                alertLogs.add(log);
            }
            if (!alertLogs.isEmpty()) insert alertLogs;

        } catch (Exception e) {
            System.debug('❌ Overtime alert email failed: ' + e.getMessage());
        }
    }


    // ─── UPDATE LEAVE ──────────────────────────────────────────────────────
    /**
     * Updates Leave Type and/or Reason on a Pending leave request.
     * Blocked if leave is already Approved (user must contact HR).
     */
    private static String handleUpdateLeave(Map<String, Object> data, Id userId) {
        String startDateStr   = (String)data.get('startDate');
        String endDateStr     = (String)data.get('endDate');
        String newLeaveType   = (String)data.get('newLeaveType');
        if (String.isBlank(newLeaveType)) newLeaveType = (String)data.get('leaveType'); // Alias
        String newReason      = (String)data.get('newReason');
        if (String.isBlank(newReason)) newReason = (String)data.get('reason'); // Alias

        if (String.isBlank(startDateStr)) {
            return '⚠️ Please specify the date of the leave you want to update.';
        }
        Date startDate = Date.valueOf(startDateStr);
        Date endDate   = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : startDate;

        // ✅ Past Date Validation for Updates too
        if (startDate < Date.today()) {
            return '⚠️ Cannot update a leave request for a past date (' + startDate.format() + ').';
        }

        // Find existing non-cancelled/rejected leave overlapping the date
        List<Leave_Request__c> leaves = [
            SELECT Id, Status__c, Leave_Type__r.Leave_Type_Name__c, Reason__c, Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND Start_Date__c <= :endDate
            AND End_Date__c   >= :startDate
            AND Status__c NOT IN ('Cancelled', 'Rejected')
            LIMIT 1
        ];
        if (leaves.isEmpty()) {
            return '⚠️ No active leave request found for ' + startDate.format() + '. Nothing to update.';
        }

        Leave_Request__c lr = leaves[0];
        if (lr.Status__c == 'Approved') {
            return '⚠️ Your "' + lr.Leave_Type__r.Leave_Type_Name__c + '" leave (' +
                   lr.Start_Date__c.format() + ' – ' + lr.End_Date__c.format() +
                   ') is already Approved and cannot be changed here. Please contact HR to modify it.';
        }

        // Resolve new leave type if provided
        if (String.isNotBlank(newLeaveType)) {
            Id newLeaveTypeId;
            List<Leave_Type__c> exactTypes = [SELECT Id FROM Leave_Type__c WHERE Leave_Type_Name__c = :newLeaveType LIMIT 1];
            if (!exactTypes.isEmpty()) {
                newLeaveTypeId = exactTypes[0].Id;
            } else {
                String fuzzy = '%' + newLeaveType + '%';
                List<Leave_Type__c> fuzzyTypes = [SELECT Id, Leave_Type_Name__c FROM Leave_Type__c WHERE Leave_Type_Name__c LIKE :fuzzy LIMIT 1];
                if (!fuzzyTypes.isEmpty()) newLeaveTypeId = fuzzyTypes[0].Id;
            }
            if (newLeaveTypeId == null) {
                return '⚠️ Leave type "' + newLeaveType + '" not found. Please use a valid leave type name.';
            }
            lr.Leave_Type__c = newLeaveTypeId;
        }

        // Update reason if provided
        if (String.isNotBlank(newReason)) {
            lr.Reason__c = newReason;
        }

        update lr;

        String msg = '✅ Leave request for ' + lr.Start_Date__c.format();
        if (lr.Start_Date__c != lr.End_Date__c) msg += ' – ' + lr.End_Date__c.format();
        msg += ' updated successfully.';
        if (String.isNotBlank(newLeaveType)) msg += ' Type changed to "' + newLeaveType + '".';
        if (String.isNotBlank(newReason))    msg += ' Reason updated to "' + newReason + '".';
        return msg;
    }

    // ─── CANCEL LEAVE ──────────────────────────────────────────────────────
    /**
     * Cancels a Pending leave request.
     * If Approved, informs user to contact HR instead.
     */
    private static String handleCancelLeave(Map<String, Object> data, Id userId) {
        String startDateStr = (String)data.get('startDate');
        String endDateStr   = (String)data.get('endDate');

        if (String.isBlank(startDateStr)) {
            return '⚠️ Please specify the date of the leave you want to cancel.';
        }
        Date startDate = Date.valueOf(startDateStr);
        Date endDate   = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : startDate;

        List<Leave_Request__c> leaves = [
            SELECT Id, Status__c, Leave_Type__r.Leave_Type_Name__c, Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND Start_Date__c <= :endDate
            AND End_Date__c   >= :startDate
            AND Status__c NOT IN ('Cancelled', 'Rejected')
            LIMIT 1
        ];
        if (leaves.isEmpty()) {
            return '⚠️ No active leave request found for ' + startDate.format() + '.';
        }

        Leave_Request__c lr = leaves[0];
        String leaveName = lr.Leave_Type__r.Leave_Type_Name__c;
        String dateRange = lr.Start_Date__c.format();
        if (lr.Start_Date__c != lr.End_Date__c) dateRange += ' – ' + lr.End_Date__c.format();

        if (lr.Status__c == 'Approved') {
            return '⚠️ Your "' + leaveName + '" leave (' + dateRange + ') is already Approved. ' +
                   'You cannot cancel an approved leave here. Please contact HR or your Reporting Manager to process the cancellation.';
        }

        // Cancel the Pending leave
        lr.Status__c = 'Cancelled';
        update lr;
        return '✅ Your "' + leaveName + '" leave (' + dateRange + ') has been cancelled successfully.';
    }

    private static String handleCheckIn(Map<String, Object> data, Id userId) {
        // Prevent duplicate check-in
        List<Employee_Attendance__c> openSessions = [
            SELECT Id, Date__c FROM Employee_Attendance__c 
            WHERE Employee_Name__c = :userId AND Check_Out_Time__c = null LIMIT 1
        ];
        if (!openSessions.isEmpty()) {
            return 'Wait! You already have an active session from ' + openSessions[0].Date__c + '. Please check out before starting a new one.';
        }

        // Leave check
        Date today = Date.today();
        List<Leave_Request__c> todayLeaves = [
            SELECT Id, Status__c FROM Leave_Request__c 
            WHERE Employee__c = :userId AND Start_Date__c <= :today AND End_Date__c >= :today 
            AND Status__c IN ('Approved', 'Pending') LIMIT 1
        ];
        if (!todayLeaves.isEmpty()) {
            return 'Check-in blocked: You have a ' + todayLeaves[0].Status__c + ' leave request for today.';
        }

        Map<String, Object> payload = new Map<String, Object>{
            'Employee_Name__c' => userId,
            'Date__c' => String.valueOf(today),
            'Check_In_Time__c' => Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
            'Status__c' => 'Present',
            'Work_Location__c' => data.containsKey('workLocation') ? (String)data.get('workLocation') : 'Work from Office',
            'Notes__c' => 'Logged via HRMS Action Service'
        };
        NewController.createAttendance(payload);
        return (String)data.get('message') != null ? (String)data.get('message') : 'Checked in successfully.';
    }

    private static String handleCheckOut(Map<String, Object> data, Id userId) {
        List<Employee_Attendance__c> atts = [
            SELECT Id FROM Employee_Attendance__c 
            WHERE Employee_Name__c = :userId AND Check_Out_Time__c = null
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (atts.isEmpty()) return 'You don\'t have an active check-in record.';
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
            'Status__c' => 'Present'
        };
        EditController.updateAttendance(atts[0].Id, changes);
        return (String)data.get('message') != null ? (String)data.get('message') : 'Checked out successfully.';
    }
    // ─── ATTENDANCE SUMMARY ────────────────────────────────────────────────
    private static String handleAttendanceSummary(Id userId) {
        try {
            Map<String, Object> summary = AttendanceSummaryController.getMonthlySummary(userId);
            if (summary == null || summary.get('success') != true) {
                return 'Could not retrieve your attendance summary for this month.';
            }
            
            String monthName = (String)summary.get('monthName');
            Integer presentDays = (Integer)summary.get('presentDays');
            Integer lateDays = (Integer)summary.get('lateDays');
            Integer absentDays = (Integer)summary.get('absentDays');
            String totalHours = (String)summary.get('totalHours');
            
            String result = '📋 Your Attendance Summary for ' + monthName + ':\n';
            result += '✅ Present Days: ' + presentDays + '\n';
            result += '⏰ Late Days: ' + lateDays + '\n';
            result += '❌ Absent Days: ' + absentDays + '\n';
            result += '⏱️ Total Hours: ' + totalHours + ' hrs\n';
            
            return result;
        } catch (Exception e) {
            System.debug('Error in handleAttendanceSummary: ' + e.getMessage());
            return 'Failed to generate attendance summary: ' + e.getMessage();
        }
    }

    // ─── LEAVE BALANCE ────────────────────────────────────────────────────
    private static String handleLeaveBalance(Id userId) {
        String yearStr = String.valueOf(Date.today().year());
        List<Employee_Leave_Balance__c> balances = [
            SELECT Leave_Type__r.Leave_Type_Name__c, Total_Allocated__c, Available__c, Used__c, Booked__c
            FROM Employee_Leave_Balance__c
            WHERE Employee__c = :userId AND Year__c = :yearStr AND Is_Active__c = true AND Is_Eligible__c = true
            ORDER BY Leave_Type__r.Leave_Type_Name__c ASC
        ];
        if (balances.isEmpty()) {
            return 'No leave balance records found for ' + yearStr + '. Please contact your HR administrator.';
        }
        String result = '📋 Your Leave Balances for ' + yearStr + ':\n';
        for (Employee_Leave_Balance__c lb : balances) {
            Double avail  = lb.Available__c       != null ? lb.Available__c       : 0;
            Double total  = lb.Total_Allocated__c != null ? lb.Total_Allocated__c : 0;
            // Booked__c = days deducted from available (what portal labels as "Used")
            // Used__c   = pending leave requests not yet taken (what portal labels as "Pending")
            Double used   = lb.Booked__c != null ? lb.Booked__c : 0;  // portal "Used"
            Double pending = lb.Used__c  != null ? lb.Used__c  : 0;  // portal "Pending"
            String status = avail <= 0 ? ' ❌ No balance' : '';
            result += '• ' + lb.Leave_Type__r.Leave_Type_Name__c + ': ' + avail.intValue() + ' days available' +
                      ' (Total: ' + total.intValue() + ', Used: ' + used.intValue() +
                      (pending > 0 ? ', Pending: ' + pending.intValue() : '') + ')' + status + '\n';
        }
        return result;
    }

    private static String handleLeaveApplication(Map<String, Object> data, Id userId) {
        String leaveTypeName = (String)data.get('leaveType');
        String startDateStr = (String)data.get('startDate');
        String endDateStr = (String)data.get('endDate');
        String reason = (String)data.get('reason');
        
        System.debug('🏖️ handleLeaveApplication: leaveType=' + leaveTypeName + ', startDate=' + startDateStr + ', userId=' + userId);

        if (String.isBlank(leaveTypeName) || String.isBlank(startDateStr)) {
            return 'Missing leave details. LeaveType=' + leaveTypeName + ', StartDate=' + startDateStr;
        }

        // ✅ No Past Date for Leave: Cannot apply leave for dates already passed
        Date startDateParsed = Date.valueOf(startDateStr);
        if (startDateParsed < Date.today()) {
            return '⚠️ Cannot apply leave for a past date (' + startDateParsed.format() + '). Leave requests must be for today or a future date.';
        }

        // ✅ Weekend Validation: Leave cannot be applied for weekend dates
        Date endDateEarly = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : startDateParsed;
        if (isWeekend(startDateParsed)) {
            Date suggestion = nextWeekday(startDateParsed);
            return '⚠️ ' + startDateParsed.format() + ' is a ' + weekdayName(startDateParsed) +
                   '. Leave cannot be applied on weekends. Did you mean ' + suggestion.format() + ' (' + weekdayName(suggestion) + ')?';
        }
        if (isWeekend(endDateEarly)) {
            Date suggestion = prevWeekday(endDateEarly);
            return '⚠️ End date ' + endDateEarly.format() + ' is a ' + weekdayName(endDateEarly) +
                   '. Please use a working day as the end date. Did you mean ' + suggestion.format() + ' (' + weekdayName(suggestion) + ')?';
        }

        // 1. Resolve Leave Type ID — Try direct lookup first (exact, then fuzzy), then fall back to balance
        Id leaveTypeId;

        // Exact match on Leave_Type__c object
        List<Leave_Type__c> exactTypes = [
            SELECT Id FROM Leave_Type__c 
            WHERE Leave_Type_Name__c = :leaveTypeName 
            LIMIT 1
        ];
        if (!exactTypes.isEmpty()) {
            leaveTypeId = exactTypes[0].Id;
            System.debug('✅ Leave type found via exact match: ' + leaveTypeId);
        }

        // Fuzzy LIKE match
        if (leaveTypeId == null) {
            String fuzzy = '%' + leaveTypeName + '%';
            List<Leave_Type__c> fuzzyTypes = [
                SELECT Id, Leave_Type_Name__c FROM Leave_Type__c 
                WHERE Leave_Type_Name__c LIKE :fuzzy 
                LIMIT 1
            ];
            if (!fuzzyTypes.isEmpty()) {
                leaveTypeId = fuzzyTypes[0].Id;
                System.debug('✅ Leave type found via fuzzy match: ' + fuzzyTypes[0].Leave_Type_Name__c);
            }
        }

        // Fallback: via Employee_Leave_Balance__c
        if (leaveTypeId == null) {
            String yearStr = String.valueOf(Date.today().year());
            List<Employee_Leave_Balance__c> balances = [
                SELECT Leave_Type__c FROM Employee_Leave_Balance__c 
                WHERE Employee__c = :userId AND Year__c = :yearStr 
                LIMIT 1
            ];
            if (!balances.isEmpty()) {
                leaveTypeId = balances[0].Leave_Type__c;
                System.debug('✅ Leave type found via balance fallback: ' + leaveTypeId);
            }
        }

        if (leaveTypeId == null) {
            System.debug('❌ No leave type found for: ' + leaveTypeName);
            return 'Could not find leave type: "' + leaveTypeName + '". Please use a valid leave type name.';
        }

        // ✅ Balance Check: Block if Available__c = 0, suggest alternatives
        String yearStr2 = String.valueOf(Date.today().year());
        List<Employee_Leave_Balance__c> balCheck = [
            SELECT Available__c FROM Employee_Leave_Balance__c
            WHERE Employee__c = :userId AND Leave_Type__c = :leaveTypeId AND Year__c = :yearStr2
            LIMIT 1
        ];
        if (!balCheck.isEmpty() && (balCheck[0].Available__c == null || balCheck[0].Available__c <= 0)) {
            List<Employee_Leave_Balance__c> alternatives = [
                SELECT Leave_Type__r.Leave_Type_Name__c, Available__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :userId AND Year__c = :yearStr2
                AND Is_Active__c = true AND Is_Eligible__c = true AND Available__c > 0
                ORDER BY Available__c DESC LIMIT 5
            ];
            String msg = '❌ You have no remaining "' + leaveTypeName + '" balance for ' + yearStr2 + '.';
            if (!alternatives.isEmpty()) {
                msg += ' \nYou can use: ';
                List<String> opts = new List<String>();
                for (Employee_Leave_Balance__c alt : alternatives) {
                    opts.add(alt.Leave_Type__r.Leave_Type_Name__c + ' (' + alt.Available__c.intValue() + ' days)');
                }
                msg += String.join(opts, ', ') + '.';
            } else {
                msg += ' No other leave types have remaining balance. Please contact HR.';
            }
            return msg;
        }

        // ✅ Duplicate Leave Check: Block if any Pending/Approved leave overlaps the requested dates
        Date endDateFinal = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : startDateParsed;
        List<Leave_Request__c> overlapping = [
            SELECT Id, Leave_Type__r.Leave_Type_Name__c, Start_Date__c, End_Date__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND Start_Date__c <= :endDateFinal
            AND End_Date__c   >= :startDateParsed
            AND Status__c NOT IN ('Rejected', 'Cancelled')
            LIMIT 1
        ];
        if (!overlapping.isEmpty()) {
            Leave_Request__c dup = overlapping[0];
            return '⚠️ You already have a ' + dup.Status__c + ' "' + dup.Leave_Type__r.Leave_Type_Name__c +
                   '" leave request from ' + dup.Start_Date__c.format() + ' to ' + dup.End_Date__c.format() +
                   '. Duplicate leave requests for the same dates are not allowed.';
        }

        // 2. Prepare Leave Request Record
        Leave_Request__c req = new Leave_Request__c();
        req.Employee__c    = userId;
        req.Leave_Type__c  = leaveTypeId;
        req.Start_Date__c  = startDateParsed;
        req.End_Date__c    = endDateFinal;
        req.Reason__c      = String.isNotBlank(reason) ? reason : 'Requested via HRMS Voice Assistant';
        req.Total_Days__c  = Double.valueOf(req.Start_Date__c.daysBetween(req.End_Date__c) + 1);

        System.debug('📋 Creating Leave_Request__c: Employee=' + req.Employee__c + ', LeaveType=' + req.Leave_Type__c + ', Start=' + req.Start_Date__c + ', End=' + req.End_Date__c);

        // 3. Submit using existing controller logic
        try {
            String reqId = LeaveRequestController.submitLeaveRequest(req);
            System.debug('✅ Leave submitted, ID: ' + reqId);
            return (String)data.get('message') != null ? (String)data.get('message') : 'Leave request submitted successfully (ID: ' + reqId + ').';
        } catch (Exception e) {
            System.debug('❌ Leave submission error: ' + e.getMessage());
            return 'Leave application failed: ' + e.getMessage();
        }
    }

    // ─── DATE HELPERS ─────────────────────────────────────────────
    // Returns 0=Sunday, 1=Monday, ..., 5=Friday, 6=Saturday
    private static Integer dayOfWeekNum(Date d) {
        return d.toStartOfWeek().daysBetween(d);
    }
    private static Boolean isWeekend(Date d) {
        Integer dow = dayOfWeekNum(d);
        return dow == 0 || dow == 6; // Sunday=0, Saturday=6
    }
    private static Date nextWeekday(Date d) {
        Date next = d.addDays(1);
        while (isWeekend(next)) next = next.addDays(1);
        return next;
    }
    private static Date prevWeekday(Date d) {
        Date prev = d.addDays(-1);
        while (isWeekend(prev)) prev = prev.addDays(-1);
        return prev;
    }
    private static String weekdayName(Date d) {
        String[] names = new String[]{'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
        return names[dayOfWeekNum(d)];
    }
}