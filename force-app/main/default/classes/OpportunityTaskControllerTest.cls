@isTest
private class OpportunityTaskControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        );
        insert testOpp;
    }
    
    @isTest
    static void testCloseRelatedTasks_NoTasks() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Integer result = OpportunityTaskController.closeRelatedTasks(testOpp.Id);
        Test.stopTest();
        
        System.assertEquals(0, result, 'Should return 0 when no tasks exist');
    }
    
    @isTest
    static void testCloseRelatedTasks_ExistingOpenTasks() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Create open tasks - include Subject to avoid SOQL error
        List<Task> testTasks = new List<Task>();
        for(Integer i = 0; i < 3; i++) {
            testTasks.add(new Task(
                Subject = 'Test Task ' + i,  // ✅ Required standard field
                WhatId = testOpp.Id,
                Status = 'In Progress'
            ));
        }
        insert testTasks;
        
        Test.startTest();
        Integer result = OpportunityTaskController.closeRelatedTasks(testOpp.Id);
        Test.stopTest();
        
        // Query with ALL required fields to avoid SOQL errors
        List<Task> updatedTasks = [SELECT Id, Status, IsClosed, Subject 
                                 FROM Task 
                                 WHERE WhatId = :testOpp.Id];
        
        System.assertEquals(3, result, 'Should return count of updated tasks');
        System.assertEquals(3, updatedTasks.size(), 'All tasks should be updated');
        for(Task t : updatedTasks) {
            System.assertEquals('Completed', t.Status, 'Task status should be Completed');
            System.assert(t.IsClosed, 'Task should be marked as closed');
        }
    }
    
    @isTest
    static void testCloseRelatedTasks_ClosedTasksSkipped() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Create mix of open and closed tasks - include Subject
        List<Task> testTasks = new List<Task>();
        testTasks.add(new Task(
            Subject = 'Open Task',        // ✅ Required
            WhatId = testOpp.Id,
            Status = 'Not Started'
        ));
        testTasks.add(new Task(
            Subject = 'Closed Task',      // ✅ Required
            WhatId = testOpp.Id,
            Status = 'Completed'
        ));
        insert testTasks;
        
        Test.startTest();
        Integer result = OpportunityTaskController.closeRelatedTasks(testOpp.Id);
        Test.stopTest();
        
        List<Task> updatedTasks = [SELECT Id, Status, Subject 
                                 FROM Task 
                                 WHERE WhatId = :testOpp.Id];
        
        System.assertEquals(1, result, 'Should only update open tasks');
        Boolean openTaskUpdated = false;
        
        for(Task t : updatedTasks) {
            if(t.Subject == 'Open Task') {
                System.assertEquals('Completed', t.Status, 'Open task should be completed');
                openTaskUpdated = true;
            }
        }
        
        System.assert(openTaskUpdated, 'Open task should have been updated');
    }
    
    @isTest
    static void testUpdateTasksOnClosedLost_NoTasks() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String testLossReason = 'Customer chose competitor';
        
        Test.startTest();
        Integer result = OpportunityTaskController.updateTasksOnClosedLost(testOpp.Id, testLossReason);
        Test.stopTest();
        
        System.assertEquals(0, result, 'Should return 0 when no open tasks exist');
    }
    
    @isTest
    static void testUpdateTasksOnClosedLost_OpenTasksUpdated() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String testLossReason = 'Budget constraints';
        
        // Create open tasks with Subject field
        List<Task> testTasks = new List<Task>();
        for(Integer i = 0; i < 5; i++) {
            testTasks.add(new Task(
                Subject = 'Pending Task ' + i,  // ✅ Required
                WhatId = testOpp.Id,
                Status = 'In Progress'
            ));
        }
        insert testTasks;
        
        Test.startTest();
        Integer result = OpportunityTaskController.updateTasksOnClosedLost(testOpp.Id, testLossReason);
        Test.stopTest();
        
        // Query ALL fields used in test - including Subject
        List<Task> updatedTasks = [SELECT Id, Status, Remarks__c, IsClosed, Subject 
                                 FROM Task 
                                 WHERE WhatId = :testOpp.Id];
        
        System.assertEquals(5, result, 'Should update all open tasks');
        for(Task t : updatedTasks) {
            System.assertEquals('In-Complete', t.Status, 'Status should be In-Complete');
            System.assertEquals(testLossReason, t.Remarks__c, 'Remarks should match loss reason');
        }
    }
    
    @isTest
    static void testUpdateTasksOnClosedLost_ClosedTasksSkipped() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String testLossReason = 'Timeline mismatch';
        
        // Mix of open/closed tasks with Subject
        List<Task> testTasks = new List<Task>();
        testTasks.add(new Task(
            Subject = 'Open Task',         // ✅ Required
            WhatId = testOpp.Id,
            Status = 'Not Started'
        ));
        testTasks.add(new Task(
            Subject = 'Closed Task',       // ✅ Required
            WhatId = testOpp.Id,
            Status = 'Completed'
        ));
        insert testTasks;
        
        Test.startTest();
        Integer result = OpportunityTaskController.updateTasksOnClosedLost(testOpp.Id, testLossReason);
        Test.stopTest();
        
        List<Task> updatedTasks = [SELECT Id, Status, Remarks__c, Subject 
                                 FROM Task 
                                 WHERE WhatId = :testOpp.Id];
        
        System.assertEquals(1, result, 'Should only update open tasks');
        
        for(Task t : updatedTasks) {
            if(t.Subject == 'Open Task') {
                System.assertEquals('In-Complete', t.Status);
                System.assertEquals(testLossReason, t.Remarks__c);
            } else if(t.Subject == 'Closed Task') {
                System.assertEquals('Completed', t.Status);
                System.assert(t.Remarks__c == null);
            }
        }
    }
}