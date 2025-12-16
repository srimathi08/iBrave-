@IsTest
public class HybridWorkScheduleControllerTest {

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        Long ts = System.currentTimeMillis();

        // Manager
        User manager = new User(
            FirstName = 'Manager', LastName = 'Test1', Alias = 'mgr1',
            Email = 'manager' + ts + '@test.com',
            Username = 'manager' + ts + '@test.com.mgr',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', IsActive = true
        );
        insert manager;

        // Employee
        User employee = new User(
            FirstName = 'Employee', LastName = 'Test1', Alias = 'emp1',
            Email = 'employee' + ts + '@test.com',
            Username = 'employee' + ts + '@test.com.emp',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', IsActive = true, ManagerId = manager.Id
        );
        insert employee;

        // Approved schedule for duplicate‑month check
        Hybrid_Work_Schedule__c approved = new Hybrid_Work_Schedule__c(
            Employee__c = employee.Id, Manager__c = manager.Id,
            Schedule_Month__c = Date.newInstance(2025, 1, 1),
            Start_Date__c = Date.newInstance(2025, 1, 1), End_Date__c = Date.newInstance(2025, 1, 31),
            WFH_days__c = 'Monday;Tuesday', Office_Days__c = 'Wednesday',
            Schedule_Type__c = 'Flexible', Reason__c = 'Approved test data 1234567890',
            Approval_Status__c = 'Approved', Is_Active__c = true
        );
        insert approved;

        // Pending schedule for manager‑pending list
        Hybrid_Work_Schedule__c pending = new Hybrid_Work_Schedule__c(
            Employee__c = employee.Id, Manager__c = manager.Id,
            Schedule_Month__c = Date.newInstance(2025, 2, 1),
            Start_Date__c = Date.newInstance(2025, 2, 1), End_Date__c = Date.newInstance(2025, 2, 28),
            WFH_days__c = 'Friday', Office_Days__c = 'Thursday',
            Schedule_Type__c = 'Custom', Reason__c = 'Pending test data 1234567890',
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert pending;
    }

    /* ---------------- SUBMIT REQUEST ---------------- */

    @IsTest
    static void testSubmitHybridSchedule_Success() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        System.runAs(emp) {
            Test.startTest();
            Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
                emp.Id,
                '2025-03-01',
                'Monday;Tuesday',
                'Wednesday;Thursday',
                'Fixed Days',
                'This is a valid long test reason with more than 20 characters'
            );
            Test.stopTest();

            System.assertEquals(true, result.get('success'));
            System.assertNotEquals(null, result.get('scheduleId'));
            System.assertEquals(true, (Boolean) result.get('emailSent'));
        }
    }

    @IsTest
    static void testSubmitHybridSchedule_DuplicateMonth() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id,
            '2025-01-01',          // month that already has Approved schedule
            'Monday',
            'Tuesday',
            'Flexible',
            'Valid reason for duplicate month test'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_ShortReason() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id,
            '2025-04-01',
            'Monday',
            'Tuesday',
            'Flexible',
            'short'                 // too short
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_MissingFields() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id,
            null,                   // missing date
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_InvalidDateString() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
            emp.Id,
            'invalid-date',
            'Monday',
            'Tuesday',
            'Flexible',
            'Valid long reason for invalid date test'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testSubmitHybridSchedule_NullEmployeeId() {
        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.submitHybridScheduleRequest(
            null,
            '2025-05-01',
            'Monday',
            'Tuesday',
            'Flexible',
            'Valid long reason for null employee test'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    /* ---------------- MANAGER DECISION ---------------- */

    @IsTest
    static void testProcessManagerDecision_Approve() {
        User emp = [SELECT Id, ManagerId FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Manager__c = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 5, 1),
            Start_Date__c = Date.newInstance(2025, 5, 1),
            End_Date__c = Date.newInstance(2025, 5, 31),
            WFH_days__c = 'Monday',
            Office_Days__c = 'Tuesday',
            Schedule_Type__c = 'Flexible',
            Reason__c = 'Approval test reason with enough length',
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert req;

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.processManagerDecision(req.Id, 'Approve', null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));

        Hybrid_Work_Schedule__c updated = [
            SELECT Approval_Status__c, Is_Active__c
            FROM Hybrid_Work_Schedule__c
            WHERE Id = :req.Id
        ];
        System.assertEquals('Approved', updated.Approval_Status__c);
        System.assertEquals(true, updated.Is_Active__c);
    }

    @IsTest
    static void testProcessManagerDecision_Reject() {
        User emp = [SELECT Id, ManagerId FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Manager__c = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 6, 1),
            Start_Date__c = Date.newInstance(2025, 6, 1),
            End_Date__c = Date.newInstance(2025, 6, 30),
            WFH_days__c = 'Friday',
            Office_Days__c = 'Thursday',
            Schedule_Type__c = 'Custom',
            Reason__c = 'Rejection test reason with enough length',
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert req;

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.processManagerDecision(
            req.Id,
            'Reject',
            'Test rejection reason'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'));

        Hybrid_Work_Schedule__c updated = [
            SELECT Approval_Status__c, Rejection_Reason__c
            FROM Hybrid_Work_Schedule__c
            WHERE Id = :req.Id
        ];
        System.assertEquals('Rejected', updated.Approval_Status__c);
        System.assertEquals('Test rejection reason', updated.Rejection_Reason__c);
    }

    @IsTest
    static void testProcessManagerDecision_InvalidAction() {
        User emp = [SELECT Id, ManagerId FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Manager__c = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 7, 1),
            Approval_Status__c = 'Pending Manager Approval'
        );
        insert req;

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.processManagerDecision(
            req.Id,
            'SomethingElse',
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testProcessManagerDecision_AlreadyProcessed() {
        User emp = [SELECT Id, ManagerId FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Hybrid_Work_Schedule__c req = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Manager__c = emp.ManagerId,
            Schedule_Month__c = Date.newInstance(2025, 8, 1),
            Approval_Status__c = 'Approved'
        );
        insert req;

        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.processManagerDecision(
            req.Id,
            'Approve',
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testProcessManagerDecision_NullScheduleId() {
        Test.startTest();
        Map<String, Object> result = HybridWorkScheduleController.processManagerDecision(
            null,
            'Approve',
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'));
    }

    /* ---------------- CHECK ACTIVE SCHEDULE ---------------- */

    @IsTest
    static void testCheckActiveScheduleForDate_AllCases() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Date baseDate = Date.newInstance(2025, 12, 15); // Monday
        String dayName = HybridWorkScheduleController.getDayOfWeekName(baseDate);

        Test.startTest();

        // 0. No schedule found (future date)
        Map<String, Object> noSchedule = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.addYears(1).format()
        );
        System.assertEquals(false, noSchedule.get('hasActiveSchedule'));

        // 1. WFH schedule (day in WFH_days__c)
        Hybrid_Work_Schedule__c wfh = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Schedule_Month__c = baseDate.toStartOfMonth(),
            Start_Date__c = baseDate,
            End_Date__c = baseDate.addDays(10),
            WFH_days__c = dayName,
            Office_Days__c = 'Tuesday',
            Schedule_Type__c = 'Flexible',
            Reason__c = 'WFH test',
            Approval_Status__c = 'Approved',
            Is_Active__c = true
        );
        insert wfh;
        Map<String, Object> wfhResult = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.format()
        );

        // 2. Office schedule (day in Office_Days__c)
        Hybrid_Work_Schedule__c office = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Schedule_Month__c = baseDate.addMonths(1).toStartOfMonth(),
            Start_Date__c = baseDate.addMonths(1),
            End_Date__c = baseDate.addMonths(1).addDays(10),
            WFH_days__c = 'Tuesday',
            Office_Days__c = dayName,
            Schedule_Type__c = 'Fixed Days',
            Reason__c = 'Office test',
            Approval_Status__c = 'Approved',
            Is_Active__c = true
        );
        insert office;
        Map<String, Object> officeResult = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.addMonths(1).format()
        );

        // 3. Neither WFH nor Office (day not present)
        Hybrid_Work_Schedule__c neither = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Schedule_Month__c = baseDate.addMonths(2).toStartOfMonth(),
            Start_Date__c = baseDate.addMonths(2),
            End_Date__c = baseDate.addMonths(2).addDays(10),
            WFH_days__c = 'Wednesday',
            Office_Days__c = 'Thursday',
            Schedule_Type__c = 'Custom',
            Reason__c = 'Neither test',
            Approval_Status__c = 'Approved',
            Is_Active__c = true
        );
        insert neither;
        Map<String, Object> neitherResult = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.addMonths(2).format()
        );

        // 4. Blank WFH/Office days
        Hybrid_Work_Schedule__c blank = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Schedule_Month__c = baseDate.addMonths(3).toStartOfMonth(),
            Start_Date__c = baseDate.addMonths(3),
            End_Date__c = baseDate.addMonths(3).addDays(10),
            WFH_days__c = null,
            Office_Days__c = null,
            Schedule_Type__c = 'Flexible',
            Reason__c = 'Blank test',
            Approval_Status__c = 'Approved',
            Is_Active__c = true
        );
        insert blank;
        Map<String, Object> blankResult = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.addMonths(3).format()
        );

        // 5. Inactive schedule
        Hybrid_Work_Schedule__c inactive = new Hybrid_Work_Schedule__c(
            Employee__c = emp.Id,
            Schedule_Month__c = baseDate.addMonths(4).toStartOfMonth(),
            Start_Date__c = baseDate.addMonths(4),
            End_Date__c = baseDate.addMonths(4).addDays(10),
            WFH_days__c = dayName,
            Office_Days__c = 'Tuesday',
            Schedule_Type__c = 'Flexible',
            Reason__c = 'Inactive test',
            Approval_Status__c = 'Approved',
            Is_Active__c = false
        );
        insert inactive;
        Map<String, Object> inactiveResult = HybridWorkScheduleController.checkActiveScheduleForDate(
            emp.Id,
            baseDate.addMonths(4).format()
        );

        Test.stopTest();
    }

    @IsTest
    static void testCheckActiveScheduleForDate_NullAndInvalid() {
        User anyUser = [SELECT Id FROM User LIMIT 1];

        Test.startTest();
        Map<String, Object> nullEmp = HybridWorkScheduleController.checkActiveScheduleForDate(
            null,
            '2025-12-15'
        );
        Map<String, Object> nullDate = HybridWorkScheduleController.checkActiveScheduleForDate(
            anyUser.Id,
            null
        );
        Map<String, Object> invalidDate = HybridWorkScheduleController.checkActiveScheduleForDate(
            anyUser.Id,
            'invalid-date'
        );
        Test.stopTest();

        System.assertEquals(false, nullEmp.get('hasActiveSchedule'));
    }

    /* ---------------- QUERY HELPERS ---------------- */

    @IsTest
    static void testGetEmployeeSchedules() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        Test.startTest();
        List<Hybrid_Work_Schedule__c> schedules = HybridWorkScheduleController.getEmployeeSchedules(emp.Id);
        List<Hybrid_Work_Schedule__c> emptySchedules = HybridWorkScheduleController.getEmployeeSchedules(null);
        Test.stopTest();

        System.assert(schedules.size() >= 2);
    }

    @IsTest
    static void testGetPendingApprovalsForManager() {
        User mgr = [SELECT Id FROM User WHERE FirstName = 'Manager' LIMIT 1];

        Test.startTest();
        List<Hybrid_Work_Schedule__c> pending = HybridWorkScheduleController.getPendingApprovalsForManager(mgr.Id);
        List<Hybrid_Work_Schedule__c> empty = HybridWorkScheduleController.getPendingApprovalsForManager(null);
        Test.stopTest();

        System.assert(pending.size() >= 1);
    }

    @IsTest
    static void testGetDayOfWeekName_AllDays() {
        Test.startTest();
        HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 6));  // Monday
        HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 7));  // Tuesday
        HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 8));  // Wednesday
        HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 9));  // Thursday
        HybridWorkScheduleController.getDayOfWeekName(Date.newInstance(2025, 1, 10)); // Friday
        Test.stopTest();
    }

    /* ---------------- BULK & ERROR PATHS ---------------- */

    @IsTest
    static void testBulkCoverage_SubmitManyRequests() {
        User emp = [SELECT Id FROM User WHERE FirstName = 'Employee' LIMIT 1];

        System.runAs(emp) {
            Test.startTest();
            for (Integer i = 9; i <= 12; i++) {
                HybridWorkScheduleController.submitHybridScheduleRequest(
                    emp.Id,
                    '2025-' + i + '-01',
                    'Monday',
                    'Tuesday',
                    'Fixed Days',
                    'Bulk test reason number ' + i + ' with sufficient length'
                );
            }
            Test.stopTest();
        }
    }
}