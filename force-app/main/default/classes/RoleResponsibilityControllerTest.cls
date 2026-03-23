@IsTest
public class RoleResponsibilityControllerTest {

    @TestSetup
    static void setupData() {

        Role_Category__c role1 = new Role_Category__c(
            Name = 'Developer',
            Is_Active__c = true
        );

        Role_Category__c role2 = new Role_Category__c(
            Name = 'Tester',
            Is_Active__c = true
        );

        insert new List<Role_Category__c>{ role1, role2 };

        insert new List<Role_Responsibilities__c>{
            new Role_Responsibilities__c(
                Name = 'Dev Resp 1',
                Responsibility_Text__c = 'Write Code',
                Role_Category__c = role1.Id,
                Sequence__c = 1,
                Is_Active__c = true
            ),
            new Role_Responsibilities__c(
                Name = 'Test Resp 1',
                Responsibility_Text__c = 'Test Features',
                Role_Category__c = role2.Id,
                Sequence__c = 1,
                Is_Active__c = true
            )
        };
    }

    // ✅ getRoleCategories
    @IsTest
    static void testGetRoleCategories() {

        Test.startTest();
        List<Role_Category__c> roles = RoleResponsibilityController.getRoleCategories();
        Test.stopTest();

        System.assertEquals(2, roles.size());
    }

    // ✅ getResponsibilities (MULTIPLE ROLE IDS)
    @IsTest
    static void testGetResponsibilities() {

        List<Role_Category__c> roles = [SELECT Id FROM Role_Category__c];

        Test.startTest();
        List<Role_Responsibilities__c> resps =
            RoleResponsibilityController.getResponsibilities(
                new List<Id>{ roles[0].Id, roles[1].Id }
            );
        Test.stopTest();

        System.assertEquals(2, resps.size());
    }

    // ✅ saveResponsibilities – Candidate
    @IsTest
    static void testSaveResponsibilitiesCandidate() {

        Candidate__c candidate = new Candidate__c(
            First_Name__c      = 'Test',
            Last_Name__c       = 'Candidate',
            Date_Of_Birth__c   = Date.newInstance(1995, 5, 15),
            Personal_Email__c  = 'test@mail.com',
            Phone_No__c        = '9876543210'
        );
        insert candidate;

        List<Role_Responsibilities__c> responsibilities =
            [SELECT Id FROM Role_Responsibilities__c];

        Test.startTest();
        RoleResponsibilityController.saveResponsibilities(
            candidate.Id,
            'Candidate__c',
            new List<Id>{ responsibilities[0].Id }
        );
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Person_Responsibility__c WHERE Candidate__c = :candidate.Id]
        );
    }

    // ✅ saveResponsibilities – Contact (COVER CONTACT BRANCH)
    @IsTest
    static void testSaveResponsibilitiesContact() {

        Contact con = new Contact(LastName = 'Test Contact');
        insert con;

        Role_Responsibilities__c resp =
            [SELECT Id FROM Role_Responsibilities__c LIMIT 1];

        Test.startTest();
        RoleResponsibilityController.saveResponsibilities(
            con.Id,
            'Contact',
            new List<Id>{ resp.Id }
        );
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Person_Responsibility__c WHERE Contact__c = :con.Id]
        );
    }

    // ✅ Duplicate Prevention
    @IsTest
    static void testDuplicatePrevention() {

        Candidate__c candidate = new Candidate__c(
            First_Name__c      = 'Duplicate',
            Last_Name__c       = 'Candidate',
            Date_Of_Birth__c   = Date.newInstance(1994, 1, 10),
            Personal_Email__c  = 'duplicate@mail.com',
            Phone_No__c        = '9999999999'
        );
        insert candidate;

        Role_Responsibilities__c resp =
            [SELECT Id FROM Role_Responsibilities__c LIMIT 1];

        RoleResponsibilityController.saveResponsibilities(
            candidate.Id,
            'Candidate__c',
            new List<Id>{ resp.Id }
        );

        RoleResponsibilityController.saveResponsibilities(
            candidate.Id,
            'Candidate__c',
            new List<Id>{ resp.Id }
        );

        System.assertEquals(1,
            [SELECT COUNT() FROM Person_Responsibility__c WHERE Candidate__c = :candidate.Id]
        );
    }

    // ✅ getAssignedResponsibilities – Candidate
    @IsTest
    static void testGetAssignedResponsibilitiesCandidate() {

        Candidate__c candidate = new Candidate__c(
            First_Name__c      = 'Assigned',
            Last_Name__c       = 'Candidate',
            Date_Of_Birth__c   = Date.newInstance(1993, 3, 20),
            Personal_Email__c  = 'assigned@mail.com',
            Phone_No__c        = '8888888888'
        );
        insert candidate;

        Role_Responsibilities__c resp =
            [SELECT Id FROM Role_Responsibilities__c LIMIT 1];

        RoleResponsibilityController.saveResponsibilities(
            candidate.Id,
            'Candidate__c',
            new List<Id>{ resp.Id }
        );

        Test.startTest();
        List<Id> assignedIds =
            RoleResponsibilityController.getAssignedResponsibilities(
                candidate.Id,
                'Candidate__c'
            );
        Test.stopTest();

        System.assertEquals(1, assignedIds.size());
    }

    // ✅ getAssignedResponsibilities – Contact (IMPORTANT COVERAGE BOOST)
    @IsTest
    static void testGetAssignedResponsibilitiesContact() {

        Contact con = new Contact(LastName = 'Assigned Contact');
        insert con;

        Role_Responsibilities__c resp =
            [SELECT Id FROM Role_Responsibilities__c LIMIT 1];

        RoleResponsibilityController.saveResponsibilities(
            con.Id,
            'Contact',
            new List<Id>{ resp.Id }
        );

        Test.startTest();
        List<Id> assignedIds =
            RoleResponsibilityController.getAssignedResponsibilities(
                con.Id,
                'Contact'
            );
        Test.stopTest();

        System.assertEquals(1, assignedIds.size());
    }

    // ✅ saveResponsibilities – EMPTY LIST (EDGE CASE COVERAGE)
    @IsTest
    static void testSaveResponsibilitiesEmptyList() {

        Candidate__c candidate = new Candidate__c(
            First_Name__c      = 'Empty',
            Last_Name__c       = 'Test',
            Date_Of_Birth__c   = Date.newInstance(1990, 1, 1),
            Personal_Email__c  = 'empty@mail.com',
            Phone_No__c        = '7777777777'
        );
        insert candidate;

        Test.startTest();
        RoleResponsibilityController.saveResponsibilities(
            candidate.Id,
            'Candidate__c',
            new List<Id>()   // EMPTY
        );
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM Person_Responsibility__c WHERE Candidate__c = :candidate.Id]
        );
    }
}