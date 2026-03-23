@isTest
private class WFHApprovalControllerTest {

    // ================================================================
    // TEST DATA SETUP
    // ================================================================
    @TestSetup
    static void setupTestData() {

        // Create Manager user
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User manager = new User(
            FirstName       = 'Test',
            LastName        = 'Manager',
            Email           = 'testmanager@testorg.com',
            Username        = 'testmanager_wfh@testorg.com' + System.currentTimeMillis(),
            Alias           = 'tmgr',
            TimeZoneSidKey  = 'Asia/Kolkata',
            LocaleSidKey    = 'en_US',
            EmailEncodingKey= 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId       = standardProfile.Id
        );
        insert manager;

        // Create Employee user — assigned to manager
        User employee = new User(
            FirstName       = 'Test',
            LastName        = 'Employee',
            Email           = 'testemployee@testorg.com',
            Username        = 'testemployee_wfh@testorg.com' + System.currentTimeMillis(),
            Alias           = 'temp',
            TimeZoneSidKey  = 'Asia/Kolkata',
            LocaleSidKey    = 'en_US',
            EmailEncodingKey= 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId       = standardProfile.Id,
            ManagerId       = manager.Id
        );
        insert employee;
    }

    // ================================================================
    // HELPER: Create WFH record directly (bypasses email)
    // ================================================================
    static Work_from_home_Request__c createWFHRecord(
        Id employeeId, Id managerId,
        Integer days, String status, String approvalLevel
    ) {
        Work_from_home_Request__c wfh = new Work_from_home_Request__c();
        wfh.Employee__c               = employeeId;
        wfh.Manager__c                = managerId;
        wfh.Start_Date__c             = Date.today().addDays(1);
        wfh.End_Date__c               = Date.today().addDays(days);
        wfh.Reason__c                 = 'Test WFH reason';
        wfh.Status__c                 = status;
        wfh.Approval_Level__c         = approvalLevel;
        wfh.Number_of_Days__c         = days;
        wfh.Is_Active__c              = true;
        wfh.Applied_Date__c           = System.now();
        wfh.Year__c                   = String.valueOf(Date.today().year());
        wfh.Employment_Type__c        = 'Full Time';
        return wfh;
    }

    // ================================================================
    // HELPER: Set page parameter and instantiate controller
    // ================================================================
    static WFHApprovalController buildController(Id wfhId) {
        PageReference page = Page.WFHApprovalPage;
        if (wfhId != null) {
            page.getParameters().put('id', wfhId);
        }
        Test.setCurrentPage(page);
        return new WFHApprovalController();
    }

    // ================================================================
    // TEST 1: No record Id in URL → showError
    // ================================================================
    @isTest
    static void testNoRecordIdInURL() {
        Test.startTest();
        WFHApprovalController ctrl = buildController(null);
        Test.stopTest();

        System.assertEquals(true,  ctrl.showError,   'showError should be true');
        System.assertEquals(false, ctrl.showSuccess,  'showSuccess should be false');
        System.assertNotEquals(null, ctrl.errorMessage, 'errorMessage should be set');
    }

    // ================================================================
    // TEST 2: Invalid record Id → showError
    // ================================================================
    @isTest
    static void testInvalidRecordId() {
        Test.startTest();
        PageReference page = Page.WFHApprovalPage;
        page.getParameters().put('id', 'INVALIDID000');
        Test.setCurrentPage(page);
        WFHApprovalController ctrl = new WFHApprovalController();
        Test.stopTest();

        System.assertEquals(true, ctrl.showError, 'showError should be true for invalid Id');
    }

    // ================================================================
    // TEST 3: Record already processed → showInfo
    // ================================================================
    @isTest
    static void testAlreadyApprovedRecord() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 2, 'Approved', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true,  ctrl.showInfo,   'showInfo should be true for already processed');
        System.assertEquals(false, ctrl.showError,  'showError should be false');
        System.assert(ctrl.infoMessage.contains('Approved'), 'infoMessage should mention Approved');
    }

    // ================================================================
    // TEST 4: 1-2 days — Manager level loads correctly
    // ================================================================
    @isTest
    static void testManagerLevelLoad_1to2Days() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 2, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true,  ctrl.isManagerLevel,       'isManagerLevel should be true');
        System.assertEquals(false, ctrl.isHRLevel,            'isHRLevel should be false');
        System.assertEquals(false, ctrl.isTwoLevelApproval,   'isTwoLevelApproval should be false for 2 days');
        System.assertEquals('Manager Approval', ctrl.approvalLevelLabel, 'Label should be simple for 1-2 days');
        System.assertEquals('Approve', ctrl.approveButtonLabel,          'Button should say Approve');
        System.assertEquals(false, ctrl.showError,  'showError should be false');
        System.assertEquals(false, ctrl.showInfo,   'showInfo should be false');
        System.assertNotEquals(null, ctrl.wfh,      'wfh should be loaded');
        System.assertEquals('Test Employee', ctrl.employeeName, 'employeeName should be set');
    }

    // ================================================================
    // TEST 5: 3-5 days — Manager Level 1 loads correctly
    // ================================================================
    @isTest
    static void testManagerLevelLoad_3to5Days() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true,  ctrl.isManagerLevel,      'isManagerLevel should be true');
        System.assertEquals(false, ctrl.isHRLevel,           'isHRLevel should be false');
        System.assertEquals(true,  ctrl.isTwoLevelApproval,  'isTwoLevelApproval should be true for 4 days');
        System.assertEquals('Level 1 – Manager Approval', ctrl.approvalLevelLabel, 'Label should show Level 1');
        System.assertEquals('Approve & Forward to HR',    ctrl.approveButtonLabel, 'Button should say Forward to HR');
    }

    // ================================================================
    // TEST 6: HR Level 2 loads correctly with manager comments
    // ================================================================
    @isTest
    static void testHRLevelLoad() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending HR Approval', 'HR');
        wfh.Manager_Approval_Status__c = 'Approved';
        wfh.Comments__c                = 'Manager approved this request';
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(false, ctrl.isManagerLevel,     'isManagerLevel should be false');
        System.assertEquals(true,  ctrl.isHRLevel,          'isHRLevel should be true');
        System.assertEquals(true,  ctrl.isTwoLevelApproval, 'isTwoLevelApproval should be true');
        System.assertEquals('Level 2 – HR Final Approval', ctrl.approvalLevelLabel, 'Label should show Level 2');
        System.assertEquals('Final Approve', ctrl.approveButtonLabel, 'Button should say Final Approve');
        System.assertEquals('Manager approved this request', ctrl.managerComments, 'Manager comments should be visible to HR');
        System.assertEquals('Approved', ctrl.managerApprovalStatus, 'Manager approval status should be Approved');
        System.assertNotEquals(null, ctrl.managerName, 'Manager name should be populated');
    }

    // ================================================================
    // TEST 7: Manager approves 1-2 day request → Status = Approved (Final)
    // ================================================================
    @isTest
    static void testManagerApproves_1to2Days_Final() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 2, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl  = buildController(wfh.Id);
        ctrl.approvalComments       = 'Approved - looks fine';
        PageReference result        = ctrl.approve();
        Test.stopTest();

        System.assertEquals(null,     result,           'approve() should return null');
        System.assertEquals(true,     ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Approved', ctrl.actionTaken, 'actionTaken should be Approved');
        System.assertEquals(null,     ctrl.wfh,         'wfh should be null after processing');

        Work_from_home_Request__c updated = [
            SELECT Status__c, Manager_Approval_Status__c, Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Approved', updated.Status__c, 'Status should be Approved');
        System.assertEquals('Approved', updated.Manager_Approval_Status__c, 'Manager status should be Approved');
    }

    // ================================================================
    // TEST 8: Manager approves 3-5 day request → Escalates to HR
    // ================================================================
    @isTest
    static void testManagerApproves_3to5Days_EscalatesToHR() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl  = buildController(wfh.Id);
        ctrl.approvalComments       = 'Approved - forwarding to HR for 4 days';
        PageReference result        = ctrl.approve();
        Test.stopTest();

        System.assertEquals(true,     ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Approved', ctrl.actionTaken, 'actionTaken should be Approved');

        Work_from_home_Request__c updated = [
            SELECT Status__c, Approval_Level__c,
                   Manager_Approval_Status__c, Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Pending HR Approval', updated.Status__c,        'Status should escalate to Pending HR Approval');
        System.assertEquals('HR',                  updated.Approval_Level__c, 'Approval level should move to HR');
        System.assertEquals('Approved',            updated.Manager_Approval_Status__c, 'Manager status should be Approved');
        System.assertEquals('Approved - forwarding to HR for 4 days', updated.Comments__c, 'Manager comments should be saved');
    }

    // ================================================================
    // TEST 9: Manager rejects → Status = Rejected (no HR involved)
    // ================================================================
    @isTest
    static void testManagerRejects() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        ctrl.rejectionReason       = 'Cannot approve WFH during project deadline';
        PageReference result       = ctrl.reject();
        Test.stopTest();

        System.assertEquals(true,      ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Rejected', ctrl.actionTaken, 'actionTaken should be Rejected');

        Work_from_home_Request__c updated = [
            SELECT Status__c, Manager_Approval_Status__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Rejected', updated.Status__c,               'Status should be Rejected');
        System.assertEquals('Rejected', updated.Manager_Approval_Status__c, 'Manager status should be Rejected');
    }

    // ================================================================
    // TEST 10: HR approves → Final Status = Approved
    // ================================================================
    @isTest
    static void testHRApproves_Final() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending HR Approval', 'HR');
        wfh.Manager_Approval_Status__c = 'Approved';
        wfh.Comments__c                = 'Manager approved this';
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl  = buildController(wfh.Id);
        ctrl.approvalComments       = 'HR approved - policy compliant';
        PageReference result        = ctrl.approve();
        Test.stopTest();

        System.assertEquals(true,      ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Approved', ctrl.actionTaken, 'actionTaken should be Approved');

        Work_from_home_Request__c updated = [
            SELECT Status__c, HR_Approval_Status__c, HR_Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Approved', updated.Status__c,           'Final Status should be Approved');
        System.assertEquals('Approved', updated.HR_Approval_Status__c, 'HR status should be Approved');
        System.assertEquals('HR approved - policy compliant', updated.HR_Comments__c, 'HR comments should be saved');
    }

    // ================================================================
    // TEST 11: HR rejects → Final Status = Rejected
    // ================================================================
    @isTest
    static void testHRRejects() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending HR Approval', 'HR');
        wfh.Manager_Approval_Status__c = 'Approved';
        wfh.Comments__c                = 'Manager approved this';
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        ctrl.rejectionReason       = 'HR policy does not allow 4-day WFH';
        PageReference result       = ctrl.reject();
        Test.stopTest();

        System.assertEquals(true,      ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Rejected', ctrl.actionTaken, 'actionTaken should be Rejected');

        Work_from_home_Request__c updated = [
            SELECT Status__c, HR_Approval_Status__c, HR_Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Rejected', updated.Status__c,             'Final Status should be Rejected');
        System.assertEquals('Rejected', updated.HR_Approval_Status__c, 'HR status should be Rejected');
    }

    // ================================================================
    // TEST 12: Reject without reason → validation message shown
    // ================================================================
    @isTest
    static void testRejectWithoutReason() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 2, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        ctrl.rejectionReason       = ''; // blank — should fail validation
        PageReference result       = ctrl.reject();
        Test.stopTest();

        System.assertEquals(false, ctrl.showSuccess, 'showSuccess should be false when reason is blank');
        System.assertEquals(null,  result,           'reject() should return null on validation failure');

        // Record should still be Pending
        Work_from_home_Request__c unchanged = [
            SELECT Status__c FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Pending', unchanged.Status__c, 'Status should remain Pending');
    }

    // ================================================================
    // TEST 13: Approve when wfh is null → showInfo (already processed)
    // ================================================================
    @isTest
    static void testApproveWhenWfhIsNull() {
        Test.startTest();
        WFHApprovalController ctrl = buildController(null);
        ctrl.showError             = false; // reset to test null wfh path
        ctrl.wfh                   = null;
        ctrl.isManagerLevel        = true;
        PageReference result       = ctrl.approve();
        Test.stopTest();

        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true when wfh is null');
    }

    // ================================================================
    // TEST 14: Reject when wfh is null → showInfo (already processed)
    // ================================================================
    @isTest
    static void testRejectWhenWfhIsNull() {
        Test.startTest();
        WFHApprovalController ctrl = buildController(null);
        ctrl.showError             = false;
        ctrl.wfh                   = null;
        ctrl.isManagerLevel        = true;
        ctrl.rejectionReason       = 'Some reason';
        PageReference result       = ctrl.reject();
        Test.stopTest();

        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true when wfh is null on reject');
    }

    // ================================================================
    // TEST 15: Approve with no comments (blank approvalComments)
    // ================================================================
    @isTest
    static void testApproveWithNoComments() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 2, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl  = buildController(wfh.Id);
        ctrl.approvalComments       = ''; // no comments — should still work
        PageReference result        = ctrl.approve();
        Test.stopTest();

        System.assertEquals(true,      ctrl.showSuccess, 'showSuccess should be true even with no comments');
        System.assertEquals('Approved', ctrl.actionTaken, 'actionTaken should be Approved');
    }

    // ================================================================
    // TEST 16: Full 2-level flow — Manager approves with comments
    //          → HR approves → Final Approved
    // ================================================================
    @isTest
    static void testFull2LevelApprovalFlow() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();

        // --- Level 1: Manager approves ---
        WFHApprovalController ctrl1  = buildController(wfh.Id);
        ctrl1.approvalComments       = 'Manager: Approved - valid reason for 4 days';
        ctrl1.approve();

        Work_from_home_Request__c afterManager = [
            SELECT Status__c, Approval_Level__c, Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Pending HR Approval', afterManager.Status__c,        'Should escalate after Manager');
        System.assertEquals('HR',                  afterManager.Approval_Level__c, 'Level should move to HR');
        System.assertEquals('Manager: Approved - valid reason for 4 days', afterManager.Comments__c, 'Comments should be saved');

        // --- Level 2: HR approves ---
        WFHApprovalController ctrl2  = buildController(wfh.Id);
        System.assertEquals('Manager: Approved - valid reason for 4 days', ctrl2.managerComments, 'HR should see manager comments');
        ctrl2.approvalComments       = 'HR: Final approval granted - policy compliant';
        ctrl2.approve();

        Work_from_home_Request__c afterHR = [
            SELECT Status__c, HR_Approval_Status__c, HR_Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Approved', afterHR.Status__c,             'Final status should be Approved');
        System.assertEquals('Approved', afterHR.HR_Approval_Status__c, 'HR status should be Approved');
        System.assertEquals('HR: Final approval granted - policy compliant', afterHR.HR_Comments__c, 'HR comments should be saved');

        Test.stopTest();
    }

    // ================================================================
    // TEST 17: Manager rejects 3-5 day request → HR never involved
    // ================================================================
    @isTest
    static void testManagerRejects_3to5Days_HRNotInvolved() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 5, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        ctrl.rejectionReason       = 'Cannot approve during sprint';
        ctrl.reject();
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, Approval_Level__c, HR_Approval_Status__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Rejected', updated.Status__c,              'Status should be Rejected');
        System.assertEquals('Manager',  updated.Approval_Level__c,      'Should stay at Manager level — HR not involved');
        System.assertEquals(null,       updated.HR_Approval_Status__c,  'HR should not have been involved');
    }

    // ================================================================
    // TEST 18: 3 days exactly — isTwoLevelApproval = true
    // ================================================================
    @isTest
    static void testExactly3Days_isTwoLevel() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 3, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true, ctrl.isTwoLevelApproval, '3 days should trigger 2-level approval');
        System.assertEquals(true, ctrl.isManagerLevel,     'Should be at Manager level');
    }

    // ================================================================
    // TEST 19: 5 days exactly — isTwoLevelApproval = true
    // ================================================================
    @isTest
    static void testExactly5Days_isTwoLevel() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 5, 'Pending', 'Manager');
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true, ctrl.isTwoLevelApproval, '5 days should trigger 2-level approval');
    }

    // ================================================================
    // TEST 20: HR level — no manager comments (blank Comments__c)
    // ================================================================
    @isTest
    static void testHRLevel_NoManagerComments() {
        User emp = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager'  LIMIT 1];

        Work_from_home_Request__c wfh = createWFHRecord(emp.Id, mgr.Id, 4, 'Pending HR Approval', 'HR');
        wfh.Manager_Approval_Status__c = 'Approved';
        wfh.Comments__c                = null; // no comments from manager
        insert wfh;

        Test.startTest();
        WFHApprovalController ctrl = buildController(wfh.Id);
        Test.stopTest();

        System.assertEquals(true, ctrl.isHRLevel, 'Should be HR level');
        System.assertEquals(null, ctrl.managerComments, 'Manager comments should be null');
    }
}