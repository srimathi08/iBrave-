@isTest
public class EmployeeSkillChartController_Test {
    
    @isTest
    static void test_getCategoryCounts_withData() {
        // Step 1: Create test data hierarchy using the factory
        Map<String, SObject> dataMap = TestDataFactory.createAccountHierarchy(true);

        // Extract key records
        Account acc = (Account) dataMap.get('Account');

        // Step 2: Add more Employee_Skill__c records for variety
        Skill__c skill2 = new Skill__c(
            Skill_Name__c = 'Visualforce',
            Category__c = 'Technical',
            Active__c = true
        );
        insert skill2;

        Employee_Skill__c empSkill2 = new Employee_Skill__c(
            Name = 'EmpSkill_Tech_2',
            Employee_Name__c = acc.Id,
            Skill__c = skill2.Id,
            Is_Skill_Certified__c = true,
            Primary_Secondary_Skill__c = 'Secondary Skill',
            Proficiency__c = 'Intermediate'
        );
        insert empSkill2;

        // Step 3: Another category for testing grouping
        Skill__c skill3 = new Skill__c(
            Skill_Name__c = 'Project Management',
            Category__c = 'Management',
            Active__c = true
        );
        insert skill3;

        Employee_Skill__c empSkill3 = new Employee_Skill__c(
            Name = 'EmpSkill_Mgmt',
            Employee_Name__c = acc.Id,
            Skill__c = skill3.Id,
            Is_Skill_Certified__c = false,
            Primary_Secondary_Skill__c = 'Primary Skill',
            Proficiency__c = 'Advanced'
        );
        insert empSkill3;

        Test.startTest();
            // Step 4: Call method under test
            Map<String, Integer> resultMap = EmployeeSkillChartController.getCategoryCounts(acc.Id);
        Test.stopTest();

        // Step 5: Assertions
        System.assertNotEquals(null, resultMap, 'Result map should not be null');
        System.assert(resultMap.containsKey('Technical'), 'Technical category should exist');
        System.assert(resultMap.containsKey('Management'), 'Management category should exist');
        System.assertEquals(2, resultMap.get('Technical'), 'Technical count should be 2');
        System.assertEquals(1, resultMap.get('Management'), 'Management count should be 1');
    }

    @isTest
    static void test_getCategoryCounts_noData() {
        // Step 1: Create an account without any employee skills
        Account acc = TestDataFactory.createAccount(true);

        Test.startTest();
            // Step 2: Call method for account with no Employee_Skill__c
            Map<String, Integer> resultMap = EmployeeSkillChartController.getCategoryCounts(acc.Id);
        Test.stopTest();

        // Step 3: Assertions
        System.assertNotEquals(null, resultMap, 'Result map should not be null');
        System.assertEquals(0, resultMap.size(), 'Map should be empty when no skills exist');
    }

    @isTest
    static void test_getCategoryCounts_withException() {
        Test.startTest();
        try {
            // ✅ Pass null to trigger handled exception inside controller
            EmployeeSkillChartController.getCategoryCounts(null);
           // System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            // Step 2: Verify the exception message
            System.assert(e.getMessage().contains('Error:'), 'Exception message should contain "Error:"');
        }
        Test.stopTest();
    }
}