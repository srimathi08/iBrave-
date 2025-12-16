@isTest
public class LeaveAdminControllerTest {

    @testSetup
    static void setupTestData() {
        // Get Standard User Profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create test Users
        List<User> users = new List<User>();
        for (Integer i = 0; i < 3; i++) {
            users.add(new User(
                FirstName = 'Test' + i,
                LastName = 'User' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'uniqueTestUser' + i + '@example.com',
                Alias = 'tu' + i,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US',
                Employee_Id__c = Decimal.valueOf(100 + i) // Decimal value
            ));
        }
        insert users;

        // Create Leave Types
        List<Leave_Type__c> leaveTypes = new List<Leave_Type__c>{
            new Leave_Type__c(
                Leave_Type_Name__c = 'Sick Leave',
                Leave_Code__c = 'SL',
                Default_Allocation__c = 10,
                Is_Active__c = true
            ),
            new Leave_Type__c(
                Leave_Type_Name__c = 'Casual Leave',
                Leave_Code__c = 'CL',
                Default_Allocation__c = 15,
                Is_Active__c = true
            )
        };
        insert leaveTypes;

        // Create Holiday with valid picklist
        insert new Holiday__c(
            Name = 'Test Holiday',
            Holiday_Date__c = Date.today(),
            Holiday_Type__c = 'Public Holiday', // correct picklist value
            Is_Active__c = true
        );

        // Create Leave Request
        insert new Leave_Request__c(
            Employee__c = users[0].Id,
            Leave_Type__c = leaveTypes[0].Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(2),
            Total_Days__c = 3,
            Status__c = 'Pending',
            Is_Active__c = true
        );
    }

    @isTest
    static void testGetLeaveTypesAndHolidays() {
        Test.startTest();
        List<Leave_Type__c> types = LeaveAdminController.getLeaveTypes();
        List<Holiday__c> hol = LeaveAdminController.getHolidays();
        Test.stopTest();

        System.assert(types.size() > 0);
        System.assert(hol.size() > 0);
    }

    @isTest
    static void testSaveLeaveTypeAndBalanceCreation() {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c = 'Test Leave 2',
            Leave_Code__c = 'TL2',
            Default_Allocation__c = 5,
            Is_Active__c = true
        );

        Test.startTest();
        String id = LeaveAdminController.saveLeaveType(lt);
        Test.stopTest();

        System.assertNotEquals(null, id);

        List<Employee_Leave_Balance__c> balances = [
            SELECT Id FROM Employee_Leave_Balance__c 
            WHERE Leave_Type__c = :id
        ];
        System.assert(balances.size() > 0, 'Balances should be created');
    }

    @isTest
    static void testSyncAllBalances() {
        Test.startTest();
        String msg = LeaveAdminController.syncAllBalances();
        Test.stopTest();

        System.assert(msg.contains('Success') || msg.contains('already'));
    }

    // New method to test branch where no users exist
    @isTest
    static void testSyncAllBalances_NoUsers() {
        // Remove Employee_Id__c so system sees "no users"
        List<User> users = [SELECT Id, Employee_Id__c FROM User WHERE Employee_Id__c != null];
        for (User u : users) {
            u.Employee_Id__c = null;
        }
        update users;

        Test.startTest();
        String msg = LeaveAdminController.syncAllBalances();
        Test.stopTest();

        System.assert(msg.contains('No active users'));
    }

    @isTest
    static void testSaveHoliday() {
        Holiday__c h = new Holiday__c(
            Name = 'New Holiday',
            Holiday_Date__c = Date.today().addDays(5),
            Holiday_Type__c = 'Public Holiday',
            Is_Active__c = true
        );

        Test.startTest();
        String hId = LeaveAdminController.saveHoliday(h);
        Test.stopTest();

        System.assertNotEquals(null, hId);
    }

    @isTest
    static void testDeleteLeaveTypeAndHoliday() {
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];
        Holiday__c h = [SELECT Id FROM Holiday__c LIMIT 1];

        Test.startTest();
        LeaveAdminController.deleteLeaveType(lt.Id);
        LeaveAdminController.deleteHoliday(h.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Leave_Type__c WHERE Id = :lt.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM Holiday__c WHERE Id = :h.Id]);
    }

    @isTest
    static void testSearchAndExportLeaveRequests() {
        Leave_Request__c lr = [
            SELECT Id, Employee__r.Employee_Id__c, Employee__r.Name,
                   Employee__r.Department, Leave_Type__c,
                   Status__c, Start_Date__c, End_Date__c
            FROM Leave_Request__c
            LIMIT 1
        ];

        Map<String, String> filters = new Map<String, String>{
            'employeeId' => String.valueOf(lr.Employee__r.Employee_Id__c),
            'employeeName' => lr.Employee__r.Name,
            'department' => lr.Employee__r.Department != null ? lr.Employee__r.Department : '',
            'leaveTypeId' => lr.Leave_Type__c,
            'status' => lr.Status__c,
            'startDateFrom' => String.valueOf(lr.Start_Date__c),
            'startDateTo' => String.valueOf(lr.End_Date__c)
        };

        Test.startTest();
        List<Leave_Request__c> result = LeaveAdminController.searchLeaveRequests(filters);
        String csv = LeaveAdminController.exportLeaveRequestsToCSV(filters);
        Test.stopTest();

        System.assert(result.size() > 0, 'Search should return results');
        System.assert(csv.contains('Request Number'), 'CSV header must be present');
    }
}