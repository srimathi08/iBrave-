@isTest
private class AttendanceSummaryControllerTest {

    // ===================================================================
    // HELPER: Get next weekday
    // ===================================================================
    private static Date getNextWeekday(Date startDate) {
        Date d = startDate;
        Integer maxTries = 10;
        Integer tries = 0;
        while (tries < maxTries) {
            Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            String dow = dt.format('EEEE');
            if (dow != 'Saturday' && dow != 'Sunday') {
                return d;
            }
            d = d.addDays(1);
            tries++;
        }
        return startDate;
    }

    // ===================================================================
    // TEST DATA SETUP
    // ===================================================================
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName         = 'Test',
            LastName          = 'Employee',
            Email             = 'testemployee@testorg.com',
            Username          = 'testemployee_' + System.currentTimeMillis() + '@testorg.com',
            Alias             = 'templ',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert testUser;

        Leave_Type__c casualLeaveType = new Leave_Type__c(
            Leave_Type_Name__c = 'Casual Leave',
            Leave_Code__c      = 'CL'
        );
        insert casualLeaveType;

        Leave_Type__c sickLeaveType = new Leave_Type__c(
            Leave_Type_Name__c = 'Sick Leave',
            Leave_Code__c      = 'SL'
        );
        insert sickLeaveType;

        Date today      = Date.today();
        Date monthStart = today.toStartOfMonth();
        Date day1       = getNextWeekday(monthStart);
        Date day2       = getNextWeekday(day1.addDays(1));

        List<Employee_Attendance__c> attendanceList = new List<Employee_Attendance__c>();

        // Day1 Session 1 — Present
        attendanceList.add(new Employee_Attendance__c(
            Employee_Name__c       = testUser.Id,
            Date__c                = day1,
            Check_In_Time__c       = DateTime.newInstance(day1, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c      = DateTime.newInstance(day1, Time.newInstance(18, 0, 0, 0)),
            Status__c              = 'Present',
            Work_Location__c       = 'Work from Office',
            Session_Number__c      = 1,
            Is_Multiple_Session__c = false
        ));

        // Day1 Session 2 — multiple sessions same day
        attendanceList.add(new Employee_Attendance__c(
            Employee_Name__c       = testUser.Id,
            Date__c                = day1,
            Check_In_Time__c       = DateTime.newInstance(day1, Time.newInstance(14, 0, 0, 0)),
            Check_Out_Time__c      = DateTime.newInstance(day1, Time.newInstance(16, 0, 0, 0)),
            Status__c              = 'Present',
            Work_Location__c       = 'Work from Office',
            Session_Number__c      = 2,
            Is_Multiple_Session__c = true
        ));

        // Day2 — Late (only if day2 is not in the future)
        if (day2 <= today) {
            attendanceList.add(new Employee_Attendance__c(
                Employee_Name__c       = testUser.Id,
                Date__c                = day2,
                Check_In_Time__c       = DateTime.newInstance(day2, Time.newInstance(10, 30, 0, 0)),
                Check_Out_Time__c      = DateTime.newInstance(day2, Time.newInstance(19, 0, 0, 0)),
                Status__c              = 'Late',
                Work_Location__c       = 'Work from Home',
                Session_Number__c      = 1,
                Is_Multiple_Session__c = false
            ));
        }

        // Today — checked in, not checked out
        attendanceList.add(new Employee_Attendance__c(
            Employee_Name__c       = testUser.Id,
            Date__c                = today,
            Check_In_Time__c       = DateTime.newInstance(today, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c      = null,
            Status__c              = 'Present',
            Work_Location__c       = 'Work from Office',
            Session_Number__c      = 1,
            Is_Multiple_Session__c = false
        ));

        insert attendanceList;

        // Pending Leave 1
        insert new Leave_Request__c(
            Employee__c     = testUser.Id,
            Leave_Type__c   = casualLeaveType.Id,
            Start_Date__c   = today.addDays(5),
            End_Date__c     = today.addDays(6),
            Total_Days__c   = 2,
            Status__c       = 'Pending',
            Is_Active__c    = true,
            Reason__c       = 'Test pending leave 1',
            Applied_Date__c = DateTime.now()
        );

        // Pending Leave 2
        insert new Leave_Request__c(
            Employee__c     = testUser.Id,
            Leave_Type__c   = sickLeaveType.Id,
            Start_Date__c   = today.addDays(10),
            End_Date__c     = today.addDays(10),
            Total_Days__c   = 1,
            Status__c       = 'Pending',
            Is_Active__c    = true,
            Reason__c       = 'Test pending leave 2',
            Applied_Date__c = DateTime.now()
        );

        // Approved Leave
        insert new Leave_Request__c(
            Employee__c     = testUser.Id,
            Leave_Type__c   = casualLeaveType.Id,
            Start_Date__c   = today.addDays(-5),
            End_Date__c     = today.addDays(-4),
            Total_Days__c   = 2,
            Status__c       = 'Approved',
            Is_Active__c    = true,
            Reason__c       = 'Test approved leave',
            Applied_Date__c = DateTime.now().addDays(-10)
        );

        // WFH Request — Pending this month
        Date monthStartForWfh = today.toStartOfMonth();
        insert new Work_from_home_Request__c(
            Employee__c   = testUser.Id,
            Status__c     = 'Pending',
            Is_Active__c  = true,
            Start_Date__c = monthStartForWfh,
            End_Date__c   = monthStartForWfh.addDays(1)
        );

        // ✅ FIX: Create Timesheet__c parent first, then TimesheetEntry__c child
        // The controller queries TimesheetEntry__c filtered by Date__c within the current month
        Timesheet__c ts = new Timesheet__c(
            Employee__c        = testUser.Id,
            Approval_Status__c = 'Submitted',
            Week_Year__c       = today.year()
        );
        insert ts;

        // ✅ FIX: Insert a TimesheetEntry__c record with Date__c in the current month
        // and Approval_Status__c = 'Submitted' so the controller's COUNT query finds it
        insert new TimesheetEntry__c(
            Timesheet__c       = ts.Id,
            Date__c            = today,
            Approval_Status__c = 'Submitted'
        );
    }

    // ===================================================================
    // TESTS: getMonthlySummary
    // ===================================================================

    @isTest
    static void testGetMonthlySummary_HappyPath() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();

        System.assertEquals(true,  result.get('success'),           'success must be true');
        System.assertNotEquals(null, result.get('presentDays'),      'presentDays must not be null');
        System.assertNotEquals(null, result.get('lateDays'),         'lateDays must not be null');
        System.assertNotEquals(null, result.get('absentDays'),       'absentDays must not be null');
        System.assertNotEquals(null, result.get('totalHours'),       'totalHours must not be null');
        System.assertNotEquals(null, result.get('avgHoursPerDay'),   'avgHoursPerDay must not be null');
        System.assertNotEquals(null, result.get('attendanceRate'),   'attendanceRate must not be null');
        System.assertNotEquals(null, result.get('monthName'),        'monthName must not be null');
        System.assertNotEquals(null, result.get('totalWorkingDays'), 'totalWorkingDays must not be null');
    }

    @isTest
    static void testGetMonthlySummary_PresentDaysAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        System.assert((Integer) result.get('presentDays') >= 1, 'Should have at least 1 present day');
    }

    @isTest
    static void testGetMonthlySummary_AbsentDaysNonNegative() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        System.assert((Integer) result.get('absentDays') >= 0, 'Absent days must be >= 0');
    }

    @isTest
    static void testGetMonthlySummary_AttendanceRateInRange() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        Decimal rate = Decimal.valueOf((String) result.get('attendanceRate'));
        System.assert(rate >= 0 && rate <= 100, 'Rate must be 0–100');
    }

    @isTest
    static void testGetMonthlySummary_MonthNameContainsYear() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        String monthName = (String) result.get('monthName');
        System.assert(
            monthName.contains(String.valueOf(Date.today().year())),
            'Month name should contain current year'
        );
    }

    @isTest
    static void testGetMonthlySummary_TotalWorkingDaysAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        System.assert((Integer) result.get('totalWorkingDays') >= 1, 'Working days must be >= 1');
    }

    @isTest
    static void testGetMonthlySummary_RecordsFoundAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();
        System.assert((Integer) result.get('recordsFound') >= 1, 'recordsFound must be >= 1');
    }

    @isTest
    static void testGetMonthlySummary_NoRecords_ZeroState() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User emptyUser = new User(
            FirstName='Empty', LastName='User',
            Email='emptyuser@testorg.com',
            Username='emptyuser_'+System.currentTimeMillis()+'@testorg.com',
            Alias='empty', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert emptyUser;
        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(emptyUser.Id);
        Test.stopTest();
        System.assertEquals(true,  result.get('success'),        'success should be true');
        System.assertEquals(0,     result.get('presentDays'),    'presentDays should be 0');
        System.assertEquals(0,     result.get('lateDays'),       'lateDays should be 0');
        System.assertEquals('0.0', result.get('totalHours'),     'totalHours should be 0.0');
        System.assertEquals('0.0', result.get('avgHoursPerDay'), 'avgHoursPerDay should be 0.0');
    }

    // ===================================================================
    // TESTS: shouldShowCheckInPopup
    // ===================================================================

    @isTest
    static void testShouldShowCheckInPopup_AlreadyCheckedIn() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Boolean result = AttendanceSummaryController.shouldShowCheckInPopup();
            Test.stopTest();
            System.assertEquals(false, result, 'Popup should be false when already checked in');
        }
    }

    @isTest
    static void testShouldShowCheckInPopup_NotCheckedIn() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User noCheckinUser = new User(
            FirstName='NoCheckin', LastName='User',
            Email='nocheckin@testorg.com',
            Username='nocheckin_'+System.currentTimeMillis()+'@testorg.com',
            Alias='noch', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert noCheckinUser;
        System.runAs(noCheckinUser) {
            Test.startTest();
            Boolean result = AttendanceSummaryController.shouldShowCheckInPopup();
            Test.stopTest();
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }

    // ===================================================================
    // TESTS: getMyRequestCountsForCurrentWeek
    // ===================================================================

    @isTest
    static void testGetMyRequestCounts_AllKeysPresent() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            System.assert(counts.containsKey('pendingLeave'),       'pendingLeave key missing');
            System.assert(counts.containsKey('approvedLeave'),      'approvedLeave key missing');
            System.assert(counts.containsKey('pendingWFH'),         'pendingWFH key missing');
            System.assert(counts.containsKey('submittedTimesheet'), 'submittedTimesheet key missing');
        }
    }

    @isTest
    static void testGetMyRequestCounts_PendingLeaveAtLeastTwo() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            System.assert(counts.get('pendingLeave') >= 2, 'Should have >= 2 pending leaves');
        }
    }

    @isTest
    static void testGetMyRequestCounts_ApprovedLeaveAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            System.assert(counts.get('approvedLeave') >= 1, 'Should have >= 1 approved leave');
        }
    }

    @isTest
    static void testGetMyRequestCounts_WFHPendingAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            System.assert(counts.get('pendingWFH') >= 1, 'Should have >= 1 pending WFH');
        }
    }

    @isTest
    static void testGetMyRequestCounts_TimesheetAtLeastOne() {
        User u = [SELECT Id FROM User WHERE Email = 'testemployee@testorg.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            // ✅ FIX: Now passes because TimesheetEntry__c is created in @TestSetup
            // with Date__c = today (within current month) and Approval_Status__c = 'Submitted'
            System.assert(counts.get('submittedTimesheet') >= 1, 'Should have >= 1 submitted timesheet');
        }
    }

    @isTest
    static void testGetMyRequestCounts_ZeroState() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User freshUser = new User(
            FirstName='Fresh', LastName='User',
            Email='freshuser@testorg.com',
            Username='freshuser_'+System.currentTimeMillis()+'@testorg.com',
            Alias='fresh', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert freshUser;
        System.runAs(freshUser) {
            Test.startTest();
            Map<String, Integer> counts = AttendanceSummaryController.getMyRequestCountsForCurrentWeek();
            Test.stopTest();
            System.assertEquals(0, counts.get('pendingLeave'),       'pendingLeave should be 0');
            System.assertEquals(0, counts.get('approvedLeave'),      'approvedLeave should be 0');
            System.assertEquals(0, counts.get('pendingWFH'),         'pendingWFH should be 0');
            System.assertEquals(0, counts.get('submittedTimesheet'), 'submittedTimesheet should be 0');
        }
    }

    // ===================================================================
    // TEST: getAllUsersMonthlySummary
    // ===================================================================

    @isTest
    static void testGetAllUsersMonthlySummary_ReturnsList() {
        Test.startTest();
        List<Map<String, Object>> results = AttendanceSummaryController.getAllUsersMonthlySummary();
        Test.stopTest();
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 0, 'Results list should be valid');
    }
}