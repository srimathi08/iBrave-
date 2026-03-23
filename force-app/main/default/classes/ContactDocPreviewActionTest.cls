@isTest
public class ContactDocPreviewActionTest {

    @isTest
    static void testPreviewDocs() {

        // 1. Create test data
        Contact con = new Contact(
             FirstName = 'Test',
            LastName  = 'User'
        );
        insert con;

        // 2. Create input for the Invocable method
        ContactDocPreviewAction.PreviewInput input =
            new ContactDocPreviewAction.PreviewInput();
        input.contactId = con.Id;

        List<ContactDocPreviewAction.PreviewInput> inputs =
            new List<ContactDocPreviewAction.PreviewInput>{ input };

        // 3. Execute method
        Test.startTest();
        List<ContactDocPreviewAction.PreviewResult> results =
            ContactDocPreviewAction.previewDocs(inputs);
        Test.stopTest();

        // 4. Validate results
        System.assertEquals(1, results.size(), 'Should return one result');

        ContactDocPreviewAction.PreviewResult res = results[0];

         System.assert( res.appointmentFileName.contains('Test User'),
            'Appointment file name should include contact name');

        System.assert(res.ndaFileName.contains('Test User'),
            'NDA file name should include contact name');

        System.assertNotEquals(null,
            res.appointmentBase64, 'Appointment Base64 should not be null');

        System.assertNotEquals(null,
            res.ndaBase64, 'NDA Base64 should not be null');
    }
}