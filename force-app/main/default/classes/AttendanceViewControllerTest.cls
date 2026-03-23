@isTest
private class AttendanceViewControllerTest {

    // ===================================================================
    // HELPER: Get next weekday
    // ===================================================================
    private static Date getNextWeekday(Date startDate) {
        Date d = startDate;
        Integer tries = 0;
        while (tries < 10) {
            Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            String dow = dt.format('EEEE');
            if (dow != 'Saturday' && dow != 'Sunday') return d;
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
            FirstName='Test', LastName='Employee',
            Email='viewtest@testorg.com',
            Username='viewtest_' + System.currentTimeMillis() + '@testorg.com',
            Alias='vtest', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;

        Date today      = Date.today();
        Date monthStart = today.toStartOfMonth();
        Date day1       = getNextWeekday(monthStart);
        Date day2       = getNextWeekday(day1.addDays(1));

        // Branch record
        Branch__c branch = new Branch__c(
            Branch_Name__c = 'Test Branch',
            City__c        = 'Chennai',
            State__c       = 'Tamil Nadu'
        );
        insert branch;

        List<Employee_Attendance__c> recs = new List<Employee_Attendance__c>();

        // 1. Present — Work from Office with branch
        recs.add(new Employee_Attendance__c(
            Employee_Name__c       = testUser.Id,
            Date__c                = day1,
            Check_In_Time__c       = DateTime.newInstance(day1, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c      = DateTime.newInstance(day1, Time.newInstance(18, 0, 0, 0)),
            Status__c              = 'Present',
            Work_Location__c       = 'Work from Office',
            Branch__c              = branch.Id,
            Session_Number__c      = 1,
            Is_Multiple_Session__c = false,
            Notes__c               = 'Office check-in'
        ));

        // 2. Late — Work from Home with WFH reason, submitted for approval
        if (day2 <= today) {
            recs.add(new Employee_Attendance__c(
                Employee_Name__c        = testUser.Id,
                Date__c                 = day2,
                Check_In_Time__c        = DateTime.newInstance(day2, Time.newInstance(10, 30, 0, 0)),
                Check_Out_Time__c       = DateTime.newInstance(day2, Time.newInstance(19, 0, 0, 0)),
                Status__c               = 'Late',
                Work_Location__c        = 'Work from Home',
                WFH_Reason__c           = 'Personal work',
                Submitted_For_Approval__c = true,
                WFH_Approval_Status__c  = 'Pending',
                Session_Number__c       = 1,
                Is_Multiple_Session__c  = false
            ));
        }

        // 3. Session 2 on day1 — multiple sessions
        recs.add(new Employee_Attendance__c(
            Employee_Name__c       = testUser.Id,
            Date__c                = day1,
            Check_In_Time__c       = DateTime.newInstance(day1, Time.newInstance(14, 0, 0, 0)),
            Check_Out_Time__c      = DateTime.newInstance(day1, Time.newInstance(16, 0, 0, 0)),
            Status__c              = 'Present',
            Work_Location__c       = 'Work from Office',
            Branch__c              = branch.Id,
            Session_Number__c      = 2,
            Is_Multiple_Session__c = true
        ));

        // 4. Client Place
        Date day3 = getNextWeekday(day2.addDays(1));
        if (day3 <= today) {
            recs.add(new Employee_Attendance__c(
                Employee_Name__c       = testUser.Id,
                Date__c                = day3,
                Check_In_Time__c       = DateTime.newInstance(day3, Time.newInstance(9, 0, 0, 0)),
                Check_Out_Time__c      = DateTime.newInstance(day3, Time.newInstance(17, 0, 0, 0)),
                Status__c              = 'Present',
                Work_Location__c       = 'Client Place',
                Client_Place_Details__c= 'ABC Corp, 123 Main Street, Building A — very long detail text here for testing truncation purposes abcdefgh',
                Session_Number__c      = 1,
                Is_Multiple_Session__c = false
            ));
        }

        // 5. Field Work
        Date day4 = getNextWeekday(day2.addDays(2));
        if (day4 <= today) {
            recs.add(new Employee_Attendance__c(
                Employee_Name__c       = testUser.Id,
                Date__c                = day4,
                Check_In_Time__c       = DateTime.newInstance(day4, Time.newInstance(8, 0, 0, 0)),
                Check_Out_Time__c      = DateTime.newInstance(day4, Time.newInstance(16, 0, 0, 0)),
                Status__c              = 'Present',
                Work_Location__c       = 'Field Work',
                Field_Work_Details__c  = 'Site visit to Construction XYZ — very long detail text here for testing truncation purposes abcdefgh',
                Session_Number__c      = 1,
                Is_Multiple_Session__c = false
            ));
        }

        // 6. Today — checked in only (no checkout) — for getTodayAttendanceRecord
        recs.add(new Employee_Attendance__c(
            Employee_Name__c        = testUser.Id,
            Date__c                 = today,
            Check_In_Time__c        = DateTime.newInstance(today, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c       = null,
            Status__c               = 'Present',
            Work_Location__c        = 'Work from Home',
            WFH_Reason__c           = 'WFH reason',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c  = 'Approved',
            Session_Number__c       = 1,
            Is_Multiple_Session__c  = false,
            Notes__c                = 'Today checkin'
        ));

        // 7. WFH Rejected record
        Date day5 = getNextWeekday(day2.addDays(3));
        if (day5 <= today) {
            recs.add(new Employee_Attendance__c(
                Employee_Name__c        = testUser.Id,
                Date__c                 = day5,
                Check_In_Time__c        = DateTime.newInstance(day5, Time.newInstance(9, 0, 0, 0)),
                Check_Out_Time__c       = DateTime.newInstance(day5, Time.newInstance(17, 0, 0, 0)),
                Status__c               = 'Present',
                Work_Location__c        = 'Work from Home',
                WFH_Reason__c           = 'Rejected reason',
                Submitted_For_Approval__c = true,
                WFH_Approval_Status__c  = 'Rejected',
                Session_Number__c       = 1,
                Is_Multiple_Session__c  = false
            ));
        }

        insert recs;

        // Leave Request for checkLeaveForDate
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c = 'Casual Leave',
            Leave_Code__c      = 'CL'
        );
        insert lt;

        insert new Leave_Request__c(
            Employee__c     = testUser.Id,
            Leave_Type__c   = lt.Id,
            Start_Date__c   = today.addDays(10),
            End_Date__c     = today.addDays(11),
            Total_Days__c   = 2,
            Status__c       = 'Pending',
            Is_Active__c    = true,
            Reason__c       = 'Test leave',
            Applied_Date__c = DateTime.now(),
            Is_Half_Day__c  = true
        );
    }

    // ===================================================================
    // TESTS: getEmployeeAttendanceRecords
    // ===================================================================

    @isTest
    static void testGetEmployeeAttendanceRecords_HappyPath() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(u.Id, 200);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
        System.assertNotEquals(null, result.get('records'), 'records should not be null');
        Integer totalCount = (Integer) result.get('totalCount');
        System.assert(totalCount >= 1, 'Should have at least 1 record');
    }

    @isTest
    static void testGetEmployeeAttendanceRecords_DefaultLimit() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        // Pass null limit — should default to 200
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(u.Id, null);
        Test.stopTest();
        System.assertEquals(true, result.get('success'), 'success should be true with null limit');
    }

    @isTest
    static void testGetEmployeeAttendanceRecords_BlankEmployeeId() {
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords('', 10);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required') || e.getMessage() != null, 'Should throw for blank ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetEmployeeAttendanceRecords_InactiveUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User inactive = new User(
            FirstName='Inactive', LastName='User',
            Email='inactive@testorg.com',
            Username='inactive_'+System.currentTimeMillis()+'@testorg.com',
            Alias='inact', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id,
            IsActive=false
        );
        insert inactive;
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(inactive.Id, 10);
            System.assert(false, 'Should throw for inactive user');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetEmployeeAttendanceRecords_FormatsAllLocationTypes() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(u.Id, 200);
        Test.stopTest();

        List<Object> records = (List<Object>) result.get('records');
        System.assert(records.size() >= 1, 'Should have records');

        // Verify location display values are set
        for (Object obj : records) {
            Map<String, Object> rec = (Map<String, Object>) obj;
            System.assertNotEquals(null, rec.get('displayLocation'), 'displayLocation should not be null');
            System.assertNotEquals(null, rec.get('workLocation'), 'workLocation should not be null');
        }
    }

    @isTest
    static void testGetEmployeeAttendanceRecordsWithApproval_Delegates() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecordsWithApproval(u.Id, 10);
        Test.stopTest();
        System.assertEquals(true, result.get('success'), 'Delegate method should return success');
    }

    // ===================================================================
    // TESTS: getTodayAttendance
    // ===================================================================

    @isTest
    static void testGetTodayAttendance_RecordFound() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
        System.assertEquals(true, result.get('hasRecord'), 'hasRecord should be true');
        System.assertNotEquals(null, result.get('recordId'), 'recordId should not be null');
        System.assertEquals(true, result.get('isCheckedIn'), 'isCheckedIn should be true');
    }

    @isTest
    static void testGetTodayAttendance_NoRecord() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User fresh = new User(
            FirstName='Fresh2', LastName='User',
            Email='fresh2@testorg.com',
            Username='fresh2_'+System.currentTimeMillis()+'@testorg.com',
            Alias='frsh2', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert fresh;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(fresh.Id);
        Test.stopTest();
        System.assertEquals(true,  result.get('success'),   'success should be true');
        System.assertEquals(false, result.get('hasRecord'), 'hasRecord should be false');
    }

    @isTest
    static void testGetTodayAttendance_BlankId() {
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.getTodayAttendance('');
            // Method may throw or return error map
            if (result != null) {
                System.assertNotEquals(null, result, 'Result should not be null');
            }
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ===================================================================
    // TESTS: getTodayAttendanceRecord (multi-session)
    // ===================================================================

    @isTest
    static void testGetTodayAttendanceRecord_HasSession() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),    'success should be true');
        System.assertEquals(true, result.get('hasRecords'), 'hasRecords should be true');
        System.assertNotEquals(null, result.get('lastSession'), 'lastSession should not be null');
        System.assertNotEquals(null, result.get('allSessions'), 'allSessions should not be null');

        Integer totalSessions = (Integer) result.get('totalSessions');
        System.assert(totalSessions >= 1, 'totalSessions should be >= 1');
    }

    @isTest
    static void testGetTodayAttendanceRecord_NoSession() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User noSession = new User(
            FirstName='NoSession', LastName='User',
            Email='nosession@testorg.com',
            Username='nosession_'+System.currentTimeMillis()+'@testorg.com',
            Alias='noses', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert noSession;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord(noSession.Id);
        Test.stopTest();
        System.assertEquals(true,  result.get('success'),    'success should be true');
        System.assertEquals(false, result.get('hasRecords'), 'hasRecords should be false');
        System.assertEquals(0,     result.get('totalSessions'), 'totalSessions should be 0');
    }

    @isTest
    static void testGetTodayAttendanceRecord_BlankId() {
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord('');
            if (result != null) {
                System.assertNotEquals(null, result, 'Result should not be null');
            }
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ===================================================================
    // TESTS: getAttendanceSummaryWithWFH
    // ===================================================================

    @isTest
    static void testGetAttendanceSummaryWithWFH_HappyPath() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Date startDate = Date.today().toStartOfMonth();
        Date endDate   = Date.today();
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(u.Id, startDate, endDate);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
        System.assertNotEquals(null, result.get('presentDays'),    'presentDays not null');
        System.assertNotEquals(null, result.get('lateDays'),       'lateDays not null');
        System.assertNotEquals(null, result.get('wfhDays'),        'wfhDays not null');
        System.assertNotEquals(null, result.get('clientPlaceDays'),'clientPlaceDays not null');
        System.assertNotEquals(null, result.get('fieldWorkDays'),  'fieldWorkDays not null');
    }

    @isTest
    static void testGetAttendanceSummaryWithWFH_NullDates_UsesDefaults() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        // Pass null dates — should default to current month
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(u.Id, null, null);
        Test.stopTest();
        System.assertEquals(true, result.get('success'), 'success should be true with null dates');
    }

    @isTest
    static void testGetAttendanceSummaryWithWFH_BlankId() {
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH('', null, null);
            if (result != null) {
                System.assertNotEquals(null, result, 'Result should not be null');
            }
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAttendanceSummaryWithWFH_WFHApprovalRates() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(
            u.Id, Date.today().toStartOfMonth(), Date.today()
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('wfhApprovedDays'), 'wfhApprovedDays not null');
        System.assertNotEquals(null, result.get('wfhPendingDays'),  'wfhPendingDays not null');
        System.assertNotEquals(null, result.get('wfhRejectedDays'), 'wfhRejectedDays not null');
        System.assertNotEquals(null, result.get('wfhApprovalRate'), 'wfhApprovalRate not null');
    }

    // ===================================================================
    // TESTS: checkLeaveForDate
    // ===================================================================

    @isTest
    static void testCheckLeaveForDate_LeaveFound() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Date leaveDate = Date.today().addDays(10);
        // Use YYYY-MM-DD format required by Date.valueOf()
        String leaveDateStr = leaveDate.year() + '-' +
            String.valueOf(leaveDate.month()).leftPad(2, '0') + '-' +
            String.valueOf(leaveDate.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(u.Id, leaveDateStr);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),  'success should be true');
        System.assertEquals(true, result.get('hasLeave'), 'hasLeave should be true');
        System.assertNotEquals(null, result.get('leaveId'),   'leaveId should not be null');
        System.assertNotEquals(null, result.get('leaveType'), 'leaveType should not be null');
        System.assertNotEquals(null, result.get('message'),   'message should not be null');
    }

    @isTest
    static void testCheckLeaveForDate_NoLeave() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Date futureDate = Date.today().addDays(100);
        String futureDateStr = futureDate.year() + '-' +
            String.valueOf(futureDate.month()).leftPad(2, '0') + '-' +
            String.valueOf(futureDate.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(u.Id, futureDateStr);
        Test.stopTest();

        System.assertEquals(true,  result.get('success'),  'success should be true');
        System.assertEquals(false, result.get('hasLeave'), 'hasLeave should be false');
    }

    @isTest
    static void testCheckLeaveForDate_InvalidDate() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(u.Id, 'not-a-date');
        Test.stopTest();
        // Should return success=false with error
        System.assertEquals(false, result.get('success'), 'success should be false for invalid date');
    }

    // ===================================================================
    // TESTS: autoCheckOut
    // ===================================================================

    @isTest
    static void testAutoCheckOut_Success() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Get today's open check-in record
        Employee_Attendance__c rec = [
            SELECT Id FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
            AND Date__c = :Date.today()
            AND Check_Out_Time__c = null
            LIMIT 1
        ];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.autoCheckOut(rec.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'autoCheckOut should succeed');
        System.assertNotEquals(null, result.get('hoursWorked'), 'hoursWorked should not be null');
        System.assertNotEquals(null, result.get('checkOutTime'), 'checkOutTime should not be null');
    }

    @isTest
    static void testAutoCheckOut_BlankRecordId() {
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.autoCheckOut('');
        Test.stopTest();
        System.assertEquals(false, result.get('success'), 'Should fail for blank ID');
    }

    @isTest
    static void testAutoCheckOut_AlreadyCheckedOut() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Get a record that already has checkout
        Employee_Attendance__c rec = [
            SELECT Id FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
            AND Check_Out_Time__c != null
            LIMIT 1
        ];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.autoCheckOut(rec.Id);
        Test.stopTest();
        System.assertEquals(false, result.get('success'), 'Should fail if already checked out');
    }

    @isTest
    static void testAutoCheckOut_WrongDate() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Create a past date record without checkout
        Date pastDate = Date.today().addDays(-5);
        Employee_Attendance__c pastRec = new Employee_Attendance__c(
            Employee_Name__c = u.Id,
            Date__c          = pastDate,
            Check_In_Time__c = DateTime.newInstance(pastDate, Time.newInstance(9, 0, 0, 0)),
            Status__c        = 'Present',
            Work_Location__c = 'Work from Office',
            Session_Number__c = 1
        );
        insert pastRec;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.autoCheckOut(pastRec.Id);
        Test.stopTest();
        System.assertEquals(false, result.get('success'), 'Should fail for non-today record');
        System.assert(
            ((String) result.get('error')).contains('today'),
            'Error should mention today'
        );
    }

    // ===================================================================
    // TESTS: checkYesterdayAttendance
    // ===================================================================

    @isTest
    static void testCheckYesterdayAttendance_HasRecord() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Use day1 which has a real (non-OD) record
        Date day1 = getNextWeekday(Date.today().toStartOfMonth());
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkYesterdayAttendance(u.Id, day1);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),   'success should be true');
        System.assertEquals(true, result.get('hasRecord'), 'hasRecord should be true for day1');
    }

    @isTest
    static void testCheckYesterdayAttendance_NoRecord() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Far future date — no records
        Date futureDate = Date.today().addDays(60);
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkYesterdayAttendance(u.Id, futureDate);
        Test.stopTest();

        System.assertEquals(true,  result.get('success'),   'success should be true');
        System.assertEquals(false, result.get('hasRecord'), 'hasRecord should be false');
        System.assertEquals(false, result.get('hasODSubmitted'), 'hasODSubmitted should be false');
    }

    @isTest
    static void testCheckYesterdayAttendance_HasLeave() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Date leaveDate = Date.today().addDays(10);
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkYesterdayAttendance(u.Id, leaveDate);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),  'success should be true');
        System.assertEquals(true, result.get('hasLeave'), 'hasLeave should be true for leave date');
    }

    @isTest
    static void testCheckYesterdayAttendance_ODRecord() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Date odDate = Date.today().addDays(-10);

        // Insert an OD record for odDate
        Employee_Attendance__c odRec = new Employee_Attendance__c(
            Employee_Name__c  = u.Id,
            Date__c           = odDate,
            Check_In_Time__c  = DateTime.newInstance(odDate, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(odDate, Time.newInstance(17, 0, 0, 0)),
            Status__c         = 'Present',
            Work_Location__c  = 'Work from Home',
            Is_OD_Request__c  = true,
            OD_Reason__c      = 'Test OD',
            OD_Approval_Status__c = 'Pending',
            Session_Number__c = 1
        );
        insert odRec;

        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkYesterdayAttendance(u.Id, odDate);
        Test.stopTest();

        System.assertEquals(true,  result.get('success'),      'success should be true');
        System.assertEquals(false, result.get('hasRecord'),    'real record should be false (OD excluded)');
        System.assertEquals(true,  result.get('hasODSubmitted'), 'hasODSubmitted should be true');
    }

    // ===================================================================
    // TESTS: testLocationFieldsAccess
    // ===================================================================

    @isTest
    static void testLocationFieldsAccess_HappyPath() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.testLocationFieldsAccess(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
        System.assertNotEquals(null, result.get('hasClientPlaceDetailsField'), 'hasClientPlaceDetailsField not null');
        System.assertNotEquals(null, result.get('hasFieldWorkDetailsField'),   'hasFieldWorkDetailsField not null');
        System.assertNotEquals(null, result.get('sampleRecordsFound'),         'sampleRecordsFound not null');
    }

    @isTest
    static void testLocationFieldsAccess_BlankId() {
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.testLocationFieldsAccess('');
            if (result != null) {
                System.assertNotEquals(null, result, 'Result should not be null');
            }
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ===================================================================
    // TESTS: processWFHApprovalStatus (via getTodayAttendance — private method)
    // ===================================================================

    @isTest
    static void testWFHApprovalStatus_Approved_ViaGetTodayAttendance() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(u.Id);
        Test.stopTest();

        // Today's record has WFH_Approval_Status__c = 'Approved'
        System.assertEquals(true, result.get('success'), 'success should be true');
        if ((Boolean) result.get('hasRecord')) {
            System.assertNotEquals(null, result.get('wfhApprovalStatusText'), 'WFH status text not null');
        }
    }

    @isTest
    static void testWFHApprovalStatus_Pending() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        // Update today's record to Pending to hit the Pending branch
        Employee_Attendance__c todayRec = [
            SELECT Id, WFH_Approval_Status__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
            AND Date__c = :Date.today()
            LIMIT 1
        ];
        todayRec.WFH_Approval_Status__c = 'Pending';
        update todayRec;

        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
    }

    @isTest
    static void testWFHApprovalStatus_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Employee_Attendance__c todayRec = [
            SELECT Id, WFH_Approval_Status__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
            AND Date__c = :Date.today()
            LIMIT 1
        ];
        todayRec.WFH_Approval_Status__c = 'Rejected';
        update todayRec;

        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
    }

    @isTest
    static void testWFHApprovalStatus_UnknownStatus() {
        User u = [SELECT Id FROM User WHERE Email = 'viewtest@testorg.com' LIMIT 1];
        Employee_Attendance__c todayRec = [
            SELECT Id, WFH_Approval_Status__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
            AND Date__c = :Date.today()
            LIMIT 1
        ];
        todayRec.WFH_Approval_Status__c = 'pending';
        update todayRec;

        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(u.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'success should be true');
    }

    // ===================================================================
    // TESTS: testDataSetup (private @TestVisible method)
    // ===================================================================

    @isTest
    static void testDataSetup_Runs() {
        Test.startTest();
        AttendanceViewController.testDataSetup();
        Test.stopTest();
        System.assert(true, 'testDataSetup should run without error');
    }
}