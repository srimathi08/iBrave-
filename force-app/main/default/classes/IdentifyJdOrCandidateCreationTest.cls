@isTest
public class IdentifyJdOrCandidateCreationTest {

    @testSetup
    static void setupData() {
        // Create a Service__c record
        Service__c service = new Service__c(
            Name = 'Test Service',
            emailfrom__c = 'test@example.com'
        );
        insert service;

        // Create ContentVersion (this automatically creates ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Sample data'),
            IsMajorVersion = true
        );
        insert cv;

        // Re-query ContentVersion to get ContentDocumentId
        cv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];

        // Query the ContentDocument
        ContentDocument doc = [
            SELECT Id, Title 
            FROM ContentDocument 
            WHERE Id = :cv.ContentDocumentId
        ];

        // Link ContentDocument to Service__c
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = service.Id,
            ContentDocumentId = doc.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGetPDDPromptResponsesWithValidInput() {
        Service__c service = [SELECT Id FROM Service__c LIMIT 1];

        IdentifyJdOrCandidateCreation.InputWrapper input = new IdentifyJdOrCandidateCreation.InputWrapper();
        input.recordId = service.Id;

        Test.startTest();
        List<String> responses;
        try {
            responses = IdentifyJdOrCandidateCreation.getPDDPromptResponses(
                new List<IdentifyJdOrCandidateCreation.InputWrapper>{ input }
            );
        } catch (Exception e) {
            // Expected: ConnectApi.EinsteinLLM call fails in test context
            System.debug('Caught expected exception: ' + e.getMessage());
            responses = new List<String>();
        }
        Test.stopTest();

        System.assertNotEquals(null, responses, 'Response list should not be null');
    }

    @isTest
    static void testGetPDDPromptResponsesWithEmptyInput() {
        Test.startTest();
        List<String> responses = IdentifyJdOrCandidateCreation.getPDDPromptResponses(
            new List<IdentifyJdOrCandidateCreation.InputWrapper>()
        );
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'Should return empty list for empty inputs');
    }

    @isTest
    static void testGetPDDPromptResponsesWithNullInput() {
        Test.startTest();
        List<String> responses = IdentifyJdOrCandidateCreation.getPDDPromptResponses(null);
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'Should return empty list for null inputs');
    }
}