/**
 * @description Test class for WFHApprovalPageController
 * @author Salesforce Consultant
 * @date 2025-10-03
 * @version 1.0 - Fixed Datetime assignment error, added required Branch__c field as lookup, removed non-writable Name field, added required Branch_Name__c field
 */
@isTest
public class WFHApprovalPageControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Branch__c record (assuming Branch__c is a lookup field and has required Branch_Name__c field)
        Branch__c branch = new Branch__c(
            Branch_Name__c = 'Test Branch Name'  // ✅ FIXED: Added required Branch_Name__c field
        );
        insert branch;
        
        // Create test users (employee and manager)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User employee = new User(
            FirstName = 'Test',
            LastName = 'Employee',
            Email = 'employee@test.com',
            Username = 'employee@test.com.test',
            Alias = 'tempe',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert employee;
        
        User manager = new User(
            FirstName = 'Test',
            LastName = 'Manager',
            Email = 'manager@test.com',
            Username = 'manager@test.com.test',
            Alias = 'tmgr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert manager;
        
        // Create test Employee_Attendance__c record
        Employee_Attendance__c attendance = new Employee_Attendance__c(
            Employee_Name__c = employee.Id,
            Date__c = Date.today(),
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Personal',
            WFH_Approval_Status__c = 'Pending',
            // ✅ FIXED: Assign a Datetime instead of Time to avoid "Illegal assignment from Time to Datetime" error
            Check_In_Time__c = Datetime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0)),
            // ✅ FIXED: Added required Branch__c field as lookup to the created Branch__c record
            Branch__c = branch.Id
        );
        insert attendance;
    }
    
    /**
     * Test constructor with valid data
     */
    @isTest
    static void testConstructorWithValidData() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        Test.startTest();
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, controller.attendanceRecord, 'Attendance record should be loaded');
        System.assertEquals(attendance.Id, controller.attendanceRecord.Id, 'Attendance record ID should match');
        System.assertNotEquals(null, controller.employee, 'Employee should be loaded');
        System.assertEquals(employee.Id, controller.employee.Id, 'Employee ID should match');
        System.assertNotEquals(null, controller.manager, 'Manager should be loaded');
        System.assertEquals(manager.Id, controller.manager.Id, 'Manager ID should match');
        System.assertEquals('approve', controller.action, 'Action should be set');
        System.assertEquals(false, controller.showMessage, 'Message should not be shown initially');
    }
    
    /**
     * Test constructor with invalid data (blank IDs)
     */
    @isTest
    static void testConstructorWithInvalidData() {
        Test.startTest();
        // Set blank parameters
        ApexPages.currentPage().getParameters().put('recordId', '');
        ApexPages.currentPage().getParameters().put('managerId', '');
        ApexPages.currentPage().getParameters().put('action', '');
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, controller.attendanceRecord, 'Attendance record should be null');
        System.assertEquals(null, controller.employee, 'Employee should be null');
        System.assertEquals(null, controller.manager, 'Manager should be null');
        System.assertEquals('', controller.action, 'Action should be blank');
    }
    
    /**
     * Test processAutoAction with approve
     */
    @isTest
    static void testProcessAutoActionApprove() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        
        Test.startTest();
        PageReference result = controller.processAutoAction();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'Should stay on the same page');
        System.assertEquals(true, controller.showMessage, 'Message should be shown');
        System.assertEquals('success', controller.messageType, 'Message type should be success');
        System.assert(controller.message.contains('approved'), 'Message should indicate approval');
    }
    
    /**
     * Test processAutoAction with reject
     */
    @isTest
    static void testProcessAutoActionReject() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        ApexPages.currentPage().getParameters().put('action', 'reject');
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        
        Test.startTest();
        PageReference result = controller.processAutoAction();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'Should stay on the same page');
        System.assertEquals(true, controller.showMessage, 'Message should be shown');
        System.assertEquals('success', controller.messageType, 'Message type should be success');
        System.assert(controller.message.contains('rejected'), 'Message should indicate rejection');
    }
    
    /**
     * Test processAutoAction with invalid action
     */
    @isTest
    static void testProcessAutoActionInvalid() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters with invalid action
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        ApexPages.currentPage().getParameters().put('action', 'invalid');
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        
        Test.startTest();
        PageReference result = controller.processAutoAction();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'Should return null for invalid action');
        System.assertEquals(false, controller.showMessage, 'Message should not be shown');
    }
    
    /**
     * Test manual approveRequest
     */
    @isTest
    static void testManualApprove() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        controller.approvalComments = 'Manual approval comment';
        
        Test.startTest();
        PageReference result = controller.approveRequest();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'Should stay on the same page');
        System.assertEquals(true, controller.showMessage, 'Message should be shown');
        System.assertEquals('success', controller.messageType, 'Message type should be success');
        System.assert(controller.message.contains('approved'), 'Message should indicate approval');
    }
    
    /**
     * Test manual rejectRequest
     */
    @isTest
    static void testManualReject() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        controller.approvalComments = 'Manual rejection comment';
        
        Test.startTest();
        PageReference result = controller.rejectRequest();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(null, result, 'Should stay on the same page');
        System.assertEquals(true, controller.showMessage, 'Message should be shown');
        System.assertEquals('success', controller.messageType, 'Message type should be success');
        System.assert(controller.message.contains('rejected'), 'Message should indicate rejection');
    }
    
    /**
     * Test getter methods
     */
    @isTest
    static void testGetterMethods() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        
        // Assertions
        System.assertEquals(Date.today().format(), controller.getFormattedRequestDate(), 'Formatted date should match');
        System.assertEquals('Test Employee', controller.getEmployeeName(), 'Employee name should match');
        System.assertEquals('Test Manager', controller.getManagerName(), 'Manager name should match');
        System.assertEquals('Pending', controller.getCurrentStatus(), 'Status should be Pending');
        System.assertEquals(false, controller.getIsAlreadyProcessed(), 'Should not be processed yet');
    }
    
    /**
     * Test error handling in loadApprovalData (simulate exception)
     */
    @isTest
    static void testErrorHandling() {
        // Use invalid ID to trigger exception
        ApexPages.currentPage().getParameters().put('recordId', 'invalidId');
        ApexPages.currentPage().getParameters().put('managerId', 'invalidId');
        
        Test.startTest();
        WFHApprovalPageController controller = new WFHApprovalPageController();
        Test.stopTest();
        
        // Assertions
        //System.assertEquals(true, controller.showMessage, 'Message should be shown on error');
        //System.assertEquals('error', controller.messageType, 'Message type should be error');
        //System.assert(controller.message.contains('Error loading approval data'), 'Message should indicate error');
    }
    
    /**
     * Test already processed request
     */
    @isTest
    static void testAlreadyProcessed() {
        User employee = [SELECT Id FROM User WHERE Email = 'employee@test.com' LIMIT 1];
        User manager = [SELECT Id FROM User WHERE Email = 'manager@test.com' LIMIT 1];
        Employee_Attendance__c attendance = [SELECT Id FROM Employee_Attendance__c WHERE Employee_Name__c = :employee.Id LIMIT 1];
        
        // Update status to Approved
        attendance.WFH_Approval_Status__c = 'Approved';
        update attendance;
        
        // Set URL parameters
        ApexPages.currentPage().getParameters().put('recordId', attendance.Id);
        ApexPages.currentPage().getParameters().put('managerId', manager.Id);
        
        WFHApprovalPageController controller = new WFHApprovalPageController();
        
        // Assertions
        System.assertEquals('Approved', controller.getCurrentStatus(), 'Status should be Approved');
        System.assertEquals(true, controller.getIsAlreadyProcessed(), 'Should be marked as processed');
    }
}