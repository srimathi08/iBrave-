@isTest
private class LeaveApprovalController_Test {
    
    @TestSetup
    static void setup() {
        // Minimal safe setup - no complex data
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        insert new User(Alias='t1', Email='test1@test.com',
            EmailEncodingKey='UTF-8', LastName='Test1',
            LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            ProfileId=p.Id, TimeZoneSidKey='America/Los_Angeles',
            UserName='test1'+System.currentTimeMillis()+'@test.com');
            
        insert new User(Alias='t2', Email='test2@test.com',
            EmailEncodingKey='UTF-8', LastName='Test2',
            LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            ProfileId=p.Id, TimeZoneSidKey='America/Los_Angeles',
            UserName='test2'+System.currentTimeMillis()+'@test.com');
            
        insert new Leave_Type__c(Leave_Type_Name__c='Test Leave', Leave_Code__c='TEST');
    }
    
    private static Leave_Request__c makeRequest() {
        List<User> users = [SELECT Id FROM User LIMIT 2];
        Leave_Type__c lt = [SELECT Id FROM Leave_Type__c LIMIT 1];
        
        return new Leave_Request__c(
            Employee__c=users[0].Id,
            Leave_Type__c=lt.Id,
            Start_Date__c=Date.today(),
            End_Date__c=Date.today().addDays(1),
            Total_Days__c=2,
            Reason__c='Test',
            Status__c='Pending',
            Manager__c=users[1].Id
        );
    }
    
    @isTest static void testConstructorValidId() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        Test.startTest();
        new LeaveApprovalController();
        Test.stopTest();
    }
    
    @isTest static void testConstructorNoId() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        
        Test.startTest();
        new LeaveApprovalController();
        Test.stopTest();
    }
    
    @isTest static void testConstructorInvalidId() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        ApexPages.currentPage().getParameters().put('id', '001000000000000');
        
        Test.startTest();
        new LeaveApprovalController();
        Test.stopTest();
    }
    
    @isTest static void testApprove() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        LeaveApprovalController ctrl = new LeaveApprovalController();
        ctrl.managerComments = 'test approve';
        
        Test.startTest();
        ctrl.approveRequest();
        Test.stopTest();
    }
    
    @isTest static void testReject() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        LeaveApprovalController ctrl = new LeaveApprovalController();
        ctrl.managerComments = 'test reject';
        
        Test.startTest();
        ctrl.rejectRequest();
        Test.stopTest();
    }
    
    @isTest static void testCancel() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        LeaveApprovalController ctrl = new LeaveApprovalController();
        ctrl.managerComments = 'test cancel';
        
        Test.startTest();
        ctrl.cancelRequest();
        Test.stopTest();
    }
    
    @isTest static void testNoCommentsApprove() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        LeaveApprovalController ctrl = new LeaveApprovalController();
        
        Test.startTest();
        ctrl.approveRequest();
        Test.stopTest();
    }
    
    @isTest static void testNoCommentsReject() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        Leave_Request__c lr = makeRequest();
        insert lr;
        ApexPages.currentPage().getParameters().put('id', lr.Id);
        
        LeaveApprovalController ctrl = new LeaveApprovalController();
        
        Test.startTest();
        ctrl.rejectRequest();
        Test.stopTest();
    }
    
    @isTest static void testDoNothing() {
        Test.setCurrentPage(Page.LeaveApprovalPage);
        
        Test.startTest();
        new LeaveApprovalController().doNothing();
        Test.stopTest();
    }
}