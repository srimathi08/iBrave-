@isTest
private class WFHApprovalActionTest {
    
    // Utility method to create Employee Attendance record
    private static Employee_Attendance__c createAttendance(User emp, Branch__c branch) {
        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c = emp.Id,
            Work_Location__c = 'Work from office',
            WFH_Reason__c = 'Medical',
            WFH_Approval_Status__c = 'Pending',
            Date__c = Date.today(),
            Branch__c = branch.Id
        );
        insert att;
        return att;
    }
    
    @testSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // ✅ Branch__c (Name auto-number, Branch_Name__c REQUIRED)
        Branch__c branch = new Branch__c(
            Branch_Name__c = 'Test Branch'
        );
        insert branch;

        // Create employee user
        User emp = new User(
            Alias = 'emp1',
            Email = 'emp1@test.com',
            Username = 'emp1' + System.currentTimeMillis() + '@test.com',
            LastName = 'Employee',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert emp;

        // Create manager user
        User mgr = new User(
            Alias = 'mgr1',
            Email = 'mgr1@test.com',
            Username = 'mgr1' + System.currentTimeMillis() + '@test.com',
            LastName = 'Manager',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert mgr;

        // Create attendance
        createAttendance(emp, branch);
    }
    
    @isTest
    static void testConstructorAndLoadData() {
        Employee_Attendance__c att = [SELECT Id FROM Employee_Attendance__c LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.startTest();
        Test.setCurrentPage(Page.WFHApprovalPage);
        ApexPages.currentPage().getParameters().put('id', att.Id);
        ApexPages.currentPage().getParameters().put('manager', mgr.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');
        
        WFHApprovalAction controller = new WFHApprovalAction();
        
        System.assertNotEquals(null, controller.attendance);
        System.assertNotEquals(null, controller.currentManager);
        System.assert(controller.showForm);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessApprovalApprove() {
        Employee_Attendance__c att = [SELECT Id FROM Employee_Attendance__c LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.startTest();
        Test.setCurrentPage(Page.WFHApprovalPage);
        ApexPages.currentPage().getParameters().put('id', att.Id);
        ApexPages.currentPage().getParameters().put('manager', mgr.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');
        
        WFHApprovalAction controller = new WFHApprovalAction();
        controller.comments = 'Looks good';
        controller.processApproval();
        
        att = [
            SELECT WFH_Approval_Status__c, Approval_Comments__c
            FROM Employee_Attendance__c
            WHERE Id = :att.Id
        ];
        
        System.assertEquals('Approved', att.WFH_Approval_Status__c);
        System.assertEquals('Looks good', att.Approval_Comments__c);
        System.assertEquals('success', controller.resultType);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessApprovalReject() {
        Employee_Attendance__c att = [SELECT Id FROM Employee_Attendance__c LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.startTest();
        Test.setCurrentPage(Page.WFHApprovalPage);
        ApexPages.currentPage().getParameters().put('id', att.Id);
        ApexPages.currentPage().getParameters().put('manager', mgr.Id);
        ApexPages.currentPage().getParameters().put('action', 'reject');
        
        WFHApprovalAction controller = new WFHApprovalAction();
        controller.comments = 'Not valid reason';
        controller.processApproval();
        
        att = [
            SELECT WFH_Approval_Status__c, Approval_Comments__c
            FROM Employee_Attendance__c
            WHERE Id = :att.Id
        ];
        
        System.assertEquals('Rejected', att.WFH_Approval_Status__c);
        System.assertEquals('Not valid reason', att.Approval_Comments__c);
        System.assertEquals('error', controller.resultType);
        Test.stopTest();
    }
    
    @isTest
    static void testInvalidAction() {
        Employee_Attendance__c att = [SELECT Id FROM Employee_Attendance__c LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.startTest();
        Test.setCurrentPage(Page.WFHApprovalPage);
        ApexPages.currentPage().getParameters().put('id', att.Id);
        ApexPages.currentPage().getParameters().put('manager', mgr.Id);
        ApexPages.currentPage().getParameters().put('action', 'invalid');
        
        WFHApprovalAction controller = new WFHApprovalAction();
        controller.processApproval();
        
        System.assertEquals('error', controller.resultType);
        System.assert(controller.resultMessage.contains('Invalid action'));
        Test.stopTest();
    }
    
    @isTest
    static void testHelperMethods() {
        Employee_Attendance__c att = [SELECT Id FROM Employee_Attendance__c LIMIT 1];
        User mgr = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
        
        Test.setCurrentPage(Page.WFHApprovalPage);
        ApexPages.currentPage().getParameters().put('id', att.Id);
        ApexPages.currentPage().getParameters().put('manager', mgr.Id);
        ApexPages.currentPage().getParameters().put('action', 'approve');
        
        WFHApprovalAction controller = new WFHApprovalAction();
        
        controller.resultType = 'success';
        System.assertEquals('Approve', controller.getActionText());
        System.assertEquals('success', controller.getStatusClass());
        
        controller.resultType = 'error';
        System.assertEquals('error', controller.getStatusClass());
        
        controller.resultType = 'other';
        System.assertEquals('info', controller.getStatusClass());
    }
}