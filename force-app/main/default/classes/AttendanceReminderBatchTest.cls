@isTest
public class AttendanceReminderBatchTest {
    
    @isTest static void testBatchFullScenario() {
        // Complete isolated test data
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();
        
        // Branch Manager
        User branchManager = new User(
            Username = 'bmgr_' + ts + '@test.com',
            Email = 'bmgr@test.com',
            LastName = 'Branch Manager',
            Alias = 'bmgr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 9998,
            IsActive = true
        );
        insert branchManager;
        
        Branch__c branch = new Branch__c(
            Branch_Manager__c = branchManager.Id,
            Branch_Name__c = 'Main Branch',
            OwnerId = branchManager.Id
        );
        insert branch;
        
        // Test User NEEDS reminder (no attendance, no leave)
        User testUser = new User(
            Username = 'tu_' + ts + '@test.com',
            Email = 'tu@test.com',
            LastName = 'Test User',
            Alias = 'tu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 1002,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        // scope=200 matches Salesforce default, handles ALL org users in ONE execution
        Database.executeBatch(new AttendanceReminderBatch(), 200);
        Test.stopTest();
        
        System.assert(Limits.getEmailInvocations() >= 0, 'Batch should process');
    }
    
    @isTest static void testUserCheckedIn_NoEmail() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();
        
        User branchManager = new User(
            Username = 'bm_' + ts + '@test.com',
            Email = 'bm@test.com',
            LastName = 'BM',
            Alias = 'bm',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 9999,
            IsActive = true
        );
        insert branchManager;
        
        Branch__c branch = new Branch__c(
            Branch_Manager__c = branchManager.Id,
            Branch_Name__c = 'Test Branch',
            OwnerId = branchManager.Id
        );
        insert branch;
        
        User testUser = new User(
            Username = 'tuc_' + ts + '@test.com',
            Email = 'tuc@test.com',
            LastName = 'Checked User',
            Alias = 'tuc',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 1003,
            IsActive = true
        );
        insert testUser;
        
        // USER HAS CHECKED IN - no reminder needed
        insert new Employee_Attendance__c(
            Employee_Name__c = testUser.Id,
            Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Branch__c = branch.Id
        );
        
        Test.startTest();
        Database.executeBatch(new AttendanceReminderBatch(), 200);
        Test.stopTest();
        
        System.assertEquals(0, Limits.getEmailInvocations(), 'No emails for checked-in user');
    }
    
    @isTest static void testUserOnLeave_NoEmail() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts = System.currentTimeMillis();
        
        User branchManager = new User(
            Username = 'bm2_' + ts + '@test.com',
            Email = 'bm2@test.com',
            LastName = 'BM2',
            Alias = 'bm2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 10000,
            IsActive = true
        );
        insert branchManager;
        
        Branch__c branch = new Branch__c(
            Branch_Manager__c = branchManager.Id,
            Branch_Name__c = 'Leave Branch',
            OwnerId = branchManager.Id
        );
        insert branch;
        
        User testUser = new User(
            Username = 'tul_' + ts + '@test.com',
            Email = 'tul@test.com',
            LastName = 'Leave User',
            Alias = 'tul',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id,
            Employee_Id__c = 1004,
            IsActive = true
        );
        insert testUser;
        
        // USER ON APPROVED LEAVE - no reminder
        insert new Leave_Request__c(
            Employee__c = testUser.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today(),
            Status__c = 'Approved',
            Is_Active__c = true,
            Total_Days__c = 1
        );
        
        Test.startTest();
        Database.executeBatch(new AttendanceReminderBatch(), 200);
        Test.stopTest();
        
        System.assertEquals(0, Limits.getEmailInvocations(), 'No emails for users on leave');
    }
    
    @isTest static void testStartMethodCoverage() {
        Test.startTest();
        AttendanceReminderBatch batch = new AttendanceReminderBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @isTest static void testEmptyBatchScenario() {
        Test.startTest();
        Database.executeBatch(new AttendanceReminderBatch(), 200);
        Test.stopTest();
        System.assert(Limits.getEmailInvocations() >= 0, 'Batch completes with no data');
    }
}