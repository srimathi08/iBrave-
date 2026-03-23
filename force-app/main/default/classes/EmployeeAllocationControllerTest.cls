@IsTest
private class EmployeeAllocationControllerTest {
    
    /* =========================
       TEST DATA SETUP
       ========================= */
    @TestSetup
    static void setupTestData() {

        // Create Leave Type
        Leave_Type__c sickLeaveType = createLeaveType('Sick Leave', 'SL', 1);

        // Create Test User
        User testUser1 = new User(
            Alias = 'tuser1',
            Email = 'testuser1@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User One',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [
                SELECT Id 
                FROM Profile 
                WHERE Name = 'Standard User' 
                LIMIT 1
            ].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser1' + Datetime.now().getTime() + '@example.com',
            Employee_IDs__c = '12345',   // 🔁 UPDATED FIELD
            IsActive = true
        );
        insert testUser1;

        // Create Leave Balance
        Employee_Leave_Balance__c balance = new Employee_Leave_Balance__c(
            Employee__c = testUser1.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Active__c = true,
            Total_Allocated__c = 20,
            Used__c = 5,
            Booked__c = 2,
            Pending_Approval__c = 1,
            Leave_Type__c = sickLeaveType.Id
        );
        insert balance;
    }

    /* =========================
       HELPER METHOD
       ========================= */
    private static Leave_Type__c createLeaveType(String name, String code, Integer sortOrder) {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c = name,
            Leave_Code__c = code,
            Sort_Order__c = sortOrder
        );
        insert lt;
        return lt;
    }

    /* =========================
       PAGINATED SEARCH TESTS
       ========================= */
    @IsTest
    static void testGetEmployeesWithBalancesPaginated() {
        Test.startTest();

        // No search text
        EmployeeAllocationController.PaginatedResult result =
            EmployeeAllocationController.getEmployeesWithBalancesPaginated(1, null);
        System.assertNotEquals(null, result);
        System.assert(result.employees.size() > 0);

        // Numeric search (Employee_IDs__c)
        result = EmployeeAllocationController.getEmployeesWithBalancesPaginated(1, '12345');
        System.assert(result.employees.size() > 0);

        // Name search
        result = EmployeeAllocationController.getEmployeesWithBalancesPaginated(1, 'Test');
        System.assert(result.employees.size() > 0);

        Test.stopTest();
    }

    /* =========================
       LEGACY METHOD TEST
       ========================= */
    @IsTest
    static void testGetEmployeesWithBalancesLegacy() {
        Test.startTest();
        List<EmployeeAllocationController.EmployeeWithBalances> employees =
            EmployeeAllocationController.getEmployeesWithBalances();
        Test.stopTest();

        System.assert(employees.size() > 0);
    }

    /* =========================
       UPDATE SUCCESS TEST
       ========================= */
    @IsTest
    static void testUpdateEmployeeBalancesSuccess() {

        User u = [
            SELECT Id 
            FROM User 
            WHERE Employee_IDs__c = '12345'
            LIMIT 1
        ];

        Employee_Leave_Balance__c bal = [
            SELECT Id, Total_Allocated__c
            FROM Employee_Leave_Balance__c
            WHERE Employee__c = :u.Id
            LIMIT 1
        ];

        Decimal originalValue = bal.Total_Allocated__c;
        bal.Total_Allocated__c += 5;

        Test.startTest();
        EmployeeAllocationController.updateEmployeeBalances(
            new List<Employee_Leave_Balance__c>{ bal }
        );
        Test.stopTest();

        Employee_Leave_Balance__c updatedBal = [
            SELECT Total_Allocated__c
            FROM Employee_Leave_Balance__c
            WHERE Id = :bal.Id
        ];

        System.assertEquals(
            originalValue + 5,
            updatedBal.Total_Allocated__c
        );
    }

    /* =========================
       UPDATE ERROR CASES
       ========================= */
    @IsTest
    static void testUpdateEmployeeBalancesEmptyList() {
        Test.startTest();
        Boolean thrown = false;
        try {
            EmployeeAllocationController.updateEmployeeBalances(
                new List<Employee_Leave_Balance__c>()
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw for empty list');
    }

    @IsTest
    static void testUpdateEmployeeBalancesNullList() {
        Test.startTest();
        Boolean thrown = false;
        try {
            EmployeeAllocationController.updateEmployeeBalances(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Should throw for null list');
    }

    /* =========================
       PAGINATION EDGE CASES
       ========================= */
    @IsTest
    static void testPaginationPositiveCases() {
        Test.startTest();

        // Page 1
        EmployeeAllocationController.PaginatedResult page1 =
            EmployeeAllocationController.getEmployeesWithBalancesPaginated(1, null);
        System.assertNotEquals(null, page1);

        // Page 2 (OFFSET safety)
        EmployeeAllocationController.PaginatedResult page2 =
            EmployeeAllocationController.getEmployeesWithBalancesPaginated(2, null);
        System.assertNotEquals(null, page2);

        Test.stopTest();
    }
}