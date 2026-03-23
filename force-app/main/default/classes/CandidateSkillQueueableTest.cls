@IsTest
public class CandidateSkillQueueableTest {

    /* --------------------------------------------------
     * Helper: Get Candidate Record Type (SAFE)
     * -------------------------------------------------- */
    private static Id getCandidateRT() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'Candidates'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /* --------------------------------------------------
     * TEST: INSERT NEW SKILLS + EMPLOYEE SKILLS
     * -------------------------------------------------- */
    @IsTest
    static void testInsertNewSkillsAndEmployeeSkills() {

        Account acc = new Account(
            Name = 'Test Candidate',
            RecordTypeId = getCandidateRT()
        );
        insert acc;

        // Existing skill
        Skill__c existingSkill = new Skill__c(
            Skill_Name__c = 'Apex',
            Active__c = true,
            Category__c = 'Programming'
        );
        insert existingSkill;

        // Skill input
        List<List<Map<String, Object>>> skillsByResume = new List<List<Map<String, Object>>>();

        Map<String, Object> skill1 = new Map<String, Object>{
            'name' => 'Apex',
            'proficiency' => 'Expert',
            'Category' => 'Programming'
        };

        Map<String, Object> skill2 = new Map<String, Object>{
            'name' => 'LWC',
            'proficiency' => 'Intermediate',
            'Category' => 'Frontend'
        };

        skillsByResume.add(new List<Map<String, Object>>{ skill1, skill2 });

        Test.startTest();
        System.enqueueJob(
            new CandidateSkillQueueable(
                new List<Account>{ acc },
                skillsByResume
            )
        );
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Skill__c WHERE Skill_Name__c IN ('Apex', 'LWC')],
            'Skills should exist'
        );

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Employee_Skill__c WHERE Employee_Name__c = :acc.Id],
            'Employee skills should be created'
        );
    }

    /* --------------------------------------------------
     * TEST: UPDATE EXISTING EMPLOYEE SKILL
     * -------------------------------------------------- */
    @IsTest
    static void testUpdateEmployeeSkillProficiency() {

        Account acc = new Account(
            Name = 'Skill Update Candidate',
            RecordTypeId = getCandidateRT()
        );
        insert acc;

        Skill__c apexSkill = new Skill__c(
            Skill_Name__c = 'Apex',
            Active__c = true,
            Category__c = 'Programming'
        );
        insert apexSkill;

        Employee_Skill__c empSkill = new Employee_Skill__c(
            Name = 'Apex',
            Full_Skill_Name__c = 'Apex',
            Skill__c = apexSkill.Id,
            Employee_Name__c = acc.Id,
            Proficiency__c = 'Beginner'
        );
        insert empSkill;

        List<List<Map<String, Object>>> skillsByResume = new List<List<Map<String, Object>>>();
        skillsByResume.add(new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'Apex',
                'proficiency' => 'Expert',
                'Category' => 'Programming'
            }
        });

        Test.startTest();
        System.enqueueJob(
            new CandidateSkillQueueable(
                new List<Account>{ acc },
                skillsByResume
            )
        );
        Test.stopTest();

        Employee_Skill__c updated = [
            SELECT Proficiency__c
            FROM Employee_Skill__c
            WHERE Id = :empSkill.Id
        ];

        System.assertEquals('Expert', updated.Proficiency__c);
    }

    /* --------------------------------------------------
     * TEST: EMPTY INPUT SAFETY
     * -------------------------------------------------- */
    @IsTest
    static void testEmptyAccounts() {

        Test.startTest();
        System.enqueueJob(
            new CandidateSkillQueueable(
                new List<Account>(),
                new List<List<Map<String, Object>>>()
            )
        );
        Test.stopTest();

        System.assert(true, 'Queueable safely exits');
    }
}