@isTest
public class ContactDocSaveActionTest {

    @isTest
    static void testSaveDocs() {

        // -------- 1. Create test Contact --------
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;

        // -------- 2. Fake Base64 PDF content --------
        Blob fakePdf = Blob.valueOf('This is a test PDF');
        String fakeBase64 = EncodingUtil.base64Encode(fakePdf);

        // -------- 3. Prepare SaveInput for Invocable method --------
        ContactDocSaveAction.SaveInput input = new ContactDocSaveAction.SaveInput();
        input.contactId = con.Id;
        input.appointmentFileName = 'Appointment_Letter_' + con.Id + '.pdf';
        input.ndaFileName = 'NDA_' + con.Id + '.pdf';
        input.appointmentBase64 = fakeBase64;
        input.ndaBase64 = fakeBase64;

        List<ContactDocSaveAction.SaveInput> inputs =
            new List<ContactDocSaveAction.SaveInput>{ input };

        // -------- 4. Execute method --------
        Test.startTest();
        ContactDocSaveAction.saveDocs(inputs);
        Test.stopTest();

        // -------- 5. Validate two ContentVersions inserted --------
        List<ContentVersion> cvs = [
            SELECT Id, ContentDocumentId, FirstPublishLocationId, PathOnClient
            FROM ContentVersion
            WHERE FirstPublishLocationId = :con.Id
        ];

        System.assertEquals(2, cvs.size(), 'Two ContentVersion records expected');

        // -------- 6. Re-query Contact to verify file IDs updated --------
        Contact updated = [
            SELECT Appointment_Letter_File_Id__c,
                   NDA_File_Id__c
            FROM Contact
            WHERE Id = :con.Id
            LIMIT 1
        ];

        System.assertNotEquals(null, updated.Appointment_Letter_File_Id__c,
            'Appointment file ID should be stored in Contact');

        System.assertNotEquals(null, updated.NDA_File_Id__c,
            'NDA file ID should be stored in Contact');
    }
}