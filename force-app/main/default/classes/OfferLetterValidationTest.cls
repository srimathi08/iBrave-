@IsTest
public class OfferLetterValidationTest {

    /* =====================================================
       UTILITY: Get Record Type Id
       ===================================================== */
    private static Id getRecordTypeId(String devName) {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Candidate__c'
            AND DeveloperName = :devName
            LIMIT 1
        ].Id;
    }

    /* =====================================================
       TEST DATA FACTORY
       ===================================================== */

    private static Candidate__c createCandidate(String recordTypeDevName) {

        Candidate__c c = new Candidate__c(
            First_Name__c = 'Test',
            Last_Name__c  = 'Candidate',
            Personal_Email__c = 'testuser@gmail.com',
            Phone_No__c = '9000000001',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            RecordTypeId = getRecordTypeId(recordTypeDevName)
        );

        insert c; // Flow sets Offer_Type__c
        return c;
    }

    private static void createSalary(Id candidateId) {
        insert new Salary_Details__c(
            Candidate__c = candidateId,
            Gross_Salary__c = 500000
        );
    }

    /* =====================================================
       ✅ NEW ROLE STRUCTURE
       ===================================================== */
    private static void createRole(Id candidateId) {

        Role_Category__c roleCat = new Role_Category__c(
            Name = 'Developer'
        );
        insert roleCat;

        Role_Responsibilities__c roleResp = new Role_Responsibilities__c(
            Name = 'Coding',
            Role_Category__c = roleCat.Id
        );
        insert roleResp;

        insert new Person_Responsibility__c(
            Candidate__c = candidateId,
            Role_Category__c = roleCat.Id,
            Role_Responsibilities__c = roleResp.Id,
            Responsibility_Text__c = 'Write Apex Code'
        );
    }

    /* =====================================================
       1️⃣ INTERN → VALID
       ===================================================== */
    @IsTest
    static void testInternCandidate_valid() {

        Candidate__c intern = createCandidate('Intern_Candidate');

        Candidate__c inserted =
            [SELECT Offer_Type__c FROM Candidate__c WHERE Id = :intern.Id];

        System.assertEquals('Intern', inserted.Offer_Type__c);

        Test.startTest();
        List<OfferLetterValidation.ValidationResult> results =
            OfferLetterValidation.validate(new List<Id>{ intern.Id });
        Test.stopTest();

        System.assertEquals(true, results[0].isValid);
    }

    /* =====================================================
       2️⃣ ON ROLE → MISSING SALARY → INVALID
       ===================================================== */
    @IsTest
    static void testOnRole_missingSalary_invalid() {

        Candidate__c onRole = createCandidate('On_Role_Candidate');

        Test.startTest();
        List<OfferLetterValidation.ValidationResult> results =
            OfferLetterValidation.validate(new List<Id>{ onRole.Id });
        Test.stopTest();

        System.assertEquals(false, results[0].isValid);
    }

    /* =====================================================
       3️⃣ ON ROLE → MISSING ROLE → INVALID
       ===================================================== */
    @IsTest
    static void testOnRole_missingRole_invalid() {

        Candidate__c onRole = createCandidate('On_Role_Candidate');
        createSalary(onRole.Id);

        Test.startTest();
        List<OfferLetterValidation.ValidationResult> results =
            OfferLetterValidation.validate(new List<Id>{ onRole.Id });
        Test.stopTest();

        System.assertEquals(false, results[0].isValid);
    }

    /* =====================================================
       4️⃣ ON ROLE → SALARY + ROLE → VALID
       ===================================================== */
    @IsTest
    static void testOnRole_withSalaryAndRole_valid() {

        Candidate__c onRole = createCandidate('On_Role_Candidate');
        createSalary(onRole.Id);
        createRole(onRole.Id);

        Test.startTest();
        List<OfferLetterValidation.ValidationResult> results =
            OfferLetterValidation.validate(new List<Id>{ onRole.Id });
        Test.stopTest();

        System.assertEquals(true, results[0].isValid);
    }
}