@IsTest
private class OfferLetterControllerTest {

    /* -----------------------------------------------------------
       ✅ RECORD TYPE UTILITY (CRITICAL FOR FLOW)
    ------------------------------------------------------------*/
    
    private static Id getRecordType(String rtName) {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Candidate__c'
            AND Name = :rtName
            LIMIT 1
        ].Id;
    }

    /* -----------------------------------------------------------
       ✅ TEST DATA — CANDIDATE CREATION
       ⚠ DO NOT SET Offer_Type__c → Flow sets it
    ------------------------------------------------------------*/

    private static Candidate__c makeCandidate(Boolean isIntern) {

        Id rtId = isIntern 
            ? getRecordType('Intern Candidate')
            : getRecordType('On Role Candidate');

        Candidate__c cand = new Candidate__c(
            First_Name__c      = 'Test',
            Last_Name__c       = 'User',
            Personal_Email__c  = 'testuser@mail.com',
            Phone_No__c        = '9876543210',
            Designations__c    = 'Software Engineer',
            Department__c      = 'IT',
            Date_of_Birth__c   = Date.newInstance(1990, 1, 1),
            Joining_Date__c    = Date.today(),
            Father_Name__c     = 'Parent Name',
            Aadhar_Card_Number__c = '123456789012',
            RecordTypeId       = rtId
        );

        insert cand;
        return cand;
    }

    /* -----------------------------------------------------------
       ✅ SALARY DATA
       ⚠ DO NOT SET FORMULA FIELDS
    ------------------------------------------------------------*/

    private static Salary_Details__c makeSalary(Id candidateId) {

        Salary_Details__c sal = new Salary_Details__c(
            Candidate__c = candidateId
        );

        insert sal;
        return sal;
    }

    /* -----------------------------------------------------------
       ✅ RESPONSIBILITY DATA
    ------------------------------------------------------------*/

    private static void makeResponsibilities(Id candidateId) {

        Role_Category__c role = new Role_Category__c(
            Name = 'Developer',
            Is_Active__c = true
        );
        insert role;

        insert new List<Person_Responsibility__c>{

            new Person_Responsibility__c(
                Candidate__c = candidateId,
                Role_Category__c = role.Id,
                Responsibility_Text__c = 'Write Code',
                Sequence__c = 1,
                Is_Selected__c = true
            ),
            new Person_Responsibility__c(
                Candidate__c = candidateId,
                Role_Category__c = role.Id,
                Responsibility_Text__c = 'Fix Bugs',
                Sequence__c = 2,
                Is_Selected__c = true
            )
        };
    }

    /* -----------------------------------------------------------
       ✅ TEST — ON ROLE OFFER ⭐⭐⭐⭐⭐
    ------------------------------------------------------------*/

    @IsTest
    static void testOnRoleOffer_FULLCoverage() {

        Candidate__c cand = makeCandidate(false);

        makeSalary(cand.Id);
        makeResponsibilities(cand.Id);

        Test.startTest();

        PageReference pr = new PageReference('/apex/Dummy');
        pr.getParameters().put('id', cand.Id);
        Test.setCurrentPage(pr);

        OfferLetterController ctrl = new OfferLetterController();

        /* ✅ Offer Type Assertions */

        System.assert(ctrl.getIsOnRoleOffer(), 'Should be On Role');
        System.assert(!ctrl.getIsInternOffer(), 'Should NOT be Intern');

        /* ✅ Salary Assertions */

        System.assertNotEquals(null, ctrl.salaryDetails);

        String compHtml = ctrl.getCompensationTableHTML();
        System.assert(compHtml.contains('Gross Salary'));
        System.assert(compHtml.contains('Net Salary'));

        /* ✅ Responsibility Grouping Assertions */

        System.assertNotEquals(null, ctrl.groupedResponsibilities);
        System.assertEquals(1, ctrl.groupedResponsibilities.size());

        /* ✅ Roles Table Assertions ⭐⭐⭐⭐⭐ */

        String rolesHtml = ctrl.getRolesTableHTML();

        System.assert(rolesHtml.contains('Developer'));
        System.assert(rolesHtml.contains('1. Write Code'));
        System.assert(rolesHtml.contains('2. Fix Bugs'));

        /* ✅ Aadhar Masking */

        System.assertEquals('XXXX XXXX 9012', ctrl.getFormattedAadhar());

        Test.stopTest();
    }

    /* -----------------------------------------------------------
       ✅ TEST — INTERN OFFER ⭐⭐⭐⭐⭐
    ------------------------------------------------------------*/

    @IsTest
    static void testInternOffer_BRANCHCoverage() {

        Candidate__c cand = makeCandidate(true);

        Test.startTest();

        PageReference pr = new PageReference('/apex/Dummy');
        pr.getParameters().put('id', cand.Id);
        Test.setCurrentPage(pr);

        OfferLetterController ctrl = new OfferLetterController();

        /* ✅ Stable Assertions */

        System.assert(ctrl.getIsInternOffer(), 'Should be Intern');
        System.assert(!ctrl.getIsOnRoleOffer(), 'Should NOT be On Role');

        /* ✅ Null Safe Branches */

        System.assertEquals(null, ctrl.salaryDetails);

        String compHtml = ctrl.getCompensationTableHTML();
        System.assert(compHtml.contains('Compensation details are not available'));

        String rolesHtml = ctrl.getRolesTableHTML();
        System.assert(rolesHtml.contains('Role and responsibility details are not available'));

        Test.stopTest();
    }

    /* -----------------------------------------------------------
       ✅ TEST — AADHAR NULL SAFE ⭐⭐⭐⭐⭐
    ------------------------------------------------------------*/

    @IsTest
    static void testAadharNullSafe() {

        Candidate__c cand = makeCandidate(false);

        cand.Aadhar_Card_Number__c = null;
        update cand;

        Test.startTest();

        PageReference pr = new PageReference('/apex/Dummy');
        pr.getParameters().put('id', cand.Id);
        Test.setCurrentPage(pr);

        OfferLetterController ctrl = new OfferLetterController();

        System.assertEquals('XXXX XXXX XXXX', ctrl.getFormattedAadhar());

        Test.stopTest();
    }
}