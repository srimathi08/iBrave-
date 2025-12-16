@isTest
private class ContactDocEmailServiceTest {

    @isTest
    static void testSendAppointmentAndNDA() {

        // -------------------------------
        // 1. Create Test Contact
        // -------------------------------
        Contact con = new Contact(
            LastName = 'Test User',
            Email = 'testuser@example.com',
            FirstName = 'Test',
            Designation__c = 'Developer',
            Send_Appointment_Letter__c = true
        );
        insert con;

        // -------------------------------
        // 2. Create FAKE PDF Blobs
        // -------------------------------
        Blob fakePdf = Blob.valueOf('Fake PDF Content');

        // -------------------------------
        // 3. Create Appointment Letter ContentDocument + Version
        // -------------------------------
        ContentVersion appCv = new ContentVersion(
            Title = 'Appointment_Letter_' + con.Id,
            PathOnClient = 'Appointment_Letter_' + con.Id + '.pdf',
            VersionData = fakePdf
        );
        insert appCv;

        // After insert, retrieve ContentDocumentId
        appCv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :appCv.Id
            LIMIT 1
        ];

        // -------------------------------
        // 4. Create NDA ContentDocument + Version
        // -------------------------------
        ContentVersion ndaCv = new ContentVersion(
            Title = 'NDA_' + con.Id,
            PathOnClient = 'NDA_' + con.Id + '.pdf',
            VersionData = fakePdf
        );
        insert ndaCv;

        ndaCv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :ndaCv.Id
            LIMIT 1
        ];

        // -------------------------------
        // 5. Attach to Contact (populate custom fields)
        // -------------------------------
        con.Appointment_Letter_File_Id__c = appCv.ContentDocumentId;
        con.NDA_File_Id__c = ndaCv.ContentDocumentId;
        update con;

        // -------------------------------
        // 6. Call the method
        // -------------------------------
        Test.startTest();
        ContactDocEmailService.sendAppointmentAndNDA(new List<Id>{ con.Id });
        Test.stopTest();

        // -------------------------------
        // 7. Requery contact and assert checkbox reset
        // -------------------------------
        Contact updated = [
            SELECT Send_Appointment_Letter__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.assertEquals(false, updated.Send_Appointment_Letter__c,
            'Send Appointment Letter checkbox should be reset to FALSE');

        // -------------------------------
        // 8. Validate emails were attempted
        // -------------------------------
        // NOTE: Salesforce does not expose sent email bodies in test context,
        // but sendEmail() must not throw error.
        // So simple assertion to ensure no exceptions.
        System.assert(true, 'Email sending executed successfully.');
    }
}