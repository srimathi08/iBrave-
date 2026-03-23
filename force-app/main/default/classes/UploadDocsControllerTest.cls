@isTest
public class UploadDocsControllerTest {

    @isTest
    public static void testUpdatePhotoOnAccount() {

        // 1️⃣ Create Test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // 2️⃣ Create a fake ContentVersion (this auto-creates ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'TestPhoto',
            PathOnClient = 'TestPhoto.png',
            VersionData = Blob.valueOf('fake image data'),
            IsMajorVersion = true
        );
        insert cv;

        // After inserting ContentVersion, we must query the ContentDocumentId
        cv = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id
        ];

        String contentDocId = cv.ContentDocumentId;

        // 3️⃣ Call Apex Method
        Test.startTest();
        UploadDocsController.updatePhotoOnAccount(acc.Id, contentDocId);
        Test.stopTest();

        // 4️⃣ Validate Account field updated
        Account updatedAcc = [
            SELECT Image__c 
            FROM Account 
            WHERE Id = :acc.Id
        ];

        System.assertNotEquals(null, updatedAcc.Image__c, 'Image__c should not be null');
        System.assert(
            updatedAcc.Image__c.contains('/sfc/servlet.shepherd/document/download/' + contentDocId),
            'Image__c should contain correct image URL'
        );
        System.assert(
            updatedAcc.Image__c.contains('<img'),
            'Rich text should contain the IMG tag'
        );
    }
}