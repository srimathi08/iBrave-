/**
 * @description Hybrid Work Schedule Controller for managing monthly WFH patterns
 * @author Salesforce Consultant
 * @date 2025-11-17
 * @version 1.0 - Initial implementation for hybrid work model
 */
public without sharing class HybridWorkScheduleController {
    
    /**
     * @description Submit a new hybrid work schedule request for approval
     * @param employeeId Employee submitting the request
     * @param scheduleMonth Month for which schedule applies (YYYY-MM-01)
     * @param wfhDays Multi-select picklist values (e.g., "Monday;Tuesday")
     * @param officeDays Multi-select picklist values
     * @param scheduleType Type of schedule (Fixed Days, Flexible, Custom)
     * @param reason Business justification
     * @return Map containing success status and created schedule details
     */
    @AuraEnabled
    public static Map<String, Object> submitHybridScheduleRequest(
        String employeeId, 
        String scheduleMonth, 
        String wfhDays, 
        String officeDays,
        String scheduleType,
        String reason
    ) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== SUBMITTING HYBRID WORK SCHEDULE ===');
            System.debug('Employee ID: ' + employeeId);
            System.debug('Schedule Month: ' + scheduleMonth);
            System.debug('WFH Days: ' + wfhDays);
            System.debug('Office Days: ' + officeDays);
            
            // Input validation
            if (String.isBlank(employeeId) || String.isBlank(scheduleMonth) || 
                String.isBlank(wfhDays) || String.isBlank(reason)) {
                throw new AuraHandledException('Required fields are missing');
            }
            
            // Validate reason length
            if (reason.length() < 20) {
                throw new AuraHandledException('Reason must be at least 20 characters');
            }
            
            // Get employee details including manager
            User employee = [
                SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email
                FROM User 
                WHERE Id = :employeeId AND IsActive = true
                LIMIT 1
            ];
            
            if (employee.ManagerId == null) {
                response.put('success', false);
            response.put('message', 'You do not have a manager assigned. Please contact HR.');
            return response;
            }
            
            
           // Parse week start date (Monday of selected week)
		Date monthDate = Date.valueOf(scheduleMonth);
		Date startDate = monthDate;           // Week's Monday
		Date endDate = monthDate.addDays(6);  // Week's Sunday
            
            // Check for existing schedule for the same month
            List<Hybrid_Work_Schedule__c> existingSchedules = [
                SELECT Id, Approval_Status__c, Schedule_Month__c
                FROM Hybrid_Work_Schedule__c
                WHERE Employee__c = :employeeId
                AND Schedule_Month__c = :monthDate
                AND Approval_Status__c IN ('Pending Manager Approval', 'Approved')
                LIMIT 1
            ];
            
            if (!existingSchedules.isEmpty()) {
               // throw new AuraHandledException(
                 //   'You already have a ' + existingSchedules[0].Approval_Status__c + 
                 //   ' schedule for ' + monthDate.format() + '. Please cancel it first.'
               // );
               	 response.put('success', false);
    response.put(
        'alert',
        'You already have a ' + existingSchedules[0].Approval_Status__c +
        ' schedule for ' + monthDate.format() + '. Please contact your Admin.');
                return response; //important
            }
            
        
        
        
        
        
        
        
            // Calculate total WFH and Office days in the month
            Map<String, Integer> dayCounts = calculateMonthlyDayCounts(
                startDate, endDate, wfhDays, officeDays
            );
            
            // Create hybrid work schedule record
            Hybrid_Work_Schedule__c schedule = new Hybrid_Work_Schedule__c();
            schedule.Employee__c = employeeId;
            schedule.Manager__c = employee.ManagerId;
            schedule.Schedule_Month__c = monthDate;
            schedule.Start_Date__c = startDate;
            schedule.End_Date__c = endDate;
            schedule.WFH_days__c = wfhDays;
            schedule.Office_Days__c = officeDays;
            schedule.Schedule_Type__c = scheduleType;
            schedule.Reason__c = reason;
            schedule.Approval_Status__c = 'Pending Manager Approval';
            schedule.Is_Active__c = false; // Only active after approval
            schedule.Total_WFH_Days__c = dayCounts.get('wfhDays');
            schedule.Total_Office_Days__c = dayCounts.get('officeDays');
            
            insert schedule;
            
            System.debug('✅ Hybrid schedule created: ' + schedule.Id);
            
            // Send approval email to manager
        Boolean emailSent = sendEmailToManager(schedule.Id, employee);

            
			response.put('success', true);
			response.put('scheduleId', schedule.Id);
            response.put('message', 'Request submitted successfully. ' + 
            (emailSent ? 'Manager notified via email.' : 'Email notification failed.'));
return response;
        } catch (DmlException dmlEx) {
        System.debug('❌ DML Error: ' + dmlEx.getMessage());
        response.put('success', false);
        response.put('message', 'Database error: ' + dmlEx.getDmlMessage(0));
        return response;

            
        }catch (Exception e) {
            System.debug('❌ Error: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        response.put('success', false);
        response.put('message', 'Error: ' + e.getMessage());
        return response;
        }
            

    }

       
    
    
    /**
     * @description Calculate how many WFH and Office days occur in the month
     * @param startDate First day of month
     * @param endDate Last day of month
     * @param wfhDays Multi-select picklist string (e.g., "Monday;Tuesday")
     * @param officeDays Multi-select picklist string
     * @return Map with 'wfhDays' and 'officeDays' counts
     */
    public static Map<String, Integer> calculateMonthlyDayCounts(
        Date startDate, Date endDate, String wfhDays, String officeDays
    ) {
        Map<String, Integer> counts = new Map<String, Integer>();
        
        // Parse selected days
        Set<String> wfhDaySet = new Set<String>();
        Set<String> officeDaySet = new Set<String>();
        
        if (String.isNotBlank(wfhDays)) {
            wfhDaySet.addAll(wfhDays.split(';'));
        }
        if (String.isNotBlank(officeDays)) {
            officeDaySet.addAll(officeDays.split(';'));
        }
        
        Integer wfhCount = 0;
        Integer officeCount = 0;
        
        // Loop through each day in the month
        for (Date currentDate = startDate; currentDate <= endDate; currentDate = currentDate.addDays(1)) {
            String dayOfWeek = getDayOfWeekName(currentDate);
            
            if (wfhDaySet.contains(dayOfWeek)) {
                wfhCount++;
            }
            if (officeDaySet.contains(dayOfWeek)) {
                officeCount++;
            }
        }
        
        counts.put('wfhDays', wfhCount);
        counts.put('officeDays', officeCount);
        
        System.debug('📊 Month Statistics: WFH Days = ' + wfhCount + ', Office Days = ' + officeCount);
        
        return counts;
    }
    
    /**
     * @description Get day of week name from date
     * @param inputDate Date to check
     * @return String Day name (Monday, Tuesday, etc.)
     */
    public static String getDayOfWeekName(Date inputDate) {
        DateTime dt = DateTime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));
        String dayName = dt.format('EEEE'); // Full day name (Monday, Tuesday, etc.)
        return dayName;
    }
    
    	    /**
     * @description Send approval email to manager with schedule details
     * @param scheduleId Hybrid work schedule record ID
     * @param employee User record with manager details
     * @return Boolean Email sent successfully
     */
 public static Boolean sendEmailToManager(Id scheduleId, User employee) {
    try {
                  // Query schedule
        Hybrid_Work_Schedule__c schedule = [
            SELECT Id, Name, Schedule_Month__c, Start_Date__c, End_Date__c,
                   WFH_days__c, Office_Days__c, Schedule_Type__c, Reason__c,
                   Total_WFH_Days__c, Total_Office_Days__c
            FROM Hybrid_Work_Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];
            
            // Get base URL and build approval page URL
            //String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        //String baseUrl  = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/HybridApproval';
        String baseUrl  = 'https://innovation-dream-9744.my.salesforce-sites.com/HybridApproval';
        
        
        
           // String approvalUrl = baseUrl + '/lightning/r/Leave_Request__c/' + request.Id + '/view';
           //         // ✅ Build Visualforce Approval Page URL
        //String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        String approvalUrl = baseUrl + '/apex/HybrideSchedulePage' + '?id=' + schedule.Id + '&mgr=' + employee.ManagerId;
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { employee.Manager.Email });
            mail.setSubject('🏠 Hybrid Work Schedule Approval Request ' + employee.Name);
              //mail.setOrgWideEmailAddressId('0D2fs00000001tl');
// ✅ Dynamic org-wide email address
            OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
            mail.setOrgWideEmailAddressId(owea.Id);
            
            String body = '<html><body style="font-family: Arial, sans-serif;">';
            body += '<h2 style="color: #0176d3;">New Hybrid Work Schedule Request Pending Approval</h2>';
            body += '<p>Dear ' + employee.Manager.Name + ',</p>';
            body += '<p>' + employee.Name + ' has requested Hybrid work schedule. Please review and approve/reject:</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse; width: 100%; max-width: 600px;">';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Employee</strong></td><td>' + employee.Name + '</td></tr>';
            body += '<tr><td><strong>Email</strong></td><td>' + employee.Email + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Schedule Type</strong></td><td>' + schedule.Schedule_Type__c+ '</td></tr>';
            body += '<tr><td><strong>Work From Home Days</strong></td><td>' + schedule.WFH_days__c.replace(';', ', ') + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Work From Office Days</strong></td><td>' + schedule.Office_Days__c.replace(';', ', ')  + '</td></tr>';
            body += '<tr><td><strong>Total WFH Days</strong></td><td>' + schedule.Total_WFH_Days__c  + '</td></tr>';
            body += '<tr><td><strong>Total Office Days</strong></td><td>' + schedule.Total_Office_Days__c + '</td></tr>';
            
            body += '<tr><td><strong>Reason</strong></td><td>' + schedule.Reason__c + '</td></tr>';
            
            body += '</table>';
            body += '<br/>';
            body += '<div style="text-align: center; margin: 30px 0;">';
            body += '<a href="' + approvalUrl + '" style="background-color: #0176d3; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">Click here to review</a>';
            body += '</div>';
            body += '<p style="color: #666; font-size: 12px;">Click the button above to view the Hybrid work schedule request in Salesforce.</p>';
            body += '<p>Thank you,<br/><strong>HR Management System</strong></p>';
            body += '</body></html>';
            
            mail.setHtmlBody(body);
            
           // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
             Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
         //return true; // ✅ REQUIRED
        
        if (results[0].isSuccess()) {
            System.debug('✅ Email sent successfully to manager');
            return true;
        } else {
            System.debug('❌ Email failed: ' + results[0].getErrors()[0].getMessage());
            return false;
        }
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
             return false; // ✅ REQUIRED
        }
}

    
    /**
     * @description Build HTML email body for manager approval
     * ✅ FIXED: Changed URL.getSalesforceBaseUrl() to URL.getOrgDomainUrl()
     */
    public static String buildManagerApprovalEmailHTML(Hybrid_Work_Schedule__c schedule, User employee) {
        // ✅ FIXED: Use getOrgDomainUrl() instead of deprecated getSalesforceBaseUrl()
        //String baseUrl  = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/HybridApproval';
 String baseUrl  = 'https://innovation-dream-9744.my.salesforce-sites.com/HybridApproval';
          String approvalUrl = baseUrl + '/apex/HybrideSchedulePage' + '?id=' + schedule.Id + '&mgr=' + employee.ManagerId;


        
        String monthName = schedule.Schedule_Month__c.format();
        
        String html = '<html><body style="font-family: Arial, sans-serif; color: #333;">';
        html += '<div style="max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px;">';
        
        // Header
        html += '<div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0;">';
        html += '<h2 style="margin: 0;">🏠 Hybrid Work Schedule Approval Required</h2>';
        html += '</div>';
        
        // Content
        html += '<div style="padding: 30px;">';
        html += '<p style="font-size: 16px;">Hello <strong>' + employee.Manager.Name + '</strong>,</p>';
        html += '<p><strong>' + employee.Name + '</strong> has requested approval for a hybrid work schedule for <strong>' + monthName + '</strong>.</p>';
        
        // Schedule Details Box
        html += '<div style="background: #f8f9fa; border-left: 4px solid #667eea; padding: 15px; margin: 20px 0;">';
        html += '<h3 style="margin-top: 0; color: #667eea;">📅 Schedule Details</h3>';
        html += '<p><strong>Employee:</strong> ' + employee.Name + '</p>';
        html += '<p><strong>Month:</strong> ' + monthName + '</p>';
        html += '<p><strong>Schedule Type:</strong> ' + schedule.Schedule_Type__c + '</p>';
        html += '<p><strong>🏠 Work From Home Days:</strong> ' + schedule.WFH_days__c.replace(';', ', ') + '</p>';
        html += '<p><strong>🏢 Office Days:</strong> ' + schedule.Office_Days__c.replace(';', ', ') + '</p>';
        html += '<p><strong>Total WFH Days in Month:</strong> ' + schedule.Total_WFH_Days__c + '</p>';
        html += '<p><strong>Total Office Days in Month:</strong> ' + schedule.Total_Office_Days__c + '</p>';
        html += '</div>';
        
        // Reason Box
        html += '<div style="background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">';
        html += '<h4 style="margin-top: 0;">💬 Reason for Request:</h4>';
        html += '<p style="white-space: pre-wrap;">' + schedule.Reason__c + '</p>';
        html += '</div>';
        
        // Action Buttons
        html += '<div style="text-align: center; margin: 30px 0;">';
        html += '<a href="' + approvalUrl + '" style="background: #28a745; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 0 10px; display: inline-block;">✅ Review & Approve</a>';
        html += '</div>';
        
        html += '<p style="color: #666; font-size: 14px;">Please review and take action on this request at your earliest convenience.</p>';
        html += '<p style="color: #666; font-size: 14px;">To approve or reject, click the button above to view the request in Salesforce.</p>';
        
        html += '</div>'; // Close content
        
        // Footer
        html += '<div style="background: #f8f9fa; padding: 15px; border-top: 1px solid #ddd; text-align: center; font-size: 12px; color: #666;">';
        html += '<p>This is an automated notification from your HRMS Attendance System.</p>';
        html += '</div>';
        
        html += '</div></body></html>';
        
        return html;
    }
    
    /**
     * @description Build plain text email body for manager approval
     * ✅ FIXED: Changed URL.getSalesforceBaseUrl() to URL.getOrgDomainUrl()
     */
    public static String buildManagerApprovalEmailPlainText(Hybrid_Work_Schedule__c schedule, User employee) {
        String monthName = schedule.Schedule_Month__c.format();
        
        // ✅ FIXED: Use getOrgDomainUrl() instead of deprecated getSalesforceBaseUrl()
       // String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        //String approveUrl = baseUrl + '/lightning/r/HybrideSchedulePage/' + schedule.Id + '/view';
        
         // String baseUrl  = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/HybridApproval';
 String baseUrl  = 'https://innovation-dream-9744.my.salesforce-sites.com/HybridApproval';
          String approvalUrl = baseUrl + '/apex/HybrideSchedulePage' + '?id=' + schedule.Id + '&mgr=' + employee.ManagerId;
        
        String text = '🏠 HYBRID WORK SCHEDULE APPROVAL REQUEST\n\n';
        text += 'Hello ' + employee.Manager.Name + ',\n\n';
        text += employee.Name + ' has requested approval for a hybrid work schedule for ' + monthName + '.\n\n';
        text += '📅 SCHEDULE DETAILS:\n';
        text += '- Employee: ' + employee.Name + '\n';
        text += '- Month: ' + monthName + '\n';
        text += '- Schedule Type: ' + schedule.Schedule_Type__c + '\n';
        text += '- Work From Home Days: ' + schedule.WFH_days__c.replace(';', ', ') + '\n';
        text += '- Office Days: ' + schedule.Office_Days__c.replace(';', ', ') + '\n';
        text += '- Total WFH Days in Month: ' + schedule.Total_WFH_Days__c + '\n';
        text += '- Total Office Days in Month: ' + schedule.Total_Office_Days__c + '\n\n';
        text += '💬 REASON:\n' + schedule.Reason__c + '\n\n';
        text += 'To review and approve this request, please visit:\n';
        text += approvalUrl + '\n\n';
        text += 'Thank you,\nHRMS Attendance System';
        
        return text;
    }

    
    /**
     * @description Process manager's approval or rejection
     * @param scheduleId Hybrid schedule record ID
     * @param action 'Approve' or 'Reject'
     * @param rejectionReason Reason if rejected
     * @return Map with success status
     */
    @AuraEnabled
    public static Map<String, Object> processManagerDecision(
        String scheduleId, 
        String action,
        String rejectionReason
    ) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== PROCESSING MANAGER DECISION ===');
            System.debug('Schedule ID: ' + scheduleId);
            System.debug('Action: ' + action);
            
            // Query schedule with employee details
            Hybrid_Work_Schedule__c schedule = [
                SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Email,
                       Manager__c, Manager__r.Name, Approval_Status__c,
                       Schedule_Month__c, WFH_days__c, Office_Days__c
                FROM Hybrid_Work_Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];
            
            // Validate current status
            if (schedule.Approval_Status__c != 'Pending Manager Approval') {
                throw new AuraHandledException('This request has already been processed.');
            }
            
            // Update schedule based on action
            if (action == 'Approve') {
                schedule.Approval_Status__c = 'Approved';
                schedule.Is_Active__c = true;
                schedule.Approval_Date__c = DateTime.now();
                System.debug('✅ Schedule APPROVED');
                
            } else if (action == 'Reject') {
                if (String.isBlank(rejectionReason)) {
                    throw new AuraHandledException('Rejection reason is required');
                }
                schedule.Approval_Status__c = 'Rejected';
                schedule.Is_Active__c = false;
                schedule.Rejection_Reason__c = rejectionReason;
                schedule.Approval_Date__c = DateTime.now();
                System.debug('❌ Schedule REJECTED');
                
            } else {
                throw new AuraHandledException('Invalid action: ' + action);
            }
            
            update schedule;
            
            // Send notification email to employee
            sendEmployeeNotificationEmail(schedule, action);
            
            response.put('success', true);
            response.put('action', action);
            response.put('scheduleId', schedule.Id);
            response.put('message', 'Schedule ' + action.toLowerCase() + 'd successfully');
            
            System.debug('=== DECISION PROCESSED SUCCESSFULLY ===');
            
        } catch (QueryException qe) {
            System.debug('❌ Schedule not found: ' + qe.getMessage());
            response.put('success', false);
            response.put('error', 'Schedule not found');
        } catch (DmlException dmlEx) {
            System.debug('❌ Update failed: ' + dmlEx.getMessage());
            response.put('success', false);
            response.put('error', 'Failed to update schedule: ' + dmlEx.getDmlMessage(0));
        } catch (AuraHandledException ahe) {
            System.debug('❌ Validation error: ' + ahe.getMessage());
            response.put('success', false);
            response.put('error', ahe.getMessage());
        } catch (Exception e) {
            System.debug('❌ Unexpected error: ' + e.getMessage());
            response.put('success', false);
            response.put('error', 'Unexpected error: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Send notification email to employee after manager decision
     */
    public static void sendEmployeeNotificationEmail(Hybrid_Work_Schedule__c schedule, String action) {
        try {
            System.debug('📧 Sending notification to employee...');
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ schedule.Employee__r.Email });
            //email.setOrgWideEmailAddressId('0D2fs00000001tl'); // ✅ ADD THIS LINE
            // ✅ Dynamic org-wide email address
            OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
            email.setOrgWideEmailAddressId(owea.Id);
            String monthName = schedule.Schedule_Month__c.format();
            
            if (action == 'Approve') {
                email.setSubject('✅ Your Hybrid Work Schedule for ' + monthName + ' has been Approved');
                
                String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
                htmlBody += '<div style="max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px;">';
                htmlBody += '<div style="background: #28a745; color: white; padding: 20px; border-radius: 8px 8px 0 0;">';
                htmlBody += '<h2 style="margin: 0;">✅ Schedule Approved!</h2></div>';
                htmlBody += '<div style="padding: 30px;">';
                htmlBody += '<p>Hello <strong>' + schedule.Employee__r.Name + '</strong>,</p>';
                htmlBody += '<p>Great news! Your hybrid work schedule for <strong>' + monthName + '</strong> has been approved by ' + schedule.Manager__r.Name + '.</p>';
                htmlBody += '<div style="background: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 20px 0;">';
                htmlBody += '<h3 style="margin-top: 0; color: #155724;">Your Approved Schedule:</h3>';
                htmlBody += '<p><strong>🏠 Work From Home:</strong> ' + schedule.WFH_days__c.replace(';', ', ') + '</p>';
                htmlBody += '<p><strong>🏢 Office Days:</strong> ' + schedule.Office_Days__c.replace(';', ', ') + '</p>';
                htmlBody += '</div>';
                htmlBody += '<p>Your schedule is now active. When you check in on approved WFH days, no additional approval will be required.</p>';
                htmlBody += '</div></div></body></html>';
                
                email.setHtmlBody(htmlBody);
                
            } else if (action == 'Reject') {
                email.setSubject('❌ Your Hybrid Work Schedule Request has been Declined');
                
                String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
                htmlBody += '<div style="max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px;">';
                htmlBody += '<div style="background: #dc3545; color: white; padding: 20px; border-radius: 8px 8px 0 0;">';
                htmlBody += '<h2 style="margin: 0;">❌ Schedule Request Declined</h2></div>';
                htmlBody += '<div style="padding: 30px;">';
                htmlBody += '<p>Hello <strong>' + schedule.Employee__r.Name + '</strong>,</p>';
                htmlBody += '<p>Your hybrid work schedule request for <strong>' + monthName + '</strong> has been declined by ' + schedule.Manager__r.Name + '.</p>';
                
                if (String.isNotBlank(schedule.Rejection_Reason__c)) {
                    htmlBody += '<div style="background: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 20px 0;">';
                    htmlBody += '<h4 style="margin-top: 0;">Manager\'s Feedback:</h4>';
                    htmlBody += '<p style="white-space: pre-wrap;">' + schedule.Rejection_Reason__c + '</p>';
                    htmlBody += '</div>';
                }
                
                htmlBody += '<p>Please discuss with your manager to understand the reason and resubmit if appropriate.</p>';
                htmlBody += '</div></div></body></html>';
                
                email.setHtmlBody(htmlBody);
            }
            
           // Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
                   Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
             if (results[0].isSuccess()) {
            System.debug('✅ Employee notification sent successfully');
        } else {
            System.debug('❌ Employee notification failed: ' + results[0].getErrors()[0].getMessage());
        }
            
        } catch (Exception e) {
            System.debug('⚠️ Failed to send employee notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Check if employee has an active hybrid schedule for today
     * @param employeeId Employee ID
     * @param checkDate Date to check (usually today)
     * @return Map containing schedule details and validation result
     */
    @AuraEnabled
    public static Map<String, Object> checkActiveScheduleForDate(String employeeId, String checkDate) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            Date dateToCheck = Date.valueOf(checkDate);
            String dayOfWeek = getDayOfWeekName(dateToCheck);
            
            System.debug('🔍 Checking schedule for: ' + employeeId + ' on ' + dateToCheck + ' (' + dayOfWeek + ')');
            
            // Query active schedules for this employee covering this date
            List<Hybrid_Work_Schedule__c> activeSchedules = [
                SELECT Id, Name, WFH_days__c, Office_Days__c, Schedule_Type__c,
                       Start_Date__c, End_Date__c, Employee__r.Name
                FROM Hybrid_Work_Schedule__c
                WHERE Employee__c = :employeeId
                AND Approval_Status__c = 'Approved'
                AND Is_Active__c = true
                AND Start_Date__c <= :dateToCheck
                AND End_Date__c >= :dateToCheck
                LIMIT 1
            ];
            
            if (activeSchedules.isEmpty()) {
                result.put('hasActiveSchedule', false);
                result.put('message', 'No active hybrid schedule found for this date');
                System.debug('⚠️ No active schedule found');
                return result;
            }
            
            Hybrid_Work_Schedule__c schedule = activeSchedules[0];
            
            // Check if today is a WFH day according to schedule
            Boolean isScheduledWFH = false;
            Boolean isScheduledOffice = false;
            
            if (String.isNotBlank(schedule.WFH_days__c)) {
                isScheduledWFH = schedule.WFH_days__c.contains(dayOfWeek);
            }
            
            if (String.isNotBlank(schedule.Office_Days__c)) {
                isScheduledOffice = schedule.Office_Days__c.contains(dayOfWeek);
            }
            
            result.put('hasActiveSchedule', true);
            result.put('scheduleId', schedule.Id);
            result.put('scheduleName', schedule.Name);
            result.put('isScheduledWFH', isScheduledWFH);
            result.put('isScheduledOffice', isScheduledOffice);
            result.put('dayOfWeek', dayOfWeek);
            result.put('wfhDays', schedule.WFH_days__c);
            result.put('officeDays', schedule.Office_Days__c);
            
            if (isScheduledWFH) {
                result.put('message', 'This is a scheduled WFH day - No approval needed');
                result.put('autoApproveWFH', true);
                System.debug('✅ Today is scheduled WFH day - Auto-approve');
            } else if (isScheduledOffice) {
                result.put('message', 'This is a scheduled office day');
                result.put('autoApproveWFH', false);
                System.debug('🏢 Today is scheduled office day');
            } else {
                result.put('message', 'No specific schedule for today');
                result.put('autoApproveWFH', false);
                System.debug('⚠️ No specific schedule for ' + dayOfWeek);
            }
            
        } catch (Exception e) {
            System.debug('❌ Error checking schedule: ' + e.getMessage());
            result.put('hasActiveSchedule', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Get all hybrid schedules for an employee
     * @param employeeId Employee ID
     * @return List of schedules
     */
   /** @AuraEnabled(cacheable=true)
    public static List<Hybrid_Work_Schedule__c> getEmployeeSchedules(String employeeId) {
        try {
            return [
                SELECT Id, Name, Schedule_Month__c, Start_Date__c, End_Date__c,
                       WFH_days__c, Office_Days__c, Schedule_Type__c,
                       Approval_Status__c, Is_Active__c, Approval_Date__c,
                       Total_WFH_Days__c, Total_Office_Days__c, Reason__c,
                       Rejection_Reason__c, Employee__r.Manager.Name
                FROM Hybrid_Work_Schedule__c
                WHERE Employee__c = :employeeId
                ORDER BY Schedule_Month__c DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('❌ Error fetching schedules: ' + e.getMessage());
            throw new AuraHandledException('Failed to fetch schedules: ' + e.getMessage());
        }      
    }*/


@AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getEmployeeSchedules(String employeeId) {

    // 1️⃣ Fetch employee manager safely
    User emp = [
        SELECT Id, Manager.Name
        FROM User
        WHERE Id = :employeeId
        LIMIT 1
    ];

    String managerName =
        emp.Manager != null ? emp.Manager.Name : null;

    // 2️⃣ Fetch schedules
    List<Hybrid_Work_Schedule__c> schedules = [
        SELECT Id, Name, Schedule_Month__c, Start_Date__c, End_Date__c,
               WFH_days__c, Office_Days__c, Schedule_Type__c,
               Approval_Status__c, Is_Active__c, Approval_Date__c,
               Total_WFH_Days__c, Total_Office_Days__c,
               Reason__c, Rejection_Reason__c
        FROM Hybrid_Work_Schedule__c
        WHERE Employee__c = :employeeId
        ORDER BY Schedule_Month__c DESC
        LIMIT 50
    ];

    // 3️⃣ Build response (FLATTENED)
    List<Map<String, Object>> response = new List<Map<String, Object>>();

    for (Hybrid_Work_Schedule__c s : schedules) {
        Map<String, Object> row = new Map<String, Object>();

        row.put('Id', s.Id);
        row.put('Name', s.Name);
        row.put('Schedule_Month__c', s.Schedule_Month__c);
        row.put('Start_Date__c', s.Start_Date__c);
        row.put('End_Date__c', s.End_Date__c);
        row.put('WFH_days__c', s.WFH_days__c);
        row.put('Office_Days__c', s.Office_Days__c);
        row.put('Schedule_Type__c', s.Schedule_Type__c);
        row.put('Approval_Status__c', s.Approval_Status__c);
        row.put('Is_Active__c', s.Is_Active__c);
        row.put('Approval_Date__c', s.Approval_Date__c);
        row.put('Total_WFH_Days__c', s.Total_WFH_Days__c);
        row.put('Total_Office_Days__c', s.Total_Office_Days__c);
        row.put('Reason__c', s.Reason__c);
        row.put('Rejection_Reason__c', s.Rejection_Reason__c);

        // ✅ COMMUNITY SAFE
        row.put('managerName', managerName);

        response.add(row);
    }

    return response;
}


    
    /**
     * @description Get pending approval requests for a manager
     * @param managerId Manager ID
     * @return List of pending schedules
     */
    @AuraEnabled(cacheable=false)
    public static List<Hybrid_Work_Schedule__c> getPendingApprovalsForManager(String managerId) {
        try {
            return [
                SELECT Id, Name, Employee__r.Name, Employee__r.Email,
                       Schedule_Month__c, Start_Date__c, End_Date__c,
                       WFH_days__c, Office_Days__c, Schedule_Type__c,
                       Total_WFH_Days__c, Total_Office_Days__c, Reason__c,
                       CreatedDate
                FROM Hybrid_Work_Schedule__c
                WHERE Manager__c = :managerId
                AND Approval_Status__c = 'Pending Manager Approval'
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            System.debug('❌ Error fetching pending approvals: ' + e.getMessage());
            throw new AuraHandledException('Failed to fetch pending approvals: ' + e.getMessage());
        }
    }
    
    
      @AuraEnabled(cacheable=true)
    public static String getEmployeeManagerName() {
        // Get logged-in user
        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.ContactId == null) {
            return null;
        }

        // Fetch Contact + Manager
        Contact c = [
            SELECT Manager__r.Name
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];

        return c.Manager__r != null ? c.Manager__r.Name : null;
    }
}