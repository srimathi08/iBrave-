@isTest
public class JD_AttachmentControllerTest {

    @testSetup
    static void setupData() {
        // Minimal Service__c record for testing
        Service__c svc = new Service__c(
            Name = 'Test Service',
            emailfrom__c = 'test@example.com'
        );
        insert svc;
    }

    @isTest
    static void testCreateParent() {
        Test.startTest();
        String idStr = JD_AttachmentController.createParent('ParentTestFile');
        Test.stopTest();

        System.assertNotEquals(null, idStr, 'createParent should return a new Service__c Id');
        Service__c svc = [SELECT Id, Name FROM Service__c WHERE Id = :idStr];
        System.assertEquals('ParentTestFile', svc.Name);
    }

    @isTest
    static void testUploadFile() {
        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];
        String recordId = svc.Id;

        // Create dummy base64 string ("Hello World")
        String base64 = EncodingUtil.base64Encode(Blob.valueOf('Hello World'));

        Test.startTest();
        String cdlId = JD_AttachmentController.uploadFile(base64, 'MyFile.txt', recordId);
        Test.stopTest();

        System.assertNotEquals(null, cdlId, 'uploadFile should return a ContentDocumentLink Id');

        ContentDocumentLink cdl = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE Id = :cdlId];
        System.assertEquals(recordId, cdl.LinkedEntityId, 'File should be linked to the Service__c');
    }

   @isTest
static void testUploadFileWithNulls() {
    Test.startTest();
    // Use invalid string instead of null → will fail insert gracefully and return null
    String cdlId = JD_AttachmentController.uploadFile('invalid', 'NoData.txt', null);
    Test.stopTest();

    System.assertEquals(null, cdlId, 'uploadFile should return null if inputs are invalid');
}


    @isTest
    static void testGetPromptThrowsHandledException() {
        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        Boolean caught = false;
        try {
            Test.startTest();
            JD_AttachmentController.getPrompt(svc.Id);
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            caught = true;
           // System.assert(ahe.getMessage().contains('Error while generating prompt'),'Expected AuraHandledException from getPrompt');
        }

        System.assertEquals(true, caught, 'Expected getPrompt to throw AuraHandledException');
    }
}