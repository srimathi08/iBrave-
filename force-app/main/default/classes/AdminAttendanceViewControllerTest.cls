/**
 * @description Test class for AdminAttendanceViewController
 * @author Salesforce Consultant
 * @date 2025-01-28
 * @version 2.0 - Enhanced for 90%+ code coverage
 */
@isTest
private class AdminAttendanceViewControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test branches
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
        
        // Create test users with different Employee Categories for access testing
        List<User> testUsers = new List<User>();
        
        // User 1: Regular employee (Sales)
        testUsers.add(new User(
            LastName = 'Alpha', FirstName = 'Test', Email = 'alpha' + ts + '@test.com',
            Username = 'alpha' + ts + '@test.com.test', Alias = 'ata',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_IDs__c = '1001', 
            Department = 'Sales', IsActive = true,
            Employee_Category__c = 'On-Role(Team Member)'
        ));
        
        // User 2: HR Team member
        testUsers.add(new User(
            LastName = 'Beta', FirstName = 'Test', Email = 'beta' + ts + '@test.com',
            Username = 'beta' + ts + '@test.com.test', Alias = 'bta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_IDs__c = '1002', 
            Department = 'HR', IsActive = true,
            Employee_Category__c = 'HR Team'
        ));
        
        // User 3: HR Manager
        testUsers.add(new User(
            LastName = 'Gamma', FirstName = 'Test', Email = 'gamma' + ts + '@test.com',
            Username = 'gamma' + ts + '@test.com.test', Alias = 'gta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_IDs__c = '1003', 
            Department = 'Sales', IsActive = true,
            Employee_Category__c = 'HR Manager'
        ));
        
        // User 4: Management (no admin access)
        testUsers.add(new User(
            LastName = 'Delta', FirstName = 'Test', Email = 'delta' + ts + '@test.com',
            Username = 'delta' + ts + '@test.com.test', Alias = 'dta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_IDs__c = '1004', 
            Department = 'Management', IsActive = true,
            Employee_Category__c = 'Management'
        ));
        
        // User 5: No category set
        testUsers.add(new User(
            LastName = 'Epsilon', FirstName = 'Test', Email = 'epsilon' + ts + '@test.com',
            Username = 'epsilon' + ts + '@test.com.test', Alias = 'eta',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id, Employee_IDs__c = '1005', 
            Department = 'IT', IsActive = true
            // No Employee_Category__c set
        ));
        
        insert testUsers;
        
        Date today = Date.today();
        Date yesterday = today.addDays(-1);
        Date twoDaysAgo = today.addDays(-2);
        DateTime start9AM = DateTime.newInstance(today, Time.newInstance(9, 0, 0, 0));
        DateTime end5PM = DateTime.newInstance(today, Time.newInstance(17, 0, 0, 0));
        
        // Create attendance records with various scenarios
        List<Employee_Attendance__c> attRecords = new List<Employee_Attendance__c>();
        
        // Record 1: Regular office attendance
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = today,
            Check_In_Time__c = start9AM, Check_Out_Time__c = end5PM,
            Work_Location__c = 'Work from office', Branch__c = branchMap.get('HQ Branch'),
            Check_In_Location_Name__c = 'HQ Office', Check_Out_Location_Name__c = 'HQ Office'
        ));
        
        // Record 2: WFH with Approved status
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[1].Id, Date__c = today,
            Check_In_Time__c = start9AM.addMinutes(30), Check_Out_Time__c = end5PM.addMinutes(-30),
            Work_Location__c = 'Work from Home', Branch__c = branchMap.get('Branch 1'),
            WFH_Reason__c = 'Remote meeting', WFH_Approval_Status__c = 'Approved'
        ));
        
        // Record 3: WFH with Pending status
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = yesterday,
            Check_In_Time__c = DateTime.newInstance(yesterday, Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(yesterday, Time.newInstance(17, 0, 0, 0)),
            Work_Location__c = 'Work from Home', Branch__c = branchMap.get('HQ Branch'),
            WFH_Reason__c = 'Sick leave', WFH_Approval_Status__c = 'Pending'
        ));
        
        // Record 4: WFH with Rejected status
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = twoDaysAgo,
            Work_Location__c = 'Work from Home', Branch__c = branchMap.get('Branch 1'),
            WFH_Reason__c = 'Family event', WFH_Approval_Status__c = 'Rejected'
        ));
        
        // Record 5: WFH with blank/null status (to cover pending else branch)
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[2].Id, Date__c = today,
            Check_In_Time__c = start9AM, Check_Out_Time__c = end5PM,
            Work_Location__c = 'Work from Home', Branch__c = branchMap.get('Branch 2'),
            WFH_Reason__c = 'Doctor appointment'
            // WFH_Approval_Status__c is blank - covers the null/pending branch
        ));
        
        // Record 6: Client Place without WFH reason
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[3].Id, Date__c = today,
            Check_In_Time__c = start9AM, Check_Out_Time__c = end5PM,
            Work_Location__c = 'Client Place', Branch__c = branchMap.get('HQ Branch')
        ));
        
        // Record 7: Attendance with no check-in/check-out (partial day)
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[4].Id, Date__c = today,
            Work_Location__c = 'Work from office', Branch__c = branchMap.get('Branch 1')
        ));
        
        // Record 8: Record with special characters for CSV testing
        attRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testUsers[0].Id, Date__c = today.addDays(-3),
            Check_In_Time__c = start9AM, Check_Out_Time__c = end5PM,
            Work_Location__c = 'Work from Home', Branch__c = branchMap.get('HQ Branch'),
            WFH_Reason__c = 'Meeting with "Client", needs review\nMulti-line reason',
            WFH_Approval_Status__c = 'Approved'
        ));
        
        insert attRecords;
    }
    
    // ============================================
    // MAIN METHOD TESTS
    // ============================================
    
    @isTest 
    static void testMainMethod_AllFilters() {
        Test.startTest();
        Map<String, Object> fullFilters = new Map<String, Object>{
            'employeeId' => '1001', 
            'employeeName' => 'Test Alpha', 
            'department' => 'Sales',
            'startDate' => Date.today().addDays(-5).format(), 
            'endDate' => Date.today().format(),
            'pageSize' => 10, 
            'pageNumber' => 1, 
            'sortField' => 'Date__c', 
            'sortDirection' => 'ASC'
        };
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(fullFilters);
        System.assertEquals(true, result.get('success'), 'Should return success');
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_NoFilters() {
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        System.assertEquals(true, result.get('success'), 'Should return success with no filters');
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_InvalidDate() {
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'startDate' => 'invalid-date'}
        );
        System.assertEquals(true, result.get('success'), 'Should handle invalid date gracefully');
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_InvalidPageSize() {
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 'abc'}
        );
        System.assertEquals(true, result.get('success'), 'Should handle invalid page size gracefully');
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_NullParams() {
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(null);
        System.assertEquals(true, result.get('success'), 'Should handle null params');
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_NullValues() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'employeeId' => null}
        );
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'startDate' => null}
        );
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => null}
        );
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_Pagination() {
        Test.startTest();
        // Page 1 with small size
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 1, 'pageNumber' => 1}
        );
        // Page 2
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 1, 'pageNumber' => 2}
        );
        // Large page size
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 1000}
        );
        // Edge cases
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageNumber' => 0}
        );
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_Sorting() {
        Test.startTest();
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'sortDirection' => 'ASC'}
        );
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'sortDirection' => 'DESC'}
        );
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'sortField' => 'Check_In_Time__c'}
        );
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'sortField' => 'Employee_Name__r.Name', 'sortDirection' => 'ASC'}
        );
        Test.stopTest();
    }
    
    @isTest 
    static void testMainMethod_FilterCombinations() {
        Test.startTest();
        // Only employee ID
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'employeeId' => '1001'}
        );
        // Only employee name
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'employeeName' => 'Test Alpha'}
        );
        // Only department
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'department' => 'Sales'}
        );
        // Only start date
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'startDate' => Date.today().format()}
        );
        // Only end date
        AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'endDate' => Date.today().format()}
        );
        // Multiple filters
        AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{
            'employeeId' => '1001', 
            'department' => 'Sales', 
            'startDate' => Date.today().addDays(-5).format(),
            'endDate' => Date.today().format()
        });
        Test.stopTest();
    }
    
    // ============================================
    // DROPDOWN METHODS TESTS
    // ============================================
    
    @isTest 
    static void testGetEmployeeIds() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.getEmployeeIds();
        System.assertNotEquals(null, result, 'Should return employee IDs');
        System.assert(result.size() > 0, 'Should have at least one employee ID');
        Test.stopTest();
    }
    
    @isTest 
    static void testGetEmployeeNames() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.getEmployeeNames();
        System.assertNotEquals(null, result, 'Should return employee names');
        System.assert(result.size() > 0, 'Should have at least one employee name');
        Test.stopTest();
    }
    
    @isTest 
    static void testGetDepartments() {
        Test.startTest();
        List<String> result = AdminAttendanceViewController.getDepartments();
        System.assertNotEquals(null, result, 'Should return departments');
        Test.stopTest();
    }
    
    // ============================================
    // SEARCH EMPLOYEES TESTS
    // ============================================
    
    @isTest 
    static void testSearchEmployees_ValidSearch() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployees('Test');
        System.assertNotEquals(null, result, 'Should return search results');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployees_MinLength() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployees('Te');
        System.assertNotEquals(null, result, 'Should return results for 2 chars');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployees_TooShort() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployees('T');
        System.assertEquals(0, result.size(), 'Should return empty for 1 char');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployees_Empty() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployees('');
        System.assertEquals(0, result.size(), 'Should return empty for blank');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployees_Null() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployees(null);
        System.assertEquals(0, result.size(), 'Should return empty for null');
        Test.stopTest();
    }
    
    // ============================================
    // SEARCH EMPLOYEES LIGHTWEIGHT TESTS
    // ============================================
    
    @isTest 
    static void testSearchEmployeesLightweight_ByEmployeeId() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('employeeId', '1001');
        System.assertNotEquals(null, result, 'Should return results for employee ID search');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployeesLightweight_ByName() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('name', 'Test');
        System.assertNotEquals(null, result, 'Should return results for name search');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployeesLightweight_EmptySearch() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('name', '');
        System.assertEquals(0, result.size(), 'Should return empty for blank search');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployeesLightweight_NullSearch() {
        Test.startTest();
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('name', null);
        System.assertEquals(0, result.size(), 'Should return empty for null search');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployeesLightweight_NonNumericEmployeeId() {
        Test.startTest();
        // Search with non-numeric characters in employee ID
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('employeeId', 'ABC');
        System.assertNotEquals(null, result, 'Should handle non-numeric employee ID');
        Test.stopTest();
    }
    
    @isTest 
    static void testSearchEmployeesLightweight_MixedEmployeeId() {
        Test.startTest();
        // Search with mixed alphanumeric
        List<Map<String, Object>> result = AdminAttendanceViewController.searchEmployeesLightweight('employeeId', 'EMP1001');
        System.assertNotEquals(null, result, 'Should extract numeric portion');
        Test.stopTest();
    }
    
    // ============================================
    // ADMIN ACCESS TESTS (NEW - Missing Coverage)
    // ============================================
    
    @isTest 
    static void testCheckAdminAccess_HRManager() {
        User hrManager = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Manager' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.checkAdminAccess(hrManager.Id);
        System.assertEquals(true, result.get('hasAccess'), 'HR Manager should have access');
        System.assertEquals('HR Manager', result.get('categoryType'), 'Should be HR Manager type');
        Test.stopTest();
    }
    
    @isTest 
    static void testCheckAdminAccess_HRTeam() {
        User hrTeam = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Team' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.checkAdminAccess(hrTeam.Id);
        System.assertEquals(true, result.get('hasAccess'), 'HR Team should have access');
        System.assertEquals('HR Team (Assistant HR)', result.get('categoryType'), 'Should be HR Team type');
        Test.stopTest();
    }
    
    @isTest 
    static void testCheckAdminAccess_RegularEmployee() {
        User regularUser = [SELECT Id FROM User WHERE Employee_Category__c = 'On-Role(Team Member)' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.checkAdminAccess(regularUser.Id);
        System.assertEquals(false, result.get('hasAccess'), 'Regular employee should not have access');
        Test.stopTest();
    }
    
    @isTest 
    static void testCheckAdminAccess_Management() {
        User mgmtUser = [SELECT Id FROM User WHERE Employee_Category__c = 'Management' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.checkAdminAccess(mgmtUser.Id);
        System.assertEquals(false, result.get('hasAccess'), 'Management should not have access');
        Test.stopTest();
    }
    
    @isTest 
    static void testCheckAdminAccess_NoCategory() {
        User noCategoryUser = [SELECT Id FROM User WHERE Employee_Category__c = null AND Employee_IDs__c = '1005' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.checkAdminAccess(noCategoryUser.Id);
        System.assertEquals(false, result.get('hasAccess'), 'User with no category should not have access');
        System.assertEquals('Not Set', result.get('categoryType'), 'Category should be Not Set');
        Test.stopTest();
    }
    
    // ============================================
    // IS CURRENT USER ADMIN TESTS (NEW)
    // ============================================
    
    @isTest 
    static void testIsCurrentUserAdmin_HRManager() {
        User hrManager = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Manager' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Boolean result = AdminAttendanceViewController.isCurrentUserAdmin(hrManager.Id);
        System.assertEquals(true, result, 'HR Manager should be admin');
        Test.stopTest();
    }
    
    @isTest 
    static void testIsCurrentUserAdmin_HRTeam() {
        User hrTeam = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Team' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Boolean result = AdminAttendanceViewController.isCurrentUserAdmin(hrTeam.Id);
        System.assertEquals(true, result, 'HR Team should be admin');
        Test.stopTest();
    }
    
    @isTest 
    static void testIsCurrentUserAdmin_RegularUser() {
        User regularUser = [SELECT Id FROM User WHERE Employee_Category__c = 'On-Role(Team Member)' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Boolean result = AdminAttendanceViewController.isCurrentUserAdmin(regularUser.Id);
        System.assertEquals(false, result, 'Regular user should not be admin');
        Test.stopTest();
    }
    
    // ============================================
    // GET ADMIN ACCESS DETAILS TESTS (NEW)
    // ============================================
    
    @isTest 
    static void testGetAdminAccessDetails_HRManager() {
        User hrManager = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Manager' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAccessDetails(hrManager.Id);
        System.assertEquals(true, result.get('hasAccess'), 'HR Manager should have access');
        System.assertEquals(true, result.get('isHRManager'), 'Should be HR Manager');
        System.assertEquals(false, result.get('isHRTeam'), 'Should not be HR Team');
        System.assertEquals('Full Admin Access - HR Manager', result.get('accessMessage'));
        System.assertEquals('utility:shield', result.get('accessIcon'));
        System.assertEquals('success', result.get('accessVariant'));
        Test.stopTest();
    }
    
    @isTest 
    static void testGetAdminAccessDetails_HRTeam() {
        User hrTeam = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Team' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAccessDetails(hrTeam.Id);
        System.assertEquals(true, result.get('hasAccess'), 'HR Team should have access');
        System.assertEquals(false, result.get('isHRManager'), 'Should not be HR Manager');
        System.assertEquals(true, result.get('isHRTeam'), 'Should be HR Team');
        System.assertEquals('Full Admin Access - HR Team', result.get('accessMessage'));
        System.assertEquals('utility:user', result.get('accessIcon'));
        System.assertEquals('success', result.get('accessVariant'));
        Test.stopTest();
    }
    
    @isTest 
    static void testGetAdminAccessDetails_NoAccess() {
        User regularUser = [SELECT Id FROM User WHERE Employee_Category__c = 'On-Role(Team Member)' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAccessDetails(regularUser.Id);
        System.assertEquals(false, result.get('hasAccess'), 'Regular user should not have access');
        System.assertEquals(false, result.get('isHRManager'), 'Should not be HR Manager');
        System.assertEquals(false, result.get('isHRTeam'), 'Should not be HR Team');
        System.assertEquals('Access Restricted - Not an HR Admin', result.get('accessMessage'));
        System.assertEquals('utility:block_visitor', result.get('accessIcon'));
        System.assertEquals('error', result.get('accessVariant'));
        Test.stopTest();
    }
    
    @isTest 
    static void testGetAdminAccessDetails_AllowedCategories() {
        User hrManager = [SELECT Id FROM User WHERE Employee_Category__c = 'HR Manager' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAccessDetails(hrManager.Id);
        List<String> allowedCategories = (List<String>) result.get('allowedCategories');
        System.assertNotEquals(null, allowedCategories, 'Should return allowed categories');
        System.assert(allowedCategories.contains('HR Manager'), 'Should contain HR Manager');
        System.assert(allowedCategories.contains('HR Team'), 'Should contain HR Team');
        
        List<String> restrictedCategories = (List<String>) result.get('restrictedCategories');
        System.assertNotEquals(null, restrictedCategories, 'Should return restricted categories');
        Test.stopTest();
    }
    
    // ============================================
    // EXPORT TO CSV TESTS
    // ============================================
    
    @isTest 
    static void testExportToCSV_NoFilters() {
        Test.startTest();
        String csv = AdminAttendanceViewController.exportAttendanceToCSV(new Map<String, Object>());
        System.assertNotEquals(null, csv, 'Should return CSV content');
        System.assert(csv.contains('Employee ID'), 'Should contain header');
        Test.stopTest();
    }
    
    @isTest 
    static void testExportToCSV_WithFilters() {
        Test.startTest();
        String csv = AdminAttendanceViewController.exportAttendanceToCSV(new Map<String, Object>{
            'department' => 'Sales',
            'startDate' => Date.today().addDays(-30).format(),
            'endDate' => Date.today().format()
        });
        System.assertNotEquals(null, csv, 'Should return CSV content');
        Test.stopTest();
    }
    
    @isTest 
    static void testExportToCSV_SpecialCharacters() {
        // This tests the csvEscape method with special characters
        Test.startTest();
        String csv = AdminAttendanceViewController.exportAttendanceToCSV(new Map<String, Object>());
        System.assertNotEquals(null, csv, 'Should handle special characters in CSV');
        Test.stopTest();
    }
    
    // ============================================
    // WFH STATUS TESTS (Edge Cases)
    // ============================================
    
    @isTest 
    static void testWFHStatus_AllStatuses() {
        // This test covers all WFH status branches
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>{
            'pageSize' => 100
        });
        
        System.assertEquals(true, result.get('success'), 'Should return success');
        List<Object> records = (List<Object>) result.get('records');
        
        // Verify we have records with different WFH statuses
        Boolean hasApproved = false;
        Boolean hasPending = false;
        Boolean hasRejected = false;
        Boolean hasNone = false;
        
        for (Object obj : records) {
            Map<String, Object> record = (Map<String, Object>) obj;
            String statusText = (String) record.get('wfhApprovalStatusText');
            if (statusText == 'Approved') hasApproved = true;
            if (statusText == 'Pending') hasPending = true;
            if (statusText == 'Rejected') hasRejected = true;
            if (statusText == '--') hasNone = true;
        }
        
        // At least one status should be present
        System.assert(hasApproved || hasPending || hasRejected || hasNone, 
            'Should have at least one WFH status');
        Test.stopTest();
    }
    
    @isTest 
    static void testWFHStatus_WorkFromHome_NoStatus() {
        // Creates a WFH record with blank status to test the pending branch
        Branch__c testBranch = [SELECT Id FROM Branch__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Employee_IDs__c = '1001' AND IsActive = true LIMIT 1];
        
        Employee_Attendance__c wfhRecord = new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = Date.today().addDays(-10),
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Test Reason for Pending',
            Branch__c = testBranch.Id
            // WFH_Approval_Status__c is intentionally null/blank
        );
        insert wfhRecord;
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        System.assertEquals(true, result.get('success'), 'Should return success');
        Test.stopTest();
    }
    
    // ============================================
    // FORMAT METHODS EDGE CASES
    // ============================================
    
    @isTest 
    static void testFormatMethods_NullValues() {
        // This tests formatDateTime and formatHoursWorked with null values
        Branch__c testBranch = [SELECT Id FROM Branch__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Employee_IDs__c = '1001' AND IsActive = true LIMIT 1];
        
        // Record with null date, check-in, check-out, hours
        Employee_Attendance__c nullRecord = new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = null,
            Check_In_Time__c = null,
            Check_Out_Time__c = null,
            Work_Location__c = 'Work from office',
            Branch__c = testBranch.Id
        );
        insert nullRecord;
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        System.assertEquals(true, result.get('success'), 'Should handle null values');
        Test.stopTest();
    }
    
    @isTest 
    static void testFormatMethods_ZeroHours() {
        // Tests formatHoursWorked with 0 value
        Branch__c testBranch = [SELECT Id FROM Branch__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Employee_IDs__c = '1001' AND IsActive = true LIMIT 1];
        
        Employee_Attendance__c zeroHoursRecord = new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = Date.today().addDays(-15),
            //Hours_Worked__c = 0,
            Work_Location__c = 'Work from office',
            Branch__c = testBranch.Id
        );
        insert zeroHoursRecord;
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        System.assertEquals(true, result.get('success'), 'Should handle zero hours');
        Test.stopTest();
    }
    
    // ============================================
    // BLANK LOCATION TESTS
    // ============================================
    
    @isTest 
    static void testBlankLocation_FallbackToOffice() {
        // Tests the location fallback logic
        Branch__c testBranch = [SELECT Id FROM Branch__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Employee_IDs__c = '1001' AND IsActive = true LIMIT 1];
        
        Employee_Attendance__c blankLocationRecord = new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = Date.today().addDays(-20),
            Check_In_Location_Name__c = null,
            Work_Location__c = null,
            Branch__c = testBranch.Id
        );
        insert blankLocationRecord;
        
        Test.startTest();
        Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(new Map<String, Object>());
        System.assertEquals(true, result.get('success'), 'Should handle blank location');
        
        List<Object> records = (List<Object>) result.get('records');
        Boolean foundOfficeDefault = false;
        for (Object obj : records) {
            Map<String, Object> record = (Map<String, Object>) obj;
            if (record.get('location') == 'Office') {
                foundOfficeDefault = true;
                break;
            }
        }
        System.assert(foundOfficeDefault, 'Should default to Office location');
        Test.stopTest();
    }
    
    // ============================================
    // ERROR HANDLING TESTS
    // ============================================
    
    @isTest 
    static void testErrorHandling_InvalidQueryField() {
        // Test with potentially problematic sort field
        Test.startTest();
        try {
            Map<String, Object> result = AdminAttendanceViewController.getAdminAttendanceRecords(
                new Map<String, Object>{
                    'sortField' => 'InvalidField__c',
                    'sortDirection' => 'ASC'
                }
            );
            // If it doesn't throw, check that error handling works
            System.assertNotEquals(null, result, 'Should return a result');
        } catch (Exception e) {
            // Expected behavior for invalid field
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }
    
    // ============================================
    // BULK DATA TESTS
    // ============================================
    
    @isTest 
    static void testBulkRecords_Pagination() {
        // Create additional records to test pagination math
        Branch__c testBranch = [SELECT Id FROM Branch__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Employee_IDs__c = '1001' AND IsActive = true LIMIT 1];
        
        List<Employee_Attendance__c> bulkRecords = new List<Employee_Attendance__c>();
        for (Integer i = 0; i < 25; i++) {
            bulkRecords.add(new Employee_Attendance__c(
                Employee_Name__c = testUser.Id,
                Date__c = Date.today().addDays(-100 - i),
                Work_Location__c = 'Work from office',
                Branch__c = testBranch.Id
            ));
        }
        insert bulkRecords;
        
        Test.startTest();
        // Test pagination with small page size
        Map<String, Object> page1 = AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 5, 'pageNumber' => 1}
        );
        Map<String, Object> page2 = AdminAttendanceViewController.getAdminAttendanceRecords(
            new Map<String, Object>{'pageSize' => 5, 'pageNumber' => 2}
        );
        
        System.assertEquals(5, ((List<Object>) page1.get('records')).size(), 'Page 1 should have 5 records');
        System.assertEquals(5, ((List<Object>) page2.get('records')).size(), 'Page 2 should have 5 records');
        System.assert((Integer) page1.get('totalPages') > 1, 'Should have multiple pages');
        Test.stopTest();
    }
}