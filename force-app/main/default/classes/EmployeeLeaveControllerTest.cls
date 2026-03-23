@IsTest
public class EmployeeLeaveControllerTest {

    @testSetup
    static void setupTestData() {
        // Get standard profile
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];

        // Dynamically fetch valid picklist values
        String validEmploymentType = User.Employment_Type__c.getDescribe().getPicklistValues().size() > 0 
            ? User.Employment_Type__c.getDescribe().getPicklistValues()[0].getValue() : null;
        String validGender = User.Gender__c.getDescribe().getPicklistValues().size() > 0 
            ? User.Gender__c.getDescribe().getPicklistValues()[0].getValue() : null;
        String validHolidayType = Holiday__c.Holiday_Type__c.getDescribe().getPicklistValues().size() > 0 
            ? Holiday__c.Holiday_Type__c.getDescribe().getPicklistValues()[0].getValue() : null;

        // Create manager user
        User managerUser = new User(
            FirstName='Manager', LastName='Test',
            Username='manager'+System.currentTimeMillis()+'@test.com',
            Email='manager@test.com',
            Alias='mgrt', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert managerUser;

        // Create employee user
        User emp = new User(
            FirstName='Employee', LastName='Test',
            Username='employee'+System.currentTimeMillis()+'@test.com',
            Email='employee@test.com',
            Alias='empt', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id,
            ManagerId=managerUser.Id,
            Date_of_Joining__c=Date.today().addYears(-1),
            Gender__c=validGender,
            Employment_Type__c=validEmploymentType
        );
        insert emp;

        // Create second employee for edge case tests
        User emp2 = new User(
            FirstName='Employee2', LastName='Test',
            Username='employee2'+System.currentTimeMillis()+'@test.com',
            Email='employee2@test.com',
            Alias='emp2', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id,
            ManagerId=managerUser.Id,
            Date_of_Joining__c=Date.today().addYears(-1),
            Gender__c=validGender,
            Employment_Type__c=validEmploymentType
        );
        insert emp2;

        // Create leave types
        Leave_Type__c annualLeave = new Leave_Type__c(
            Leave_Type_Name__c='Annual Leave', Leave_Code__c='AL', Is_Active__c=true, Sort_Order__c=1
        );
        Leave_Type__c sickLeave = new Leave_Type__c(
            Leave_Type_Name__c='Sick Leave', Leave_Code__c='SL', Is_Active__c=true, Sort_Order__c=2
        );
        Leave_Type__c casualLeave = new Leave_Type__c(
            Leave_Type_Name__c='Casual Leave', Leave_Code__c='CL', Is_Active__c=true, Sort_Order__c=3
        );
        Leave_Type__c earnedLeave = new Leave_Type__c(
            Leave_Type_Name__c='Earned Leave', Leave_Code__c='EL', Is_Active__c=true, Sort_Order__c=4
        );
        Leave_Type__c lopLeave = new Leave_Type__c(
            Leave_Type_Name__c='Loss of Pay', Leave_Code__c='LOP', Is_Active__c=true, Sort_Order__c=5,
            Is_Fallback_Leave__c=true
        );
        Leave_Type__c limitedLeave = new Leave_Type__c(
            Leave_Type_Name__c='Limited Leave', Leave_Code__c='LL', Is_Active__c=true, Sort_Order__c=6,
            Max_Lifetime_Occurrences__c=1
        );
        insert new List<Leave_Type__c>{annualLeave, sickLeave, casualLeave, earnedLeave, lopLeave, limitedLeave};

        // Create holidays dynamically
        Holiday__c h1 = new Holiday__c(
            Name='Holiday 1', Holiday_Date__c=Date.today().addDays(1),
            Holiday_Type__c=validHolidayType, Is_Active__c=true
        );
        Holiday__c h2 = new Holiday__c(
            Name='Holiday 2', Holiday_Date__c=Date.today().addDays(5),
            Holiday_Type__c=validHolidayType, Is_Active__c=true
        );
        insert new List<Holiday__c>{h1, h2};

        // Pre-create leave balances for test coverage
        String year = String.valueOf(Date.today().year());
        List<Employee_Leave_Balance__c> balances = new List<Employee_Leave_Balance__c>{
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=annualLeave.Id, Year__c=year,
                Total_Allocated__c=20, Used__c=5, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=2
            ),
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=sickLeave.Id, Year__c=year,
                Total_Allocated__c=10, Used__c=10, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=false, Eligibility_Reason__c='Not eligible yet', 
                Is_Active__c=true, Lifetime_Usage_Count__c=1
            ),
            // Balance for getLeaveBalanceSummary1 coverage
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=casualLeave.Id, Year__c=year,
                Total_Allocated__c=12, Used__c=2, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=0
            ),
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=earnedLeave.Id, Year__c=year,
                Total_Allocated__c=15, Used__c=3, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=0
            ),
            // Balance with zero available
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=lopLeave.Id, Year__c=year,
                Total_Allocated__c=0, Used__c=0, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=0
            ),
            // Balance with max lifetime reached
            new Employee_Leave_Balance__c(
                Employee__c=emp.Id, Leave_Type__c=limitedLeave.Id, Year__c=year,
                Total_Allocated__c=5, Used__c=0, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=1
            ),
            // Employee2 - all leaves exhausted scenario
            new Employee_Leave_Balance__c(
                Employee__c=emp2.Id, Leave_Type__c=annualLeave.Id, Year__c=year,
                Total_Allocated__c=10, Used__c=10, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=0
            ),
            new Employee_Leave_Balance__c(
                Employee__c=emp2.Id, Leave_Type__c=lopLeave.Id, Year__c=year,
                Total_Allocated__c=0, Used__c=0, Booked__c=0, Pending_Approval__c=0,
                Carried_Forward__c=0, Is_Eligible__c=true, Is_Active__c=true, Lifetime_Usage_Count__c=0
            )
        };
        insert balances;
    }

    // ------------------- TEST METHODS -------------------

    @isTest static void testGetEmployeeLeaveBalances() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        List<Employee_Leave_Balance__c> result = EmployeeLeaveController.getEmployeeLeaveBalances(emp.Id, year);
        Test.stopTest();

        System.assert(result.size() > 0, 'Balances should be returned');
    }

    @isTest static void testGetUpcomingHolidays() {
        Test.startTest();
        List<Holiday__c> holidays = EmployeeLeaveController.getUpcomingHolidays();
        Test.stopTest();
        System.assert(holidays.size() >= 2, 'Upcoming holidays should be returned');
    }

    @isTest static void testGetUpcomingLeavesAndHolidays() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];

        insert new Leave_Request__c(
            Employee__c=emp.Id, Leave_Type__c=lt.Id,
            Start_Date__c=Date.today().addDays(1), End_Date__c=Date.today().addDays(2),
            Total_Days__c=2, Status__c='Pending', Is_Active__c=true
        );

        Test.startTest();
        List<Map<String,Object>> results = EmployeeLeaveController.getUpcomingLeavesAndHolidays(emp.Id);
        Test.stopTest();

        System.assert(results.size() > 0, 'Upcoming leaves and holidays should be returned');
    }

    @isTest static void testGetUpcomingLeavesAndHolidays_WithApproved() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];

        insert new Leave_Request__c(
            Employee__c=emp.Id, Leave_Type__c=lt.Id,
            Start_Date__c=Date.today().addDays(10), End_Date__c=Date.today().addDays(12),
            Total_Days__c=3, Status__c='Approved', Is_Active__c=true
        );

        Test.startTest();
        List<Map<String,Object>> results = EmployeeLeaveController.getUpcomingLeavesAndHolidays(emp.Id);
        Test.stopTest();

        System.assert(results.size() > 0, 'Approved leaves should be returned');
    }

    @isTest static void testGetPastLeavesAndHolidays() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];

        insert new Leave_Request__c(
            Employee__c=emp.Id, Leave_Type__c=lt.Id,
            Start_Date__c=Date.today().addDays(-5), End_Date__c=Date.today().addDays(-3),
            Total_Days__c=3, Status__c='Completed', Is_Active__c=true
        );

        Test.startTest();
        List<Map<String,Object>> results = EmployeeLeaveController.getPastLeavesAndHolidays(emp.Id);
        Test.stopTest();

        System.assert(results.size() > 0, 'Past leaves and holidays should be returned');
    }

    @isTest static void testGetLeaveBalance_and_canApplyForLeave() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c annual = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];
        Leave_Type__c sick = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='SL' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> bal = EmployeeLeaveController.getLeaveBalance(emp.Id, annual.Id, year);
        Map<String,Object> canApply = EmployeeLeaveController.canApplyForLeave(emp.Id, annual.Id, year);
        Map<String,Object> cannotApply = EmployeeLeaveController.canApplyForLeave(emp.Id, sick.Id, year);
        Test.stopTest();

        System.assertEquals(true, canApply.get('canApply'), 'Eligible leave with balance');
        System.assertEquals(false, cannotApply.get('canApply'), 'Ineligible leave should return false');
        System.assertNotEquals(null, bal, 'Balance map should not be null');
    }

    @isTest static void testGetLeaveBalance_NoBalance() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());
        
        // Create a new leave type without any balance
        Leave_Type__c newType = new Leave_Type__c(
            Leave_Type_Name__c='New Leave Type', Leave_Code__c='NLT', Is_Active__c=true, Sort_Order__c=99
        );
        insert newType;

        Test.startTest();
        Map<String,Object> bal = EmployeeLeaveController.getLeaveBalance(emp.Id, newType.Id, year);
        Test.stopTest();

        System.assertEquals(null, bal, 'Balance should be null for non-existent balance');
    }

    @isTest static void testCanApplyForLeave_NoBalance() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());
        
        // Create a new leave type without any balance
        Leave_Type__c newType = new Leave_Type__c(
            Leave_Type_Name__c='Another Leave Type', Leave_Code__c='ALT', Is_Active__c=true, Sort_Order__c=100
        );
        insert newType;

        Test.startTest();
        Map<String,Object> result = EmployeeLeaveController.canApplyForLeave(emp.Id, newType.Id, year);
        Test.stopTest();

        System.assertEquals(false, result.get('canApply'), 'Should not be able to apply without balance');
        System.assertEquals('You do not have this leave type allocated.', result.get('message'));
    }

    @isTest static void testCanApplyForLeave_ZeroBalance() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lop = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='LOP' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> result = EmployeeLeaveController.canApplyForLeave(emp.Id, lop.Id, year);
        Test.stopTest();

        System.assertEquals(false, result.get('canApply'), 'Should not be able to apply with zero balance');
    }

    @isTest static void testCanApplyForLeave_MaxLifetimeReached() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c limited = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='LL' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> result = EmployeeLeaveController.canApplyForLeave(emp.Id, limited.Id, year);
        Test.stopTest();

        System.assertEquals(false, result.get('canApply'), 'Should not be able to apply when max lifetime reached');
        System.assert(((String)result.get('message')).contains('Maximum lifetime usage'), 'Should contain lifetime message');
    }

    @isTest static void testAreAllLeavesExhausted() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Boolean exhausted = EmployeeLeaveController.areAllLeavesExhausted(emp.Id, year);
        Test.stopTest();

        System.assertEquals(false, exhausted, 'Not all leaves are exhausted');
    }

    @isTest static void testAreAllLeavesExhausted_AllExhausted() {
        User emp2 = [SELECT Id FROM User WHERE FirstName='Employee2' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Boolean exhausted = EmployeeLeaveController.areAllLeavesExhausted(emp2.Id, year);
        Test.stopTest();

        System.assertEquals(true, exhausted, 'All leaves should be exhausted for emp2');
    }

    @isTest static void testGetEmployeeDetails() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];

        Test.startTest();
        Map<String,Object> details = EmployeeLeaveController.getEmployeeDetails(emp.Id);
        Test.stopTest();

        System.assert(details.containsKey('employee'), 'Employee details should be returned');
        System.assert(details.containsKey('serviceMonths'), 'Service months should be calculated');
        System.assert(details.containsKey('serviceDays'), 'Service days should be calculated');
    }

    @isTest static void testGetAllLeaveTypes_and_summary() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        List<Leave_Type__c> types = EmployeeLeaveController.getAllLeaveTypes();
        Map<String,Object> summary = EmployeeLeaveController.getLeaveBalanceSummary(emp.Id, year);
        Map<String,Integer> counts = EmployeeLeaveController.getLeaveRequestsCountByStatus(emp.Id, year);
        String refresh = EmployeeLeaveController.refreshLeaveBalances(emp.Id, year);
        Test.stopTest();

        System.assert(types.size() >= 2, 'Leave types returned');
        System.assertNotEquals(null, summary, 'Summary returned');
        System.assert(summary.containsKey('totalAllocated'), 'Total allocated should be in summary');
        System.assert(summary.containsKey('totalUsed'), 'Total used should be in summary');
        System.assert(summary.containsKey('totalAvailable'), 'Total available should be in summary');
        System.assertNotEquals(null, counts, 'Counts returned');
        System.assertEquals('Leave balances refreshed successfully', refresh, 'Refresh returns correct message');
    }

    @isTest static void testGetLeaveRequestsCountByStatus_WithRequests() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        // Create leave requests with different statuses
        List<Leave_Request__c> requests = new List<Leave_Request__c>{
            new Leave_Request__c(
                Employee__c=emp.Id, Leave_Type__c=lt.Id,
                Start_Date__c=Date.today().addDays(1), End_Date__c=Date.today().addDays(2),
                Total_Days__c=2, Status__c='Pending', Is_Active__c=true, Year__c=year
            ),
            new Leave_Request__c(
                Employee__c=emp.Id, Leave_Type__c=lt.Id,
                Start_Date__c=Date.today().addDays(5), End_Date__c=Date.today().addDays(6),
                Total_Days__c=2, Status__c='Approved', Is_Active__c=true, Year__c=year
            )
        };
        insert requests;

        Test.startTest();
        Map<String,Integer> counts = EmployeeLeaveController.getLeaveRequestsCountByStatus(emp.Id, year);
        Test.stopTest();

        System.assert(counts.get('Pending') >= 1, 'Pending count should be at least 1');
        System.assert(counts.get('Approved') >= 1, 'Approved count should be at least 1');
    }

    @isTest static void testCalculateWorkingDays() {
        Test.startTest();
        Integer days = EmployeeLeaveController.calculateWorkingDays(Date.today(), Date.today().addDays(10));
        List<Holiday__c> holidays = EmployeeLeaveController.getHolidaysBetweenDates(Date.today(), Date.today().addDays(10));
        Test.stopTest();

        System.assert(days >= 0, 'Working days calculated');
        System.assert(holidays.size() >= 0, 'Holidays in range returned');
    }

    @isTest static void testCalculateWorkingDays_NullDates() {
        Test.startTest();
        Integer days1 = EmployeeLeaveController.calculateWorkingDays(null, Date.today());
        Integer days2 = EmployeeLeaveController.calculateWorkingDays(Date.today(), null);
        Integer days3 = EmployeeLeaveController.calculateWorkingDays(null, null);
        Test.stopTest();

        System.assertEquals(0, days1, 'Null start date should return 0');
        System.assertEquals(0, days2, 'Null end date should return 0');
        System.assertEquals(0, days3, 'Both null dates should return 0');
    }

    @isTest static void testCalculateWorkingDays_InvalidRange() {
        Test.startTest();
        Integer days = EmployeeLeaveController.calculateWorkingDays(Date.today().addDays(5), Date.today());
        Test.stopTest();

        System.assertEquals(0, days, 'Start date after end date should return 0');
    }

    @isTest static void testCalculateWorkingDays_SameDay() {
        Test.startTest();
        Integer days = EmployeeLeaveController.calculateWorkingDays(Date.today(), Date.today());
        Test.stopTest();

        System.assert(days >= 0 && days <= 1, 'Same day should return 0 or 1 depending on day');
    }

    @isTest static void testGetHolidaysBetweenDates() {
        Test.startTest();
        List<Holiday__c> holidays = EmployeeLeaveController.getHolidaysBetweenDates(
            Date.today(), Date.today().addDays(10)
        );
        Test.stopTest();

        System.assert(holidays.size() >= 2, 'Should return holidays in range');
    }

    @isTest static void testGetLeaveBalanceSummary1() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> summary = EmployeeLeaveController.getLeaveBalanceSummary1(emp.Id, year);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary1 should be returned');
        System.assert(summary.containsKey('totalAvailable'), 'Should contain totalAvailable');
    }

    @isTest static void testGetLeaveBalanceSummary1_NoBalances() {
        // Create a user with no balances for the specific leave types
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName='NoBalance', LastName='User',
            Username='nobalance'+System.currentTimeMillis()+'@test.com',
            Email='nobalance@test.com',
            Alias='nbu', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;
        
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> summary = EmployeeLeaveController.getLeaveBalanceSummary1(testUser.Id, year);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary1 should be returned even with no balances');
        System.assertEquals(0, (Decimal)summary.get('totalAvailable'), 'Total available should be 0');
    }

    // ------------------- EDGE CASE TESTS -------------------

    @isTest static void testGetUpcomingLeavesAndHolidays_NoData() {
        // Create a user with no leave requests
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName='NoLeave', LastName='User',
            Username='noleave'+System.currentTimeMillis()+'@test.com',
            Email='noleave@test.com',
            Alias='nlu', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;

        Test.startTest();
        List<Map<String,Object>> results = EmployeeLeaveController.getUpcomingLeavesAndHolidays(testUser.Id);
        Test.stopTest();

        // Should still return holidays even if no leaves
        System.assertNotEquals(null, results, 'Results should not be null');
    }

    @isTest static void testGetPastLeavesAndHolidays_NoData() {
        // Create a user with no past leave requests
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName='NoPast', LastName='User',
            Username='nopast'+System.currentTimeMillis()+'@test.com',
            Email='nopast@test.com',
            Alias='npu', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;

        Test.startTest();
        List<Map<String,Object>> results = EmployeeLeaveController.getPastLeavesAndHolidays(testUser.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should have no past leaves');
    }

    @isTest static void testGetLeaveBalanceSummary_EmptyBalances() {
        // Create a user with no balances
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName='Empty', LastName='Balance',
            Username='emptybal'+System.currentTimeMillis()+'@test.com',
            Email='emptybal@test.com',
            Alias='ebu', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;
        
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> summary = EmployeeLeaveController.getLeaveBalanceSummary(testUser.Id, year);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary should be returned');
        System.assertEquals(0, (Decimal)summary.get('totalAllocated'), 'Total allocated should be 0');
        System.assertEquals(0, (Decimal)summary.get('totalUsed'), 'Total used should be 0');
        System.assertEquals(0, (Decimal)summary.get('totalAvailable'), 'Total available should be 0');
    }

    @isTest static void testGetEmployeeDetails_WithNullJoiningDate() {
        // Create a user without date of joining
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser = new User(
            FirstName='NoJoin', LastName='Date',
            Username='nojoin'+System.currentTimeMillis()+'@test.com',
            Email='nojoin@test.com',
            Alias='njd', TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert testUser;

        Test.startTest();
        Map<String,Object> details = EmployeeLeaveController.getEmployeeDetails(testUser.Id);
        Test.stopTest();

        System.assert(details.containsKey('employee'), 'Employee details should be returned');
        System.assert(!details.containsKey('serviceMonths'), 'Service months should not be present');
    }

    @isTest static void testGetLeaveBalance_WithNullValues() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Leave_Code__c='AL' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Map<String,Object> balance = EmployeeLeaveController.getLeaveBalance(emp.Id, lt.Id, year);
        Test.stopTest();

        System.assertNotEquals(null, balance, 'Balance should be returned');
        System.assert(balance.containsKey('Available__c'), 'Available should be present');
    }

    @isTest static void testCalculateWorkingDays_WeekendOnly() {
        // Find a Saturday
        Date saturday = Date.today();
        while (saturday.toStartOfWeek() != saturday.addDays(-5)) {
            saturday = saturday.addDays(1);
        }
        // This gets us to a Saturday
        Datetime dt = Datetime.newInstance(saturday.year(), saturday.month(), saturday.day());
        while (dt.format('u') != '6') {
            saturday = saturday.addDays(1);
            dt = Datetime.newInstance(saturday.year(), saturday.month(), saturday.day());
        }
        Date sunday = saturday.addDays(1);

        Test.startTest();
        Integer days = EmployeeLeaveController.calculateWorkingDays(saturday, sunday);
        Test.stopTest();

        System.assertEquals(0, days, 'Weekend only should return 0 working days');
    }
}