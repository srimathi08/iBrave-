public without sharing class TimesheetApprovalService {
    
    /* =====================================================================================
       1. SEND APPROVAL REQUEST EMAIL TO MANAGER
    ===================================================================================== */
    @AuraEnabled
    public static Map<String, Object> sendApprovalRequestToManager(Integer weekNumber, Integer year) {
        try {
            Id userId = UserInfo.getUserId();
            
            System.debug('=== APPROVAL REQUEST START ===');
            System.debug('User ID: ' + userId);
            System.debug('User Type: ' + UserInfo.getUserType());
            System.debug('Week: ' + weekNumber + ', Year: ' + year);
            
            // Get the timesheet record
            Timesheet__c sheet = [
                SELECT Id, Employee__c, Manager__c, Week_Number__c, Week_Year__c, 
                       Approval_Status__c, Employee__r.Name, Employee__r.Email,
                       Manager__r.Name, Manager__r.Email
                FROM Timesheet__c
                WHERE Employee__c = :userId
                  AND Week_Number__c = :weekNumber
                  AND Week_Year__c = :year
                LIMIT 1
            ];
            
            System.debug('Timesheet found: ' + sheet.Id);
            System.debug('Manager ID: ' + sheet.Manager__c);
            System.debug('Manager Name: ' + sheet.Manager__r.Name);
            System.debug('Manager Email: ' + sheet.Manager__r.Email);
            
            if (sheet.Manager__c == null) {
                throw new AuraHandledException('No manager assigned for this timesheet.');
            }
            
            // Get all entries for this week
            List<TimesheetEntry__c> entries = [
                SELECT Id, Date__c, Project__r.Name, Task__c, 
                       Total_Hours__c, Regular_Hours__c, Overtime_Hours__c
                FROM TimesheetEntry__c
                WHERE Timesheet__c = :sheet.Id
                ORDER BY Date__c
            ];
            
            System.debug('Entries found: ' + entries.size());
            
            if (entries.isEmpty()) {
                throw new AuraHandledException('No timesheet entries found for this week.');
            }
            
            // Update timesheet status BEFORE sending email
            sheet.Approval_Status__c = 'Submitted';
            sheet.Submitted_Date__c = DateTime.now();
            update sheet;
            
            System.debug('Timesheet status updated to Submitted');
            
            // Update entry statuses
            for (TimesheetEntry__c entry : entries) {
                entry.Approval_Status__c = 'Submitted';
                entry.Submitted_Date__c = DateTime.now();
            }
            update entries;
            
            System.debug('Entry statuses updated to Submitted');
            
            // ⭐ FIX: Use @future method to send email from community users
            if (UserInfo.getUserType() == 'CspLitePortal' || 
                UserInfo.getUserType() == 'PowerCustomerSuccess' ||
                UserInfo.getUserType() == 'CustomerSuccess') {
                // Community user - send email asynchronously
                System.debug('Community user detected - sending email via @future');
                sendEmailAsync(sheet.Id);
            } else {
                // Internal user - send email directly
                System.debug('Internal user - sending email directly');
                sendManagerApprovalEmail(sheet, entries);
            }
            
            Map<String, Object> response = new Map<String, Object>();
            response.put('success', true);
            response.put('message', 'Approval request sent to ' + sheet.Manager__r.Name);
            response.put('managerEmail', sheet.Manager__r.Email);
            response.put('managerName', sheet.Manager__r.Name);
            response.put('entriesSubmitted', entries.size());
            
            System.debug('=== APPROVAL REQUEST COMPLETE ===');
            System.debug('Response: ' + JSON.serialize(response));
            
            return response;
            
        } catch (Exception e) {
            System.debug('ERROR in sendApprovalRequestToManager: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sending approval request: ' + e.getMessage());
        }
    }
    
    /* =====================================================================================
       1A. ASYNC EMAIL SENDER FOR COMMUNITY USERS
    ===================================================================================== */
    @future
    public static void sendEmailAsync(Id timesheetId) {
        try {
            System.debug('=== ASYNC EMAIL START ===');
            System.debug('Timesheet ID: ' + timesheetId);
            
            // Re-query timesheet with all details
            Timesheet__c sheet = [
                SELECT Id, Employee__c, Manager__c, Week_Number__c, Week_Year__c, 
                       Approval_Status__c, Employee__r.Name, Employee__r.Email,
                       Manager__r.Name, Manager__r.Email
                FROM Timesheet__c
                WHERE Id = :timesheetId
                LIMIT 1
            ];
            
            // Get entries
            List<TimesheetEntry__c> entries = [
                SELECT Id, Date__c, Project__r.Name, Task__c, 
                       Total_Hours__c, Regular_Hours__c, Overtime_Hours__c
                FROM TimesheetEntry__c
                WHERE Timesheet__c = :timesheetId
                ORDER BY Date__c
            ];
            
            System.debug('Sending email for ' + entries.size() + ' entries');
            
            // Send the email
            sendManagerApprovalEmail(sheet, entries);
            
            System.debug('=== ASYNC EMAIL COMPLETE ===');
            
        } catch (Exception e) {
            System.debug('ERROR in sendEmailAsync: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /* =====================================================================================
       2. SEND EMAIL TO MANAGER
    ===================================================================================== */
    private static void sendManagerApprovalEmail(Timesheet__c sheet, List<TimesheetEntry__c> entries) {
        
        // Generate unique approval token
        String approvalToken = generateApprovalToken(sheet.Id);
        
        // Store token in a custom object or field for validation
        sheet.Approval_Token__c = approvalToken;
        sheet.Token_Expiry__c = DateTime.now().addDays(7); // Token valid for 7 days
        update sheet;
        
        // Build email body
        String emailBody = buildApprovalEmailBody(sheet, entries, approvalToken);
        
        // DEBUGGING: Log email details
        System.debug('=== EMAIL DEBUG ===');
        System.debug('Manager Email: ' + sheet.Manager__r.Email);
        System.debug('Manager Name: ' + sheet.Manager__r.Name);
        System.debug('Approval Token: ' + approvalToken);
        System.debug('Email Subject: Timesheet Approval Required: ' + sheet.Employee__r.Name);
        
        // Check if manager has email
        if (String.isBlank(sheet.Manager__r.Email)) {
            throw new AuraHandledException('Manager does not have an email address configured.');
        }
        
        try {
            // Send email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { sheet.Manager__r.Email });
            mail.setSubject('Timesheet Approval Required: ' + sheet.Employee__r.Name + ' - Week ' + sheet.Week_Number__c + ', ' + sheet.Week_Year__c);
            mail.setHtmlBody(emailBody);
            mail.setSaveAsActivity(false);
            //  GENERIC ORG-WIDE EMAIL 
if (!Test.isRunningTest()) {
    OrgWideEmailAddress owea = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = true
        LIMIT 1
    ];
    mail.setOrgWideEmailAddressId(owea.Id);
}
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            // Check if email was sent successfully
            if (results[0].isSuccess()) {
                System.debug('Email sent successfully to: ' + sheet.Manager__r.Email);
            } else {
                System.debug('Email send failed. Errors:');
                for (Messaging.SendEmailError error : results[0].getErrors()) {
                    System.debug('Error: ' + error.getMessage());
                }
                throw new AuraHandledException('Failed to send email: ' + results[0].getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            System.debug('Exception sending email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sending approval email: ' + e.getMessage());
        }
    }
    
    /* =====================================================================================
       3. BUILD EMAIL BODY WITH APPROVAL LINKS
    ===================================================================================== */
    private static String buildApprovalEmailBody(Timesheet__c sheet, List<TimesheetEntry__c> entries, String token) {
        
        // Get base URL for your org (compatible with all API versions)
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        
        // Build approval/rejection links
        String approveUrl = baseUrl + '/apex/TimesheetApprovalPage?action=approve&token=' + token;
        String rejectUrl = baseUrl + '/apex/TimesheetApprovalPage?action=reject&token=' + token;
        
        // Calculate totals
        Decimal totalHours = 0;
        Decimal regularHours = 0;
        Decimal overtimeHours = 0;
        
        for (TimesheetEntry__c entry : entries) {
            totalHours += (entry.Total_Hours__c != null ? entry.Total_Hours__c : 0);
            regularHours += (entry.Regular_Hours__c != null ? entry.Regular_Hours__c : 0);
            overtimeHours += (entry.Overtime_Hours__c != null ? entry.Overtime_Hours__c : 0);
        }
        
        // Build HTML email
        String html = '<html><body style="font-family: Arial, sans-serif;">';
        html += '<div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd;">';
        html += '<h2 style="color: #333;">Timesheet Approval Request</h2>';
        html += '<p>Hello ' + sheet.Manager__r.Name + ',</p>';
        html += '<p><strong>' + sheet.Employee__r.Name + '</strong> has submitted their timesheet for your approval.</p>';
        
        html += '<div style="background-color: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px;">';
        html += '<h3 style="margin-top: 0;">Week ' + sheet.Week_Number__c + ', ' + sheet.Week_Year__c + '</h3>';
        html += '<p><strong>Total Hours:</strong> ' + totalHours + '</p>';
        html += '<p><strong>Regular Hours:</strong> ' + regularHours + '</p>';
        html += '<p><strong>Overtime Hours:</strong> ' + overtimeHours + '</p>';
        html += '</div>';
        
        // Entry details table
        html += '<h3>Timesheet Entries:</h3>';
        html += '<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">';
        html += '<thead><tr style="background-color: #4CAF50; color: white;">';
        html += '<th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Date</th>';
        html += '<th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Project</th>';
        html += '<th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Task</th>';
        html += '<th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Hours</th>';
        html += '</tr></thead><tbody>';
        
        for (TimesheetEntry__c entry : entries) {
            html += '<tr>';
            html += '<td style="padding: 8px; border: 1px solid #ddd;">' + entry.Date__c.format() + '</td>';
            html += '<td style="padding: 8px; border: 1px solid #ddd;">' + (entry.Project__r.Name != null ? entry.Project__r.Name : '-') + '</td>';
            html += '<td style="padding: 8px; border: 1px solid #ddd;">' + (entry.Task__c != null ? entry.Task__c : '-') + '</td>';
            html += '<td style="padding: 8px; border: 1px solid #ddd; text-align: right;">' + entry.Total_Hours__c + '</td>';
            html += '</tr>';
        }
        
        html += '</tbody></table>';
        
        // Action buttons
        html += '<div style="margin-top: 30px; text-align: center;">';
        html += '<a href="' + approveUrl + '" style="display: inline-block; padding: 12px 30px; margin: 10px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">Approve</a>';
        html += '<a href="' + rejectUrl + '" style="display: inline-block; padding: 12px 30px; margin: 10px; background-color: #f44336; color: white; text-decoration: none; border-radius: 5px; font-weight: bold;">Reject</a>';
        html += '</div>';
        
        html += '<p style="margin-top: 30px; font-size: 12px; color: #666;">This approval link will expire in 7 days.</p>';
        html += '<p style="font-size: 12px; color: #666;">If you cannot click the buttons above, copy and paste these links:</p>';
        html += '<p style="font-size: 11px; color: #666;">Approve: ' + approveUrl + '</p>';
        html += '<p style="font-size: 11px; color: #666;">Reject: ' + rejectUrl + '</p>';
        
        html += '</div></body></html>';
        
        return html;
    }
    
    /* =====================================================================================
       4. GENERATE SECURE APPROVAL TOKEN
    ===================================================================================== */
    private static String generateApprovalToken(Id timesheetId) {
        // Create a unique token using timesheet ID and timestamp
        String timestamp = String.valueOf(DateTime.now().getTime());
        String combined = timesheetId + timestamp + UserInfo.getOrganizationId();
        
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(combined));
        return EncodingUtil.convertToHex(hash).substring(0, 32);
    }
    
    /* =====================================================================================
       5. PROCESS APPROVAL (Called from Visualforce page or API)
    ===================================================================================== */
    @AuraEnabled
    public static Map<String, Object> processApproval(String token, String action, String comments) {
        try {
            // Validate token
            List<Timesheet__c> sheets = [
                SELECT Id, Employee__c, Manager__c, Approval_Status__c, 
                       Token_Expiry__c, Employee__r.Name, Employee__r.Email,
                       Week_Number__c, Week_Year__c
                FROM Timesheet__c
                WHERE Approval_Token__c = :token
                  AND Token_Expiry__c >= :DateTime.now()
                LIMIT 1
            ];
            
            if (sheets.isEmpty()) {
                throw new AuraHandledException('Invalid or expired approval link.');
            }
            
            Timesheet__c sheet = sheets[0];
            
            // Verify current user is the manager
            if (UserInfo.getUserId() != sheet.Manager__c) {
                throw new AuraHandledException('You are not authorized to approve this timesheet.');
            }
            
            // Update timesheet status
            if (action == 'approve') {
                sheet.Approval_Status__c = 'Approved';
                sheet.Approved_Date__c = DateTime.now();
                sheet.Approved_By__c = UserInfo.getUserId();
            } else if (action == 'reject') {
                sheet.Approval_Status__c = 'Rejected';
                sheet.Rejected_Date__c = DateTime.now();
                sheet.Rejected_By__c = UserInfo.getUserId();
            } else {
                throw new AuraHandledException('Invalid action.');
            }
            
            sheet.Approval_Comments__c = comments;
            sheet.Approval_Token__c = null; // Invalidate token
            update sheet;
            
            // Update all related entries
            List<TimesheetEntry__c> entries = [
                SELECT Id FROM TimesheetEntry__c WHERE Timesheet__c = :sheet.Id
            ];
            
            for (TimesheetEntry__c entry : entries) {
                entry.Approval_Status__c = sheet.Approval_Status__c;
            }
            update entries;
            
            // Send confirmation email to employee
            sendEmployeeNotificationEmail(sheet, action, comments);
            
            Map<String, Object> response = new Map<String, Object>();
            response.put('success', true);
            response.put('action', action);
            response.put('message', 'Timesheet ' + action + 'd successfully');
            
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing approval: ' + e.getMessage());
        }
    }
    
    /* =====================================================================================
       6. SEND NOTIFICATION TO EMPLOYEE
    ===================================================================================== */
    private static void sendEmployeeNotificationEmail(Timesheet__c sheet, String action, String comments) {
        
        String status = action == 'approve' ? 'Approved' : 'Rejected';
        String color = action == 'approve' ? '#4CAF50' : '#f44336';
        
        String html = '<html><body style="font-family: Arial, sans-serif;">';
        html += '<div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #ddd;">';
        html += '<h2 style="color: ' + color + ';">Timesheet ' + status + '</h2>';
        html += '<p>Hello ' + sheet.Employee__r.Name + ',</p>';
        html += '<p>Your timesheet for Week ' + sheet.Week_Number__c + ', ' + sheet.Week_Year__c + ' has been <strong>' + status.toLowerCase() + '</strong>.</p>';
        
        if (String.isNotBlank(comments)) {
            html += '<div style="background-color: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px;">';
            html += '<h3 style="margin-top: 0;">Comments:</h3>';
            html += '<p>' + comments + '</p>';
            html += '</div>';
        }
        
        if (action == 'reject') {
            html += '<p>Please make necessary corrections and resubmit your timesheet.</p>';
        }
        
        html += '</div></body></html>';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { sheet.Employee__r.Email });
        mail.setSubject('Timesheet ' + status + ': Week ' + sheet.Week_Number__c + ', ' + sheet.Week_Year__c);
        mail.setHtmlBody(html);
        mail.setSaveAsActivity(false);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
    
    /* =====================================================================================
       7. ALLOW MANAGER TO VIEW PENDING APPROVALS
    ===================================================================================== */
    @AuraEnabled(cacheable=false)
    public static List<Timesheet__c> getPendingApprovals() {
        Id managerId = UserInfo.getUserId();
        
        return [
            SELECT Id, Employee__r.Name, Week_Number__c, Week_Year__c, 
                   Submitted_Date__c, Approval_Status__c,
                   (SELECT Id, Date__c, Project__r.Name, Total_Hours__c 
                    FROM TimesheetEntry__r)
            FROM Timesheet__c
            WHERE Manager__c = :managerId
              AND Approval_Status__c = 'Submitted'
            ORDER BY Submitted_Date__c DESC
        ];
    }
}