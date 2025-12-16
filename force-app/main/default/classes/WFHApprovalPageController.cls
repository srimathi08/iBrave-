/**
 * @description WFH Approval Page Controller - Fixed DML Constructor Issue
 * @author Salesforce Consultant
 * @date 2025-10-03
 * @version 2.0 - Fixed DML constructor error
 */
public class WFHApprovalPageController {
    
    public String attendanceRecordId { get; set; }
    public String managerId { get; set; }
    public String action { get; set; }
    public String message { get; set; }
    public String messageType { get; set; }
    public Boolean showMessage { get; set; }
    
    public Employee_Attendance__c attendanceRecord { get; set; }
    public User employee { get; set; }
    public User manager { get; set; }
    
    public String approvalComments { get; set; }
    
    /**
     * ✅ FIXED: Constructor without DML operations
     */
    public WFHApprovalPageController() {
        // Get URL parameters
        this.attendanceRecordId = ApexPages.currentPage().getParameters().get('recordId');
        this.managerId = ApexPages.currentPage().getParameters().get('managerId');
        this.action = ApexPages.currentPage().getParameters().get('action');
        
        this.showMessage = false;
        this.messageType = 'info';
        this.message = '';
        
        System.debug('✅ Constructor - RecordId: ' + this.attendanceRecordId + ', Action: ' + this.action);
        
        // Load data without DML
        loadApprovalData();
    }
    
    /**
     * ✅ FIXED: Load data without DML operations
     */
    private void loadApprovalData() {
        try {
            if (String.isNotBlank(this.attendanceRecordId)) {
                // Load attendance record
                List<Employee_Attendance__c> records = [
                    SELECT Id, Employee_Name__c, Employee_Name__r.Name, Employee_Name__r.Email,
                           Date__c, Work_Location__c, WFH_Reason__c, WFH_Approval_Status__c,
                           Check_In_Time__c, Approval_Comments__c
                    FROM Employee_Attendance__c 
                    WHERE Id = :this.attendanceRecordId 
                    LIMIT 1
                ];
                
                if (!records.isEmpty()) {
                    this.attendanceRecord = records[0];
                    
                    // Load employee details
                    List<User> employees = [
                        SELECT Id, Name, Email, Department, Title
                        FROM User 
                        WHERE Id = :this.attendanceRecord.Employee_Name__c 
                        LIMIT 1
                    ];
                    
                    if (!employees.isEmpty()) {
                        this.employee = employees[0];
                    }
                }
            }
            
            if (String.isNotBlank(this.managerId)) {
                // Load manager details
                List<User> managers = [
                    SELECT Id, Name, Email, Department, Title
                    FROM User 
                    WHERE Id = :this.managerId 
                    LIMIT 1
                ];
                
                if (!managers.isEmpty()) {
                    this.manager = managers[0];
                }
            }
            
        } catch (Exception e) {
            System.debug('❌ Error loading approval data: ' + e.getMessage());
            this.message = 'Error loading approval data: ' + e.getMessage();
            this.messageType = 'error';
            this.showMessage = true;
        }
    }
    
    /**
     * ✅ FIXED: Auto-process action using page action (not constructor)
     */
    public PageReference processAutoAction() {
        System.debug('=== PROCESSING AUTO ACTION ===');
        System.debug('Action: ' + this.action + ', RecordId: ' + this.attendanceRecordId);
        
        try {
            if (String.isNotBlank(this.action) && String.isNotBlank(this.attendanceRecordId)) {
                if (this.action.equalsIgnoreCase('approve')) {
                    return processApproval();
                } else if (this.action.equalsIgnoreCase('reject')) {
                    return processRejection();
                }
            }
        } catch (Exception e) {
            System.debug('❌ Error in processAutoAction: ' + e.getMessage());
            this.message = 'Error processing request: ' + e.getMessage();
            this.messageType = 'error';
            this.showMessage = true;
        }
        
        return null;
    }
    
    /**
     * ✅ FIXED: Process approval with proper DML in action method
     */
    public PageReference processApproval() {
        return processRequest('Approved', 'Auto-approved via email link by ' + (this.manager != null ? this.manager.Name : 'Manager'));
    }
    
    /**
     * ✅ FIXED: Process rejection with proper DML in action method
     */
    public PageReference processRejection() {
        return processRequest('Rejected', 'Auto-rejected via email link by ' + (this.manager != null ? this.manager.Name : 'Manager'));
    }
    
    /**
     * Manual approval action
     */
    public PageReference approveRequest() {
        return processRequest('Approved', this.approvalComments);
    }
    
    /**
     * Manual rejection action
     */
    public PageReference rejectRequest() {
        return processRequest('Rejected', this.approvalComments);
    }
    
    /**
     * ✅ FIXED: Process request with DML operations in action method
     */
    private PageReference processRequest(String approvalStatus, String comments) {
        try {
            System.debug('=== PROCESSING REQUEST ===');
            System.debug('Status: ' + approvalStatus + ', Comments: ' + comments);
            
            // ✅ DML IS ALLOWED IN ACTION METHODS
            Map<String, Object> result = WFHApprovalController.processManagerResponse(
                this.attendanceRecordId, 
                this.managerId, 
                approvalStatus, 
                comments
            );
            
            if ((Boolean)result.get('success')) {
                String statusText = approvalStatus.equalsIgnoreCase('Approved') ? 'approved' : 'rejected';
                this.message = 'WFH request has been ' + statusText + ' successfully. Employee will be notified.';
                this.messageType = 'success';
                
                // Reload data to show updated status
                loadApprovalData();
                
            } else {
                this.message = 'Error processing request: ' + result.get('error');
                this.messageType = 'error';
            }
            
            this.showMessage = true;
            
        } catch (Exception e) {
            System.debug('❌ Error processing request: ' + e.getMessage());
            this.message = 'Error processing request: ' + e.getMessage();
            this.messageType = 'error';
            this.showMessage = true;
        }
        
        return null; // Stay on the same page
    }
    
    // Getter methods for display
    public String getFormattedRequestDate() {
        return this.attendanceRecord != null ? this.attendanceRecord.Date__c.format() : '';
    }
    
    public String getEmployeeName() {
        return this.employee != null ? this.employee.Name : 'Unknown Employee';
    }
    
    public String getManagerName() {
        return this.manager != null ? this.manager.Name : 'Unknown Manager';
    }
    
    public String getCurrentStatus() {
        return this.attendanceRecord != null ? this.attendanceRecord.WFH_Approval_Status__c : 'Unknown';
    }
    
    public Boolean getIsAlreadyProcessed() {
        return this.attendanceRecord != null && 
               this.attendanceRecord.WFH_Approval_Status__c != null &&
               !this.attendanceRecord.WFH_Approval_Status__c.equals('Pending');
    }
}