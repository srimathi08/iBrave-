/**
 * @description Visualforce controller for WFH approval action links
 * @author Your Name
 * @date October 2025
 */
public with sharing class WFHApprovalAction {
    
    public String action { get; set; }
    public String attendanceId { get; set; }
    public String managerId { get; set; }
    public String comments { get; set; }
    public Boolean showForm { get; set; }
    public Boolean isProcessed { get; set; }
    public String resultMessage { get; set; }
    public String resultType { get; set; }
    public Employee_Attendance__c attendance { get; set; }
    public User currentManager { get; set; }
    
    public WFHApprovalAction() {
        action = ApexPages.currentPage().getParameters().get('action');
        attendanceId = ApexPages.currentPage().getParameters().get('id');
        managerId = ApexPages.currentPage().getParameters().get('manager');
        
        showForm = false;
        isProcessed = false;
        comments = '';
        
        loadData();
        
        // If action is provided in URL, show confirmation form
        if (String.isNotBlank(action) && String.isNotBlank(attendanceId)) {
            showForm = true;
        }
    }
    
    private void loadData() {
        try {
            // Load Employee_Attendance__c record
            if (String.isNotBlank(attendanceId)) {
                List<Employee_Attendance__c> records = [
                    SELECT Id, Employee_Name__r.Name, Employee_Name__r.Email, Work_Location__c, 
                           WFH_Reason__c, WFH_Approval_Status__c, Date__c, Approval_Comments__c
                    FROM Employee_Attendance__c 
                    WHERE Id = :attendanceId 
                    LIMIT 1
                ];
                
                if (!records.isEmpty()) {
                    attendance = records[0];
                }
            }
            
            // Load manager info
            if (String.isNotBlank(managerId)) {
                List<User> managers = [
                    SELECT Id, Name, Email
                    FROM User 
                    WHERE Id = :managerId 
                    LIMIT 1
                ];
                
                if (!managers.isEmpty()) {
                    currentManager = managers[0];
                }
            }
            
        } catch (Exception e) {
            System.debug('Error loading data: ' + e.getMessage());
        }
    }
    
    public PageReference processApproval() {
        try {
            if (attendance == null) {
                throw new CustomException('Employee Attendance record not found');
            }
            
            String newStatus = '';
            String statusMessage = '';
            
            if (action.toLowerCase() == 'approve') {
                newStatus = 'Approved';
                statusMessage = 'WFH request approved successfully';
                resultType = 'success';
            } else if (action.toLowerCase() == 'reject') {
                newStatus = 'Rejected';
                statusMessage = 'WFH request rejected';
                resultType = 'error';
            } else {
                throw new CustomException('Invalid action specified');
            }
            
            // Update Employee_Attendance__c record
            attendance.WFH_Approval_Status__c = newStatus;
            attendance.Approval_Comments__c = comments;
            
            update attendance;
            
            // Process any pending approval process
            processApprovalWorkItem(newStatus);
            
            // Send notification email to employee
            sendApprovalNotificationToEmployee(newStatus);
            
            isProcessed = true;
            resultMessage = statusMessage;
            showForm = false;
            
        } catch (Exception e) {
            isProcessed = true;
            resultMessage = 'Error processing approval: ' + e.getMessage();
            resultType = 'error';
            showForm = false;
        }
        
        return null;
    }
    
    private void processApprovalWorkItem(String decision) {
        try {
            // Find pending approval work item
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id, ProcessInstanceId
                FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :attendanceId
                AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];
            
            if (!workItems.isEmpty()) {
                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setComments(comments);
                req.setAction(decision.toLowerCase() == 'approved' ? 'Approve' : 'Reject');
                req.setWorkitemId(workItems[0].Id);
                
                Approval.ProcessResult result = Approval.process(req);
                
                if (result.isSuccess()) {
                    System.debug('Approval process completed: ' + decision);
                } else {
                    System.debug('Approval process failed: ' + result.getErrors()[0].getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug('Error processing approval work item: ' + e.getMessage());
        }
    }
    
    private void sendApprovalNotificationToEmployee(String decision) {
        try {
            if (attendance.Employee_Name__r == null) return;
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{attendance.Employee_Name__r.Email});
            
            String dateStr = attendance.Date__c != null ? attendance.Date__c.format() : 'Unknown';
            String subject = 'WFH Request ' + (decision == 'Approved' ? 'Approved' : 'Rejected') + ' - ' + dateStr;
            email.setSubject(subject);
            
            String body = buildEmployeeNotificationEmail(decision);
            email.setHtmlBody(body);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
        } catch (Exception e) {
            System.debug('Error sending notification to employee: ' + e.getMessage());
        }
    }
    
    private String buildEmployeeNotificationEmail(String decision) {
        String statusColor = (decision == 'Approved') ? '#00a652' : '#c23934';
        String statusIcon = (decision == 'Approved') ? '✓' : '✗';
        String dateStr = attendance.Date__c != null ? attendance.Date__c.format() : 'Unknown';
        
        String emailBody = '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">';
        
        emailBody += '<div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">';
        
        // Header
        emailBody += '<div style="background: ' + statusColor + '; color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0;">';
        emailBody += '<h1 style="margin: 0; font-size: 24px;">' + statusIcon + ' WFH Request ' + decision + '</h1>';
        emailBody += '</div>';
        
        // Content
        emailBody += '<div style="padding: 30px;">';
        emailBody += '<p style="font-size: 16px; color: #333;">Dear ' + attendance.Employee_Name__r.Name + ',</p>';
        
        if (decision == 'Approved') {
            emailBody += '<p style="font-size: 14px; color: #555;">Your Work from Home request for <strong>' + dateStr + '</strong> has been <span style="color: #00a652; font-weight: 600;">approved</span> by your manager.</p>';
            emailBody += '<div style="background: #e8f5e8; border-left: 4px solid #00a652; padding: 15px; margin: 20px 0;">';
            emailBody += '<p style="margin: 0; color: #2d5a2d;">You can proceed with working from home on the requested date. This will be reflected as "Approved" in your attendance records.</p>';
            emailBody += '</div>';
        } else {
            emailBody += '<p style="font-size: 14px; color: #555;">Your Work from Home request for <strong>' + dateStr + '</strong> has been <span style="color: #c23934; font-weight: 600;">rejected</span> by your manager.</p>';
            emailBody += '<div style="background: #ffecec; border-left: 4px solid #c23934; padding: 15px; margin: 20px 0;">';
            emailBody += '<p style="margin: 0; color: #5a2d2d;">As your WFH request was not approved, this day will be considered as LOP (Loss of Pay) in your attendance records. Please contact your manager for more details.</p>';
            emailBody += '</div>';
        }
        
        if (String.isNotBlank(comments)) {
            emailBody += '<div style="background: #f8f9fa; border-radius: 6px; padding: 15px; margin: 20px 0;">';
            emailBody += '<h4 style="margin: 0 0 10px 0; color: #333;">Manager Comments:</h4>';
            emailBody += '<p style="margin: 0; color: #555; font-style: italic;">' + comments + '</p>';
            emailBody += '</div>';
        }
        
        emailBody += '<p style="font-size: 12px; color: #888; margin-top: 30px;">If you have any questions, please contact your manager or HR department.</p>';
        emailBody += '</div></div></body></html>';
        
        return emailBody;
    }
    
    public String getActionText() {
        if (String.isNotBlank(action)) {
            return action.toLowerCase() == 'approve' ? 'Approve' : 'Reject';
        }
        return 'Process';
    }
    
    public String getStatusClass() {
        if (resultType == 'success') return 'success';
        if (resultType == 'error') return 'error';
        return 'info';
    }
    
    public class CustomException extends Exception {}
}