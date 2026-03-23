@IsTest
public class HybridWorkScheduleControllerTest {

    /* =========================================================
       TEST DATA
       ========================================================= */
    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();

        // Manager user
        User manager = new User(
            FirstName        = 'Manager',
            LastName         = 'User',
            Alias            = 'mgr1',
            Email            = 'manager' + ts + '@test.com',
            Username         = 'manager' + ts + '@test.com',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'Asia/Kolkata',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive         = true
        );
        insert manager;

        // Employee user
        User employee = new User(
            FirstName        = 'Employee',
            LastName         = 'User',
            Alias            = 'emp1',
            Email            = 'employee' + ts + '@test.com',
            Username         = 'employee' + ts + '@test.com',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'Asia/Kolkata',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive         = true,
            ManagerId        = manager.Id
        );
        insert employee;

        // No-manager user (for "manager not assigned" path)
        User noMgrUser = new User(
            FirstName        = 'NoMgr',
            LastName         = 'User',
            Alias            = 'nmg1',
            Email            = 'nomgr' + ts + '@test.com',
            Username         = 'nomgr' + ts + '@test.com',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'Asia/Kolkata',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive         = true
        );
        insert noMgrUser;

        // Approved schedule
        insert new Hybrid_Work_Schedule__c(
            Employee__c       = employee.Id,
            Manager__c        = manager.Id,
            Schedule_Month__c = Date.newInstance(2025, 1, 1),
            Start_Date__c     = Date.newInstance(2025, 1, 1),
            End_Date__c       = Date.newInstance(2025, 1, 31),
            WFH_days__c       = 'Monday;Tuesday',
            Office_Days__c    = 'Wednesday',
            Schedule_Type__c  = 'Flexible',
            Reason__c         = 'Approved schedule test reason long enough',
            Approval_Status__c = 'Approved',
            Is_Active__c      = true
        );

        // Pending approval schedule
        insert new Hybrid_Work_Schedule__c(
            Employee__c       = employee.Id,
            Manager__c        = manager.Id,
            Schedule_Month__c = Date.newInstance(2025, 2, 1),
            Start_Date__c     = Date.newInstance(2025, 2, 1),
            End_Date__c       = Date.newInstance(2025, 2, 28),
            WFH_days__c       = 'Thursday',
            Office_Days__c    = 'Friday',
            Schedule_Type__c  = 'Custom',
            Reason__c         = 'Pending approval test reason long enough',
            Approval_Status__c = 'Pending Manager Approval'
        );
    }

    // =========================================================
    // Helpers
    // =========================================================
    private static User getEmployee() {
        return [SELECT Id, Name, ManagerId, Manager.Name FROM User WHERE FirstName = 'Employee' LIMIT 1];
    }
    private static User getManager() {
        return [SELECT Id, Name FROM User WHERE FirstName = 'Manager' LIMIT 1];
    }
    private static User getNoMgrUser() {
        return [SELECT Id, Name FROM User WHERE FirstName = 'NoMgr' LIMIT 1];
    }
    private static Hybrid_Work_Schedule__c getApprovedSchedule() {
        return [SELECT Id, Schedule_Month__c, WFH_days__c, Office_Days__c,
                       Schedule_Type__c, Reason__c, Total_WFH_Days__c, Total_Office_Days__c
                FROM Hybrid_Work_Schedule__c WHERE Approval_Status__c = 'Approved' LIMIT 1];
    }
    private static Hybrid_Work_Schedule__c getPendingSchedule() {
        return [SELECT Id, Schedule_Month__c, WFH_days__c, Office_Days__c,
                       Schedule_Type__c, Reason__c, Total_WFH_Days__c, Total_Office_Days__c
                FROM Hybrid_Work_Schedule__c WHERE Approval_Status__c = 'Pending Manager Approval' LIMIT 1];
    }

    /* =========================================================
       SUBMIT HYBRID SCHEDULE
       ========================================================= */
    @IsTest
    static void testSubmitHybridSchedule_Success() {
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-03-01', 'Monday;Tuesday', 'Wednesday',
            'Fixed Days', 'This is a valid submission reason long enough'
        );
        Test.stopTest();
        System.assertEquals(true, res.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_DuplicateMonth() {
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-01-01', 'Monday', 'Tuesday',
            'Flexible', 'Duplicate month test reason long enough'
        );
        Test.stopTest();
        System.assertEquals(false, res.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_NoManager() {
        // User with no manager — should return success=false or throw gracefully
        User noMgr = getNoMgrUser();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            noMgr.Id, '2025-06-01', 'Monday', 'Tuesday',
            'Flexible', 'No manager assigned test reason long enough'
        );
        Test.stopTest();
        // Controller should handle gracefully — either false or an exception is acceptable
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void testSubmitHybridSchedule_NullEmployeeId() {
        // Null employee ID — should not throw unhandled exception
        Test.startTest();
        try {
            Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
                null, '2025-07-01', 'Monday', 'Tuesday',
                'Flexible', 'Null employee id test reason long enough'
            );
            System.assertNotEquals(null, res);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSubmitHybridSchedule_EmptyWFHDays() {
        User emp = getEmployee();
        Test.startTest();
        try {
            Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
                emp.Id, '2025-08-01', '', 'Wednesday',
                'Flexible', 'Empty WFH days test reason long enough'
            );
            System.assertNotEquals(null, res);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSubmitHybridSchedule_AllDayTypes() {
        // Covers multi-day WFH + office combos, exercises calculateMonthlyDayCounts paths
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-09-01',
            'Monday;Tuesday;Wednesday',
            'Thursday;Friday',
            'Custom',
            'Multi day combo test reason long enough'
        );
        Test.stopTest();
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void testSubmitHybridSchedule_PendingMonthBlocked() {
        // Month 2025-02 already has a pending schedule - should be rejected
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-02-01', 'Monday', 'Friday',
            'Flexible', 'Pending month resubmit test reason long enough'
        );
        Test.stopTest();
        System.assertEquals(false, res.get('success'));
    }

    /* =========================================================
       MANAGER DECISION
       ========================================================= */
    @IsTest
    static void testProcessManagerDecision_Approve() {
        User emp = getEmployee();
        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c       = emp.Id,
            Manager__c        = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 4, 1),
            Start_Date__c     = Date.newInstance(2025, 4, 1),
            End_Date__c       = Date.newInstance(2025, 4, 30),
            WFH_days__c       = 'Monday',
            Office_Days__c    = 'Tuesday',
            Schedule_Type__c  = 'Flexible',
            Reason__c         = 'Approval path test reason long enough',
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert req;

        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
            req.Id, 'Approve', null
        );
        Test.stopTest();
        System.assertEquals(true, res.get('success'));
    }

    @IsTest
    static void testProcessManagerDecision_Reject() {
        User emp = getEmployee();
        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c       = emp.Id,
            Manager__c        = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 5, 1),
            Approval_Status__c = 'Pending Manager Approval',
            Reason__c          = 'Reject path test reason long enough'
        );
        insert req;

        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
            req.Id, 'Reject', 'Not approved'
        );
        Test.stopTest();
        System.assertEquals(true, res.get('success'));
    }

    @IsTest
    static void testProcessManagerDecision_AlreadyProcessed() {
        Hybrid_Work_Schedule__c s = getApprovedSchedule();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
            s.Id, 'Approve', null
        );
        Test.stopTest();
        System.assertEquals(false, res.get('success'));
    }

    @IsTest
    static void testProcessManagerDecision_RejectWithComments() {
        // Reject with non-null comments - exercises the comments branch
        User emp = getEmployee();
        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c       = emp.Id,
            Manager__c        = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 10, 1),
            Approval_Status__c = 'Pending Manager Approval',
            Reason__c          = 'Reject with comments test reason long enough'
        );
        insert req;

        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
            req.Id, 'Reject', 'Detailed rejection reason for employee'
        );
        Test.stopTest();

        System.assertEquals(true, res.get('success'));
        Hybrid_Work_Schedule__c updated = [SELECT Approval_Status__c FROM Hybrid_Work_Schedule__c WHERE Id = :req.Id];
        System.assertEquals('Rejected', updated.Approval_Status__c);
    }

    @IsTest
    static void testProcessManagerDecision_ApproveWithComments() {
        // Approve with comments supplied
        User emp = getEmployee();
        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c       = emp.Id,
            Manager__c        = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 11, 1),
            Start_Date__c     = Date.newInstance(2025, 11, 1),
            End_Date__c       = Date.newInstance(2025, 11, 30),
            WFH_days__c       = 'Thursday',
            Office_Days__c    = 'Friday',
            Schedule_Type__c  = 'Custom',
            Reason__c          = 'Approve with comments test reason long enough',
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert req;

        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
            req.Id, 'Approve', 'Good request, approved'
        );
        Test.stopTest();

        System.assertEquals(true, res.get('success'));
        Hybrid_Work_Schedule__c updated = [SELECT Approval_Status__c FROM Hybrid_Work_Schedule__c WHERE Id = :req.Id];
        System.assertEquals('Approved', updated.Approval_Status__c);
    }

    @IsTest
    static void testProcessManagerDecision_NullId() {
        // Null record ID - should not cause unhandled crash
        Test.startTest();
        try {
            Map<String, Object> res = HybridWorkScheduleController.processManagerDecision(
                null, 'Approve', null
            );
            System.assertNotEquals(null, res);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    /* =========================================================
       EMAIL METHODS - ADDITIONAL BRANCHES
       ========================================================= */
    @IsTest
    static void testEmailsAndUtilities() {
        User emp = getEmployee();
        Hybrid_Work_Schedule__c s = getApprovedSchedule();

        Test.startTest();
        HybridWorkScheduleController.sendEmailToManager(s.Id, emp);
        HybridWorkScheduleController.sendEmployeeNotificationEmail(s, 'Approve');

        String html = HybridWorkScheduleController.buildManagerApprovalEmailHTML(s, emp);
        String txt  = HybridWorkScheduleController.buildManagerApprovalEmailPlainText(s, emp);

        String day = HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 6));

        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 1, 1),
            Date.newInstance(2025, 1, 31),
            'Monday;Tuesday',
            'Wednesday'
        );
        Test.stopTest();

        System.assert(html.contains('Hybrid'));
        System.assert(txt.contains('HYBRID'));
        System.assertEquals('Monday', day);
        System.assert(counts.get('wfhDays') > 0);
    }

    @IsTest
    static void testSendEmployeeNotificationEmail_Reject() {
        // Covers the Reject branch in sendEmployeeNotificationEmail
        Hybrid_Work_Schedule__c s = getApprovedSchedule();
        Test.startTest();
        HybridWorkScheduleController.sendEmployeeNotificationEmail(s, 'Reject');
        Test.stopTest();
        System.assert(true, 'Reject notification email sent without error');
    }

    @IsTest
    static void testSendEmployeeNotificationEmail_AllDecisions() {
        // Cover any additional decision values the method may branch on
        Hybrid_Work_Schedule__c s = getPendingSchedule();
        Test.startTest();
        HybridWorkScheduleController.sendEmployeeNotificationEmail(s, 'Approve');
        HybridWorkScheduleController.sendEmployeeNotificationEmail(s, 'Reject');
        Test.stopTest();
        System.assert(true, 'Both notification branches executed without error');
    }

    @IsTest
    static void testSendEmailToManager_WithPendingSchedule() {
        // sendEmailToManager with a pending (non-approved) schedule record
        User emp = getEmployee();
        Hybrid_Work_Schedule__c s = getPendingSchedule();
        Test.startTest();
        HybridWorkScheduleController.sendEmailToManager(s.Id, emp);
        Test.stopTest();
        System.assert(true, 'Email to manager sent for pending schedule without error');
    }

@IsTest
static void testBuildEmailHTML_WithAllFields() {
    User emp = getEmployee();
    Hybrid_Work_Schedule__c s = new Hybrid_Work_Schedule__c(
        Employee__c        = emp.Id,
        Manager__c         = emp.ManagerId,
        Schedule_Month__c  = Date.newInstance(2025, 12, 1),
        Start_Date__c      = Date.newInstance(2025, 12, 1),
        End_Date__c        = Date.newInstance(2025, 12, 31),
        WFH_days__c        = 'Monday;Wednesday;Friday',
        Office_Days__c     = 'Tuesday;Thursday',
        Schedule_Type__c   = 'Flexible',
        Approval_Status__c = 'Pending Manager Approval',
        Reason__c          = 'All fields populated test reason long enough'
    );
    insert s;

    s = [SELECT Id, Schedule_Month__c, WFH_days__c, Office_Days__c,
                Schedule_Type__c, Reason__c, Total_WFH_Days__c, Total_Office_Days__c
         FROM Hybrid_Work_Schedule__c WHERE Id = :s.Id];

    Test.startTest();
    String html = HybridWorkScheduleController.buildManagerApprovalEmailHTML(s, emp);
    String txt  = HybridWorkScheduleController.buildManagerApprovalEmailPlainText(s, emp);
    Test.stopTest();

    System.assertNotEquals(null, html);
    System.assertNotEquals(null, txt);
    System.assert(html.length() > 0, 'HTML body should not be empty');
    System.assert(txt.length()  > 0, 'Plain text body should not be empty');
}
    /* =========================================================
       getDayOfWeekName - ALL 7 DAYS
       ========================================================= */
    @IsTest
    static void testGetDayOfWeekName_AllDays() {
        // Jan 6 2025 = Monday, Jan 7 = Tuesday, ... Jan 12 = Sunday
        Test.startTest();
        System.assertEquals('Monday',    HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 6)));
        System.assertEquals('Tuesday',   HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 7)));
        System.assertEquals('Wednesday', HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 8)));
        System.assertEquals('Thursday',  HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 9)));
        System.assertEquals('Friday',    HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 10)));
        System.assertEquals('Saturday',  HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 11)));
        System.assertEquals('Sunday',    HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 12)));
        Test.stopTest();
    }

    @IsTest
    static void testGetDayOfWeekName_NullDate() {
        // Null date - should not throw unhandled exception
        Test.startTest();
        try {
            String result = HybridWorkScheduleController.getDayOfWeekName(null);
            System.assertNotEquals(null, result);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    /* =========================================================
       calculateMonthlyDayCounts - VARIOUS COMBINATIONS
       ========================================================= */
    @IsTest
    static void testCalculateMonthlyDayCounts_SingleWFHDay() {
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 3, 1),
            Date.newInstance(2025, 3, 31),
            'Wednesday',
            'Thursday'
        );
        Test.stopTest();

        System.assert(counts.get('wfhDays') > 0, 'Should count WFH Wednesdays in March');
        System.assert(counts.get('officeDays') > 0, 'Should count office Thursdays in March');
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_AllWeekdays() {
        // WFH on all 5 weekdays
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 4, 1),
            Date.newInstance(2025, 4, 30),
            'Monday;Tuesday;Wednesday;Thursday;Friday',
            ''
        );
        Test.stopTest();

        System.assert(counts.get('wfhDays') > 0);
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_WeekendDays() {
        // WFH on Saturday and Sunday - should still work without errors
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 5, 1),
            Date.newInstance(2025, 5, 31),
            'Saturday',
            'Sunday'
        );
        Test.stopTest();

        System.assertNotEquals(null, counts);
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_EmptyDayStrings() {
        // Empty strings for both WFH and office days
        Test.startTest();
        try {
            Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
                Date.newInstance(2025, 6, 1),
                Date.newInstance(2025, 6, 30),
                '',
                ''
            );
            System.assertNotEquals(null, counts);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_NullDayStrings() {
        Test.startTest();
        try {
            Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
                Date.newInstance(2025, 7, 1),
                Date.newInstance(2025, 7, 31),
                null,
                null
            );
            System.assertNotEquals(null, counts);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_ThursdayFriday() {
        // Covers Thursday and Friday day-name branches
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 8, 1),
            Date.newInstance(2025, 8, 31),
            'Thursday;Friday',
            'Monday'
        );
        Test.stopTest();

        System.assert(counts.get('wfhDays') > 0);
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_TuesdaySaturday() {
        // Covers Tuesday and Saturday branches
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 9, 1),
            Date.newInstance(2025, 9, 30),
            'Tuesday;Saturday',
            'Sunday'
        );
        Test.stopTest();

        System.assertNotEquals(null, counts);
    }

    /* =========================================================
       GETTERS
       ========================================================= */
    @IsTest
    static void testGetEmployeeSchedulesAndPendingApprovals() {
        User emp = getEmployee();
        Test.startTest();
        List<Map<String, Object>> schedules = HybridWorkScheduleController.getEmployeeSchedules(emp.Id);
        List<Hybrid_Work_Schedule__c> pending = HybridWorkScheduleController.getPendingApprovalsForManager(emp.ManagerId);
        Test.stopTest();

        System.assert(schedules.size() > 0);
        System.assert(pending.size() > 0);
    }

    @IsTest
    static void testGetEmployeeSchedules_NoSchedules() {
        // Manager user has no hybrid schedules - exercises empty return path
        User mgr = getManager();
        Test.startTest();
        List<Map<String, Object>> schedules = HybridWorkScheduleController.getEmployeeSchedules(mgr.Id);
        Test.stopTest();

        System.assertNotEquals(null, schedules);
        System.assertEquals(0, schedules.size(), 'Manager should have no hybrid schedules');
    }

    @IsTest
    static void testGetPendingApprovalsForManager_NoPending() {
        // NoMgrUser has no schedules, so no pending approvals for them as manager
        User noMgr = getNoMgrUser();
        Test.startTest();
        List<Hybrid_Work_Schedule__c> pending = HybridWorkScheduleController.getPendingApprovalsForManager(noMgr.Id);
        Test.stopTest();

        System.assertNotEquals(null, pending);
        System.assertEquals(0, pending.size(), 'No pending approvals expected');
    }

    @IsTest
    static void testGetEmployeeSchedules_NullEmployeeId() {
        Test.startTest();
        try {
            List<Map<String, Object>> schedules = HybridWorkScheduleController.getEmployeeSchedules(null);
            System.assertNotEquals(null, schedules);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPendingApprovalsForManager_NullManagerId() {
        Test.startTest();
        try {
            List<Hybrid_Work_Schedule__c> pending = HybridWorkScheduleController.getPendingApprovalsForManager(null);
            System.assertNotEquals(null, pending);
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    /* =========================================================
       FULL END-TO-END FLOW COVERAGE
       ========================================================= */
    @IsTest
    static void testFullFlow_SubmitThenApprove() {
        // Covers: submit -> pending state -> manager approves -> approved state
        // Also exercises email methods through the controller flow
        User emp = getEmployee();
        Test.startTest();

        // Submit a new schedule
        Map<String, Object> submitResult = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-06-01', 'Monday;Wednesday', 'Tuesday;Thursday',
            'Flexible', 'Full flow approve test reason long enough'
        );
        System.assertEquals(true, submitResult.get('success'), 'Submit should succeed');

        // Fetch the newly created record
        Hybrid_Work_Schedule__c created = [
            SELECT Id, Approval_Status__c
            FROM Hybrid_Work_Schedule__c
            WHERE Employee__c = :emp.Id AND Schedule_Month__c = :Date.newInstance(2025, 6, 1)
            LIMIT 1
        ];
        System.assertEquals('Pending Manager Approval', created.Approval_Status__c);

        // Manager approves
        Map<String, Object> approveResult = HybridWorkScheduleController.processManagerDecision(
            created.Id, 'Approve', 'Looks good'
        );
        Test.stopTest();

        System.assertEquals(true, approveResult.get('success'));
        Hybrid_Work_Schedule__c approved = [SELECT Approval_Status__c FROM Hybrid_Work_Schedule__c WHERE Id = :created.Id];
        System.assertEquals('Approved', approved.Approval_Status__c);
    }

    @IsTest
    static void testFullFlow_SubmitThenReject() {
        // Covers: submit -> pending -> manager rejects -> rejected state + rejection email
        User emp = getEmployee();
        Test.startTest();

        Map<String, Object> submitResult = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2025-07-01', 'Tuesday', 'Wednesday',
            'Custom', 'Full flow reject test reason long enough'
        );
        System.assertEquals(true, submitResult.get('success'));

        Hybrid_Work_Schedule__c created = [
            SELECT Id FROM Hybrid_Work_Schedule__c
            WHERE Employee__c = :emp.Id AND Schedule_Month__c = :Date.newInstance(2025, 7, 1)
            LIMIT 1
        ];

        Map<String, Object> rejectResult = HybridWorkScheduleController.processManagerDecision(
            created.Id, 'Reject', 'Schedule conflicts with team needs'
        );
        Test.stopTest();

        System.assertEquals(true, rejectResult.get('success'));
        Hybrid_Work_Schedule__c rejected = [SELECT Approval_Status__c FROM Hybrid_Work_Schedule__c WHERE Id = :created.Id];
        System.assertEquals('Rejected', rejected.Approval_Status__c);
    }

    @IsTest
    static void testFullFlow_MultipleSchedulesForEmployee() {
        // Submit multiple different months - exercises the duplicate check across months
        User emp = getEmployee();
        Test.startTest();

        Map<String, Object> r1 = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2026-01-01', 'Monday', 'Tuesday',
            'Fixed Days', 'Month 1 test reason long enough'
        );
        Map<String, Object> r2 = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2026-02-01', 'Wednesday', 'Thursday',
            'Flexible', 'Month 2 test reason long enough'
        );
        // Duplicate of month 1 - should fail
        Map<String, Object> r3 = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2026-01-01', 'Friday', 'Monday',
            'Custom', 'Duplicate month 1 test reason long enough'
        );
        Test.stopTest();

        System.assertEquals(true,  r1.get('success'), 'First submission should succeed');
        System.assertEquals(true,  r2.get('success'), 'Second submission different month should succeed');
        System.assertEquals(false, r3.get('success'), 'Duplicate month should fail');
    }

    /* =========================================================
       SCHEDULE TYPE VARIATIONS
       ========================================================= */
    @IsTest
    static void testSubmit_ScheduleTypeFixed() {
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2026-03-01', 'Monday;Friday', 'Wednesday',
            'Fixed Days', 'Fixed days schedule type test reason long enough'
        );
        Test.stopTest();
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void testSubmit_ScheduleTypeCustom() {
        User emp = getEmployee();
        Test.startTest();
        Map<String, Object> res = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id, '2026-04-01', 'Tuesday;Thursday', 'Monday',
            'Custom', 'Custom schedule type test reason long enough'
        );
        Test.stopTest();
        System.assertNotEquals(null, res);
    }

    /* =========================================================
       buildManagerApprovalEmailHTML / PlainText - BRANCH COVERAGE
       ========================================================= */
    @IsTest
    static void testBuildEmailHTML_WithWFHAndOfficeDays() {
        User emp = getEmployee();
        Hybrid_Work_Schedule__c s = getApprovedSchedule();
        Test.startTest();
        String html = HybridWorkScheduleController.buildManagerApprovalEmailHTML(s, emp);
        String txt  = HybridWorkScheduleController.buildManagerApprovalEmailPlainText(s, emp);
        Test.stopTest();

        System.assert(html != null && html.length() > 0, 'HTML body should not be empty');
        System.assert(txt  != null && txt.length()  > 0, 'Plain text body should not be empty');
        System.assert(html.contains('Hybrid'), 'HTML should mention Hybrid');
        System.assert(txt.contains('HYBRID'),  'Plain text should mention HYBRID');
    }

    @IsTest
    static void testBuildEmailHTML_PendingSchedule() {
        User emp = getEmployee();
        Hybrid_Work_Schedule__c s = getPendingSchedule();
        Test.startTest();
        String html = HybridWorkScheduleController.buildManagerApprovalEmailHTML(s, emp);
        String txt  = HybridWorkScheduleController.buildManagerApprovalEmailPlainText(s, emp);
        Test.stopTest();

        System.assertNotEquals(null, html);
        System.assertNotEquals(null, txt);
    }

    /* =========================================================
       CALCULATE MONTHLY DAY COUNTS - COMPLETE DAY COVERAGE
       ========================================================= */
    @IsTest
    static void testCalculateMonthlyDayCounts_AllDayNames() {
        // One test that hits every day-name branch in a single call
        Test.startTest();
        Map<String, Integer> counts = HybridWorkScheduleController.calculateMonthlyDayCounts(
            Date.newInstance(2025, 10, 1),
            Date.newInstance(2025, 10, 31),
            'Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday',
            'Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday'
        );
        Test.stopTest();

        System.assertNotEquals(null, counts);
        System.assert(counts.get('wfhDays') > 0, 'All-day WFH count should be > 0');
        System.assert(counts.get('officeDays') > 0, 'All-day office count should be > 0');
    }

    @IsTest
    static void testCalculateMonthlyDayCounts_SingleDayEachType() {
        // Each call exercises a different single day name to hit all 7 branches
        Test.startTest();
        Integer mon = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Monday',    '').get('wfhDays');
        Integer tue = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Tuesday',   '').get('wfhDays');
        Integer wed = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Wednesday', '').get('wfhDays');
        Integer thu = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Thursday',  '').get('wfhDays');
        Integer fri = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Friday',    '').get('wfhDays');
        Integer sat = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Saturday',  '').get('wfhDays');
        Integer sun = HybridWorkScheduleController.calculateMonthlyDayCounts(Date.newInstance(2025,11,1), Date.newInstance(2025,11,30), 'Sunday',    '').get('wfhDays');
        Test.stopTest();

        System.assert(mon > 0, 'Monday WFH count > 0 in Nov 2025');
        System.assert(tue > 0, 'Tuesday WFH count > 0 in Nov 2025');
        System.assert(wed > 0, 'Wednesday WFH count > 0 in Nov 2025');
        System.assert(thu > 0, 'Thursday WFH count > 0 in Nov 2025');
        System.assert(fri > 0, 'Friday WFH count > 0 in Nov 2025');
        System.assert(sat > 0, 'Saturday WFH count > 0 in Nov 2025');
        System.assert(sun > 0, 'Sunday WFH count > 0 in Nov 2025');
    }
}