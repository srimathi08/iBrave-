@IsTest
private class AppointmentLetterPDFGeneratorTest {

    // Helper: create a Contact with email
    private static Contact createContactWithEmail() {
        Contact c = new Contact(
            LastName = 'TestUser ' + Datetime.now().getTime(),
            Email    = 'appttest' + Datetime.now().getTime() + '@example.com'
        );
        insert c;
        return c;
    }

    // Helper: create a Contact without email (to hit skip branch)
    private static Contact createContactWithoutEmail() {
        Contact c = new Contact(
            LastName = 'NoEmail ' + Datetime.now().getTime()
        );
        insert c;
        return c;
    }

    @IsTest
    static void testGenerateAppointmentLettersHappyPath() {
        // Test data
        Contact withEmail = createContactWithEmail();
        Contact noEmail   = createContactWithoutEmail();

        // IMPORTANT: avoid calling getContentAsPDF in test.
        // Use Test.setFixedSearchResults to bypass page rendering is not possible,
        // so instead use Test.isRunningTest() guard in the production code *if* needed.
        // For now, we call the method and assert it does not error.

        List<Id> ids = new List<Id>{ withEmail.Id, noEmail.Id };

        Test.startTest();
        AppointmentLetterPDFGenerator.generateAppointmentLetters(ids);
        Test.stopTest();

        // Contact without email should be skipped; with email should produce at least one email.
        // We cannot assert on Messaging.sendEmail directly, but we can assert that a ContentVersion was created.
        Integer fileCount = [
            SELECT count()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :withEmail.Id
        ];
        System.assertEquals(1, fileCount, 'One PDF file should be stored for the contact with email');
    }

    @IsTest
    static void testGenerateAppointmentLettersEmptyList() {
        Test.startTest();
        // Should simply return without error
        AppointmentLetterPDFGenerator.generateAppointmentLetters(new List<Id>());
        Test.stopTest();

        // No ContentVersion should have been inserted
        Integer cvCount = [SELECT count() FROM ContentVersion];
        System.assertEquals(0, cvCount, 'No files should be created for empty input list');
    }

    @IsTest
    static void testGenerateAppointmentLettersNullList() {
        Test.startTest();
        // Null input should be safely ignored
        AppointmentLetterPDFGenerator.generateAppointmentLetters(null);
        Test.stopTest();

        Integer cvCount = [SELECT count() FROM ContentVersion];
        System.assertEquals(0, cvCount, 'No files should be created for null input');
    }
}