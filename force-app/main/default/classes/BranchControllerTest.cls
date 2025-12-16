@isTest
public class BranchControllerTest {

    // ---------------------------------------------
    // Test Setup – Creates reusable test data
    // ---------------------------------------------
    @testSetup
    static void setupData() {

        // Create a test user to act as Branch Manager
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User managerUser = new User(
            FirstName = 'Manager',
            LastName = 'User',
            Email = 'manager@example.com',
            Username = 'manageruser@example.com',
            Alias = 'mgr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert managerUser;

        // Insert Active Branches
        List<Branch__c> branches = new List<Branch__c>{
            new Branch__c(
                Branch_Name__c = 'Main Branch',
                City__c = 'Chennai',
                State__c = 'TN',
                Country__c = 'India',
                Is_Active__c = true,
                Branch_Manager__c = managerUser.Id
            ),
            new Branch__c(
                Branch_Name__c = 'Second Branch',
                City__c = 'Bangalore',
                State__c = 'KA',
                Country__c = 'India',
                Is_Active__c = true
            ),
            new Branch__c(
                Branch_Name__c = 'Inactive Branch',
                City__c = 'Delhi',
                State__c = 'DL',
                Country__c = 'India',
                Is_Active__c = false
            )
                };
        insert branches;
    }

    // ---------------------------------------------
    // TEST: Get Active Branches
    // ---------------------------------------------
    @isTest
    static void testGetActiveBranches() {

        Test.startTest();
        List<Map<String, String>> result = BranchController.getActiveBranches();
        Test.stopTest();

        System.assert(result.size() == 2, 'Only 2 active branches should be returned');

        Map<String, String> sample = result[0];
        System.assert(sample.containsKey('label'), 'Label field missing');
        System.assert(sample.containsKey('value'), 'Value field missing');
    }

    // ---------------------------------------------
    // TEST: Get Branch Details Successfully
    // ---------------------------------------------
    @isTest
    static void testGetBranchDetails_Success() {

        Branch__c activeBranch = [
            SELECT Id FROM Branch__c WHERE Is_Active__c = true LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> details = BranchController.getBranchDetails(activeBranch.Id);
        Test.stopTest();

        //System.assertEquals(true, details.get('success'));
        System.assertEquals(activeBranch.Id, details.get('branchId'));
        System.assert(details.containsKey('branchName'), 'Branch Name missing');
    }

    // ---------------------------------------------
    // TEST: Get Branch Details - Invalid ID
    // ---------------------------------------------
    @isTest
    static void testGetBranchDetails_InvalidId() {

        try {
            Test.startTest();
            BranchController.getBranchDetails(null);
            Test.stopTest();
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            //System.assertEquals('Branch ID is required', e.getMessage());
        }
    }

    // ---------------------------------------------
    // TEST: Get Branch Details - Not Found
    // ---------------------------------------------
    @isTest
    static void testGetBranchDetails_NotFound() {

        try {
            Test.startTest();
            BranchController.getBranchDetails('a01XXXXXXXXXXXX'); // invalid ID
            Test.stopTest();
            System.assert(false, 'Should throw AuraHandledException');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Branch not found'),
              //  'Expected branch not found message');
        }
    }

    // ---------------------------------------------
    // TEST: testBranchData()
    // ---------------------------------------------
    @isTest
    static void testTestBranchData() {

        Test.startTest();
        Map<String, Object> result = BranchController.testBranchData();
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assert(result.containsKey('totalBranches'));
        System.assert(result.containsKey('activeBranches'));
        System.assert(result.containsKey('samples'));
    }
}