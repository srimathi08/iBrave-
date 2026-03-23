@IsTest
private class AppointmentLetterControllerTest {

    // Helper to create a Contact
    private static Contact createContact() {
        Contact c = new Contact(
            LastName = 'TestUser_' + Datetime.now().getTime(),
            Email    = 'test' + Datetime.now().getTime() + '@example.com'
        );
        insert c;
        return c;
    }

    // Helper to create Salary Details for a Contact
    private static Salary_Details__c createSalary(Contact c) {
        Salary_Details__c sal = new Salary_Details__c(
            Contact__c = c.Id,
            Gross_Salary__C = 250000,         
            Health_Policy_Insurance__c = 5000,
            Variable_Pay__c = 25000
            
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
        System.assertEquals(sal.Id, ctrl.salaryDetails.Id);
    }

    @IsTest
    static void testConstructorInvalidId() {
        PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
        Test.setCurrentPage(pageRef); // No ID passed

        Contact dummy = new Contact(LastName = 'Dummy');
        ApexPages.StandardController sc = new ApexPages.StandardController(dummy);

        Test.startTest();
        AppointmentLetterController ctrl = new AppointmentLetterController(sc);
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError);
        System.assertEquals('Invalid Contact ID.', ctrl.errorMessage);
        System.assertEquals(null, ctrl.contact);
        System.assertEquals(null, ctrl.salaryDetails);
    }

    @IsTest
    static void testConstructorNoSalaryDetails() {
        Contact c = createContact(); // Contact without salary

        PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        AppointmentLetterController ctrl = new AppointmentLetterController(sc);
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError);
        System.assert(ctrl.errorMessage.contains('Salary Details are missing'));
        System.assertNotEquals(null, ctrl.contact);  // Contact queried successfully
        System.assertEquals(null, ctrl.salaryDetails);
    }
@IsTest
static void testGetCompensationTableHTML() {
    // Create contact + salary
    Contact c = createContact();
    Salary_Details__c sal = createSalary(c);

    // Set page reference
    PageReference pageRef = new PageReference('/apex/AppointmentLetterPage');
    pageRef.getParameters().put('id', c.Id);
    Test.setCurrentPage(pageRef);

    // Instantiate controller
    ApexPages.StandardController sc = new ApexPages.StandardController(c);
    AppointmentLetterController ctrl = new AppointmentLetterController(sc);

    // Call the HTML generator
    String html = ctrl.getCompensationTableHTML();

    // Assertions
    System.assertNotEquals(null, html, 'HTML should not be null');
    System.assert(html.contains('<table'), 'HTML must contain table tag');
    System.assert(html.contains('Variable Pay'), 'HTML must contain expected row');
    System.assert(html.contains('Cost To Company'), 'HTML must include CTC row');
}

}