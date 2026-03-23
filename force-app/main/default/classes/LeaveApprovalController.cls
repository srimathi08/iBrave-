global without sharing class LeaveApprovalController {
    
    public Leave_Request__c leaveRequest { get; set; }
    public String managerComments { get; set; }
    public Boolean showSuccess { get; set; }
    public Boolean showInfo { get; set; }
    public Boolean showError { get; set; }
    public String errorMessage { get; set; }
    public String actionTaken { get; set; }
    public String infoMessage { get; set; }
    
    public String employeeName { get; set; }
    public String employeeEmail { get; set; }
    public String leaveTypeName { get; set; }
    public String startDate { get; set; }
    public String endDate { get; set; }
    public String totalDays { get; set; }
    public String reason { get; set; }
    public String rejectionReason { get; set; }
    
    private String requestId;
    private String managerId;
    
    public LeaveApprovalController() {
        showSuccess = false;
        showError   = false;
        showInfo    = false;
        
        requestId = ApexPages.currentPage().getParameters().get('id');
        managerId = ApexPages.currentPage().getParameters().get('mgr');
        
        if (String.isNotBlank(requestId)) {
            loadLeaveRequest();
        } else {
            showError = true;
            errorMessage = 'Invalid or expired leave request.';
        }
    }
    
    private void loadLeaveRequest() {
        try {
            List<Leave_Request__c> requests = [
                SELECT Id, Employee__c, Employee__r.Name, Employee__r.Email,
                       Leave_Type__c, Leave_Type__r.Leave_Type_Name__c,
                       Start_Date__c, End_Date__c, Total_Days__c,
                       Reason__c, Status__c, Manager__c, Manager_Comments__c
                FROM Leave_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            
            if (!requests.isEmpty()) {
                Leave_Request__c req = requests[0];
                
                // If already processed, show info — don't load the form
                if (req.Status__c != 'Pending') {
                    showInfo = true;
                    infoMessage = 'This leave request has already been ' 
                                  + req.Status__c 
                                  + ' and cannot be actioned again.';
                    return;
                }
                
                leaveRequest   = req;
                employeeName   = leaveRequest.Employee__r.Name;
                employeeEmail  = leaveRequest.Employee__r.Email;
                leaveTypeName  = leaveRequest.Leave_Type__r.Leave_Type_Name__c;
                startDate      = leaveRequest.Start_Date__c.format();
                endDate        = leaveRequest.End_Date__c.format();
                totalDays      = String.valueOf(leaveRequest.Total_Days__c);
                reason         = leaveRequest.Reason__c;
                
            } else {
                showError = true;
                errorMessage = 'Leave request not found. The link may be invalid or expired.';
            }
            
        } catch (Exception e) {
            showError = true;
            errorMessage = 'Error loading leave request: ' + e.getMessage();
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
            if (leaveRequest == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }
            
            leaveRequest.Status__c          = action;
            leaveRequest.Manager_Comments__c = managerComments;
            leaveRequest.Approved_By__c     = managerId;
            
            if (action == 'Approved') {
                leaveRequest.Approved_Date__c = System.now();
            } else if (action == 'Cancelled') {
                leaveRequest.Cancelled_Date__c  = System.now();
                leaveRequest.Cancelled_Reason__c = managerComments;
            }
            
            update leaveRequest;
            sendConfirmationEmail(action);
            
            showSuccess = true;
            actionTaken = action; // Keep original casing: 'Approved' / 'Cancelled'
            leaveRequest = null;  // Clear so form hides on any back/reload
            
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
            
            if (leaveRequest == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }
            
            leaveRequest.Status__c           = 'Rejected';
            leaveRequest.Rejection_Reason__c = rejectionReason;
            leaveRequest.Manager_Comments__c = rejectionReason;
            leaveRequest.Approved_By__c      = managerId;
            leaveRequest.Rejected_Date__c    = Date.today();
            
            update leaveRequest;
            
            // Set email vars before clearing leaveRequest
            managerComments = rejectionReason;
            sendConfirmationEmail('Rejected');
            
            showSuccess  = true;
            actionTaken  = 'Rejected';
            leaveRequest = null;
            
        } catch (Exception e) {
            showError    = true;
            errorMessage = e.getMessage();
        }
        return null;
    }
    
    private void sendConfirmationEmail(String action) {
        try {
            String subject = 'Leave Request ' + action;
            String body = '<html><body style="font-family: Arial, sans-serif; color:#333;">';
            body += '<div style="max-width:600px; margin:auto; border:1px solid #e0e0e0; border-radius:10px; overflow:hidden;">';
            body += '<div style="background:#0176d3; padding:25px; text-align:center;">';
            body += '<h2 style="color:white; margin:0;">Leave Request ' + action + '</h2>';
            body += '</div>';
            body += '<div style="padding:30px;">';
            body += '<p>Dear <strong>' + employeeName + '</strong>,</p>';
            body += '<p>Your leave request has been <strong>' + action + '</strong>.</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse:collapse; width:100%;">';
            body += '<tr style="background:#f3f4f6;"><td><strong>Leave Type</strong></td><td>' + leaveTypeName + '</td></tr>';
            body += '<tr><td><strong>Start Date</strong></td><td>' + startDate + '</td></tr>';
            body += '<tr style="background:#f3f4f6;"><td><strong>End Date</strong></td><td>' + endDate + '</td></tr>';
            body += '<tr><td><strong>Total Days</strong></td><td>' + totalDays + '</td></tr>';
            if (String.isNotBlank(managerComments)) {
                body += '<tr style="background:#f3f4f6;"><td><strong>Manager Comments</strong></td><td>' + managerComments + '</td></tr>';
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