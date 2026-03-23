global with sharing class WFHApprovalController {

    public Work_from_home_Request__c wfh { get; set; }
    public Boolean showSuccess     { get; set; }
    public Boolean showInfo        { get; set; }
    public Boolean showError       { get; set; }
    public String  errorMessage    { get; set; }
    public String  infoMessage     { get; set; }
    public String  actionTaken     { get; set; }
    public String  rejectionReason { get; set; }

    // Display fields
    public String employeeName   { get; set; }
    public String employeeEmail  { get; set; }
    public String startDate      { get; set; }
    public String endDate        { get; set; }
    public String numberOfDays   { get; set; }
    public String reason         { get; set; }

    // 2-level approval UI properties
    public String  approvalLevel         { get; set; }
    public Boolean isManagerLevel        { get; set; }
    public Boolean isHRLevel             { get; set; }
    public String  managerName           { get; set; }
    public String  managerComments       { get; set; }
    public String  managerApprovalStatus { get; set; }
    public String  approvalLevelLabel    { get; set; }
    public String  approveButtonLabel    { get; set; }
    public Boolean isTwoLevelApproval    { get; set; }

    // ================================================================
    // NEW: Captures approver's comments when clicking Approve
    //      Manager comments → stored in Comments__c → shown to HR
    //      HR comments      → stored in HR_Comments__c
    // ================================================================
    public String approvalComments { get; set; }

    private String managerId;

    public WFHApprovalController() {
        showSuccess        = false;
        showInfo           = false;
        showError          = false;
        isManagerLevel     = false;
        isHRLevel          = false;
        isTwoLevelApproval = false;
        approvalComments   = '';

        String recordId = ApexPages.currentPage().getParameters().get('id');
        managerId       = ApexPages.currentPage().getParameters().get('mgr');

        if (String.isNotBlank(recordId)) {
            loadWFHRequest(recordId);
        } else {
            showError    = true;
            errorMessage = 'Invalid or expired WFH request link.';
        }
    }

    private void loadWFHRequest(String recordId) {
        try {
            List<Work_from_home_Request__c> records = [
                SELECT Id, Status__c,
                       Start_Date__c, End_Date__c,
                       Number_Of_Days__c, Reason__c,
                       Employee__r.Name, Employee__r.Email,
                       Manager__r.Name,
                       Approval_Level__c,
                       Manager_Approval_Status__c,
                       Comments__c,
                       Rejection_Reason__c
                FROM Work_from_home_Request__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (records.isEmpty()) {
                showError    = true;
                errorMessage = 'WFH request not found. The link may be invalid or expired.';
                return;
            }

            Work_from_home_Request__c rec = records[0];

            Boolean isPendingManager = (rec.Status__c == 'Pending'             && rec.Approval_Level__c == 'Manager');
            Boolean isPendingHR      = (rec.Status__c == 'Pending HR Approval' && rec.Approval_Level__c == 'HR');

            if (!isPendingManager && !isPendingHR) {
                showInfo    = true;
                infoMessage = 'This WFH request has already been '
                              + rec.Status__c
                              + ' and cannot be actioned again.';
                return;
            }

            wfh           = rec;
            employeeName  = wfh.Employee__r.Name;
            employeeEmail = wfh.Employee__r.Email;
            startDate     = wfh.Start_Date__c.format();
            endDate       = wfh.End_Date__c.format();
            numberOfDays  = String.valueOf(Integer.valueOf(wfh.Number_Of_Days__c));
            reason        = wfh.Reason__c;
            approvalLevel = rec.Approval_Level__c;

            Integer days       = Integer.valueOf(wfh.Number_Of_Days__c);
            isTwoLevelApproval = (days >= 3);

            if (isPendingManager) {
                isManagerLevel = true;
                isHRLevel      = false;

                if (isTwoLevelApproval) {
                    approvalLevelLabel = 'Level 1 – Manager Approval';
                    approveButtonLabel = 'Approve & Forward to HR';
                } else {
                    approvalLevelLabel = 'Manager Approval';
                    approveButtonLabel = 'Approve';
                }

            } else {
                isManagerLevel       = false;
                isHRLevel            = true;
                isTwoLevelApproval   = true;
                approvalLevelLabel   = 'Level 2 – HR Final Approval';
                approveButtonLabel   = 'Final Approve';
                // ================================================================
                // Pull Manager's saved comments from Comments__c
                // These were stored when Manager clicked Approve at Level 1
                // ================================================================
                managerName           = wfh.Manager__r != null ? wfh.Manager__r.Name : '';
                managerComments       = wfh.Comments__c;
                managerApprovalStatus = wfh.Manager_Approval_Status__c;
            }

        } catch (Exception e) {
            showError    = true;
            errorMessage = 'Error loading WFH request: ' + e.getMessage();
        }
    }

    // ================================================================
    // approve() — passes approvalComments to the correct level method
    // Manager approving 3-5 days: comments saved to Comments__c
    //   → HR sees them in Manager Decision card
    // ================================================================
    public PageReference approve() {
        try {
            if (wfh == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }
            if (isManagerLevel) {
                WFH_Request.processManagerDecision(
                    wfh.Id, 'Approved',
                    String.isNotBlank(approvalComments) ? approvalComments : ''
                );
            } else if (isHRLevel) {
                WFH_Request.processHRDecision(
                    wfh.Id, 'Approved',
                    String.isNotBlank(approvalComments) ? approvalComments : ''
                );
            }
            showSuccess = true;
            actionTaken = 'Approved';
            wfh         = null;
        } catch (Exception e) {
            showError    = true;
            errorMessage = 'Error approving request: ' + e.getMessage();
        }
        return null;
    }

    // ================================================================
    // reject() — passes rejectionReason to the correct level method
    // ================================================================
    public PageReference reject() {
        try {
            if (String.isBlank(rejectionReason)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 'Rejection reason is required.'
                ));
                return null;
            }
            if (wfh == null) {
                showInfo    = true;
                infoMessage = 'This request has already been processed.';
                return null;
            }
            if (isManagerLevel) {
                WFH_Request.processManagerDecision(wfh.Id, 'Rejected', rejectionReason);
            } else if (isHRLevel) {
                WFH_Request.processHRDecision(wfh.Id, 'Rejected', rejectionReason);
            }
            showSuccess = true;
            actionTaken = 'Rejected';
            wfh         = null;
        } catch (Exception e) {
            showError    = true;
            errorMessage = 'Error rejecting request: ' + e.getMessage();
        }
        return null;
    }
}