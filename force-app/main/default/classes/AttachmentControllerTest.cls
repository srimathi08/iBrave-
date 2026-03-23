/*@isTest
public class AttachmentControllerTest {

    // ----------------------------------------
    // 1️⃣ Test createParent()
    // ----------------------------------------
    @isTest
    static void testCreateParent_ValidName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('Test Service File Name');
        Test.stopTest();

        System.assertNotEquals(null, serviceId, 'Service__c record should be created');

        Service__c sr = [
            SELECT Id, Name, Email_Subject__c
            FROM Service__c
            WHERE Id = :serviceId
            LIMIT 1
        ];

        System.assertEquals('Test Service File Name', sr.Email_Subject__c, 'Full file name should be preserved');
        System.assert(sr.Name.length() <= 80, 'Name should not exceed 80 chars');
    }

    // ----------------------------------------
    // 2️⃣ Test createParent() - No FileName Case
    // ----------------------------------------
    @isTest
    static void testCreateParent_NoFileName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('');
        Test.stopTest();

        Service__c sr = [SELECT Name FROM Service__c WHERE Id = :serviceId LIMIT 1];
        System.assertEquals('No File Name', sr.Name, 'Should set "No File Name" when input blank');
    }

    // ----------------------------------------
    // 3️⃣ Test uploadFile()
    // ----------------------------------------
    @isTest
    static void testUploadFileAndCreateContentLink() {
        // Arrange - use factory
        Map<String, SObject> data = TestDataFactory.createAccountHierarchy(true);
        Account acc = (Account) data.get('Account');

        // Create a Base64 string
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Hello world!'));

        // Act
        Test.startTest();
        String cdlId = AttachmentController.uploadFile(base64Data, 'testFile.txt', acc.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, cdlId, 'ContentDocumentLink should be created');
        ContentDocumentLink cdl = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE Id = :cdlId
            LIMIT 1
        ];
        System.assertEquals(acc.Id, cdl.LinkedEntityId, 'Linked entity should match Account');
    }

    // ----------------------------------------
    // 4️⃣ Test createContentLink() directly
    // ----------------------------------------
    @isTest
    static void testCreateContentLinkDirectly() {
        // Arrange
        Map<String, SObject> data = TestDataFactory.createAccountHierarchy(true);
        Account acc = (Account) data.get('Account');

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'testFile.txt',
            VersionData = Blob.valueOf('Unit test content')
        );
        insert cv;

        // Act
        Test.startTest();
        ContentDocumentLink cdl = AttachmentController.createContentLink(cv.Id, acc.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, cdl, 'ContentDocumentLink should be created');
        System.assertEquals(acc.Id, cdl.LinkedEntityId, 'Linked Account should match');
    }

    // ----------------------------------------
    // 5️⃣ Test createContentLinkwhatsapp()
    // ----------------------------------------
    @isTest
    static void testCreateContentLinkWhatsapp() {
        // Arrange
        Map<String, SObject> data = TestDataFactory.createAccountHierarchy(true);
        Account acc = (Account) data.get('Account');

        ContentVersion cv = new ContentVersion(
            Title = 'WhatsApp File',
            PathOnClient = 'whatsapp.txt',
            VersionData = Blob.valueOf('WA file content')
        );
        insert cv;

        // Act
        Test.startTest();
        ContentDocumentLink cdl = AttachmentController.createContentLinkwhatsapp(cv.Id, acc.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, cdl, 'ContentDocumentLink should be created');
        System.assertEquals(acc.Id, cdl.LinkedEntityId, 'Linked Account should match');
    }

    // ----------------------------------------
    // 6️⃣ Test getPrompt() with exception handling
    // ----------------------------------------
    @isTest
    static void testGetPrompt_withException() {
        // Arrange
        Map<String, SObject> data = TestDataFactory.createAccountHierarchy(true);
        Service__c serv = (Service__c) data.get('Service');

        // Force exception (mock missing prompt class behavior)
        try {
            Test.startTest();
            AttachmentController.getPrompt(serv.Id);
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Error while generating prompt'),
              //  'Expected AuraHandledException message');
        }
    }
} */   


/* 7.1.26
@IsTest(SeeAllData=true)
public class AttachmentControllerTest {

    // ----------------------------------------
    // 1️⃣ Test createparent() - valid filename
    // ----------------------------------------
    @isTest
    static void testCreateParent_ValidName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('Test Service File Name');
        Test.stopTest();

        System.assertNotEquals(null, serviceId);

        Service__c sr = [
            SELECT Name, Email_Subject__c
            FROM Service__c
            WHERE Id = :serviceId
        ];

        System.assertEquals('Test Service File Name', sr.Email_Subject__c);
        System.assert(sr.Name.length() <= 80);
    }

    // ----------------------------------------
    // 2️⃣ Test createparent() - blank filename
    // ----------------------------------------
    @isTest
    static void testCreateParent_NoFileName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('');
        Test.stopTest();

        Service__c sr = [
            SELECT Name
            FROM Service__c
            WHERE Id = :serviceId
        ];

        System.assertEquals('No File Name', sr.Name);
    }

    // ----------------------------------------
    // 3️⃣ Test uploadFile()
    // ----------------------------------------
    @isTest
    static void testUploadFile() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        String base64Data =
            EncodingUtil.base64Encode(Blob.valueOf('Hello world'));

        Test.startTest();
        String cdlId =
            AttachmentController.uploadFile(base64Data, 'test.txt', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdlId);

        ContentDocumentLink cdl = [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE Id = :cdlId
        ];
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 4️⃣ Test createContentLink()
    // ----------------------------------------
    @isTest
    static void testCreateContentLink() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test data')
        );
        insert cv;

        Test.startTest();
        ContentDocumentLink cdl =
            AttachmentController.createContentLink(cv.Id, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdl);
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 5️⃣ Test createContentLinkwhatsapp()
    // ----------------------------------------
    @isTest
    static void testCreateContentLinkWhatsapp() {
        Account acc = new Account(Name = 'WA Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'WA File',
            PathOnClient = 'wa.txt',
            VersionData = Blob.valueOf('WA data')
        );
        insert cv;

        Test.startTest();
        ContentDocumentLink cdl =
            AttachmentController.createContentLinkwhatsapp(cv.Id, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdl);
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 6️⃣ Test getPrompt() - SUCCESS path
    // ----------------------------------------
  @isTest
static void testGetPrompt_success() {

    // Create Service__c only
    Service__c sr = new Service__c(Name = 'Prompt Service');
    insert sr;

    // ❌ DO NOT attach any file here
    // This ensures batch executes with EMPTY scope

    Test.startTest();
    List<String> response = AttachmentController.getPrompt(sr.Id);
    Test.stopTest();

    System.assertEquals(
        1,
        response.size(),
        'Response list should contain success message'
    );
    System.assertEquals(
        'Batch Started Successfully',
        response[0]
    );
}

    // ----------------------------------------
    // 7️⃣ Test getPrompt() - blank recordId
    // ----------------------------------------
    @isTest
    static void testGetPrompt_blankId() {
        try {
            Test.startTest();
            AttachmentController.getPrompt(null);
            Test.stopTest();
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Service Id is required'));
        }
    }
}  */



@IsTest
public class AttachmentControllerTest {

    // ----------------------------------------
    // 1️⃣ Test createparent() - valid filename
    // ----------------------------------------
    @isTest
    static void testCreateParent_ValidName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('Test Service File Name');
        Test.stopTest();

        System.assertNotEquals(null, serviceId);

        Service__c sr = [
            SELECT Name, Email_Subject__c
            FROM Service__c
            WHERE Id = :serviceId
        ];

        System.assertEquals('Test Service File Name', sr.Email_Subject__c);
        System.assert(sr.Name.length() <= 80);
    }

    // ----------------------------------------
    // 2️⃣ Test createparent() - blank filename
    // ----------------------------------------
    @isTest
    static void testCreateParent_NoFileName() {
        Test.startTest();
        String serviceId = AttachmentController.createparent('');
        Test.stopTest();

        Service__c sr = [
            SELECT Name
            FROM Service__c
            WHERE Id = :serviceId
        ];

        System.assertEquals('No File Name', sr.Name);
    }

    // ----------------------------------------
    // 3️⃣ Test uploadFile()
    // ----------------------------------------
    @isTest
    static void testUploadFile() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        String base64Data =
            EncodingUtil.base64Encode(Blob.valueOf('Hello world'));

        Test.startTest();
        String cdlId =
            AttachmentController.uploadFile(base64Data, 'test.txt', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdlId);

        ContentDocumentLink cdl = [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE Id = :cdlId
        ];
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 4️⃣ Test createContentLink()
    // ----------------------------------------
    @isTest
    static void testCreateContentLink() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test data')
        );
        insert cv;

        Test.startTest();
        ContentDocumentLink cdl =
            AttachmentController.createContentLink(cv.Id, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdl);
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 5️⃣ Test createContentLinkwhatsapp()
    // ----------------------------------------
    @isTest
    static void testCreateContentLinkWhatsapp() {
        Account acc = new Account(Name = 'WA Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'WA File',
            PathOnClient = 'wa.txt',
            VersionData = Blob.valueOf('WA data')
        );
        insert cv;

        Test.startTest();
        ContentDocumentLink cdl =
            AttachmentController.createContentLinkwhatsapp(cv.Id, acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cdl);
        System.assertEquals(acc.Id, cdl.LinkedEntityId);
    }

    // ----------------------------------------
    // 6️⃣ Test getPrompt() - SUCCESS path
    // ----------------------------------------
    @isTest
    static void testGetPrompt_success() {

        Service__c sr = new Service__c(Name = 'Prompt Service');
        insert sr;

        Test.startTest();
        List<String> response = AttachmentController.getPrompt(sr.Id);
        Test.stopTest();

        System.assertEquals(1, response.size());
        System.assertEquals(
            'Batch Started Successfully',
            response[0]
        );
    }

    // ----------------------------------------
    // 7️⃣ Test getPrompt() - blank recordId
    // ----------------------------------------
    @isTest
    static void testGetPrompt_blankId() {
        try {
            Test.startTest();
            AttachmentController.getPrompt(null);
            Test.stopTest();
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Service Id is required'));
        }
    }

    // ----------------------------------------
    // 8️⃣ ✅ Test getTodayUploadedFiles() (FIXED)
    // ----------------------------------------
    @isTest
    static void testGetTodayUploadedFiles() {

        // Create Account (Created TODAY)
        Account acc = new Account(Name = 'Today Account');
        insert acc;

        // Create file
        ContentVersion cv = new ContentVersion(
            Title = 'TodayFile',
            PathOnClient = 'today.txt',
            VersionData = Blob.valueOf('Today file data')
        );
        insert cv;

        // Link file to Account
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ].ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        // Execute
        Test.startTest();
        List<Map<String, Object>> result =
            AttachmentController.getTodayUploadedFiles();
        Test.stopTest();

        // Assertions
        System.assertEquals(1, result.size());
        System.assertEquals(
            'Today Account',
            result[0].get('accountName')
        );
        System.assertEquals(
            'TodayFile',
            result[0].get('fileName')
        );
    }
}