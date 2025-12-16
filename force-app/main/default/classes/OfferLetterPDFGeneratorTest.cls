@IsTest
private class OfferLetterPDFGeneratorTest {

    // Insert a sample candidate record
    private static Candidate__c createCandidate() {
        Candidate__c cand = new Candidate__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Personal_Email__c = 'john.doe@test.com'
        );
        insert cand;
        return cand;
    }

    // ----------------------------------------------------
    // TEST 1: Ensure token generator returns 32-char string
    // ----------------------------------------------------
    @IsTest
    static void test_generateUniqueToken() {
        Test.startTest();
        String token = OfferLetterPDFGenerator.generateUniqueToken();
        Test.stopTest();

        System.assertNotEquals(null, token, 'Token must not be null');
        System.assertEquals(32, token.length(), 'Token must be exactly 32 characters');
    }


    // ----------------------------------------------------
    // TEST 2: Full Offer Letter Generation flow
    // ----------------------------------------------------
    @IsTest
    static void test_generateOfferLetter() {

        Candidate__c cand = createCandidate();

        Test.startTest();
        OfferLetterPDFGenerator.generateOfferLetter(new List<Id>{ cand.Id });
        Test.stopTest();


        // Reload updated candidate
        Candidate__c updatedCand = [
            SELECT
                Offer_Letter_Status__c,
                Offer_Letter_Document_Id__c,
                Offer_Letter_Doc_Link__c,
                Offer_Acceptance_Token__c,
                Offer_Acceptance_URL__c,
                Onboarding_Status__c
            FROM Candidate__c
            WHERE Id = :cand.Id
        ];

        // Assertions
        System.assertEquals('Generated', updatedCand.Offer_Letter_Status__c, 'Status should be set to Generated');
        System.assertNotEquals(null, updatedCand.Offer_Letter_Document_Id__c, 'Document Id must be set');
        System.assertNotEquals(null, updatedCand.Offer_Letter_Doc_Link__c, 'Public PDF link must be set');
        System.assertNotEquals(null, updatedCand.Offer_Acceptance_Token__c, 'Token must be set');
        System.assertEquals(32, updatedCand.Offer_Acceptance_Token__c.length(), 'Token length should be 32');
        System.assert(updatedCand.Offer_Acceptance_URL__c.contains(updatedCand.Offer_Acceptance_Token__c),
                       'Acceptance URL must include the token');
        System.assertEquals('Not Started', updatedCand.Onboarding_Status__c, 'Onboarding status must be Not Started');


        // Validate ContentVersion created
        ContentVersion cv = [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE FirstPublishLocationId = :cand.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, cv.ContentDocumentId, 'ContentDocumentId must exist');


        // Validate ContentDistribution created
        ContentDistribution cd = [
            SELECT Id, ContentVersionId, ContentDownloadUrl
            FROM ContentDistribution
            WHERE ContentVersionId = :cv.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, cd.ContentDownloadUrl, 'Public PDF URL must exist');
    }
}