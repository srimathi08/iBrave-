public without sharing class TimesheetApprovalController {
    
    public String token { get; set; }
    public String action { get; set; }
    public String comments { get; set; }
    
    public Boolean showForm { get; set; }
    public Boolean showMessage { get; set; }
    public Boolean isSuccess { get; set; }
    public Boolean isLoading { get; set; }
    public String message { get; set; }
    
    // Timesheet details
    public String employeeName { get; set; }
    public Integer weekNumber { get; set; }
    public Integer weekYear { get; set; }
    public Decimal totalHours { get; set; }
    public DateTime submittedDate { get; set; }
    public List<TimesheetEntry__c> entries { get; set; }
    
    private Timesheet__c timesheet;
    
    public TimesheetApprovalController() {
        // Get parameters from URL
        token = ApexPages.currentPage().getParameters().get('token');
        action = ApexPages.currentPage().getParameters().get('action');
        
        showForm = false;
        showMessage = false;
        isLoading = false;
        isSuccess = false;
        comments = '';
        
        if (String.isBlank(token)) {
            showMessage = true;
            isSuccess = false;
            message = 'Invalid approval link. Token is missing.';
            return;
        }
        
        // Load timesheet data (NO DML here)
        loadTimesheetData();
        
        // ⭐ FIX: Don't auto-process in constructor - wait for button click
        // Remove auto-processing logic from constructor
    }
    
    private void loadTimesheetData() {
        try {
            // Query timesheet with token (READ ONLY - no DML)
            List<Timesheet__c> sheets = [
                SELECT Id, Employee__c, Manager__c, Week_Number__c, Week_Year__c,
                       Approval_Status__c, Submitted_Date__c, Token_Expiry__c,
                       Employee__r.Name, Manager__r.Name
                FROM Timesheet__c
                WHERE Approval_Token__c = :token
                LIMIT 1
            ];
            
            if (sheets.isEmpty()) {
                showMessage = true;
                isSuccess = false;
                message = 'Invalid or expired approval link.';
                return;
            }
            
            timesheet = sheets[0];
            
            // Check if token is expired
            if (timesheet.Token_Expiry__c < DateTime.now()) {
                showMessage = true;
                isSuccess = false;
                message = 'This approval link has expired. Please contact the employee for a new link.';
                return;
            }
            
            // Check if already processed
            if (timesheet.Approval_Status__c != 'Submitted') {
                showMessage = true;
                isSuccess = true;
                message = 'This timesheet has already been ' + timesheet.Approval_Status__c.toLowerCase() + '.';
                return;
            }
            
            // Verify current user is the manager (if logged in)
            if (UserInfo.getUserType() != 'Guest' && UserInfo.getUserId() != timesheet.Manager__c) {
                showMessage = true;
                isSuccess = false;
                message = 'You are not authorized to approve this timesheet.';
                return;
            }
            
            // Load timesheet entries (READ ONLY)
            entries = [
                SELECT Id, Date__c, Project__r.Name, Task__c, Description__c,
                       Total_Hours__c, Regular_Hours__c, Overtime_Hours__c
                FROM TimesheetEntry__c
                WHERE Timesheet__c = :timesheet.Id
                ORDER BY Date__c
            ];
            
            // Calculate total hours
            totalHours = 0;
            for (TimesheetEntry__c entry : entries) {
                totalHours += (entry.Total_Hours__c != null ? entry.Total_Hours__c : 0);
            }
            
            // Populate display fields
            employeeName = timesheet.Employee__r.Name;
            weekNumber = Integer.valueOf(timesheet.Week_Number__c);
            weekYear = Integer.valueOf(timesheet.Week_Year__c);
            submittedDate = timesheet.Submitted_Date__c;
            
            // Show the approval form
            showForm = true;
            
        } catch (Exception e) {
            showMessage = true;
            isSuccess = false;
            message = 'Error loading timesheet: ' + e.getMessage();
            System.debug('Error in loadTimesheetData: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
    
    // ⭐ FIX: These methods now use reRender properly
    public PageReference approveTimesheet() {
        processApproval('approve');
        return null; // Stay on same page
    }
    
    public PageReference rejectTimesheet() {
        processApproval('reject');
        return null; // Stay on same page
    }
    
    private void processApproval(String approvalAction) {
        try {
            System.debug('=== APPROVAL PROCESS START ===');
            System.debug('Action: ' + approvalAction);
            System.debug('Comments: ' + comments);
            
            isLoading = true;
            
            if (timesheet == null) {
                throw new CustomException('Timesheet data not loaded.');
            }
            
            // Re-query to ensure we have latest data (avoid stale data issues)
            timesheet = [
                SELECT Id, Employee__c, Manager__c, Week_Number__c, Week_Year__c,
                       Approval_Status__c, Submitted_Date__c, Token_Expiry__c,
                       Approval_Token__c, Employee__r.Name, Employee__r.Email
                FROM Timesheet__c
                WHERE Id = :timesheet.Id
                LIMIT 1
            ];
            
            // Validate timesheet is still in submitted state
            if (timesheet.Approval_Status__c != 'Submitted') {
                throw new CustomException('This timesheet has already been processed.');
            }
            
            // Validate token hasn't been used
            if (String.isBlank(timesheet.Approval_Token__c)) {
                throw new CustomException('This approval link has already been used.');
            }
            
            // Update timesheet
            if (approvalAction == 'approve') {
                timesheet.Approval_Status__c = 'Approved';
                timesheet.Approved_Date__c = DateTime.now();
                if (UserInfo.getUserType() != 'Guest') {
                    timesheet.Approved_By__c = UserInfo.getUserId();
                }
            } else {
                timesheet.Approval_Status__c = 'Rejected';
                timesheet.Rejected_Date__c = DateTime.now();
                if (UserInfo.getUserType() != 'Guest') {
                    timesheet.Rejected_By__c = UserInfo.getUserId();
                }
            }
            
            timesheet.Approval_Comments__c = comments;
            timesheet.Approval_Token__c = null; // Invalidate token
            
            System.debug('Updating timesheet: ' + timesheet.Id);
            update timesheet;
            
            // Update all related entries
            List<TimesheetEntry__c> entriesToUpdate = [
                SELECT Id, Approval_Status__c
                FROM TimesheetEntry__c
                WHERE Timesheet__c = :timesheet.Id
            ];
            
            for (TimesheetEntry__c entry : entriesToUpdate) {
                entry.Approval_Status__c = timesheet.Approval_Status__c;
            }
            
            System.debug('Updating ' + entriesToUpdate.size() + ' entries');
            update entriesToUpdate;
            
            // Send notification email to employee
            sendEmployeeNotification(approvalAction);
            
            // Show success message
            isLoading = false;
            showForm = false;
            showMessage = true;
            isSuccess = true;
            
            String actionText = (approvalAction == 'approve') ? 'approved' : 'rejected';
            message = 'Timesheet has been ' + actionText + ' successfully. The employee has been notified.';
            
            System.debug('=== APPROVAL PROCESS COMPLETE ===');
            
        } catch (Exception e) {
            isLoading = false;
            showForm = false;
            showMessage = true;
            isSuccess = false;
            message = 'Error processing approval: ' + e.getMessage();
            System.debug('Error in processApproval: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
    
    private void sendEmployeeNotification(String approvalAction) {
        try {
            String status = (approvalAction == 'approve') ? 'Approved' : 'Rejected';
            String color = (approvalAction == 'approve') ? '#4CAF50' : '#f44336';
            
            String html = '<html><body style="font-family: Arial, sans-serif;">';
            html += '<div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd;">';
            html += '<h2 style="color: ' + color + ';">Timesheet ' + status + '</h2>';
            html += '<p>Hello ' + employeeName + ',</p>';
            html += '<p>Your timesheet for Week ' + weekNumber + ', ' + weekYear + ' has been <strong>' + status.toLowerCase() + '</strong>.</p>';
            
            if (String.isNotBlank(comments)) {
                html += '<div style="background-color: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px;">';
                html += '<h3 style="margin-top: 0;">Manager Comments:</h3>';
                html += '<p>' + comments.escapeHtml4() + '</p>';
                html += '</div>';
            }
            
            if (approvalAction == 'reject') {
                html += '<p>Please review the comments above, make necessary corrections, and resubmit your timesheet.</p>';
            } else {
                html += '<p>No further action is required from you.</p>';
            }
            
            html += '<div style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">';
            html += '<p>Total Hours: ' + totalHours + '</p>';
            html += '<p>Processed on: ' + DateTime.now().format('MMM dd, yyyy \'at\' hh:mm a') + '</p>';
            html += '</div>';
            
            html += '</div></body></html>';
            
            // Get employee email
            User employee = [SELECT Email FROM User WHERE Id = :timesheet.Employee__c LIMIT 1];
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { employee.Email });
            mail.setSubject('Timesheet ' + status + ': Week ' + weekNumber + ', ' + weekYear);
            mail.setHtmlBody(html);
            mail.setSaveAsActivity(false);
            
            // Use Org-Wide Email if available
            List<OrgWideEmailAddress> owea = [
                SELECT Id 
                FROM OrgWideEmailAddress 
                WHERE DisplayName = 'Timesheet Notifications' 
                OR DisplayName = 'No Reply'
                LIMIT 1
            ];
            
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending employee notification: ' + e.getMessage());
            // Don't throw exception - approval already processed
        }
    }
    
    public class CustomException extends Exception {}
}