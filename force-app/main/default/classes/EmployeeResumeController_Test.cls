@IsTest
private class EmployeeResumeController_Test {

    // Utility method to create Record Types for Account (if needed)
    private static Id getRecordTypeId(String devName) {
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = :devName LIMIT 1];
        return rt.Id;
    }

    // -----------------------------------
    // 🔹 Setup Test Data
    // -----------------------------------
    private static void setupTestData() {
        Id empRtId = getRecordTypeId('Employee');

        // 1️⃣ Create Employee (Person Account)
        Account emp1 = new Account(
            RecordTypeId = empRtId,
            Name = 'John Doe',
            Designation__c = 'Salesforce Developer',
            Years_of_Experience__c = '5',
            Description = 'Certified Salesforce Developer'
           
        );
        insert emp1;

        Account emp2 = new Account(
            RecordTypeId = empRtId,
            Name = 'Jane Smith',
            Designation__c = 'Project Manager',
            Years_of_Experience__c = '8',
            Description = 'Manages multiple CRM projects'
            
        );
        insert emp2;

        // 2️⃣ Create Certifications
        List<Certification__c> certs = new List<Certification__c>{
            new Certification__c(Name = 'Salesforce Admin', Candidate_Name__c = emp1.Id),
            new Certification__c(Name = 'Salesforce Developer', Candidate_Name__c = emp1.Id),
            new Certification__c(Name = 'PMP', Candidate_Name__c = emp2.Id)
        };
        insert certs;

        // 3️⃣ Create Projects
        List<Project_Experience__c> projects = new List<Project_Experience__c>{
            new Project_Experience__c(Name = 'CRM Revamp', Employee_Name__c = emp1.Id, Project_Name__c = 'CRM Revamp Project', Action__c = 'Development'),
            new Project_Experience__c(Name = 'Implementation Project', Employee_Name__c = emp2.Id, Project_Name__c = 'Implementation', Action__c = 'Management')
        };
        insert projects;

        // 4️⃣ Create Skills
        List<Employee_Skill__c> skills = new List<Employee_Skill__c>{
            new Employee_Skill__c(Name = 'Apex', Employee_Name__c = emp1.Id),
            new Employee_Skill__c(Name = 'Project Planning', Employee_Name__c = emp2.Id)
        };
        insert skills;
    }

    // -----------------------------------
    // 🔸 TEST 1: getEmployeesByCertification
    // -----------------------------------
    @IsTest
    static void test_getEmployeesByCertification() {
        setupTestData();

        Test.startTest();
        List<EmployeeResumeController.EmployeeRow> rows =
            EmployeeResumeController.getEmployeesByCertification('Salesforce');
        Test.stopTest();

        System.assertNotEquals(0, rows.size(), 'Should return employees with Salesforce certifications');
        Boolean foundJohn = false;
        for (EmployeeResumeController.EmployeeRow r : rows) {
            if (r.Name == 'John Doe') {
                foundJohn = true;
                System.assert(r.Certifications.contains('Salesforce'), 'Certifications should contain Salesforce');
            }
        }
        System.assert(foundJohn, 'John Doe should appear in the result');
    }

    // -----------------------------------
    // 🔸 TEST 2: getEmployeesByCertification - Blank Keyword
    // -----------------------------------
    @IsTest
    static void test_getEmployeesByCertification_blankKeyword() {
        setupTestData();

        Test.startTest();
        List<EmployeeResumeController.EmployeeRow> rows =
            EmployeeResumeController.getEmployeesByCertification('');
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Should return empty list for blank keyword');
    }

    // -----------------------------------
    // 🔸 TEST 3: getEmployeeFullProfile
    // -----------------------------------
    @IsTest
    static void test_getEmployeeFullProfile() {
        setupTestData();

        Account emp = [SELECT Id FROM Account WHERE Name = 'John Doe' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = EmployeeResumeController.getEmployeeFullProfile(new List<Id>{emp.Id});
        Test.stopTest();

        System.assert(result.containsKey('employees'), 'Result should contain employees');
        System.assert(result.containsKey('projects'), 'Result should contain projects');
        System.assert(result.containsKey('skills'), 'Result should contain skills');
        System.assert(result.containsKey('certifications'), 'Result should contain certifications');

        List<Account> employees = (List<Account>) result.get('employees');
        System.assertEquals(1, employees.size(), 'One employee should be returned');
    }

    // -----------------------------------
    // 🔸 TEST 4: getEmployeeFullProfile - Empty List
    // -----------------------------------
    @IsTest
    static void test_getEmployeeFullProfile_empty() {
        Test.startTest();
        Map<String, Object> result = EmployeeResumeController.getEmployeeFullProfile(new List<Id>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, ((List<Account>) result.get('employees')).size(), 'Empty employee list expected');
    }

    // -----------------------------------
    // 🔸 TEST 5: getEmployeeFullProfileJSON
    // -----------------------------------
    @IsTest
    static void test_getEmployeeFullProfileJSON() {
        setupTestData();
        Account emp = [SELECT Id FROM Account WHERE Name = 'Jane Smith' LIMIT 1];

        Test.startTest();
        String jsonResult = EmployeeResumeController.getEmployeeFullProfileJSON(new List<Id>{emp.Id});
        Test.stopTest();

        System.assert(!String.isBlank(jsonResult), 'JSON result should not be blank');
        System.assert(jsonResult.contains('Jane Smith'), 'JSON result should contain employee name');
    }
}