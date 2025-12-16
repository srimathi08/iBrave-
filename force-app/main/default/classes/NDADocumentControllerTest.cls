@IsTest
private class NDADocumentControllerTest {

    @IsTest
    static void testConstructorWithId() {
        // Test data
        Contact c = new Contact(
            LastName = 'Test User',
            Email    = 'test@example.com'
        );
        insert c;

        // Simulate opening the VF page with ?id=CONTACTID
        PageReference pageRef = new PageReference('/apex/NDADocumentPage'); // name doesn't matter in test
        pageRef.getParameters().put('id', c.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        NDADocumentController ctrl = new NDADocumentController(sc);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.contact, 'Contact should be loaded');
        System.assertEquals(c.Id, ctrl.contact.Id, 'Loaded contact Id should match');
    }

    @IsTest
    static void testConstructorWithoutId() {
        // No id parameter set on page
        PageReference pageRef = new PageReference('/apex/NDADocumentPage');
        Test.setCurrentPage(pageRef);

        // Use a dummy contact for the StandardController
        Contact c = new Contact(LastName = 'Dummy');
        ApexPages.StandardController sc = new ApexPages.StandardController(c);

        Test.startTest();
        NDADocumentController ctrl = new NDADocumentController(sc);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.contact, 'Contact property should be initialized');
        System.assertEquals(null, ctrl.contact.Id, 'Contact should be a new instance when no id is passed');
    }
}