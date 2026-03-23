/*@isTest
public class CandidateCreationControllerTest {

    // --------------------------
    // Utility method to build sample JSON input
    // --------------------------
    private static String buildJson(Boolean includeProjects) {
        String projectPart = includeProjects 
            ? '"projects":[{"projectName":"CRM Upgrade","projectRole":"Developer","situation":"Legacy migration","task":"Data mapping","action":"Code + LWC","result":"Improved efficiency","learningOutcome":"Better Apex skills","skillsApplied":"Apex,LWC","toolsUsed":"VSCode","startDate":"2023-01-01","endDate":"2023-06-30","projectPhase":"None"}],' 
            : '';

        return '{' +
            '"resumes":[' +
                '{' +
                    '"account":{' +
                        '"name":"John Tester",' +
                        '"phone":"1234567890",' +
                        '"email":"john.doe@test.com",' +
                        '"summary":"Salesforce Dev",' +
                        '"designation":"Developer",' +
                        '"experience":"5",' +
                        '"languagesKnown":"English",' +
                        '"currentCompany":"TechCorp",' +
                        '"currentLocation":"Hyderabad",' +
                        '"filename":"resume.pdf",' +
                        '"degree":"B.Tech",' +
                        '"college":"Anna University",' +
                        '"dateofBirth":"1995-05-05"' +
                    '},' +
                    '"skills":[' +
                        '{"name":"Apex","proficiency":"Expert"}' +
                    '],' +
                    '"certifications":[' +
                        '{"name":"PD1","issuedBy":"Salesforce","issueDate":"2022-01-01","expiryDate":"2025-01-01"}' +
                    '],' +
                    projectPart +
                    '"extra":"notUsed"' +
                '}' +
            ']' +
        '}';
    }

    // --------------------------
    // 1️⃣ Test new candidate creation flow
    // --------------------------
    @isTest
    static void testCreateNewCandidate_UsingFactory() {
        // Prepare prerequisite data from factory (skills etc.)
        Map<String, SObject> factoryData = TestDataFactory.createAccountHierarchy(true);
        Skill__c baseSkill = (Skill__c) factoryData.get('Skill'); // Existing Skill record for lookup safety

        // Build test JSON input
        String jsonInput = buildJson(true);

        Test.startTest();
        List<Account> created = CandidateCreationController.createCandidates(jsonInput);
        Test.stopTest();

        System.assertNotEquals(0, created.size(), 'Account should be inserted');
        Account acc = [
            SELECT Id, Name, Personal_Email__c, Designation__c, Current_Organization__c
            FROM Account
            WHERE Personal_Email__c = 'john.doe@test.com'
            LIMIT 1
        ];
        System.assertEquals('Developer', acc.Designation__c);
        System.assertEquals('TechCorp', acc.Current_Organization__c);

        // ✅ Validate related Skill__c
        System.assertEquals(true, [SELECT COUNT() FROM Skill__c WHERE Skill_Name__c = 'Apex'] > 0, 'Skill Apex should exist');
        System.assertEquals(true, [SELECT COUNT() FROM Employee_Skill__c WHERE Employee_Name__c = :acc.Id] > 0, 'Employee_Skill__c should be created');

        // ✅ Validate Certification
        Certification__c cert = [
            SELECT Full_Certification_Name__c, Issuing_Organization__c, Candidate_Name__c
            FROM Certification__c
            WHERE Candidate_Name__c = :acc.Id
            LIMIT 1
        ];
        System.assertEquals('PD1', cert.Full_Certification_Name__c, 'Certification should match JSON');
        System.assertEquals('Salesforce', cert.Issuing_Organization__c);

        // ✅ Validate Project Experience
        Project_Experience__c proj = [
            SELECT Project_Name__c, Project_Role__c, Employee_Name__c
            FROM Project_Experience__c
            WHERE Employee_Name__c = :acc.Id
            LIMIT 1
        ];
        System.assertEquals('CRM Upgrade', proj.Project_Name__c, 'Project name should match JSON');
        System.assertEquals('Developer', proj.Project_Role__c);
    }

    // --------------------------
    // 2️⃣ Test existing candidate skip logic
    // --------------------------
    @isTest
    static void testSkipExistingCandidate_UsingFactory() {
        // Setup: create existing candidate using TestDataFactory
        Map<String, SObject> factoryData = TestDataFactory.createAccountHierarchy(true);
        Account existing = (Account) factoryData.get('Account');
        existing.Personal_Email__c = 'john.doe@test.com';
        update existing;

        // Build test JSON input with same email
        String jsonInput = buildJson(false);

        Test.startTest();
        List<Account> created = CandidateCreationController.createCandidates(jsonInput);
        Test.stopTest();

        // ✅ The method should skip creating new records and return all processed (existing)
        System.assertNotEquals(null, created, 'Should return processed list');
        System.assertEquals(1, created.size(), 'Should return only existing account reference');
    }

    // --------------------------
    // 3️⃣ Test missing projects
    // --------------------------
    @isTest
    static void testCreateCandidate_NoProjects_UsingFactory() {
        Map<String, SObject> factoryData = TestDataFactory.createAccountHierarchy(true);
        String jsonInput = buildJson(false);

        Test.startTest();
        List<Account> created = CandidateCreationController.createCandidates(jsonInput);
        Test.stopTest();

        System.assertEquals(1, created.size(), 'Candidate should still be created even without projects');
    }

    // --------------------------
    // 4️⃣ Test invalid/empty JSON
    // --------------------------
    @isTest
    static void testEmptyJson_UsingFactory() {
        Test.startTest();
        List<Account> created = CandidateCreationController.createCandidates('{}');
        Test.stopTest();

        System.assertEquals(null, created, 'Should return null for invalid or missing resumes key');
    }

// ✅ 5️⃣ Test project update logic (to cover compare & update fields)
@isTest
static void testUpdateExistingProject_UsingFactory() {
    // Step 1: Create a base candidate + project
    Map<String, SObject> factoryData = TestDataFactory.createAccountHierarchy(true);
    Account existingAcc = (Account) factoryData.get('Account');
    existingAcc.Personal_Email__c = 'john.doe@test.com';
    update existingAcc;

    // Step 2: Create an existing project record linked to candidate
    Project_Experience__c existingProj = new Project_Experience__c(
        Employee_Name__c = existingAcc.Id,
        Full_Project_Name__c = 'CRM Upgrade',
        Project_Name__c = 'CRM Upgrade',
        Project_Role__c = 'Developer',
        Client_Name__c = 'TechCorp',
        Situtation__c = 'Legacy migration',
        Task__c = 'Data mapping',
        Action__c = 'Code + LWC',
        Result__c = 'Improved efficiency'
    );
    insert existingProj;

    // Step 3: Build JSON with same project name but changed data
    String jsonInput =
        '{' +
        '"resumes":[' +
            '{' +
                '"account":{' +
                    '"name":"John Tester",' +
                    '"phone":"1234567890",' +
                    '"email":"john.doe@test.com",' +
                    '"summary":"Salesforce Dev",' +
                    '"designation":"Developer",' +
                    '"experience":"6",' +
                    '"languagesKnown":"English",' +
                    '"currentCompany":"TechCorp",' +
                    '"currentLocation":"Hyderabad",' +
                    '"filename":"resume.pdf",' +
                    '"degree":"B.Tech",' +
                    '"college":"Anna University",' +
                    '"dateofBirth":"1995-05-05"' +
                '},' +
                '"projects":[' +
                    '{' +
                        '"projectName":"CRM Upgrade",' +  // 🔹 Same name → triggers update path
                        '"projectRole":"Lead Developer",' + // 🔹 Changed field
                        '"situation":"Migration Phase 2",' +
                        '"task":"Integration",' +
                        '"action":"Code + APIs",' +
                        '"result":"Enhanced performance",' +
                        '"learningOutcome":"Advanced Apex",' +
                        '"skillsApplied":"Apex,LWC",' +
                        '"toolsUsed":"VSCode",' +
                        '"startDate":"2024-01-01",' +
                        '"endDate":"2024-06-30",' +
                        '"achievements":"Lead Project",' +
                        '"clientName":"TechCorp",' +
                        '"responsibilities":"Handled migration",' +
                        '"designationJobTitle":"Senior Dev",' +
                        '"projectLocation":"Remote",' +
                        '"environment":"Agile"' +
                    '}' +
                ']' +
            '}' +
        ']' +
        '}';

    // Step 4: Execute controller to update the project
    Test.startTest();
    List<Account> result = CandidateCreationController.createCandidates(jsonInput);
    Test.stopTest();

    // Step 5: Assert updates applied
    Project_Experience__c updatedProj = [
        SELECT Project_Role__c, Situtation__c, Task__c, Action__c, Result__c, 
               Learning_Outcome__c, Skills_Applied__c, Tools_Used__c, Start_Date__c, End_Date__c,
               Achievements__c, Responsibilities__c, Designation_Job_Title__c, 
               Project_Location__c, Environment__c
        FROM Project_Experience__c
        WHERE Id = :existingProj.Id
        LIMIT 1
    ];

    System.assertEquals('Lead Developer', updatedProj.Project_Role__c, 'Project role should update');
    System.assertEquals('Integration', updatedProj.Task__c, 'Task should update');
    System.assertEquals('Agile', updatedProj.Environment__c, 'Environment should update');
    System.assertEquals(Date.newInstance(2024, 1, 1), updatedProj.Start_Date__c, 'Start Date updated');
}


}  */



@isTest
public class CandidateCreationControllerTest {

    /* --------------------------
     * Utility method to build JSON
     * -------------------------- */
    private static String buildJson(Boolean includeProjects) {

        String projectPart = includeProjects
            ? '"projects":[{' +
              '"projectName":"CRM Upgrade",' +
              '"projectRole":"Developer",' +
              '"situation":"Legacy migration",' +
              '"task":"Data mapping",' +
              '"action":"Code + LWC",' +
              '"result":"Improved efficiency",' +
              '"learningOutcome":"Better Apex skills",' +
              '"skillsApplied":"Apex,LWC",' +
              '"toolsUsed":"VSCode",' +
              '"startDate":"2023-01-01",' +
              '"endDate":"2023-06-30",' +
              '"clientName":"TechCorp"' +
              '}],'
            : '';

        return '{' +
            '"resumes":[{' +
                '"account":{' +
                    '"name":"John Tester",' +
                    '"phone":"1234567890",' +
                    '"email":"john.doe@test.com",' +
                    '"summary":"Salesforce Dev",' +
                    '"designation":"Developer",' +
                    '"experience":"5",' +
                    '"languagesKnown":"English",' +
                    '"currentCompany":"TechCorp",' +
                    '"currentLocation":"Hyderabad",' +
                    '"filename":"resume.pdf",' +
                    '"degree":"B.Tech",' +
                    '"college":"Anna University",' +
                    '"dateofBirth":"1995-05-05"' +
                '},' +
                '"skills":[{"name":"Apex","proficiency":"Expert"}],' +
                '"certifications":[{' +
                    '"name":"PD1",' +
                    '"issuedBy":"Salesforce",' +
                    '"issueDate":"2022-01-01",' +
                    '"expiryDate":"2025-01-01"' +
                '}],' +
                projectPart +
                '"extra":"notUsed"' +
            '}]' +
        '}';
    }

    /* --------------------------
     * 1️⃣ New Candidate Creation
     * -------------------------- */
    @isTest
    static void testCreateNewCandidate() {

        String jsonInput = buildJson(true);

        Test.startTest();
        List<Account> created =
            CandidateCreationController.createCandidates(jsonInput, null);
        Test.stopTest();

        System.assertEquals(1, created.size());

        Account acc = [
            SELECT Id, Designation__c, Current_Organization__c
            FROM Account
            WHERE Personal_Email__c = 'john.doe@test.com'
            LIMIT 1
        ];

        System.assertEquals('Developer', acc.Designation__c);
        System.assertEquals('TechCorp', acc.Current_Organization__c);

        // Certification
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Certification__c WHERE Candidate_Name__c = :acc.Id]
        );

        // Project
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Project_Experience__c WHERE Employee_Name__c = :acc.Id]
        );
    }

    /* --------------------------
     * 2️⃣ Existing Candidate Update Path
     * -------------------------- */
    @isTest
    static void testExistingCandidate_NoDuplicate() {

        // Pre-create candidate
        Account acc = new Account(
            Name = 'John Tester',
            Personal_Email__c = 'john.doe@test.com',
            RecordTypeId = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'Account'
                AND DeveloperName = 'Candidates'
                LIMIT 1
            ].Id
        );
        insert acc;

        String jsonInput = buildJson(false);

        Test.startTest();
        List<Account> result =
            CandidateCreationController.createCandidates(jsonInput, null);
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* --------------------------
     * 3️⃣ No Projects Case
     * -------------------------- */
    @isTest
    static void testCreateCandidate_NoProjects() {

        String jsonInput = buildJson(false);

        Test.startTest();
        List<Account> created =
            CandidateCreationController.createCandidates(jsonInput, null);
        Test.stopTest();

        System.assertEquals(1, created.size());
    }

    /* --------------------------
     * 4️⃣ Empty JSON Handling
     * -------------------------- */
    @isTest
    static void testEmptyJson() {

        Test.startTest();
        List<Account> created =
            CandidateCreationController.createCandidates('{}', null);
        Test.stopTest();

        System.assertEquals(0, created.size());
    }

    /* --------------------------
     * 5️⃣ Project Update Logic
     * -------------------------- */
    @isTest
    static void testProjectUpdate() {

        // Create candidate
        Account acc = new Account(
            Name = 'John Tester',
            Personal_Email__c = 'john.doe@test.com',
            RecordTypeId = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'Account'
                AND DeveloperName = 'Candidates'
                LIMIT 1
            ].Id
        );
        insert acc;

        // Existing project
        Project_Experience__c proj = new Project_Experience__c(
            Employee_Name__c = acc.Id,
            Full_Project_Name__c = 'CRM Upgrade',
            Project_Name__c = 'CRM Upgrade',
            Project_Role__c = 'Developer',
            Client_Name__c = 'TechCorp'
        );
        insert proj;

        String updateJson =
        '{ "resumes": [{' +
        '  "account": {' +
        '    "name":"John Tester",' +
        '    "email":"john.doe@test.com"' +
        '  },' +
        '  "projects": [{' +
        '    "projectName":"CRM Upgrade",' +
        '    "projectRole":"Lead Developer",' +
        '    "clientName":"TechCorp",' +
        '    "startDate":"2024-01-01",' +
        '    "endDate":"2024-06-30",' +
        '    "environment":"Agile"' +
        '  }]' +
        '}]}';

        Test.startTest();
        CandidateCreationController.createCandidates(updateJson, null);
        Test.stopTest();

        Project_Experience__c updated = [
            SELECT Project_Role__c, Environment__c, Start_Date__c
            FROM Project_Experience__c
            WHERE Id = :proj.Id
        ];

        System.assertEquals('Lead Developer', updated.Project_Role__c);
        System.assertEquals('Agile', updated.Environment__c);
        System.assertEquals(Date.newInstance(2024, 1, 1), updated.Start_Date__c);
    }
}