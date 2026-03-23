@isTest
private class HybridWorkScheduleApprovalControllerTest {

    // ===================================================================
    // HELPERS: Create test users
    // ===================================================================
    private static User createManager() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User mgr = new User(
            FirstName='Manager', LastName='HWS',
            Email='mgr_hws@testorg.com',
            Username='mgr_hws_' + System.currentTimeMillis() + '@testorg.com',
            Alias='mgrhws', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert mgr;
        return mgr;
    }

    private static User createEmployee(Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emp = new User(
            FirstName='Employee', LastName='HWS',
            Email='emp_hws@testorg.com',
            Username='emp_hws_' + System.currentTimeMillis() + '@testorg.com',
            Alias='emphws', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id,
            ManagerId=managerId
        );
        insert emp;
        return emp;
    }

    // ===================================================================
    // HELPER: Create a Hybrid Work Schedule record
    // ===================================================================
   private static Hybrid_Work_Schedule__c createSchedule(
        Id empId, Id managerId, String status) {

    String scheduleType = getPicklistValue('Schedule_Type__c');
    String wfhDay       = getPicklistValue('WFH_days__c');
    String officeDay    = getPicklistValue('Office_Days__c');

    Hybrid_Work_Schedule__c rec = new Hybrid_Work_Schedule__c(
        Employee__c          = empId,
        Manager__c           = managerId,
        Schedule_Type__c     = scheduleType,
        WFH_days__c          = wfhDay,
        Office_Days__c       = officeDay,
        Total_WFH_Days__c    = 1,
        Total_Office_Days__c = 1,
        Reason__c            = 'Test hybrid schedule reason',
        Approval_Status__c   = status,
        Rejection_Reason__c  = (status == 'Rejected')  ? 'Test rejection reason'    : null,
        Manager_Comments__c  = (status == 'Cancelled') ? 'Test cancellation reason' : null
    );

    insert rec;
    return rec;
}
// ===================================================================
// HELPER: Get valid picklist value dynamically
// ===================================================================
private static String getPicklistValue(String fieldName) {
    Schema.DescribeFieldResult fieldDesc;

    if (fieldName == 'Schedule_Type__c') {
        fieldDesc = Hybrid_Work_Schedule__c.Schedule_Type__c.getDescribe();
    } else if (fieldName == 'WFH_days__c') {
        fieldDesc = Hybrid_Work_Schedule__c.WFH_days__c.getDescribe();
    } else if (fieldName == 'Office_Days__c') {
        fieldDesc = Hybrid_Work_Schedule__c.Office_Days__c.getDescribe();
    } else {
        return null;
    }

    List<Schema.PicklistEntry> values = fieldDesc.getPicklistValues();
    return values.isEmpty() ? null : values[0].getValue();
}
    // ===================================================================
    // HELPER: Build a PageReference with id and mgr params
    // ===================================================================
    private static PageReference buildPage(String scheduleId, String managerId) {
        PageReference pg = Page.HybrideSchedulePage; // adjust to your VF page name
        if (String.isNotBlank(scheduleId)) {
            pg.getParameters().put('id',  scheduleId);
        }
        if (String.isNotBlank(managerId)) {
            pg.getParameters().put('mgr', managerId);
        }
        return pg;
    }

    // ===================================================================
    // TEST: Constructor — blank scheduleId shows error
    // ===================================================================
    @isTest
    static void testConstructor_BlankScheduleId() {
        PageReference pg = Page.HybrideSchedulePage;
        Test.setCurrentPage(pg);

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(true,  ctrl.showError,   'showError should be true for blank ID');
        System.assertEquals(false, ctrl.showSuccess,  'showSuccess should be false');
        System.assertNotEquals(null, ctrl.errorMessage, 'errorMessage should not be null');
    }

    // ===================================================================
    // TEST: Constructor — valid Pending request loads form
    // ===================================================================
    @isTest
    static void testConstructor_ValidPendingRequest() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(false, ctrl.showError,  'showError should be false');
        System.assertEquals(false, ctrl.showInfo,   'showInfo should be false for Pending');
        System.assertNotEquals(null, ctrl.hybridWorkSchedule, 'schedule should be loaded');
        System.assertEquals('Employee HWS',              ctrl.employeeName,  'employeeName should match');
        System.assertEquals('emp_hws@testorg.com',       ctrl.employeeEmail, 'employeeEmail should match');
        System.assertEquals(rec.WFH_days__c, ctrl.wfhDays);
System.assertEquals(rec.Office_Days__c, ctrl.officeDays);
        System.assertEquals(
    String.valueOf(rec.Total_WFH_Days__c + rec.Total_Office_Days__c),
    ctrl.totalDays
);
        System.assertEquals('Test hybrid schedule reason', ctrl.reason,      'reason should match');
    }

    // ===================================================================
    // TEST: Constructor — already Approved status shows info
    // ===================================================================
    @isTest
    static void testConstructor_AlreadyApproved_ShowsInfo() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Approved');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(true,  ctrl.showInfo,  'showInfo should be true');
        System.assertEquals(false, ctrl.showError, 'showError should be false');
        System.assertNotEquals(null, ctrl.infoMessage, 'infoMessage should not be null');
        System.assert(ctrl.infoMessage.contains('Approved'), 'infoMessage should mention Approved');
    }

    // ===================================================================
    // TEST: Constructor — already Rejected status shows info
    // ===================================================================
    @isTest
    static void testConstructor_AlreadyRejected_ShowsInfo() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Rejected');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true for Rejected');
        System.assert(ctrl.infoMessage.contains('Rejected'), 'infoMessage should mention Rejected');
    }

    // ===================================================================
    // TEST: Constructor — already Cancelled status shows info
    // ===================================================================
    @isTest
    static void testConstructor_AlreadyCancelled_ShowsInfo() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Cancelled');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true for Cancelled');
    }

    // ===================================================================
    // TEST: Constructor — invalid / non-existent scheduleId shows error
    // ===================================================================
    @isTest
    static void testConstructor_InvalidScheduleId_ShowsError() {
        PageReference pg = Page.HybrideSchedulePage;
        pg.getParameters().put('id', 'a00000000000001AAA');
        Test.setCurrentPage(pg);

        Test.startTest();
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        Test.stopTest();

        System.assertEquals(true, ctrl.showError, 'showError should be true for invalid ID');
        System.assertNotEquals(null, ctrl.errorMessage, 'errorMessage should not be null');
    }

    // ===================================================================
    // TEST: approveRequest — happy path
    // ===================================================================
    @isTest
    static void testApproveRequest_HappyPath() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.managerComments = 'Looks good, approved!';

        Test.startTest();
        PageReference result = ctrl.approveRequest();
        Test.stopTest();

        System.assertEquals(null,       result,                  'Should return null');
        System.assertEquals(true,       ctrl.showSuccess,        'showSuccess should be true');
        System.assertEquals('Approved', ctrl.actionTaken,        'actionTaken should be Approved');
        System.assertEquals(null,       ctrl.hybridWorkSchedule, 'schedule should be cleared');

        Hybrid_Work_Schedule__c updated = [
            SELECT Approval_Status__c, Manager_Comments__c, Approval_Date__c
            FROM Hybrid_Work_Schedule__c WHERE Id = :rec.Id
        ];
        System.assertEquals('Approved',              updated.Approval_Status__c,  'Status should be Approved');
        System.assertEquals('Looks good, approved!', updated.Manager_Comments__c, 'Comments should be saved');
        System.assertNotEquals(null,                 updated.Approval_Date__c,    'Approval_Date__c should be set');
    }

    // ===================================================================
    // TEST: approveRequest — null hybridWorkSchedule (already processed)
    // ===================================================================
    @isTest
    static void testApproveRequest_NullSchedule() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.hybridWorkSchedule = null;

        Test.startTest();
        PageReference result = ctrl.approveRequest();
        Test.stopTest();

        System.assertEquals(null, result,        'Should return null');
        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true');
    }

    // ===================================================================
    // TEST: approveRequest — without managerId param (covers blank managerId branch)
    // ===================================================================
    @isTest
    static void testApproveRequest_NoManagerIdParam() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        PageReference pg = Page.HybrideSchedulePage;
        pg.getParameters().put('id', rec.Id);
        Test.setCurrentPage(pg);

        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.managerComments = 'Approved without mgr param.';

        Test.startTest();
        ctrl.approveRequest();
        Test.stopTest();

        System.assertEquals(true,       ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Approved', ctrl.actionTaken, 'actionTaken should be Approved');
    }

    // ===================================================================
    // TEST: cancelRequest — happy path
    // ===================================================================
    @isTest
    static void testCancelRequest_HappyPath() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.managerComments = 'Cancelled due to policy change.';

        Test.startTest();
        PageReference result = ctrl.cancelRequest();
        Test.stopTest();

        System.assertEquals(null,        result,                  'Should return null');
        System.assertEquals(true,        ctrl.showSuccess,        'showSuccess should be true');
        System.assertEquals('Cancelled', ctrl.actionTaken,        'actionTaken should be Cancelled');
        System.assertEquals(null,        ctrl.hybridWorkSchedule, 'schedule should be cleared');

        Hybrid_Work_Schedule__c updated = [
            SELECT Approval_Status__c, Manager_Comments__c, Rejected_Date__c
            FROM Hybrid_Work_Schedule__c WHERE Id = :rec.Id
        ];
        System.assertEquals('Cancelled',                       updated.Approval_Status__c,  'Status should be Cancelled');
        System.assertEquals('Cancelled due to policy change.', updated.Manager_Comments__c, 'Comments should be saved');
        System.assertNotEquals(null, updated.Rejected_Date__c, 'Rejected_Date__c should be set on cancel');
    }

    // ===================================================================
    // TEST: cancelRequest — null hybridWorkSchedule (already processed)
    // ===================================================================
    @isTest
    static void testCancelRequest_NullSchedule() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.hybridWorkSchedule = null;

        Test.startTest();
        PageReference result = ctrl.cancelRequest();
        Test.stopTest();

        System.assertEquals(null, result,        'Should return null');
        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true');
    }

    // ===================================================================
    // TEST: cancelRequest — null managerComments (covers blank-comments email branch)
    // ===================================================================
    @isTest
    static void testCancelRequest_NullComments() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.managerComments = null;

        Test.startTest();
        ctrl.cancelRequest();
        Test.stopTest();

        System.assertEquals(true,        ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Cancelled', ctrl.actionTaken, 'actionTaken should be Cancelled');
    }

    // ===================================================================
    // TEST: rejectRequest — happy path
    // ===================================================================
    @isTest
    static void testRejectRequest_HappyPath() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.rejectionReason = 'Does not align with team schedule.';

        Test.startTest();
        PageReference result = ctrl.rejectRequest();
        Test.stopTest();

        System.assertEquals(null,       result,                  'Should return null');
        System.assertEquals(true,       ctrl.showSuccess,        'showSuccess should be true');
        System.assertEquals('Rejected', ctrl.actionTaken,        'actionTaken should be Rejected');
        System.assertEquals(null,       ctrl.hybridWorkSchedule, 'schedule should be cleared');

        Hybrid_Work_Schedule__c updated = [
            SELECT Approval_Status__c, Rejection_Reason__c, Manager_Comments__c, Rejected_Date__c
            FROM Hybrid_Work_Schedule__c WHERE Id = :rec.Id
        ];
        System.assertEquals('Rejected',                           updated.Approval_Status__c,  'Status should be Rejected');
        System.assertEquals('Does not align with team schedule.', updated.Rejection_Reason__c, 'Rejection_Reason__c should be set');
        System.assertEquals('Does not align with team schedule.', updated.Manager_Comments__c, 'Manager_Comments__c should mirror rejectionReason');
        System.assertEquals(Date.today(), updated.Rejected_Date__c, 'Rejected_Date__c should be today');
    }

    // ===================================================================
    // TEST: rejectRequest — blank rejectionReason adds page message
    // ===================================================================
    @isTest
    static void testRejectRequest_BlankReason_AddsPageMessage() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.rejectionReason = '';

        Test.startTest();
        PageReference result = ctrl.rejectRequest();
        Test.stopTest();

        System.assertEquals(null,  result,           'Should return null without processing');
        System.assertEquals(false, ctrl.showSuccess, 'showSuccess should remain false');

        List<ApexPages.Message> msgs = ApexPages.getMessages();
        System.assert(!msgs.isEmpty(), 'Should have at least one page message');
        System.assert(
            msgs[0].getSummary().toLowerCase().contains('rejection reason'),
            'Message should mention rejection reason'
        );
    }

    // ===================================================================
    // TEST: rejectRequest — null hybridWorkSchedule (already processed)
    // ===================================================================
    @isTest
    static void testRejectRequest_NullSchedule() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.hybridWorkSchedule = null;
        ctrl.rejectionReason    = 'Some valid reason';

        Test.startTest();
        PageReference result = ctrl.rejectRequest();
        Test.stopTest();

        System.assertEquals(null, result,        'Should return null');
        System.assertEquals(true, ctrl.showInfo, 'showInfo should be true');
    }

    // ===================================================================
    // TEST: rejectRequest — without managerId param (covers blank managerId branch)
    // ===================================================================
    @isTest
    static void testRejectRequest_NoManagerIdParam() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        PageReference pg = Page.HybrideSchedulePage;
        pg.getParameters().put('id', rec.Id);
        Test.setCurrentPage(pg);

        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();
        ctrl.rejectionReason = 'Rejected without mgr param.';

        Test.startTest();
        ctrl.rejectRequest();
        Test.stopTest();

        System.assertEquals(true,       ctrl.showSuccess, 'showSuccess should be true');
        System.assertEquals('Rejected', ctrl.actionTaken, 'actionTaken should be Rejected');
    }

    // ===================================================================
    // TEST: doNothing — returns null (covers the stub method)
    // ===================================================================
    @isTest
    static void testDoNothing() {
        User mgr = createManager();
        User emp = createEmployee(mgr.Id);
        Hybrid_Work_Schedule__c rec = createSchedule(emp.Id, mgr.Id, 'Pending Manager Approval');

        Test.setCurrentPage(buildPage(rec.Id, mgr.Id));
        HybridWorkScheduleApprovalController ctrl =
            new HybridWorkScheduleApprovalController();

        Test.startTest();
        PageReference result = ctrl.doNothing();
        Test.stopTest();

        System.assertEquals(null, result, 'doNothing should return null');
    }
}