@IsTest
private class AppointmentLetterControllerTest {

    // Helper to create a Contact
    private static Contact createContact() {
        Contact c = new Contact(
             LastName = 'TestUser ' + Datetime.now().getTime(),   // make name unique
            Email    = 'test' + Datetime.now().getTime() + '@example.com'
        );
        insert c;
        return c;
    }

    // Helper to create Salary Details for a contact
    private static Salary_Details__c createSalary(Contact c) {
        Salary_Details__c sal = new Salary_Details__c(
            Contact__c = c.Id,
            Other_Basic__c                      = 200,
            Annual_CTC__c                       = 250000
        );
        insert sal;
        return sal;
    }

  @IsTest
    static void testConstructorHappyPath() {
        Contact c = createContact();
        Salary_Details__c sal = createSalary(c);

        PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        AppointmentLetterController ctrl = new AppointmentLetterController(sc);
        Test.stopTest();

        System.assertEquals(false, ctrl.hasError);
        System.assertEquals(c.Id, ctrl.contact.Id);
        System.assertEquals(sal.Id, ctrl.salaryDetail.Id);
    }
    @IsTest
    static void testConstructorInvalidId() {
        // No id parameter
        PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
        // do NOT put id param
        Test.setCurrentPage(pageRef);

        // StandardController still needs an sObject instance
        Contact dummy = new Contact(LastName = 'Dummy');
        ApexPages.StandardController sc = new ApexPages.StandardController(dummy);

        Test.startTest();
        AppointmentLetterController ctrl = new AppointmentLetterController(sc);
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError, 'hasError should be true when id is null');
        System.assertEquals('Invalid Contact ID.', ctrl.errorMessage);
        System.assertEquals(null, ctrl.contact);
        System.assertEquals(null, ctrl.salaryDetail);
    }

    @IsTest
    static void testConstructorNoSalaryDetails() {
        Contact c = createContact(); // contact without salary

        PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        AppointmentLetterController ctrl = new AppointmentLetterController(sc);
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError, 'hasError should be true when salary missing');
        System.assert(ctrl.errorMessage.contains('Salary Details are missing'),
                      'Error message should indicate missing salary');
        System.assertNotEquals(null, ctrl.contact, 'Contact is still queried even if salary missing');
        System.assertEquals(null, ctrl.salaryDetail, 'No salaryDetail should be set');
    }
}