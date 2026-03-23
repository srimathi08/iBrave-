@isTest
private class WFH_RequestTest {

    // =========================================================
    // Constants
    // =========================================================
    private static final String MGR_USERNAME   = 'wfh_testmgr@testorg.example.com';
    private static final String EMP_USERNAME   = 'wfh_tempemp@testorg.example.com';
    private static final String NOMGR_USERNAME = 'wfh_nomgr@testorg.example.com';

    // =========================================================
    // @TestSetup - runs once, all tests share this data
    // =========================================================
    @TestSetup
    static void setupTestData() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // 1. Manager user (no manager of their own)
        User manager = new User(
            FirstName         = 'WFH',
            LastName          = 'Manager',
            Email             = 'wfh.manager@testorg.example.com',
            Username          = MGR_USERNAME,
            Alias             = 'wfhmgr',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = stdProfile.Id
        );
        insert manager;

        // 2. Employee user - manager set to user above
        User employee = new User(
            FirstName         = 'WFH',
            LastName          = 'Employee',
            Email             = 'wfh.employee@testorg.example.com',
            Username          = EMP_USERNAME,
            Alias             = 'wfhemp',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = stdProfile.Id,
            ManagerId         = manager.Id
        );
        insert employee;

        // 3. A user with NO manager (to test the "Manager is not assigned" path)
        User noMgrUser = new User(
            FirstName         = 'WFH',
            LastName          = 'NoManager',
            Email             = 'wfh.nomanager@testorg.example.com',
            Username          = NOMGR_USERNAME,
            Alias             = 'wfhnmg',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = stdProfile.Id
        );
        insert noMgrUser;

        // 4. Public holiday ~30 days out (used in date-range tests)
        // NOTE: Update Holiday_Type__c to a valid picklist value in your org.
        //       Run this in Anon Apex to find values:
        //         for (Schema.PicklistEntry e :
        //              Holiday__c.Holiday_Type__c.getDescribe().getPicklistValues())
        //             System.debug(e.getValue());
        Holiday__c holiday = new Holiday__c(
            Name            = 'Test Public Holiday',
            Holiday_Date__c = Date.today().addDays(30),
            Holiday_Type__c = 'Public Holiday'
        );
        insert holiday;
    }

    // =========================================================
    // Helper: fetch test users
    // =========================================================
    private static User getManager() {
        return [SELECT Id, Name, Email, ManagerId FROM User WHERE Username = :MGR_USERNAME LIMIT 1];
    }
    private static User getEmployee() {
        return [SELECT Id, Name, Email, ManagerId FROM User WHERE Username = :EMP_USERNAME LIMIT 1];
    }
    private static User getNoMgrUser() {
        return [SELECT Id, Name, Email, ManagerId FROM User WHERE Username = :NOMGR_USERNAME LIMIT 1];
    }

    // =========================================================
    // Helper: date utilities
    // =========================================================

    /** Returns d if it is a weekday, otherwise rolls forward to Monday. */
    private static Date toWorkingDay(Date d) {
        Integer dow = dayOfWeek(d);
        if (dow == 6) return d.addDays(2);
        if (dow == 7) return d.addDays(1);
        return d;
    }

    /** Returns the next Monday strictly after d (never same day). */
    private static Date nextMonday(Date d) {
        Integer dow  = dayOfWeek(d);
        Integer skip = (dow == 1) ? 7 : (8 - dow);
        return d.addDays(skip);
    }

    /** Returns the next Saturday strictly after d. */
    private static Date nextSaturday(Date d) {
        Integer dow  = dayOfWeek(d);
        Integer skip = Math.mod((6 - dow + 7), 7);
        return d.addDays(skip == 0 ? 7 : skip);
    }

    /** ISO day-of-week: 1=Monday ... 7=Sunday. */
    private static Integer dayOfWeek(Date d) {
        DateTime dt = DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        return Integer.valueOf(dt.format('u'));
    }

    /** Build a minimal WFH record (not yet inserted). */
    private static Work_from_home_Request__c buildWFH(
            Id empId, Id mgrId,
            Date startDate, Date endDate,
            String status, String approvalLevel,
            Integer numDays) {
        return new Work_from_home_Request__c(
            Employee__c       = empId,
            Manager__c        = mgrId,
            Start_Date__c     = startDate,
            End_Date__c       = endDate,
            Status__c         = status,
            Approval_Level__c = approvalLevel,
            Is_Active__c      = true,
            Applied_Date__c   = System.now(),
            Number_of_Days__c = numDays,
            Reason__c         = 'Test reason'
        );
    }

    // =========================================================
    // 1. getAllowedRequests
    // =========================================================
    @isTest
    static void test_getAllowedRequests() {
        User emp = getEmployee();
        Test.startTest();
        List<String> allowed = WFH_Request.getAllowedRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(3, allowed.size(), 'Should return 3 request types');
        System.assert(allowed.contains('Leave'),  'Should contain Leave');
        System.assert(allowed.contains('WFH'),    'Should contain WFH');
        System.assert(allowed.contains('Hybrid'), 'Should contain Hybrid');
    }

    // =========================================================
    // 2. getManagerInfoforWFH
    // =========================================================
    @isTest
    static void test_getManagerInfoforWFH_WithManager() {
        User emp = getEmployee();
        Test.startTest();
        Map<String, String> info = WFH_Request.getManagerInfoforWFH(emp.Id);
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals('WFH Employee', info.get('employeeName'));
        System.assertNotEquals('No Manager', info.get('managerName'), 'Manager should be found');
        System.assertNotEquals(null, info.get('managerId'));
    }

    @isTest
    static void test_getManagerInfoforWFH_NoManager() {
        User mgr = getManager();
        Test.startTest();
        Map<String, String> info = WFH_Request.getManagerInfoforWFH(mgr.Id);
        Test.stopTest();

        System.assertEquals('No Manager', info.get('managerName'));
    }

    // =========================================================
    // 3. getPublicHolidaysForDateRange
    // =========================================================
    @isTest
    static void test_getPublicHolidays_InRange() {
        Date startDt = Date.today();
        Date endDt   = Date.today().addDays(60);
        Test.startTest();
        List<Holiday__c> holidays = WFH_Request.getPublicHolidaysForDateRange(startDt, endDt);
        Test.stopTest();

        System.assertEquals(1, holidays.size(), 'Should find the test holiday');
    }

    @isTest
    static void test_getPublicHolidays_OutOfRange() {
        Date startDt = Date.today().addDays(90);
        Date endDt   = Date.today().addDays(120);
        Test.startTest();
        List<Holiday__c> holidays = WFH_Request.getPublicHolidaysForDateRange(startDt, endDt);
        Test.stopTest();

        System.assertEquals(0, holidays.size(), 'Should find no holidays');
    }

    // =========================================================
    // 4. checkOverlappingRequests
    // =========================================================
    @isTest
    static void test_checkOverlap_NoOverlap() {
        User emp     = getEmployee();
        Date startDt = toWorkingDay(Date.today().addDays(10));
        Date endDt   = toWorkingDay(startDt.addDays(1));

        System.runAs(emp) {
            Test.startTest();
            Map<String, Object> result = WFH_Request.checkOverlappingRequests(startDt, endDt, emp.Id);
            Test.stopTest();
            System.assertEquals(false, result.get('hasOverlap'));
            System.assertEquals('', result.get('message'));
        }
    }

    @isTest
    static void test_checkOverlap_WithOverlap() {
        User emp     = getEmployee();
        User mgr     = getManager();
        Date startDt = toWorkingDay(Date.today().addDays(10));
        Date endDt   = startDt;

        insert buildWFH(emp.Id, mgr.Id, startDt, endDt, 'Pending', 'Manager', 1);

        System.runAs(emp) {
            Test.startTest();
            Map<String, Object> result = WFH_Request.checkOverlappingRequests(startDt, endDt, emp.Id);
            Test.stopTest();
            System.assertEquals(true, result.get('hasOverlap'));
            System.assert(String.valueOf(result.get('message')).contains('Pending'));
        }
    }

    @isTest
    static void test_checkOverlap_ApprovedStatus() {
        User emp     = getEmployee();
        User mgr     = getManager();
        Date startDt = toWorkingDay(Date.today().addDays(15));

        insert buildWFH(emp.Id, mgr.Id, startDt, startDt, 'Approved', 'Manager', 1);

        System.runAs(emp) {
            Test.startTest();
            Map<String, Object> result = WFH_Request.checkOverlappingRequests(startDt, startDt, emp.Id);
            Test.stopTest();
            System.assertEquals(true, result.get('hasOverlap'));
        }
    }

    // =========================================================
    // 5. submitWorkFromHomeRequest - happy paths
    // =========================================================
    @isTest
    static void test_submit_1WorkingDay() {
        User emp = getEmployee();
        Date wd  = toWorkingDay(Date.today().addDays(5));

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = wd,
            End_Date__c   = wd,
            Reason__c     = '1-day WFH test'
        );

        System.runAs(emp) {
            Test.startTest();
            String newId = WFH_Request.submitWorkFromHomeRequest(req);
            Test.stopTest();
            System.assertNotEquals(null, newId);
        }

        Work_from_home_Request__c saved = [
            SELECT Status__c, Approval_Level__c, Number_of_Days__c
            FROM Work_from_home_Request__c WHERE Id = :req.Id
        ];
        System.assertEquals('Pending', saved.Status__c);
        System.assertEquals('Manager', saved.Approval_Level__c);
        System.assertEquals(1, Integer.valueOf(saved.Number_of_Days__c));
    }

    @isTest
    static void test_submit_2WorkingDays() {
        User emp = getEmployee();
        Date mon = nextMonday(Date.today().addDays(7));
        Date tue = mon.addDays(1);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = tue,
            Reason__c     = '2-day WFH test'
        );

        System.runAs(emp) {
            Test.startTest();
            WFH_Request.submitWorkFromHomeRequest(req);
            Test.stopTest();
        }

        Work_from_home_Request__c saved = [
            SELECT Number_of_Days__c, Status__c
            FROM Work_from_home_Request__c WHERE Id = :req.Id
        ];
        System.assertEquals(2, Integer.valueOf(saved.Number_of_Days__c));
        System.assertEquals('Pending', saved.Status__c);
    }

    @isTest
    static void test_submit_3WorkingDays() {
        User emp = getEmployee();
        // 8+ weeks out so the holiday at today()+30 does not interfere
        Date mon = nextMonday(Date.today().addDays(60));
        Date wed = mon.addDays(2);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = wed,
            Reason__c     = '3-day WFH test'
        );

        System.runAs(emp) {
            Test.startTest();
            String newId = WFH_Request.submitWorkFromHomeRequest(req);
            Test.stopTest();
            System.assertNotEquals(null, newId);
        }

        Work_from_home_Request__c saved = [
            SELECT Number_of_Days__c FROM Work_from_home_Request__c WHERE Id = :req.Id
        ];
        System.assertEquals(3, Integer.valueOf(saved.Number_of_Days__c));
    }

    @isTest
    static void test_submit_5WorkingDays() {
        User emp = getEmployee();
        Date mon = nextMonday(Date.today().addDays(60));
        Date fri = mon.addDays(4);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = fri,
            Reason__c     = '5-day WFH test'
        );

        System.runAs(emp) {
            Test.startTest();
            String newId = WFH_Request.submitWorkFromHomeRequest(req);
            Test.stopTest();
            System.assertNotEquals(null, newId);
        }

        Work_from_home_Request__c saved = [
            SELECT Number_of_Days__c FROM Work_from_home_Request__c WHERE Id = :req.Id
        ];
        System.assertEquals(5, Integer.valueOf(saved.Number_of_Days__c));
    }

    // =========================================================
    // 6. submitWorkFromHomeRequest - validation / error paths
    //
    // FIX: AuraHandledException.getMessage() returns the generic string
    //      "Script-thrown exception" in test context, NOT the message
    //      passed to the constructor. We assert only that the correct
    //      exception TYPE was thrown, not the message content.
    // =========================================================
    @isTest
    static void test_submit_NullStartDate() {
        User emp = getEmployee();
        Work_from_home_Request__c req = new Work_from_home_Request__c(
            End_Date__c = Date.today().addDays(5),
            Reason__c   = 'Missing start date'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for null start date');
    }

    @isTest
    static void test_submit_NullEndDate() {
        User emp = getEmployee();
        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = Date.today().addDays(5),
            Reason__c     = 'Missing end date'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for null end date');
    }

    @isTest
    static void test_submit_EndBeforeStart() {
        User emp = getEmployee();
        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = Date.today().addDays(5),
            End_Date__c   = Date.today().addDays(3),
            Reason__c     = 'End before start'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for end before start');
    }

    @isTest
    static void test_submit_PastStartDate() {
        User emp = getEmployee();
        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c   = Date.today().addDays(-1),
            Reason__c     = 'Past dates'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for past dates');
    }

    @isTest
    static void test_submit_NoManagerAssigned() {
        User noMgr = getNoMgrUser();
        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = toWorkingDay(Date.today().addDays(5)),
            End_Date__c   = toWorkingDay(Date.today().addDays(5)),
            Reason__c     = 'No manager test'
        );
        Boolean thrown = false;
        System.runAs(noMgr) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for missing manager');
    }

    @isTest
    static void test_submit_MoreThan5Days() {
        User emp     = getEmployee();
        Date mon     = nextMonday(Date.today().addDays(60));
        Date nextMon = mon.addDays(7); // spans 8 working days

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = nextMon,
            Reason__c     = 'Way too many days'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for more than 5 working days');
    }

    @isTest
    static void test_submit_WeekendOnlyDates() {
        User emp = getEmployee();
        Date sat = nextSaturday(Date.today().addDays(1));
        Date sun = sat.addDays(1);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = sat,
            End_Date__c   = sun,
            Reason__c     = 'Weekend only'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for weekend-only date range');
    }

    @isTest
    static void test_submit_OverlapWithExistingPending() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(20));

        insert buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending', 'Manager', 1);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = wd,
            End_Date__c   = wd,
            Reason__c     = 'Duplicate request'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for overlap with Pending');
    }

    @isTest
    static void test_submit_OverlapWithExistingApproved() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(22));

        insert buildWFH(emp.Id, mgr.Id, wd, wd, 'Approved', 'Manager', 1);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = wd,
            End_Date__c   = wd,
            Reason__c     = 'Duplicate approved'
        );
        Boolean thrown = false;
        System.runAs(emp) {
            Test.startTest();
            try {
                WFH_Request.submitWorkFromHomeRequest(req);
            } catch (AuraHandledException ex) {
                thrown = true;
            }
            Test.stopTest();
        }
        System.assert(thrown, 'Expected AuraHandledException for overlap with Approved');
    }

    // =========================================================
    // 7. processManagerDecision - Approve 1-2 days (Final)
    // =========================================================
    @isTest
    static void test_managerApprove_1Day_Final() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending', 'Manager', 1);
        insert wfh;

        Test.startTest();
        WFH_Request.processManagerDecision(wfh.Id, 'Approved', 'Looks good');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, Manager_Approval_Status__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Approved', updated.Status__c);
        System.assertEquals('Approved', updated.Manager_Approval_Status__c);
    }

    @isTest
    static void test_managerApprove_2Days_Final() {
        User emp = getEmployee();
        User mgr = getManager();
        Date mon = nextMonday(Date.today().addDays(60));
        Date tue = mon.addDays(1);

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, mon, tue, 'Pending', 'Manager', 2);
        insert wfh;

        Test.startTest();
        WFH_Request.processManagerDecision(wfh.Id, 'Approved', 'Two days fine');
        Test.stopTest();

        Work_from_home_Request__c updated = [SELECT Status__c FROM Work_from_home_Request__c WHERE Id = :wfh.Id];
        System.assertEquals('Approved', updated.Status__c);
    }

    // =========================================================
    // 8. processManagerDecision - Approve 3-5 days (Escalate to HR)
    // =========================================================
    @isTest
    static void test_managerApprove_3Days_EscalateToHR() {
        User emp = getEmployee();
        User mgr = getManager();
        Date mon = nextMonday(Date.today().addDays(60));
        Date wed = mon.addDays(2);

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, mon, wed, 'Pending', 'Manager', 3);
        insert wfh;

        Test.startTest();
        WFH_Request.processManagerDecision(wfh.Id, 'Approved', 'Escalating to HR');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, Approval_Level__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Pending HR Approval', updated.Status__c);
        System.assertEquals('HR', updated.Approval_Level__c);
    }

    @isTest
    static void test_managerApprove_5Days_EscalateToHR() {
        User emp = getEmployee();
        User mgr = getManager();
        Date mon = nextMonday(Date.today().addDays(60));
        Date fri = mon.addDays(4);

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, mon, fri, 'Pending', 'Manager', 5);
        insert wfh;

        Test.startTest();
        WFH_Request.processManagerDecision(wfh.Id, 'Approved', 'Five days HR needed');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, Approval_Level__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Pending HR Approval', updated.Status__c);
        System.assertEquals('HR', updated.Approval_Level__c);
    }

    // =========================================================
    // 9. processManagerDecision - Reject
    // =========================================================
    @isTest
    static void test_managerReject() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending', 'Manager', 1);
        insert wfh;

        Test.startTest();
        WFH_Request.processManagerDecision(wfh.Id, 'Rejected', 'Not this week');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, Manager_Approval_Status__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Rejected', updated.Status__c);
        System.assertEquals('Rejected', updated.Manager_Approval_Status__c);
    }

    // =========================================================
    // 10. processManagerDecision - Wrong status / level (guard check)
    // =========================================================
    @isTest
    static void test_managerDecision_WrongStatus_Throws() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Approved', 'Manager', 1);
        insert wfh;

        Boolean thrown = false;
        Test.startTest();
        try {
            WFH_Request.processManagerDecision(wfh.Id, 'Approved', '');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException when status is not Pending');
    }

    @isTest
    static void test_managerDecision_WrongLevel_Throws() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending', 'HR', 1);
        insert wfh;

        Boolean thrown = false;
        Test.startTest();
        try {
            WFH_Request.processManagerDecision(wfh.Id, 'Approved', '');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException when approval level is not Manager');
    }

    // =========================================================
    // 11. processHRDecision - Approve
    // =========================================================
    @isTest
    static void test_hrApprove() {
        User emp = getEmployee();
        User mgr = getManager();
        Date mon = nextMonday(Date.today().addDays(60));
        Date wed = mon.addDays(2);

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, mon, wed, 'Pending HR Approval', 'HR', 3);
        wfh.Manager_Approval_Status__c = 'Approved';
        insert wfh;

        Test.startTest();
        WFH_Request.processHRDecision(wfh.Id, 'Approved', 'HR is happy');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, HR_Approval_Status__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Approved', updated.Status__c);
        System.assertEquals('Approved', updated.HR_Approval_Status__c);
    }

    // =========================================================
    // 12. processHRDecision - Reject
    // =========================================================
    @isTest
    static void test_hrReject() {
        User emp = getEmployee();
        User mgr = getManager();
        Date mon = nextMonday(Date.today().addDays(60));
        Date fri = mon.addDays(4);

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, mon, fri, 'Pending HR Approval', 'HR', 5);
        wfh.Manager_Approval_Status__c = 'Approved';
        insert wfh;

        Test.startTest();
        WFH_Request.processHRDecision(wfh.Id, 'Rejected', 'Policy violation');
        Test.stopTest();

        Work_from_home_Request__c updated = [
            SELECT Status__c, HR_Comments__c
            FROM Work_from_home_Request__c WHERE Id = :wfh.Id
        ];
        System.assertEquals('Rejected', updated.Status__c);
        System.assertEquals('Policy violation', updated.HR_Comments__c);
    }

    // =========================================================
    // 13. processHRDecision - Wrong status / level (guard check)
    // =========================================================
    @isTest
    static void test_hrDecision_WrongStatus_Throws() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending', 'Manager', 1);
        insert wfh;

        Boolean thrown = false;
        Test.startTest();
        try {
            WFH_Request.processHRDecision(wfh.Id, 'Approved', '');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException when status is not Pending HR Approval');
    }

    @isTest
    static void test_hrDecision_WrongLevel_Throws() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c wfh = buildWFH(emp.Id, mgr.Id, wd, wd, 'Pending HR Approval', 'Manager', 1);
        insert wfh;

        Boolean thrown = false;
        Test.startTest();
        try {
            WFH_Request.processHRDecision(wfh.Id, 'Approved', '');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Expected AuraHandledException when level is not HR');
    }

    // =========================================================
    // 14. getMyWFHRequests
    // =========================================================
    @isTest
    static void test_getMyWFHRequests_ReturnsList() {
        User emp = getEmployee();
        User mgr = getManager();
        Date wd1 = toWorkingDay(Date.today().addDays(7));
        Date wd2 = toWorkingDay(Date.today().addDays(14));

        insert new List<Work_from_home_Request__c>{
            buildWFH(emp.Id, mgr.Id, wd1, wd1, 'Pending',  'Manager', 1),
            buildWFH(emp.Id, mgr.Id, wd2, wd2, 'Approved', 'Manager', 1)
        };

        System.runAs(emp) {
            Test.startTest();
            List<Work_from_home_Request__c> results = WFH_Request.getMyWFHRequests();
            Test.stopTest();
            System.assertEquals(2, results.size(), 'Should return both WFH requests');
        }
    }

    @isTest
    static void test_getMyWFHRequests_EmptyForOtherUser() {
        User mgr = getManager();
        System.runAs(mgr) {
            Test.startTest();
            List<Work_from_home_Request__c> results = WFH_Request.getMyWFHRequests();
            Test.stopTest();
            System.assertEquals(0, results.size(), 'Manager should have no WFH requests');
        }
    }

    // =========================================================
    // 15. End-to-end: submit -> manager approve -> HR approve
    //
    // FIX: Only ONE Test.startTest()/stopTest() is allowed per test
    //      method. All three steps run inside a single test block.
    // =========================================================
    @isTest
    static void test_fullFlow_SubmitToHRApproval() {
        User emp = getEmployee();
        Date mon = nextMonday(Date.today().addDays(60));
        Date wed = mon.addDays(2); // 3 working days triggers HR level

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = wed,
            Reason__c     = 'Full flow test'
        );

        Test.startTest();

        // Step 1: Employee submits
        String wfhId;
        System.runAs(emp) {
            wfhId = WFH_Request.submitWorkFromHomeRequest(req);
        }
        System.assertNotEquals(null, wfhId);

        // Step 2: Manager approves - escalates to HR
        WFH_Request.processManagerDecision(wfhId, 'Approved', 'Manager approved');
        Work_from_home_Request__c afterMgr = [
            SELECT Status__c, Approval_Level__c
            FROM Work_from_home_Request__c WHERE Id = :wfhId
        ];
        System.assertEquals('Pending HR Approval', afterMgr.Status__c);
        System.assertEquals('HR', afterMgr.Approval_Level__c);

        // Step 3: HR final approval
        WFH_Request.processHRDecision(wfhId, 'Approved', 'HR approved');

        Test.stopTest();

        Work_from_home_Request__c afterHR = [SELECT Status__c FROM Work_from_home_Request__c WHERE Id = :wfhId];
        System.assertEquals('Approved', afterHR.Status__c);
    }

    // =========================================================
    // 16. End-to-end: submit -> manager reject
    // =========================================================
    @isTest
    static void test_fullFlow_ManagerReject() {
        User emp = getEmployee();
        Date wd  = toWorkingDay(Date.today().addDays(7));

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = wd,
            End_Date__c   = wd,
            Reason__c     = 'Rejection flow test'
        );

        Test.startTest();

        String wfhId;
        System.runAs(emp) {
            wfhId = WFH_Request.submitWorkFromHomeRequest(req);
        }
        WFH_Request.processManagerDecision(wfhId, 'Rejected', 'Denied by manager');

        Test.stopTest();

        Work_from_home_Request__c updated = [SELECT Status__c FROM Work_from_home_Request__c WHERE Id = :wfhId];
        System.assertEquals('Rejected', updated.Status__c);
    }

    // =========================================================
    // 17. End-to-end: submit -> manager approve -> HR reject
    // =========================================================
    @isTest
    static void test_fullFlow_HRReject() {
        User emp = getEmployee();
        Date mon = nextMonday(Date.today().addDays(60));
        Date wed = mon.addDays(2);

        Work_from_home_Request__c req = new Work_from_home_Request__c(
            Start_Date__c = mon,
            End_Date__c   = wed,
            Reason__c     = 'HR rejection flow'
        );

        Test.startTest();

        String wfhId;
        System.runAs(emp) {
            wfhId = WFH_Request.submitWorkFromHomeRequest(req);
        }
        WFH_Request.processManagerDecision(wfhId, 'Approved', 'Manager OK');
        WFH_Request.processHRDecision(wfhId, 'Rejected', 'HR no');

        Test.stopTest();

        Work_from_home_Request__c updated = [SELECT Status__c FROM Work_from_home_Request__c WHERE Id = :wfhId];
        System.assertEquals('Rejected', updated.Status__c);
    }

    // =========================================================
    // 18. calculateWorkingDays - holiday falls within range
    //     Exercises private getPublicHolidays() via submit.
    //
    // FIX: Replaced the unbounded while-loop (CPU limit risk) with
    //      direct arithmetic to find the Mon of the holiday's week.
    // =========================================================
    @isTest
    static void test_submit_HolidayInRange_ReducesDayCount() {
        User emp         = getEmployee();
        Date holidayDate = Date.today().addDays(30);
        Integer dow      = dayOfWeek(holidayDate);

        // Find the Monday of the same week as the holiday (no loop needed)
        // dow: 1=Mon, so weekMon = holidayDate minus (dow-1) days
        Date weekMon = holidayDate.addDays(-(dow - 1));
        Date weekFri = weekMon.addDays(4);

        // If that week is in the past or present, push 4 weeks forward
        // and mark dow=0 so we fall into the safe-submit branch
        if (weekMon <= Date.today()) {
            weekMon = weekMon.addDays(28);
            weekFri = weekFri.addDays(28);
            dow = 0;
        }

        if (dow >= 1 && dow <= 5) {
            // Holiday is a weekday - expect 4 working days in the Mon-Fri week
            Work_from_home_Request__c req = new Work_from_home_Request__c(
                Start_Date__c = weekMon,
                End_Date__c   = weekFri,
                Reason__c     = 'Holiday in range'
            );
            System.runAs(emp) {
                Test.startTest();
                String id = WFH_Request.submitWorkFromHomeRequest(req);
                Test.stopTest();
                Work_from_home_Request__c saved = [
                    SELECT Number_of_Days__c FROM Work_from_home_Request__c WHERE Id = :id
                ];
                System.assertEquals(4, Integer.valueOf(saved.Number_of_Days__c),
                    'Public holiday should reduce working days from 5 to 4');
            }
        } else {
            // Holiday falls on a weekend - just submit a clean Mon-Fri 8+ weeks out
            Date safeMon = nextMonday(Date.today().addDays(60));
            Date safeFri = safeMon.addDays(4);
            Work_from_home_Request__c req = new Work_from_home_Request__c(
                Start_Date__c = safeMon,
                End_Date__c   = safeFri,
                Reason__c     = 'Holiday on weekend safe submit'
            );
            System.runAs(emp) {
                Test.startTest();
                String id = WFH_Request.submitWorkFromHomeRequest(req);
                Test.stopTest();
                System.assertNotEquals(null, id);
            }
        }
    }
}