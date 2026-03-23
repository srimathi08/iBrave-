@IsTest
public class ProjectTimelineController_Test {

    @IsTest
    static void test_getProjectExperiences_withData() {
        // 🧩 Step 1: Create Account (Employee)
        Account acc = TestDataFactory.createAccount(true);

        // 🧩 Step 2: Create Project Experience for that account
        Project_Experience__c proj1 = TestDataFactory.createProjectExperience(false, acc.Id);
        proj1.Start_Date__c = Date.today().addMonths(-6);
        proj1.End_Date__c = Date.today().addMonths(-3);
        insert proj1;

        Project_Experience__c proj2 = TestDataFactory.createProjectExperience(false, acc.Id);
        proj2.Start_Date__c = Date.today().addMonths(-2);
        proj2.End_Date__c = Date.today();
        insert proj2;

        // 🧩 Step 3: Call the method under test
        Test.startTest();
            List<ProjectTimelineController.ProjectExperienceWrapper> result =
                ProjectTimelineController.getProjectExperiences(acc.Id);
        Test.stopTest();

        // 🧠 Step 4: Assertions
        System.assertNotEquals(null, result, 'Result list should not be null');
        System.assertEquals(2, result.size(), 'Should return 2 project experience records');
        System.assertEquals(proj1.Project_Name__c, result[0].projectName, 'First project name should match');
        System.assert(result[0].startDate < result[1].startDate, 'Results should be ordered by start date');
    }

    @IsTest
    static void test_getProjectExperiences_noData() {
        // 🧩 Step 1: Create Account with no Project Experience
        Account acc = TestDataFactory.createAccount(true);

        // 🧩 Step 2: Call method
        Test.startTest();
            List<ProjectTimelineController.ProjectExperienceWrapper> result =
                ProjectTimelineController.getProjectExperiences(acc.Id);
        Test.stopTest();

        // 🧠 Step 3: Verify result
        System.assertEquals(0, result.size(), 'Expected 0 project experiences when none exist');
    }
}