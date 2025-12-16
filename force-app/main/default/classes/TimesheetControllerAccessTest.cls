@isTest
private class TimesheetControllerAccessTest {

    @isTest
    static void testCommunityUserAccess() {
        
        // ===========================================
        // 1. SETUP: Create all required test data 
        // ===========================================
        
        // 1a. Find the Community Profile
        // Note: You can query standard setup data like Profiles in tests.
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        
        // 1b. Create the Community User to run the test as
        User testCommunityUser = new User(
            ProfileId = communityProfile.Id,
            LastName = 'TestCommunity',
            Email = 'testcommunity' + DateTime.now().getTime() + '@testorg.com',
            Username = 'testcommunity' + DateTime.now().getTime() + '@testorg.com',
            Alias = 'tccu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testCommunityUser; // Insert the user record

        // 1c. Create Project and Assignment (Data for getProjects())
        Project__c activeProject = new Project__c(Name = 'Project Alpha', Status__c = 'Active');
        insert activeProject;

        Project_Assignment__c pa = new Project_Assignment__c(
            Employee__c = testCommunityUser.Id,
            Project__c = activeProject.Id,
            Employment_Status__c = 'Hourly' // Ensure this value is valid
        );
        insert pa;
        
        // ===========================================
        // 2. EXECUTION: Run the Apex methods as the Community User
        // ===========================================
        
        // Start the test context (required for runAs() and code coverage)
        Test.startTest();
        
        // Use System.runAs() to execute the controller methods with the Community User's permissions
        System.runAs(testCommunityUser) {
            
            // A. Test getProjects()
            List<Map<String, String>> projectResults = TimesheetController.getProjects();
            System.debug('Projects returned: ' + projectResults);
            
            // B. Test getStatusPicklistValues()
            List<String> statusResults = TimesheetController.getStatusPicklistValues();
            System.debug('Status Picklist Values returned: ' + statusResults);
            
            // C. Assertions (verify expected results)
            System.assertEquals(1, projectResults.size(), 'The user should see one assigned project.');
            System.assert(statusResults.size() > 0, 'The user should see picklist values for Status__c.');
        }
        
        // End the test context
        Test.stopTest();
    }
}