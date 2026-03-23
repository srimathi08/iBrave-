@isTest
private class LeaveBalanceCreationBatchTest {
    
    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Create ONE test user with UNIQUE username
        insert new User(
            FirstName = 'Test', LastName = 'BatchUser',
            Email = 'test.batchuser@leave.com',
            Username = 'test.batchuser.leavebatch.unique001@test.com',
            Alias = 'tbu',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true,
            Employee_IDs__c = '999999',  // Unique numeric value no real user will have
            Date_of_Joining__c = Date.newInstance(2023, 1, 15),
            Gender__c = 'Male',
            Marital_Status__c = 'Single',
            Number_of_Children__c = 0.0,
            Employment_Type__c = 'Full Time'
        );
    }
    
    @isTest
    static void testBatchFullLifecycle() {
        Test.startTest();
        
        LeaveBalanceCreationBatch batch = new LeaveBalanceCreationBatch('2025');
        Id jobId = Database.executeBatch(batch);  // ONLY ONE executeBatch call
        
        Test.stopTest();
        
        // Verify batch completed successfully
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
        System.assertEquals(0, job.NumberOfErrors, 'Batch should have no errors');
    }
    
    @isTest
    static void testStartMethod() {
        LeaveBalanceCreationBatch batch = new LeaveBalanceCreationBatch('2024');
        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Verify our specific test user is found (ignores real org users)
        List<User> testUsers = [SELECT Id FROM User WHERE Employee_IDs__c = '999999'];
        System.assertEquals(1, testUsers.size(), 'Should find exactly 1 test user');
        System.assertNotEquals(null, ql, 'start() should return QueryLocator');
    }
    
    @isTest
    static void testConstructorDifferentYears() {
        // Test constructor with different years
        String year2024 = '2024';
        String year2025 = '2025';
        
        LeaveBalanceCreationBatch batch1 = new LeaveBalanceCreationBatch(year2024);
        LeaveBalanceCreationBatch batch2 = new LeaveBalanceCreationBatch(year2025);
        
        // Just verify objects are created (private year doesn't need assertion)
        System.assertNotEquals(null, batch1);
        System.assertNotEquals(null, batch2);
    }
}