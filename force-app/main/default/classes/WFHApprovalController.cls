/**
 * @description Enhanced WFH Approval Controller with Email Deliverability Error Handling
 * @author Salesforce Consultant
 * @date 2025-10-03
 * @version 3.0 - Enhanced with NO_SINGLE_MAIL_PERMISSION handling
 */
public with sharing class WFHApprovalController {
    
    /**
     * @description Submit WFH approval request and send email to manager with enhanced error handling
     * @param attendanceRecordId The ID of the Employee_Attendance__c record
     * @param employeeId The ID of the employee requesting WFH
     * @param managerId The ID of the manager (if different from employee's direct manager)
     * @param reason The reason provided by employee for WFH request
     * @return Map containing success status and details
     */
    @AuraEnabled
    public static Map<String, Object> submitWFHApproval(String attendanceRecordId, String employeeId, String managerId, String reason) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== WFH APPROVAL SUBMISSION START ===');
            System.debug('AttendanceRecordId: ' + attendanceRecordId);
            System.debug('EmployeeId: ' + employeeId);
            System.debug('ManagerId: ' + managerId);
            System.debug('Reason: ' + reason);
            
            // Input validation
            if (String.isBlank(attendanceRecordId)) {
                throw new AuraHandledException('Attendance Record ID is required');
            }
            
            if (String.isBlank(employeeId)) {
                throw new AuraHandledException('Employee ID is required');
            }
            
            if (String.isBlank(reason) || reason.trim().length() < 10) {
                throw new AuraHandledException('Please provide a detailed reason for working from home (minimum 10 characters)');
            }
            
            // Get employee details
            User employee = getEmployeeDetails(employeeId);
            if (employee == null) {
                throw new AuraHandledException('Employee not found');
            }
            
            System.debug('Employee Details: ' + employee);
            
            // Get manager details - Use employee's direct manager
            User manager = getManagerDetails(employee);
            if (manager == null) {
                throw new AuraHandledException('Manager not found for employee: ' + employee.Name + '. Please ensure manager is assigned in User record.');
            }
            
            System.debug('Manager Details: ' + manager);
            System.debug('Manager Email: ' + manager.Email);
            
            // Verify attendance record exists and update approval fields
            Employee_Attendance__c attendanceRecord = updateAttendanceWithApprovalData(attendanceRecordId, reason);
            System.debug('Updated Attendance Record: ' + attendanceRecord);
            
            // ✅ ENHANCED: Check email deliverability settings first
            Map<String, Object> deliverabilityCheck = checkEmailDeliverabilitySettings();
            System.debug('Deliverability Check Results: ' + deliverabilityCheck);
            
            // Send approval email with enhanced error handling
            Map<String, Object> emailResult = sendApprovalEmailToManagerWithEnhancedErrorHandling(
                attendanceRecord, employee, manager, reason, deliverabilityCheck
            );
            
            // Build response
            response.put('success', true);
            response.put('attendanceRecordId', attendanceRecordId);
            response.put('employeeName', employee.Name);
            response.put('managerName', manager.Name);
            response.put('managerEmail', manager.Email);
            response.put('emailSent', (Boolean)emailResult.get('emailSent'));
            response.put('emailDebugInfo', emailResult.get('debugInfo'));
            response.put('deliverabilityInfo', deliverabilityCheck);
            
            String message = 'WFH approval request submitted successfully to ' + manager.Name;
            
            // ✅ ENHANCED: Specific message based on email delivery status
            if (!(Boolean)emailResult.get('emailSent')) {
                String errorType = (String)emailResult.get('errorType');
                if ('NO_SINGLE_MAIL_PERMISSION'.equals(errorType)) {
                    message += '. ⚠️ EMAIL NOT SENT: Administrator needs to enable "All Email" in Setup → Email → Deliverability settings.';
                    response.put('configurationRequired', true);
                    response.put('adminAction', 'Enable "All Email" in Email Deliverability settings');
                    response.put('adminGuidance', (String)emailResult.get('adminGuidance'));
                    response.put('userGuidance', (String)emailResult.get('userGuidance'));
                } else if ('NO_MASS_MAIL_PERMISSION'.equals(errorType)) {
                    message += '. ⚠️ EMAIL NOT SENT: Mass email permission required. Contact administrator.';
                } else {
                    message += '. ⚠️ Email may not have been delivered. Check debug info: ' + emailResult.get('debugInfo');
                }
                response.put('emailWarning', 'Email delivery failed - ' + errorType);
            } else {
                message += '. 📧 Email sent successfully to manager!';
            }
            
            response.put('message', message);
            
            System.debug('=== WFH APPROVAL SUBMISSION SUCCESS ===');
            System.debug('Final Response: ' + response);
            
        } catch (AuraHandledException ahe) {
            System.debug('=== WFH APPROVAL SUBMISSION ERROR (AuraHandled) ===');
            System.debug('Error: ' + ahe.getMessage());
            throw ahe;
        } catch (Exception e) {
            System.debug('=== WFH APPROVAL SUBMISSION ERROR (General) ===');
            System.debug('Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            
            response.put('success', false);
            response.put('error', 'Failed to submit WFH approval: ' + e.getMessage());
            
            throw new AuraHandledException('Failed to submit WFH approval request: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * ✅ ENHANCED: Check email deliverability settings with detailed analysis
     */
    private static Map<String, Object> checkEmailDeliverabilitySettings() {
        Map<String, Object> deliverabilityInfo = new Map<String, Object>();
        
        try {
            System.debug('=== EMAIL DELIVERABILITY CHECK ===');
            
            // Check if we can query Organization settings
            List<Organization> orgs = [SELECT Id, Name, IsSandbox FROM Organization LIMIT 1];
            if (!orgs.isEmpty()) {
                Organization org = orgs[0];
                deliverabilityInfo.put('orgName', org.Name);
                deliverabilityInfo.put('isSandbox', org.IsSandbox);
                
                System.debug('Organization: ' + org.Name);
                System.debug('Is Sandbox: ' + org.IsSandbox);
                
                if (org.IsSandbox) {
                    deliverabilityInfo.put('sandboxWarning', true);
                    deliverabilityInfo.put('recommendation', 'Sandbox detected - Check Email Deliverability is set to "All Email"');
                    System.debug('🚨 SANDBOX DETECTED: Likely cause of NO_SINGLE_MAIL_PERMISSION - Check deliverability settings');
                } else {
                    deliverabilityInfo.put('sandboxWarning', false);
                    deliverabilityInfo.put('recommendation', 'Production org - Check Email Deliverability settings if emails fail');
                }
            }
            
            // Check current user email settings
            User currentUser = [SELECT Id, Email, IsActive, ProfileId, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
            deliverabilityInfo.put('currentUserEmail', currentUser.Email);
            deliverabilityInfo.put('currentUserProfile', currentUser.Profile.Name);
            deliverabilityInfo.put('currentUserActive', currentUser.IsActive);
            
            System.debug('Current User: ' + currentUser.Email + ' (' + currentUser.Profile.Name + ')');
            
            // Check org-wide email addresses availability
            List<OrgWideEmailAddress> orgWideEmails = [
                SELECT Id, Address, DisplayName, IsAllowAllProfiles 
                FROM OrgWideEmailAddress 
                WHERE IsAllowAllProfiles = true
                LIMIT 5
            ];
            
            deliverabilityInfo.put('orgWideEmailCount', orgWideEmails.size());
            deliverabilityInfo.put('hasOrgWideEmail', !orgWideEmails.isEmpty());
            
            if (!orgWideEmails.isEmpty()) {
                List<String> orgEmailAddresses = new List<String>();
                for (OrgWideEmailAddress orgEmail : orgWideEmails) {
                    orgEmailAddresses.add(orgEmail.DisplayName + ' <' + orgEmail.Address + '>');
                }
                deliverabilityInfo.put('orgWideEmails', orgEmailAddresses);
                System.debug('Available Org-Wide Emails: ' + orgEmailAddresses);
            } else {
                System.debug('No Org-Wide Email addresses found - will use system sender');
            }
            
            deliverabilityInfo.put('deliverabilityCheckSuccess', true);
            System.debug('✅ Deliverability check completed successfully');
            
        } catch (Exception e) {
            System.debug('❌ Error checking deliverability settings: ' + e.getMessage());
            deliverabilityInfo.put('deliverabilityCheckSuccess', false);
            deliverabilityInfo.put('deliverabilityError', e.getMessage());
        }
        
        return deliverabilityInfo;
    }
    
    /**
     * @description Get employee details including manager information with enhanced debugging
     */
    private static User getEmployeeDetails(String employeeId) {
        try {
            System.debug('=== GETTING EMPLOYEE DETAILS ===');
            System.debug('Employee ID: ' + employeeId);
            
            List<User> employees = [
                SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Manager.IsActive,
                       Profile.Name, Department, Title, IsActive
                FROM User 
                WHERE Id = :employeeId AND IsActive = true 
                LIMIT 1
            ];
            
            if (employees.isEmpty()) {
                System.debug('❌ ERROR: Employee not found or inactive');
                return null;
            }
            
            User employee = employees[0];
            System.debug('✅ Employee Found: ' + employee.Name + ' (' + employee.Email + ')');
            System.debug('Employee Manager ID: ' + employee.ManagerId);
            System.debug('Employee Manager Name: ' + employee.Manager?.Name);
            System.debug('Employee Manager Email: ' + employee.Manager?.Email);
            System.debug('Employee Manager Active: ' + employee.Manager?.IsActive);
            
            return employee;
            
        } catch (Exception e) {
            System.debug('❌ ERROR getting employee details: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Get manager details for the given employee with enhanced debugging
     */
    private static User getManagerDetails(User employee) {
        try {
            System.debug('=== GETTING MANAGER DETAILS ===');
            
            if (employee.ManagerId == null) {
                System.debug('❌ ERROR: No manager assigned to employee: ' + employee.Name);
                return null;
            }
            
            List<User> managers = [
                SELECT Id, Name, Email, Title, Department, IsActive, Profile.Name
                FROM User 
                WHERE Id = :employee.ManagerId AND IsActive = true 
                LIMIT 1
            ];
            
            if (managers.isEmpty()) {
                System.debug('❌ ERROR: Manager not found or inactive for ID: ' + employee.ManagerId);
                return null;
            }
            
            User manager = managers[0];
            System.debug('✅ Manager Found: ' + manager.Name + ' (' + manager.Email + ')');
            System.debug('Manager Active: ' + manager.IsActive);
            System.debug('Manager Profile: ' + manager.Profile?.Name);
            
            // Validate manager email
            if (String.isBlank(manager.Email)) {
                System.debug('❌ ERROR: Manager has no email address');
                return null;
            }
            
            return manager;
            
        } catch (Exception e) {
            System.debug('❌ ERROR getting manager details: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Update attendance record with approval data
     */
    private static Employee_Attendance__c updateAttendanceWithApprovalData(String attendanceRecordId, String reason) {
        try {
            System.debug('=== UPDATING ATTENDANCE RECORD ===');
            System.debug('Record ID: ' + attendanceRecordId);
            
            Employee_Attendance__c record = [
                SELECT Id, Employee_Name__c, Date__c, Work_Location__c
                FROM Employee_Attendance__c 
                WHERE Id = :attendanceRecordId 
                LIMIT 1
            ];
            
            record.WFH_Reason__c = reason;
            record.WFH_Approval_Status__c = 'Pending';
            record.Submitted_For_Approval__c = true;
            
            update record;
            
            System.debug('✅ Attendance record updated successfully');
            return record;
            
        } catch (Exception e) {
            System.debug('❌ ERROR updating attendance record: ' + e.getMessage());
            throw new AuraHandledException('Failed to update attendance record: ' + e.getMessage());
        }
    }
    
    /**
     * ✅ ENHANCED: Send email with specific NO_SINGLE_MAIL_PERMISSION handling
     */
    private static Map<String, Object> sendApprovalEmailToManagerWithEnhancedErrorHandling(
        Employee_Attendance__c attendanceRecord, User employee, User manager, String reason, 
        Map<String, Object> deliverabilityInfo) {
        
        Map<String, Object> emailResult = new Map<String, Object>();
        List<String> debugInfo = new List<String>();
        
        try {
            System.debug('=== SENDING APPROVAL EMAIL WITH ENHANCED ERROR HANDLING ===');
            System.debug('To: ' + manager.Email);
            System.debug('Employee: ' + employee.Name);
            System.debug('Manager: ' + manager.Name);
            System.debug('Deliverability Info: ' + deliverabilityInfo);
            
            // Create email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipients
            List<String> toAddresses = new List<String>{ manager.Email };
            email.setToAddresses(toAddresses);
            debugInfo.add('To Address: ' + manager.Email);
            
            // ✅ ENHANCED: Use org-wide email if available for better deliverability
            Boolean orgWideEmailUsed = false;
            if (deliverabilityInfo.containsKey('hasOrgWideEmail') && (Boolean)deliverabilityInfo.get('hasOrgWideEmail')) {
                List<OrgWideEmailAddress> orgWideEmails = [
                    SELECT Id, Address, DisplayName 
                    FROM OrgWideEmailAddress 
                    WHERE IsAllowAllProfiles = true 
                    LIMIT 1
                ];
                
                if (!orgWideEmails.isEmpty()) {
                    email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
                    debugInfo.add('Using Org-Wide Email: ' + orgWideEmails[0].Address);
                    orgWideEmailUsed = true;
                    System.debug('✅ Using Org-Wide Email: ' + orgWideEmails[0].DisplayName + ' <' + orgWideEmails[0].Address + '>');
                }
            }
            
            if (!orgWideEmailUsed) {
                // Fallback to system sender
                email.setSenderDisplayName('WFH Approval System');
                debugInfo.add('Using System Sender (no org-wide email available)');
                System.debug('ℹ️ Using system sender - no org-wide email available');
            }
            
            // Set email properties
            String subject = '🚨 URGENT: WFH Approval Required - ' + employee.Name + ' (' + attendanceRecord.Date__c.format() + ')';
            email.setSubject(subject);
            debugInfo.add('Subject: ' + subject);
            
            // Create enhanced email body
            String emailBody = buildEnhancedManagerApprovalEmailBody(attendanceRecord, employee, manager, reason);
            email.setHtmlBody(emailBody);
            
            // Set plain text body as fallback
            String plainTextBody = buildEnhancedPlainTextEmailBody(attendanceRecord, employee, manager, reason);
            email.setPlainTextBody(plainTextBody);
            
            // Set email options for better deliverability
            email.setSaveAsActivity(true); // Save as activity
            email.setUseSignature(false); // Don't use signature to avoid complications
            
            debugInfo.add('Email prepared - attempting to send');
            System.debug('📧 Email message prepared, attempting to send...');
            
            // ✅ CRITICAL: Send email with specific error handling
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{ email };
            
            System.debug('🔄 Calling Messaging.sendEmail...');
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails, false); // false = don't reserve for rollback
            
            // ✅ ENHANCED: Process results with specific error type detection
            if (results != null && !results.isEmpty()) {
                Messaging.SendEmailResult result = results[0];
                
                System.debug('📧 Email Send Result: ' + result);
                System.debug('📧 Email Success: ' + result.isSuccess());
                
                if (result.isSuccess()) {
                    debugInfo.add('✅ Email sent successfully');
                    System.debug('✅ SUCCESS: Email sent successfully to: ' + manager.Email);
                    
                    emailResult.put('emailSent', true);
                    emailResult.put('debugInfo', String.join(debugInfo, ' | '));
                    
                } else {
                    // ✅ ENHANCED: Handle specific email send errors
                    List<Messaging.SendEmailError> errors = result.getErrors();
                    System.debug('❌ EMAIL SEND FAILED');
                    System.debug('❌ Number of errors: ' + errors.size());
                    
                    List<String> errorMessages = new List<String>();
                    String primaryErrorType = '';
                    
                    for (Messaging.SendEmailError error : errors) {
                        String statusCode = String.valueOf(error.getStatusCode());
                        String errorMessage = error.getMessage();
                        List<String> fields = new List<String>();
                        
                        if (error.getFields() != null) {
                            for (Object field : error.getFields()) {
                                fields.add(String.valueOf(field));
                            }
                        }
                        
                        String fullErrorMsg = 'Error: ' + errorMessage + ' (Status: ' + statusCode + ', Fields: ' + String.join(fields, ',') + ')';
                        errorMessages.add(fullErrorMsg);
                        
                        // ✅ DETECT SPECIFIC ERROR TYPES FOR TARGETED SOLUTIONS
                        if (statusCode.contains('NO_SINGLE_MAIL_PERMISSION') || 
                            errorMessage.contains('Single email is not enabled')) {
                            primaryErrorType = 'NO_SINGLE_MAIL_PERMISSION';
                            System.debug('🚨 DETECTED: NO_SINGLE_MAIL_PERMISSION error - Email Deliverability not set to "All Email"');
                        } else if (statusCode.contains('NO_MASS_MAIL_PERMISSION')) {
                            primaryErrorType = 'NO_MASS_MAIL_PERMISSION';
                            System.debug('🚨 DETECTED: NO_MASS_MAIL_PERMISSION error');
                        } else if (statusCode.contains('INSUFFICIENT_ACCESS')) {
                            primaryErrorType = 'INSUFFICIENT_ACCESS';
                            System.debug('🚨 DETECTED: INSUFFICIENT_ACCESS error');
                        } else if (statusCode.contains('INVALID_EMAIL_ADDRESS')) {
                            primaryErrorType = 'INVALID_EMAIL_ADDRESS';
                        }
                        
                        System.debug('📧 Email Error: ' + fullErrorMsg);
                    }
                    
                    debugInfo.add('❌ Email failed: ' + String.join(errorMessages, '; '));
                    
                    emailResult.put('emailSent', false);
                    emailResult.put('debugInfo', String.join(debugInfo, ' | '));
                    emailResult.put('errors', errorMessages);
                    emailResult.put('errorType', primaryErrorType);
                    
                    // ✅ PROVIDE SPECIFIC GUIDANCE BASED ON ERROR TYPE
                    if ('NO_SINGLE_MAIL_PERMISSION'.equals(primaryErrorType)) {
                        emailResult.put('adminGuidance', 'Go to Setup → Email → Deliverability → Change from "System Email Only" to "All Email" → Save');
                        emailResult.put('userGuidance', 'Contact your Salesforce administrator to enable email sending from Apex code');
                        emailResult.put('solutionUrl', '/lightning/setup/EmailDeliverability/home');
                        System.debug('🔧 SOLUTION: Administrator needs to set Email Deliverability to "All Email"');
                        System.debug('🔧 PATH: Setup → Email → Deliverability → Set to "All Email"');
                    } else if ('NO_MASS_MAIL_PERMISSION'.equals(primaryErrorType)) {
                        emailResult.put('adminGuidance', 'User profile needs "Mass Email" permission or use Org-Wide Email Address');
                        emailResult.put('userGuidance', 'Contact administrator for email permissions');
                    } else if ('INSUFFICIENT_ACCESS'.equals(primaryErrorType)) {
                        emailResult.put('adminGuidance', 'Check user permissions and email access settings');
                        emailResult.put('userGuidance', 'Insufficient permissions to send email');
                    }
                }
            } else {
                debugInfo.add('❌ No email results returned from Messaging.sendEmail');
                System.debug('❌ ERROR: No email results returned');
                
                emailResult.put('emailSent', false);
                emailResult.put('debugInfo', String.join(debugInfo, ' | '));
                emailResult.put('errorType', 'NO_RESULTS');
            }
            
        } catch (System.EmailException emailEx) {
            // ✅ ENHANCED: Handle EmailException specifically
            System.debug('🚨 EMAIL EXCEPTION: ' + emailEx.getMessage());
            System.debug('🚨 EMAIL EXCEPTION Stack: ' + emailEx.getStackTraceString());
            
            String exceptionMessage = emailEx.getMessage();
            String errorType = 'EMAIL_EXCEPTION';
            
            // Check for specific exceptions
            if (exceptionMessage.contains('NO_SINGLE_MAIL_PERMISSION') || 
                exceptionMessage.contains('Single email is not enabled')) {
                errorType = 'NO_SINGLE_MAIL_PERMISSION';
                System.debug('🚨 EMAIL EXCEPTION contains NO_SINGLE_MAIL_PERMISSION');
            } else if (exceptionMessage.contains('NO_MASS_MAIL_PERMISSION')) {
                errorType = 'NO_MASS_MAIL_PERMISSION';
            }
            
            debugInfo.add('❌ Email Exception: ' + exceptionMessage);
            
            emailResult.put('emailSent', false);
            emailResult.put('debugInfo', String.join(debugInfo, ' | '));
            emailResult.put('exception', exceptionMessage);
            emailResult.put('errorType', errorType);
            
            if ('NO_SINGLE_MAIL_PERMISSION'.equals(errorType)) {
                emailResult.put('adminGuidance', 'Setup → Email → Deliverability → Set to "All Email"');
                emailResult.put('userGuidance', 'Email deliverability settings need to be updated by administrator');
            }
            
        } catch (Exception e) {
            System.debug('🚨 GENERAL EXCEPTION in email sending: ' + e.getMessage());
            System.debug('🚨 GENERAL EXCEPTION Stack: ' + e.getStackTraceString());
            
            debugInfo.add('❌ Exception: ' + e.getMessage());
            
            emailResult.put('emailSent', false);
            emailResult.put('debugInfo', String.join(debugInfo, ' | '));
            emailResult.put('exception', e.getMessage());
            emailResult.put('errorType', 'GENERAL_EXCEPTION');
        }
        
        System.debug('=== EMAIL SEND COMPLETE ===');
        System.debug('Final Email Result: ' + emailResult);
        
        return emailResult;
    }
    
    /**
     * @description Build enhanced HTML email body for manager approval with better formatting
     */
    private static String buildEnhancedManagerApprovalEmailBody(Employee_Attendance__c attendanceRecord, User employee, User manager, String reason) {
        // Use getOrgDomainUrl() for proper URL generation
        String baseUrl;
        try {
            baseUrl = URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            baseUrl = 'https://your-org.lightning.force.com'; // Fallback
        }
        
        String approveUrl = baseUrl + '/apex/WFHApprovalPage?action=approve&recordId=' + attendanceRecord.Id + '&managerId=' + manager.Id;
        String rejectUrl = baseUrl + '/apex/WFHApprovalPage?action=reject&recordId=' + attendanceRecord.Id + '&managerId=' + manager.Id;
        
        String emailBody = '';
        emailBody += '<html><head><meta charset="UTF-8"><style>';
        emailBody += 'body { font-family: "Segoe UI", Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background: #f5f5f5; }';
        emailBody += '.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }';
        emailBody += '.urgent-header { background: linear-gradient(135deg, #dc3545, #c82333); color: white; padding: 20px; text-align: center; }';
        emailBody += '.header { background: #1589ee; color: white; padding: 20px; text-align: center; }';
        emailBody += '.content { padding: 25px; }';
        emailBody += '.info-section { background: #f8f9fa; padding: 18px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #1589ee; }';
        emailBody += '.reason-section { background: #fff3cd; padding: 18px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #ffc107; }';
        emailBody += '.urgent-section { background: #f8d7da; padding: 18px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #dc3545; }';
        emailBody += '.action-buttons { text-align: center; margin: 30px 0; }';
        emailBody += '.approve-btn { background: #28a745; color: white; padding: 15px 35px; text-decoration: none; border-radius: 8px; margin: 0 15px; display: inline-block; font-weight: bold; font-size: 16px; box-shadow: 0 3px 10px rgba(40,167,69,0.3); }';
        emailBody += '.reject-btn { background: #dc3545; color: white; padding: 15px 35px; text-decoration: none; border-radius: 8px; margin: 0 15px; display: inline-block; font-weight: bold; font-size: 16px; box-shadow: 0 3px 10px rgba(220,53,69,0.3); }';
        emailBody += '.approve-btn:hover { background: #218838; text-decoration: none; }';
        emailBody += '.reject-btn:hover { background: #c82333; text-decoration: none; }';
        emailBody += '.footer { background: #343a40; color: white; padding: 20px; text-align: center; font-size: 12px; }';
        emailBody += '.highlight { background: #ffeb3b; padding: 2px 6px; border-radius: 3px; }';
        emailBody += '.timestamp { color: #666; font-size: 14px; font-style: italic; }';
        emailBody += '</style></head><body>';
        
        emailBody += '<div class="container">';
        
        // Urgent header
        emailBody += '<div class="urgent-header">';
        emailBody += '<h2 style="margin:0;">🚨 URGENT: Manager Approval Required</h2>';
        emailBody += '<p style="margin:10px 0 0 0; font-size:14px;">Immediate Action Required</p>';
        emailBody += '</div>';
        
        emailBody += '<div class="header">';
        emailBody += '<h2 style="margin:0;">Work From Home Approval Request</h2>';
        emailBody += '<p style="margin:10px 0 0 0;">Action Required from: <strong>' + manager.Name + '</strong></p>';
        emailBody += '</div>';
        
        emailBody += '<div class="content">';
        emailBody += '<p><strong>Dear ' + manager.Name + ',</strong></p>';
        emailBody += '<p>You have received an <span class="highlight">URGENT</span> Work From Home approval request that requires your <strong>immediate attention</strong>.</p>';
        
        emailBody += '<div class="urgent-section">';
        emailBody += '<h3 style="margin-top:0;">⏰ Response Required Within 2 Hours</h3>';
        emailBody += '<p style="margin-bottom:0;"><strong>Please review and respond to this request as soon as possible to avoid delays in your team member\'s work schedule.</strong></p>';
        emailBody += '</div>';
        
        emailBody += '<div class="info-section">';
        emailBody += '<h3 style="margin-top:0;">📋 Request Details:</h3>';
        emailBody += '<p><strong>Employee:</strong> ' + employee.Name + '</p>';
        emailBody += '<p><strong>Email:</strong> ' + employee.Email + '</p>';
        emailBody += '<p><strong>Date Requested:</strong> ' + attendanceRecord.Date__c.format() + '</p>';
        emailBody += '<p><strong>Work Location:</strong> ' + attendanceRecord.Work_Location__c + '</p>';
        emailBody += '<p><strong>Department:</strong> ' + (employee.Department != null ? employee.Department : 'Not specified') + '</p>';
        emailBody += '<p style="margin-bottom:0;"><strong>Request Submitted:</strong> <span class="timestamp">' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '</span></p>';
        emailBody += '</div>';
        
        emailBody += '<div class="reason-section">';
        emailBody += '<h3 style="margin-top:0;">💬 Reason for Work From Home:</h3>';
        emailBody += '<p style="font-style: italic; font-size: 16px; margin-bottom:0; line-height: 1.5;">"' + reason + '"</p>';
        emailBody += '</div>';
        
        emailBody += '<div class="action-buttons">';
        emailBody += '<p style="margin-bottom: 25px; font-size: 18px;"><strong>⏰ Please respond within 2 hours</strong></p>';
        emailBody += '<a href="' + approveUrl + '" class="approve-btn">✅ APPROVE REQUEST</a>';
        emailBody += '<a href="' + rejectUrl + '" class="reject-btn">❌ REJECT REQUEST</a>';
        emailBody += '</div>';
        
        emailBody += '<div style="background: #e9ecef; padding: 20px; border-radius: 8px; margin: 25px 0;">';
        emailBody += '<h4 style="margin-top:0;">📧 Alternative Response Methods:</h4>';
        emailBody += '<ul style="margin-bottom:0; padding-left: 20px;">';
        emailBody += '<li>Click the buttons above for instant approval/rejection</li>';
        emailBody += '<li>Reply to this email with "APPROVE" or "REJECT" in the subject line</li>';
        emailBody += '<li>Contact the employee directly if you need additional information</li>';
        emailBody += '</ul>';
        emailBody += '</div>';
        
        emailBody += '<p style="color: #666; font-size: 14px; border-top: 1px solid #eee; padding-top: 15px;">If you have any questions about this request, please contact the employee directly or reach out to HR for guidance.</p>';
        
        emailBody += '<p>Best regards,<br/><strong>Attendance Management System</strong></p>';
        emailBody += '</div>';
        
        emailBody += '<div class="footer">';
        emailBody += '<p style="margin:0;">This is an automated email from the Attendance Management System.</p>';
        emailBody += '<p style="margin:5px 0;">Record ID: ' + attendanceRecord.Id + ' | Manager ID: ' + manager.Id + '</p>';
        emailBody += '<p style="margin:0;">Generated: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '</p>';
        emailBody += '</div>';
        
        emailBody += '</div>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
    
    /**
     * @description Build enhanced plain text email body for manager approval
     */
    private static String buildEnhancedPlainTextEmailBody(Employee_Attendance__c attendanceRecord, User employee, User manager, String reason) {
        String baseUrl;
        try {
            baseUrl = URL.getOrgDomainUrl().toExternalForm();
        } catch (Exception e) {
            baseUrl = 'https://your-org.lightning.force.com';
        }
        
        String approveUrl = baseUrl + '/apex/WFHApprovalPage?action=approve&recordId=' + attendanceRecord.Id + '&managerId=' + manager.Id;
        String rejectUrl = baseUrl + '/apex/WFHApprovalPage?action=reject&recordId=' + attendanceRecord.Id + '&managerId=' + manager.Id;
        
        String emailBody = '';
        emailBody += '🚨 URGENT: WORK FROM HOME APPROVAL REQUEST\n';
        emailBody += '=====================================\n\n';
        emailBody += 'Dear ' + manager.Name + ',\n\n';
        emailBody += 'You have received an URGENT Work From Home approval request that requires your IMMEDIATE attention.\n\n';
        emailBody += '⏰ RESPONSE REQUIRED WITHIN 2 HOURS\n';
        emailBody += 'Please review and respond as soon as possible.\n\n';
        
        emailBody += '📋 REQUEST DETAILS:\n';
        emailBody += '- Employee: ' + employee.Name + '\n';
        emailBody += '- Email: ' + employee.Email + '\n';
        emailBody += '- Date Requested: ' + attendanceRecord.Date__c.format() + '\n';
        emailBody += '- Work Location: ' + attendanceRecord.Work_Location__c + '\n';
        emailBody += '- Department: ' + (employee.Department != null ? employee.Department : 'Not specified') + '\n';
        emailBody += '- Request Submitted: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '\n\n';
        
        emailBody += '💬 REASON FOR WORK FROM HOME:\n';
        emailBody += '"' + reason + '"\n\n';
        
        emailBody += '⏰ URGENT ACTION REQUIRED - Please respond within 2 hours:\n\n';
        emailBody += '✅ TO APPROVE this request, click: ' + approveUrl + '\n\n';
        emailBody += '❌ TO REJECT this request, click: ' + rejectUrl + '\n\n';
        
        emailBody += '📧 ALTERNATIVE RESPONSE METHODS:\n';
        emailBody += '• Click the buttons above for instant approval/rejection\n';
        emailBody += '• Reply to this email with "APPROVE" or "REJECT" in the subject line\n';
        emailBody += '• Contact the employee directly if you need more information\n\n';
        
        emailBody += 'If you have any questions, please contact the employee directly or reach out to HR.\n\n';
        emailBody += 'Best regards,\n';
        emailBody += 'Attendance Management System\n\n';
        emailBody += '=====================================\n';
        emailBody += 'Record ID: ' + attendanceRecord.Id + '\n';
        emailBody += 'Manager ID: ' + manager.Id + '\n';
        emailBody += 'Generated: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '\n';
        emailBody += 'This is an automated email - Please contact HR for assistance.';
        
        return emailBody;
    }
    
    /**
     * @description Process manager's approval/rejection response
     */
    @AuraEnabled
    public static Map<String, Object> processManagerResponse(String attendanceRecordId, String managerId, String approvalStatus, String comments) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== PROCESSING MANAGER RESPONSE ===');
            System.debug('Record ID: ' + attendanceRecordId);
            System.debug('Manager ID: ' + managerId);
            System.debug('Status: ' + approvalStatus);
            
            // Input validation
            if (String.isBlank(attendanceRecordId)) {
                throw new AuraHandledException('Attendance Record ID is required');
            }
            
            if (String.isBlank(managerId)) {
                throw new AuraHandledException('Manager ID is required');
            }
            
            if (String.isBlank(approvalStatus) || 
                !(approvalStatus.equalsIgnoreCase('Approved') || approvalStatus.equalsIgnoreCase('Rejected'))) {
                throw new AuraHandledException('Approval status must be either Approved or Rejected');
            }
            
            // Get manager details
            User manager = [SELECT Id, Name, Email FROM User WHERE Id = :managerId AND IsActive = true LIMIT 1];
            
            // Update attendance record with manager's decision
            Employee_Attendance__c attendanceRecord = [
                SELECT Id, Employee_Name__c, Employee_Name__r.Name, Employee_Name__r.Email, 
                       WFH_Reason__c, Date__c, Work_Location__c
                FROM Employee_Attendance__c 
                WHERE Id = :attendanceRecordId 
                LIMIT 1
            ];
            
            attendanceRecord.WFH_Approval_Status__c = approvalStatus;
            attendanceRecord.Approval_Comments__c = comments;
            attendanceRecord.Submitted_For_Approval__c = true;
            
            update attendanceRecord;
            
            // Send notification email to employee
            Boolean notificationSent = sendEmployeeNotification(attendanceRecord, manager, approvalStatus, comments);
            
            response.put('success', true);
            response.put('approvalStatus', approvalStatus);
            response.put('managerName', manager.Name);
            response.put('employeeName', attendanceRecord.Employee_Name__r.Name);
            response.put('notificationSent', notificationSent);
            response.put('message', 'WFH request ' + approvalStatus.toLowerCase() + ' successfully');
            
            System.debug('✅ Manager response processed successfully: ' + response);
            
        } catch (Exception e) {
            System.debug('❌ Exception in processManagerResponse: ' + e.getMessage());
            response.put('success', false);
            response.put('error', e.getMessage());
            throw new AuraHandledException('Failed to process manager response: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Send notification email to employee about manager's decision
     */
    private static Boolean sendEmployeeNotification(Employee_Attendance__c attendanceRecord, User manager, String approvalStatus, String comments) {
        try {
            System.debug('=== SENDING EMPLOYEE NOTIFICATION ===');
            System.debug('To Employee: ' + attendanceRecord.Employee_Name__r.Email);
            System.debug('Status: ' + approvalStatus);
            
            // Create email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipient
            email.setToAddresses(new String[] { attendanceRecord.Employee_Name__r.Email });
            
            // Set email properties
            String subject = 'WFH Request ' + approvalStatus + ' - ' + attendanceRecord.Date__c.format();
            email.setSubject(subject);
            email.setSenderDisplayName('Attendance System');
            
            // Use org-wide email if available
            List<OrgWideEmailAddress> orgWideEmails = [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                WHERE IsAllowAllProfiles = true 
                LIMIT 1
            ];
            
            if (!orgWideEmails.isEmpty()) {
                email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
                System.debug('Using Org-Wide Email for employee notification: ' + orgWideEmails[0].Address);
            }
            
            // Create email body
            String emailBody = buildEmployeeNotificationEmailBody(attendanceRecord, manager, approvalStatus, comments);
            email.setHtmlBody(emailBody);
            
            String plainTextBody = buildEmployeeNotificationPlainText(attendanceRecord, manager, approvalStatus, comments);
            email.setPlainTextBody(plainTextBody);
            
            // Set email options
            email.setSaveAsActivity(true);
            email.setUseSignature(false);
            
            // Send email
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{ email };
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails);
            
            Boolean success = results[0].isSuccess();
            System.debug('Employee notification sent: ' + success);
            
            if (!success) {
                List<Messaging.SendEmailError> errors = results[0].getErrors();
                for (Messaging.SendEmailError error : errors) {
                    System.debug('Employee notification error: ' + error.getMessage());
                }
            }
            
            return success;
            
        } catch (Exception e) {
            System.debug('❌ Exception sending employee notification: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Build HTML email body for employee notification
     */
    private static String buildEmployeeNotificationEmailBody(Employee_Attendance__c attendanceRecord, User manager, String approvalStatus, String comments) {
        String statusColor = approvalStatus.equalsIgnoreCase('Approved') ? '#28a745' : '#dc3545';
        String statusIcon = approvalStatus.equalsIgnoreCase('Approved') ? '✅' : '❌';
        
        String emailBody = '';
        emailBody += '<html><head><style>';
        emailBody += 'body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background: #f5f5f5; }';
        emailBody += '.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }';
        emailBody += '.header { background: ' + statusColor + '; color: white; padding: 25px; text-align: center; }';
        emailBody += '.content { padding: 25px; }';
        emailBody += '.status-section { background: #f8f9fa; padding: 18px; margin: 15px 0; border-radius: 8px; border-left: 4px solid ' + statusColor + '; }';
        emailBody += '.info-section { background: #e9ecef; padding: 18px; margin: 15px 0; border-radius: 8px; }';
        emailBody += '.comments-section { background: #fff3cd; padding: 18px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #ffc107; }';
        emailBody += '.footer { background: #343a40; color: white; padding: 20px; text-align: center; font-size: 12px; }';
        emailBody += '</style></head><body>';
        
        emailBody += '<div class="container">';
        emailBody += '<div class="header">';
        emailBody += '<h2 style="margin:0;">' + statusIcon + ' WFH Request ' + approvalStatus + '</h2>';
        emailBody += '<p style="margin:10px 0 0 0;">Your request has been reviewed</p>';
        emailBody += '</div>';
        
        emailBody += '<div class="content">';
        emailBody += '<p><strong>Dear ' + attendanceRecord.Employee_Name__r.Name + ',</strong></p>';
        
        String decisionText = approvalStatus.equalsIgnoreCase('Approved') ? 
            'Your Work From Home request has been <strong style="color: #28a745;">APPROVED</strong>! You may proceed with working from home on the requested date.' : 
            'Your Work From Home request has been <strong style="color: #dc3545;">REJECTED</strong>. Please make alternative arrangements and report to the office as usual.';
            
        emailBody += '<p>' + decisionText + '</p>';
        
        emailBody += '<div class="status-section">';
        emailBody += '<h3 style="margin-top:0;">Decision Details:</h3>';
        emailBody += '<p><strong>Status:</strong> <span style="color: ' + statusColor + '; font-weight: bold;">' + approvalStatus.toUpperCase() + '</span></p>';
        emailBody += '<p><strong>Reviewed by:</strong> ' + manager.Name + '</p>';
        emailBody += '<p><strong>Request Date:</strong> ' + attendanceRecord.Date__c.format() + '</p>';
        emailBody += '<p style="margin-bottom:0;"><strong>Decision Date:</strong> ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '</p>';
        emailBody += '</div>';
        
        if (String.isNotBlank(comments)) {
            emailBody += '<div class="comments-section">';
            emailBody += '<h3 style="margin-top:0;">Manager\'s Comments:</h3>';
            emailBody += '<p style="margin-bottom:0; font-style: italic;">' + comments + '</p>';
            emailBody += '</div>';
        }
        
        emailBody += '<div class="info-section">';
        emailBody += '<h4 style="margin-top:0;">Next Steps:</h4>';
        if (approvalStatus.equalsIgnoreCase('Approved')) {
            emailBody += '<ul style="margin-bottom:0;">';
            emailBody += '<li>You are approved to work from home on ' + attendanceRecord.Date__c.format() + '</li>';
            emailBody += '<li>Please ensure you have all necessary resources for remote work</li>';
            emailBody += '<li>Maintain regular communication with your team and manager</li>';
            emailBody += '<li>Complete your normal check-in process via the attendance system</li>';
            emailBody += '</ul>';
        } else {
            emailBody += '<ul style="margin-bottom:0;">';
            emailBody += '<li>Please plan to work from the office on ' + attendanceRecord.Date__c.format() + '</li>';
            emailBody += '<li>If you have concerns, discuss them with your manager</li>';
            emailBody += '<li>Consider alternative arrangements if needed</li>';
            emailBody += '<li>Follow up with HR if you have questions about the decision</li>';
            emailBody += '</ul>';
        }
        emailBody += '</div>';
        
        emailBody += '<p style="border-top: 1px solid #eee; padding-top: 15px; color: #666; font-size: 14px;">If you have any questions about this decision, please contact your manager directly or reach out to HR for assistance.</p>';
        
        emailBody += '<p>Best regards,<br/><strong>Attendance Management System</strong></p>';
        emailBody += '</div>';
        
        emailBody += '<div class="footer">';
        emailBody += '<p style="margin:0;">This notification was generated automatically by the Attendance Management System.</p>';
        emailBody += '<p style="margin:5px 0 0 0;">Generated: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '</p>';
        emailBody += '</div>';
        
        emailBody += '</div>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
    
    /**
     * @description Build plain text email body for employee notification
     */
    private static String buildEmployeeNotificationPlainText(Employee_Attendance__c attendanceRecord, User manager, String approvalStatus, String comments) {
        String statusIcon = approvalStatus.equalsIgnoreCase('Approved') ? '✅' : '❌';
        
        String emailBody = '';
        emailBody += statusIcon + ' WORK FROM HOME REQUEST ' + approvalStatus.toUpperCase() + '\n';
        emailBody += '=====================================\n\n';
        emailBody += 'Dear ' + attendanceRecord.Employee_Name__r.Name + ',\n\n';
        
        String decisionText = approvalStatus.equalsIgnoreCase('Approved') ? 
            'Your Work From Home request has been APPROVED! You may proceed with working from home on the requested date.' : 
            'Your Work From Home request has been REJECTED. Please make alternative arrangements and report to the office as usual.';
            
        emailBody += decisionText + '\n\n';
        emailBody += 'DECISION DETAILS:\n';
        emailBody += '- Status: ' + approvalStatus.toUpperCase() + '\n';
        emailBody += '- Reviewed by: ' + manager.Name + '\n';
        emailBody += '- Request Date: ' + attendanceRecord.Date__c.format() + '\n';
        emailBody += '- Decision Date: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '\n\n';
        
        if (String.isNotBlank(comments)) {
            emailBody += 'MANAGER\'S COMMENTS:\n';
            emailBody += comments + '\n\n';
        }
        
        emailBody += 'NEXT STEPS:\n';
        if (approvalStatus.equalsIgnoreCase('Approved')) {
            emailBody += '• You are approved to work from home on ' + attendanceRecord.Date__c.format() + '\n';
            emailBody += '• Please ensure you have all necessary resources for remote work\n';
            emailBody += '• Maintain regular communication with your team and manager\n';
            emailBody += '• Complete your normal check-in process via the attendance system\n\n';
        } else {
            emailBody += '• Please plan to work from the office on ' + attendanceRecord.Date__c.format() + '\n';
            emailBody += '• If you have concerns, discuss them with your manager\n';
            emailBody += '• Consider alternative arrangements if needed\n';
            emailBody += '• Follow up with HR if you have questions about the decision\n\n';
        }
        
        emailBody += 'If you have any questions, please contact your manager or HR.\n\n';
        emailBody += 'Best regards,\n';
        emailBody += 'Attendance Management System\n\n';
        emailBody += '=====================================\n';
        emailBody += 'Generated: ' + DateTime.now().format('MM/dd/yyyy hh:mm a z') + '\n';
        emailBody += 'This is an automated notification.';
        
        return emailBody;
    }
    
    /**
     * @description Get WFH approval requests for a manager
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getWFHApprovalRequests(String managerId) {
        List<Map<String, Object>> approvalRequests = new List<Map<String, Object>>();
        
        try {
            if (String.isBlank(managerId)) {
                return approvalRequests;
            }
            
            List<Employee_Attendance__c> pendingRequests = [
                SELECT Id, Employee_Name__c, Employee_Name__r.Name, Employee_Name__r.Email,
                       Employee_Name__r.Manager.Id, Date__c, Work_Location__c, WFH_Reason__c,
                       WFH_Approval_Status__c, CreatedDate, Check_In_Time__c
                FROM Employee_Attendance__c
                WHERE Employee_Name__r.Manager.Id = :managerId
                AND Submitted_For_Approval__c = true
                AND WFH_Approval_Status__c = 'Pending'
                AND Work_Location__c = 'Work from Home'
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            for (Employee_Attendance__c request : pendingRequests) {
                Map<String, Object> requestMap = new Map<String, Object>();
                requestMap.put('Id', request.Id);
                requestMap.put('employeeName', request.Employee_Name__r.Name);
                requestMap.put('employeeEmail', request.Employee_Name__r.Email);
                requestMap.put('requestDate', request.Date__c.format());
                requestMap.put('workLocation', request.Work_Location__c);
                requestMap.put('reason', request.WFH_Reason__c);
                requestMap.put('status', request.WFH_Approval_Status__c);
                requestMap.put('submittedDate', request.CreatedDate.format('MM/dd/yyyy hh:mm a'));
                requestMap.put('checkInTime', request.Check_In_Time__c != null ? request.Check_In_Time__c.format('hh:mm a') : 'Not checked in');
                
                approvalRequests.add(requestMap);
            }
            
            System.debug('✅ Found ' + approvalRequests.size() + ' pending WFH requests for manager: ' + managerId);
            
        } catch (Exception e) {
            System.debug('❌ Error getting WFH approval requests: ' + e.getMessage());
        }
        
        return approvalRequests;
    }
    
    /**
     * @description Test method for debugging email configuration issues
     */
    @AuraEnabled
    public static Map<String, Object> testEmailDebugging() {
        Map<String, Object> testResult = new Map<String, Object>();
        
        try {
            System.debug('=== EMAIL DEBUGGING TEST START ===');
            
            // Check deliverability settings
            Map<String, Object> deliverabilityInfo = checkEmailDeliverabilitySettings();
            testResult.put('deliverabilityInfo', deliverabilityInfo);
            
            // Check org-wide email addresses
            List<OrgWideEmailAddress> orgWideEmails = [SELECT Id, Address, DisplayName, IsAllowAllProfiles FROM OrgWideEmailAddress];
            System.debug('Org-Wide Email Addresses found: ' + orgWideEmails.size());
            
            List<Map<String, Object>> orgEmailDetails = new List<Map<String, Object>>();
            for (OrgWideEmailAddress orgEmail : orgWideEmails) {
                Map<String, Object> emailDetails = new Map<String, Object>();
                emailDetails.put('id', orgEmail.Id);
                emailDetails.put('address', orgEmail.Address);
                emailDetails.put('displayName', orgEmail.DisplayName);
                emailDetails.put('isAllowAllProfiles', orgEmail.IsAllowAllProfiles);
                orgEmailDetails.add(emailDetails);
                
                System.debug('Org Email: ' + orgEmail.DisplayName + ' <' + orgEmail.Address + '> (Allow All Profiles: ' + orgEmail.IsAllowAllProfiles + ')');
            }
            
            testResult.put('success', true);
            testResult.put('orgWideEmailCount', orgWideEmails.size());
            testResult.put('orgWideEmails', orgEmailDetails);
            testResult.put('debugComplete', true);
            testResult.put('message', 'Email debugging completed successfully. Check debug logs for detailed information.');
            
            System.debug('=== EMAIL DEBUGGING TEST COMPLETE ===');
            System.debug('Test Result: ' + testResult);
            
        } catch (Exception e) {
            System.debug('❌ Test debugging error: ' + e.getMessage());
            testResult.put('success', false);
            testResult.put('error', e.getMessage());
        }
        
        return testResult;
    }
}