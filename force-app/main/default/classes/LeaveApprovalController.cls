public with sharing class LeaveApprovalController {
    
    public Leave_Request__c leaveRequest { get; set; }
    public String managerComments { get; set; }
    public Boolean showSuccess { get; set; }
    public Boolean showError { get; set; }
    public String errorMessage { get; set; }
    public String actionTaken { get; set; }
    
    public String employeeName { get; set; }
    public String employeeEmail { get; set; }
    public String leaveTypeName { get; set; }
    public String startDate { get; set; }
    public String endDate { get; set; }
    public String totalDays { get; set; }
    public String reason { get; set; }
    
    private String requestId;
    private String managerId;
    
    public LeaveApprovalController() {
        showSuccess = false;
        showError = false;
        
        requestId = ApexPages.currentPage().getParameters().get('id');
        managerId = ApexPages.currentPage().getParameters().get('mgr');
        
        if (String.isNotBlank(requestId)) {
            loadLeaveRequest();
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
                AND Status__c = 'Pending'
                LIMIT 1
            ];
            
            if (!requests.isEmpty()) {
                leaveRequest = requests[0];
                employeeName = leaveRequest.Employee__r.Name;
                employeeEmail = leaveRequest.Employee__r.Email;
                leaveTypeName = leaveRequest.Leave_Type__r.Leave_Type_Name__c;
                startDate = leaveRequest.Start_Date__c.format();
                endDate = leaveRequest.End_Date__c.format();
                totalDays = String.valueOf(leaveRequest.Total_Days__c);
                reason = leaveRequest.Reason__c;
            }
        } catch (Exception e) {
            showError = true;
            errorMessage = 'Error loading leave request: ' + e.getMessage();
        }
    }
    
    public PageReference approveRequest() {
        return processRequest('Approved');
    }
    
    public PageReference rejectRequest() {
        return processRequest('Rejected');
    }
    
    public PageReference cancelRequest() {
        return processRequest('Cancelled');
    }
    
    private PageReference processRequest(String action) {
        try {
            if (String.isBlank(managerComments)) {
                showError = true;
                errorMessage = 'Please enter comments before taking action.';
                return null;
            }
            
            if (leaveRequest == null) {
                showError = true;
                errorMessage = 'Invalid leave request or already processed.';
                return null;
            }
            
            leaveRequest.Status__c = action;
            leaveRequest.Manager_Comments__c = managerComments;
            leaveRequest.Approved_By__c = managerId;
            
            if (action == 'Approved') {
                leaveRequest.Approved_Date__c = System.now();
            } else if (action == 'Rejected') {
                leaveRequest.Rejected_Date__c = System.now();
                leaveRequest.Rejection_Reason__c = managerComments;
            } else if (action == 'Cancelled') {
                leaveRequest.Cancelled_Date__c = System.now();
                leaveRequest.Cancelled_Reason__c = managerComments;
            }
            
            update leaveRequest;
            
            sendConfirmationEmail(action);
            
            showSuccess = true;
            actionTaken = action.toLowerCase();
            leaveRequest = null; // Clear to show invalid message on reload
            
            return null;
            
        } catch (Exception e) {
            showError = true;
            errorMessage = 'Error processing request: ' + e.getMessage();
            return null;
        }
    }
    
    // NEW METHOD - for action function (no-op)
    public PageReference doNothing() {
        return null;
    }
    
    private void sendConfirmationEmail(String action) {
        try {
            String subject = 'Leave Request ' + action;
            String body = '<html><body style="font-family: Arial, sans-serif;">';
            body += '<h2>Leave Request ' + action + '</h2>';
            body += '<p>Dear ' + employeeName + ',</p>';
            body += '<p>Your leave request has been <strong>' + action.toLowerCase() + '</strong>.</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse;">';
            body += '<tr><td><strong>Leave Type</strong></td><td>' + leaveTypeName + '</td></tr>';
            body += '<tr><td><strong>Start Date</strong></td><td>' + startDate + '</td></tr>';
            body += '<tr><td><strong>End Date</strong></td><td>' + endDate + '</td></tr>';
            body += '<tr><td><strong>Total Days</strong></td><td>' + totalDays + '</td></tr>';
            body += '<tr><td><strong>Manager Comments</strong></td><td>' + managerComments + '</td></tr>';
            body += '</table>';
            body += '<p>Thank you,<br/>HR Management System</p>';
            body += '</body></html>';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { employeeEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending confirmation email: ' + e.getMessage());
        }
    }
}