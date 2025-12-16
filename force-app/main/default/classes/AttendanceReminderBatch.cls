/**
 * Batch class to send check-in reminder emails at 12 PM daily
 * Only sends to users who haven't checked in and don't have leave
 * @author Salesforce Developer
 * @date 2025-11-11
 */
public class AttendanceReminderBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    // Track statistics
    private Integer emailsSent = 0;
    private Integer usersProcessed = 0;
    private Integer usersOnLeave = 0;
    private Integer usersAlreadyCheckedIn = 0;
    
    /**
     * Start method - Get all active employees
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== ATTENDANCE REMINDER BATCH STARTED ===');
        System.debug('Start Time: ' + System.now());
        
        // Query all active users with Employee_Id__c (actual employees)
        String query = 'SELECT Id, Name, Email, Employee_Id__c ' +
                      'FROM User ' +
                      'WHERE IsActive = true ' +
                      'AND Employee_Id__c != null ' +
                      'AND Email != null';
        
        return Database.getQueryLocator(query);
    }
    
    /**
     * Execute method - Process each batch of users
     */
    public void execute(Database.BatchableContext bc, List<User> users) {
        Date today = Date.today();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        // Get all employee IDs for this batch
        Set<Id> employeeIds = new Set<Id>();
        for (User u : users) {
            employeeIds.add(u.Id);
        }
        
        // Check who has already checked in today
        Set<Id> checkedInUsers = getCheckedInUsers(employeeIds, today);
        
        // Check who has leave today
        Set<Id> usersOnLeaveToday = getUsersOnLeave(employeeIds, today);
        
        // Process each user
        for (User user : users) {
            usersProcessed++;
            
            // Skip if user has already checked in
            if (checkedInUsers.contains(user.Id)) {
                usersAlreadyCheckedIn++;
                System.debug('User ' + user.Name + ' already checked in - skipping');
                continue;
            }
            
            // Skip if user has leave today
            if (usersOnLeaveToday.contains(user.Id)) {
                usersOnLeave++;
                System.debug('User ' + user.Name + ' has leave today - skipping');
                continue;
            }
            
            // User needs reminder - create email
            Messaging.SingleEmailMessage email = createReminderEmail(user);
            emailsToSend.add(email);
            emailsSent++;
        }
        
        // Send all emails in bulk
        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.sendEmail(emailsToSend);
                System.debug('✅ Sent ' + emailsToSend.size() + ' reminder emails');
            } catch (Exception e) {
                System.debug('❌ Error sending emails: ' + e.getMessage());
            }
        }
    }
    
    /**
     * Finish method - Log summary statistics
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('=== ATTENDANCE REMINDER BATCH COMPLETED ===');
        System.debug('End Time: ' + System.now());
        System.debug('Total Users Processed: ' + usersProcessed);
        System.debug('Users Already Checked In: ' + usersAlreadyCheckedIn);
        System.debug('Users On Leave: ' + usersOnLeave);
        System.debug('Reminder Emails Sent: ' + emailsSent);
        
        // Send summary email to admin (optional)
        sendSummaryEmailToAdmin(bc.getJobId());
    }
    
    /**
     * Get users who have already checked in today
     */
    private Set<Id> getCheckedInUsers(Set<Id> employeeIds, Date today) {
        Set<Id> checkedInUsers = new Set<Id>();
        
        List<Employee_Attendance__c> todayAttendance = [
            SELECT Employee_Name__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c IN :employeeIds
            AND Date__c = :today
            AND Check_In_Time__c != null
        ];
        
        for (Employee_Attendance__c att : todayAttendance) {
            checkedInUsers.add(att.Employee_Name__c);
        }
        
        return checkedInUsers;
    }
    
    /**
     * Get users who have approved or pending leave today
     */
    private Set<Id> getUsersOnLeave(Set<Id> employeeIds, Date today) {
        Set<Id> usersOnLeave = new Set<Id>();
        
        List<Leave_Request__c> leavesToday = [
            SELECT Employee__c
            FROM Leave_Request__c
            WHERE Employee__c IN :employeeIds
            AND Start_Date__c <= :today
            AND End_Date__c >= :today
            AND Status__c IN ('Approved', 'Pending')
            AND Is_Active__c = true
        ];
        
        for (Leave_Request__c leave : leavesToday) {
            usersOnLeave.add(leave.Employee__c);
        }
        
        return usersOnLeave;
    }
    
    /**
     * Create reminder email for user
     */
    private Messaging.SingleEmailMessage createReminderEmail(User user) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { user.Email });
        email.setSubject('Reminder: Check-in Required - iBRAVE Portal');
        
        // Get base URL for org
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String attendanceUrl = baseUrl + '/lightning/n/Attendance'; // Update with your actual tab name
        
        String body = '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';
        body += '<div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e5e5e5; border-radius: 8px;">';
        
        // Header
        body += '<div style="background: linear-gradient(135deg, #0176d3 0%, #0d4f8b 100%); padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">';
        body += '<h1 style="color: white; margin: 0; font-size: 24px;">⏰ Check-In Reminder</h1>';
        body += '</div>';
        
        // Content
        body += '<div style="padding: 30px 20px;">';
        body += '<p style="font-size: 16px;">Dear <strong>' + user.Name + '</strong>,</p>';
        body += '<p style="font-size: 15px;">This is a friendly reminder that you have <strong>not checked in</strong> for today.</p>';
        
        // Alert box
        body += '<div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">';
        body += '<p style="margin: 0; color: #856404; font-size: 14px;">';
        body += '<strong>⚠️ Action Required:</strong><br/>';
        body += 'Please check in on the <strong>iBRAVE Portal</strong> to mark your attendance for today.';
        body += '</p>';
        body += '</div>';
        
        // Instructions
        body += '<div style="background: #f8f9fa; padding: 15px; border-radius: 6px; margin: 20px 0;">';
        body += '<h3 style="margin-top: 0; color: #0176d3; font-size: 16px;">📋 How to Check-In:</h3>';
        body += '<ol style="margin: 10px 0; padding-left: 20px;">';
        body += '<li>Login to <strong>iBRAVE Portal</strong></li>';
        body += '<li>Navigate to <strong>Attendance</strong> tab</li>';
        body += '<li>Click the <strong>"Check In"</strong> button</li>';
        body += '<li>Confirm your work location and details</li>';
        body += '</ol>';
        body += '</div>';
        
        // Button
        body += '<div style="text-align: center; margin: 30px 0;">';
        body += '<a href="' + attendanceUrl + '" style="background-color: #0176d3; color: white; padding: 14px 32px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold; font-size: 16px;">Check In Now</a>';
        body += '</div>';
        
        // Footer info
        body += '<div style="border-top: 1px solid #e5e5e5; padding-top: 20px; margin-top: 20px;">';
        body += '<p style="font-size: 13px; color: #666; margin: 5px 0;">';
        body += '📅 <strong>Date:</strong> ' + Date.today().format() + '<br/>';
        body += '🕐 <strong>Time:</strong> ' + System.now().format('h:mm a') + '<br/>';
        body += '📧 <strong>This is an automated reminder</strong>';
        body += '</p>';
        body += '</div>';
        
        body += '</div>';
        
        // Footer
        body += '<div style="background: #f8f9fa; padding: 15px; text-align: center; border-radius: 0 0 8px 8px; border-top: 1px solid #e5e5e5;">';
        body += '<p style="margin: 0; font-size: 12px; color: #666;">iBRAVE HR Management System</p>';
        body += '<p style="margin: 5px 0 0 0; font-size: 11px; color: #999;">This is an automated message. Please do not reply.</p>';
        body += '</div>';
        
        body += '</div>';
        body += '</body></html>';
        
        email.setHtmlBody(body);
        return email;
    }
    
    /**
     * Send summary email to admin
     */
    private void sendSummaryEmailToAdmin(Id jobId) {
        try {
            // Query admin users or use a specific email
            List<User> admins = [
                SELECT Email 
                FROM User 
                WHERE Profile.Name = 'System Administrator' 
                AND IsActive = true 
                LIMIT 5
            ];
            
            if (admins.isEmpty()) {
                return;
            }
            
            List<String> adminEmails = new List<String>();
            for (User admin : admins) {
                adminEmails.add(admin.Email);
            }
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(adminEmails);
            email.setSubject('Attendance Reminder Batch - Daily Summary');
            
            String body = '<html><body style="font-family: Arial, sans-serif;">';
            body += '<h2 style="color: #0176d3;">Attendance Reminder Batch - Execution Summary</h2>';
            body += '<p>The daily attendance reminder batch job has completed successfully.</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse;">';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Job ID</strong></td><td>' + jobId + '</td></tr>';
            body += '<tr><td><strong>Execution Time</strong></td><td>' + System.now().format() + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Total Users Processed</strong></td><td>' + usersProcessed + '</td></tr>';
            body += '<tr><td><strong>Already Checked In</strong></td><td style="color: #2e7d32;">' + usersAlreadyCheckedIn + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>On Leave</strong></td><td style="color: #f57c00;">' + usersOnLeave + '</td></tr>';
            body += '<tr><td><strong>Reminder Emails Sent</strong></td><td style="color: #d32f2f; font-weight: bold;">' + emailsSent + '</td></tr>';
            body += '</table>';
            body += '<p>Thank you,<br/><strong>iBRAVE System</strong></p>';
            body += '</body></html>';
            
            email.setHtmlBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
        } catch (Exception e) {
            System.debug('Error sending admin summary: ' + e.getMessage());
        }
    }
}