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

        // Create leave types
        Leave_Type__c annualLeave = new Leave_Type__c(
            Leave_Type_Name__c='Annual Leave', Leave_Code__c='AL', Is_Active__c=true, Sort_Order__c=1
        );
        Leave_Type__c sickLeave = new Leave_Type__c(
            Leave_Type_Name__c='Sick Leave', Leave_Code__c='SL', Is_Active__c=true, Sort_Order__c=2
        );
        insert new List<Leave_Type__c>{annualLeave, sickLeave};

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
                Carried_Forward__c=0, Is_Eligible__c=false, Eligibility_Reason__c='Not eligible yet', Is_Active__c=true,
                Lifetime_Usage_Count__c=1
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

    @isTest static void testAreAllLeavesExhausted() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        Test.startTest();
        Boolean exhausted = EmployeeLeaveController.areAllLeavesExhausted(emp.Id, year);
        Test.stopTest();

        System.assertEquals(false, exhausted, 'Not all leaves are exhausted');
    }

    @isTest static void testGetEmployeeDetails() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];

        Test.startTest();
        Map<String,Object> details = EmployeeLeaveController.getEmployeeDetails(emp.Id);
        Test.stopTest();

        System.assert(details.containsKey('employee'), 'Employee details should be returned');
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
        System.assertNotEquals(null, counts, 'Counts returned');
        System.assertEquals('Leave balances refreshed successfully', refresh, 'Refresh returns correct message');
    }

    @isTest static void testCalculateWorkingDays() {
        User emp = [SELECT Id FROM User WHERE FirstName='Employee' LIMIT 1];
        String year = String.valueOf(Date.today().year());

        // Insert a holiday dynamically
        String validHolidayType = Holiday__c.Holiday_Type__c.getDescribe().getPicklistValues()[0].getValue();
        insert new Holiday__c(
            Name='Test Holiday', Holiday_Date__c=Date.today().addDays(1),
            Holiday_Type__c=validHolidayType, Is_Active__c=true
        );

        Test.startTest();
        Integer days = EmployeeLeaveController.calculateWorkingDays(Date.today(), Date.today().addDays(3));
        List<Holiday__c> holidays = EmployeeLeaveController.getHolidaysBetweenDates(Date.today(), Date.today().addDays(3));
        Test.stopTest();

        System.assert(days >= 0, 'Working days calculated');
        System.assert(holidays.size() >= 1, 'Holidays in range returned');
    }
}