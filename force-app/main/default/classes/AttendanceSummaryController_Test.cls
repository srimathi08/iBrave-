@isTest
private class AttendanceSummaryController_Test {

    public static final String BRANCH_NAME  = 'Test Branch';
    public static final String BRANCH_CITY  = 'Test City';
    public static final String BRANCH_STATE = 'Test State';

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create 2 test users
        List<User> users = new List<User>();
        for (Integer i = 1; i <= 2; i++) {
            users.add(new User(
                Alias = 'tuser' + i,
                Email = 'testuser' + i + '@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Test User ' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser' + i + DateTime.now().getTime() + '@testorg.com'
            ));
        }
        insert users;

        // Create Branch
        Branch__c testBranch = new Branch__c(
            Branch_Name__c = BRANCH_NAME,
            City__c = BRANCH_CITY,
            State__c = BRANCH_STATE,
            Is_Active__c = true
        );
        insert testBranch;

        Date today = Date.today();
        Date monthStart = today.toStartOfMonth();

        List<Employee_Attendance__c> records = new List<Employee_Attendance__c>();

        for (User u : users) {
            // 3 Present days
            for (Integer i = 0; i < 3; i++) {
                Date d = monthStart.addDays(i);
                records.add(new Employee_Attendance__c(
                    Employee_Name__c = u.Id,
                    Date__c = d,
                    Check_In_Time__c = DateTime.newInstance(d, Time.newInstance(9, 0, 0, 0)),
                    Check_Out_Time__c = DateTime.newInstance(d, Time.newInstance(17, 0, 0, 0)),
                    Status__c = 'Present',
                    Session_Number__c = 1,
                    Is_Multiple_Session__c = false,
                    Branch__c = testBranch.Id
                ));
            }

            // 1 Late day
            Date lateDay = monthStart.addDays(3);
            records.add(new Employee_Attendance__c(
                Employee_Name__c = u.Id,
                Date__c = lateDay,
                Check_In_Time__c = DateTime.newInstance(lateDay, Time.newInstance(10, 30, 0, 0)),
                Check_Out_Time__c = DateTime.newInstance(lateDay, Time.newInstance(18, 0, 0, 0)),
                Status__c = 'Late',
                Session_Number__c = 1,
                Is_Multiple_Session__c = false,
                Branch__c = testBranch.Id
            ));

            // 1 Absent day
            Date absentDay = monthStart.addDays(4);
            records.add(new Employee_Attendance__c(
                Employee_Name__c = u.Id,
                Date__c = absentDay,
                Check_In_Time__c = null,
                Status__c = 'Absent',
                Session_Number__c = 1,
                Is_Multiple_Session__c = false,
                Branch__c = testBranch.Id
            ));
        }

        insert records;
    }

    // ==============================
    // Test getMonthlySummary
    // ==============================
    @isTest
    static void testGetMonthlySummary() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser1@example.com' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = AttendanceSummaryController.getMonthlySummary(u.Id);
        Test.stopTest();

        System.debug('Monthly Summary: ' + result);
    }

    // ==============================
    // Test getAllUsersMonthlySummary
    // ==============================
    @isTest
    static void testGetAllUsersMonthlySummary() {
        Test.startTest();
        List<Map<String, Object>> allResults = AttendanceSummaryController.getAllUsersMonthlySummary();
        Test.stopTest();

        System.debug('All Users Monthly Summary: ' + allResults);
    }

    // ==============================
    // Test calculateAverageHours
    // ==============================
    @isTest
    static void testCalculateAverageHours() {
        User u = [SELECT Id FROM User LIMIT 1];

        List<Employee_Attendance__c> records = [
            SELECT Id, Date__c, Check_In_Time__c, Check_Out_Time__c, Hours_Worked__c, Status__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
        ];

        Test.startTest();
        Decimal avgHours = AttendanceSummaryController.calculateAverageHours(records);
        System.debug('Average Hours: ' + avgHours);
        Test.stopTest();
    }

    // ==============================
    // Test calculateTotalHours
    // ==============================
    @isTest
    static void testCalculateTotalHours() {
        User u = [SELECT Id FROM User LIMIT 1];

        List<Employee_Attendance__c> records = [
            SELECT Id, Hours_Worked__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
        ];

        Test.startTest();
        Decimal totalHours = AttendanceSummaryController.calculateTotalHours(records);
        System.debug('Total Hours: ' + totalHours);
        Test.stopTest();
    }

    // ==============================
    // Test calculateMonthlyMetrics
    // ==============================
    @isTest
    static void testCalculateMonthlyMetrics() {
        User u = [SELECT Id FROM User LIMIT 1];

        List<Employee_Attendance__c> records = [
            SELECT Id, Check_In_Time__c, Status__c, Date__c
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :u.Id
        ];

        Test.startTest();
        Map<String, Integer> metrics = AttendanceSummaryController.calculateMonthlyMetrics(records, Date.today().day());
        System.debug('Metrics: ' + metrics);
        Test.stopTest();
    }
}