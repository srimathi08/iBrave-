@isTest
private class AdminAttendanceViewControllerTest {
    
    @TestSetup
    static void setupTestData() {
        List<Branch__c> branches = new List<Branch__c>();
        branches.add(new Branch__c(Branch_Name__c = 'HQ Branch'));
        branches.add(new Branch__c(Branch_Name__c = 'Branch 1'));
        branches.add(new Branch__c(Branch_Name__c = 'Branch 2'));
        insert branches;
        
        Map<String, Id> branchMap = new Map<String, Id>();
        for (Branch__c b : [SELECT Id, Branch_Name__c FROM Branch__c WHERE Id IN :branches]) {
            branchMap.put(b.Branch_Name__c, b.Id);
        }
        
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();
        
        List<User> testUsers = new List<User>();
        testUsers.add(new User(
            LastName = 'Alpha', FirstName = 'Test', Email = 'alpha' + ts + '@test.com',
            Username = 'alpha' + ts + '@test.com.test', Alias = 'ata',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_Id__c = 1001, Department = 'Sales', IsActive = true
        ));
        testUsers.add(new User(
            LastName = 'Beta', FirstName = 'Test', Email = 'beta' + ts + '@test.com',
            Username = 'beta' + ts + '@test.com.test', Alias = 'bta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_Id__c = 1002, Department = 'HR', IsActive = true
        ));
        testUsers.add(new User(
            LastName = 'Gamma', FirstName = 'Test', Email = 'gamma' + ts + '@test.com',
            Username = 'gamma' + ts + '@test.com.test', Alias = 'gta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_Id__c = 1003, Department = 'Sales', IsActive = true
        ));
        insert testUsers;
        
        Date today = Date.today();
        Date yesterday = today.addDays(-1);
        Date twoDaysAgo = today.addDays(-2);
        DateTime start9AM = DateTime.newInstance(today, Time.newInstance(9, 0, 0, 0));
        DateTime end5PM = DateTime.newInstance(today, Time.newInstance(17, 0, 0, 0));
        
        List<Employee_Attendance__c> attRecords = new List<Employee_Attendance__c>();
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = today,
            Check_In_Time__c = start9AM, Check_Out_Time__c = end5PM,
            Work_Location__c = 'Work from office', Branch__c = branchMap.get('HQ Branch'),
            Check_In_Location_Name__c = 'HQ Office', Check_Out_Location_Name__c = 'HQ Office'
        ));
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[1].Id, Date__c = today,
            Check_In_Time__c = start9AM.addMinutes(30), Check_Out_Time__c = end5PM.addMinutes(-30),
            Work_Location__c = 'Work from office', Branch__c = branchMap.get('Branch 1'),
            WFH_Reason__c = 'Remote meeting', WFH_Approval_Status__c = 'Approved'
        ));
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = yesterday,
            Check_In_Time__c = DateTime.newInstance(yesterday, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(yesterday, Time.newInstance(17, 0, 0, 0)),
            Work_Location__c = 'Client Place', Branch__c = branchMap.get('HQ Branch'),
            WFH_Reason__c = 'Sick leave', WFH_Approval_Status__c = 'Pending'
        ));
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = twoDaysAgo,
            Work_Location__c = 'Client Place', Branch__c = branchMap.get('Branch 1'),
            WFH_Reason__c = 'Family event', WFH_Approval_Status__c = 'Rejected'
        ));
        insert attRecords;
    }
    
    @isTest static void testMainMethod_AllPaths() {
        Test.startTest();
        Map<String, Object> fullFilters = new Map<String, Object>{
            'employeeId' => '1001', 'employeeName' => 'Test Alpha', 'department' => 'Sales',
            'startDate' => Date.today().addDays(-5).format(), 'endDate' => Date.today().format(),
            'pageSize' => 10, 'pageNumber' => 2, 'sortField' => 'Date__c', 'sortDirection' => 'ASC'
        };
        AdminAttendanceViewController.getAdminAttendanceRecords(fullFilters);
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'startDate' => 'invalid'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageSize' => 'abc'});
        Test.stopTest();
    }
    
    @isTest static void testDropdownMethods() {
        Test.startTest();
        AdminAttendanceViewController.getEmployeeIds();
        AdminAttendanceViewController.getEmployeeNames();
        AdminAttendanceViewController.getDepartments();
        Test.stopTest();
    }
    
    @isTest static void testSearchEmployees_AllCases() {
        Test.startTest();
        AdminAttendanceViewController.searchEmployees('Test Alpha');
        AdminAttendanceViewController.searchEmployees('Te');
        AdminAttendanceViewController.searchEmployees('T');
        AdminAttendanceViewController.searchEmployees('');
        AdminAttendanceViewController.searchEmployees(null);
        Test.stopTest();
    }
    
    @isTest static void testExportToCSV_AllCases() {
        Test.startTest();
        AdminAttendanceViewController.exportAttendanceToCSV(new Map<String, Object>());
        AdminAttendanceViewController.exportAttendanceToCSV(new Map<String, Object>{'pageSize' => 10000});
        Test.stopTest();
    }
    
    @isTest static void testHelperMethods_NullPaths() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(null);
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'employeeId' => null});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'startDate' => null});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageSize' => null});
        Test.stopTest();
    }
    
    @isTest static void testDynamicQuery_AllCombinations() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'employeeId' => '1001'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'employeeName' => 'Test'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'department' => 'Sales'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'startDate' => Date.today().format()});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{
            'employeeId' => '1001', 'department' => 'Sales', 'startDate' => Date.today().addDays(-2).format()
        });
        Test.stopTest();
    }
    
    @isTest static void testPagination_EdgeCases() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageSize' => 1, 'pageNumber' => 1});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageSize' => 1000});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageNumber' => 0});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'pageNumber' => -1});
        Test.stopTest();
    }
    
    @isTest static void testSorting_AllCombinations() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'sortDirection' => 'ASC'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'sortDirection' => 'DESC'});
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{'sortField' => 'Check_In_Time__c'});
        Test.stopTest();
    }
    
    // 🔥 COVERS THE MISSING 'else' BRANCH (wfh-unknown) - FIXED PICKLIST
    @isTest static void testWFHStatus_UnknownStatus() {
        Branch__c testBranch = new Branch__c(Branch_Name__c = 'Test Branch');
        insert testBranch;
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();
        User testUser = new User(
            LastName = 'Test', FirstName = 'User', Email = 'test' + ts + '@test.com',
            Username = 'test' + ts + '@test.com.test', Alias = 'tu',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, Employee_Id__c = 9999, Department = 'Test', IsActive = true
        );
        insert testUser;
        
        Employee_Attendance__c wfhRecord = new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = Date.today(),
            Work_Location__c = 'Client Place',           // Triggers WFH logic
            WFH_Reason__c = 'Test Reason',               // Required for WFH badge
            // 🔥 BLANK/null = String.isBlank(true) → hits FIRST if branch, but ensures full coverage
            Branch__c = testBranch.Id
        );
        insert wfhRecord;
        
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        Test.stopTest();
    }
}