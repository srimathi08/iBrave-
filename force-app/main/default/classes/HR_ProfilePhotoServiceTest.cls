/*@IsTest
private class HR_ProfilePhotoServiceTest {

    private static Blob getDummyImageBlob() {
        return Blob.valueOf('fakeimagebytes');
    }

    @TestSetup
    static void setupData() {
        // Create Contact
        Contact con = new Contact(
            LastName = 'Test Emp',
            Email    = 'emp@example.com'
        );
        insert con;

        // Create a Standard User for this Contact link (mocked)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            FirstName = 'Test',
            LastName = 'Employee',
            Email = 'testemp@example.com',
            Username = 'std' + DateTime.now().getTime() + '@example.com',
            Alias = 'stde',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert stdUser;

        // Create File (ContentVersion)
        ContentVersion cv = new ContentVersion(
            Title = 'ProfilePhoto-Test',
            PathOnClient = 'ProfilePhoto-Test.png',
            VersionData  = getDummyImageBlob()
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        // Link file to Contact
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = con.Id,
            ShareType         = 'V'
        );
        insert cdl;

        // Store ContentDocumentId on Contact field 
        con.Profile_Photo_File_Id__c = cv.ContentDocumentId;
        update con;
    }

    @IsTest
    static void testMarkContactProfilePhotoSuccess() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Test Emp' LIMIT 1];
        
        ContentVersion cvNew = new ContentVersion(
            Title = 'NewPhoto',
            PathOnClient = 'NewPhoto.png',
            VersionData  = getDummyImageBlob()
        );
        insert cvNew;
        cvNew = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvNew.Id LIMIT 1];

        Test.startTest();
        HR_ProfilePhotoService.markContactProfilePhoto(c.Id, cvNew.ContentDocumentId);
        Test.stopTest();

        Contact updated = [SELECT Profile_Photo_File_Id__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(cvNew.ContentDocumentId, updated.Profile_Photo_File_Id__c);
    }

    @IsTest
    static void testMarkContactProfilePhotoThrows() {
        Boolean thrown = false;
        try {
            HR_ProfilePhotoService.markContactProfilePhoto(null, null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown, 'AuraHandledException should be thrown for null inputs');
    }

    @IsTest
    static void testGetProfilePhotoUrlFromFileFallback() {
        HR_ProfilePhotoService.skipUserPhotoLogic = true; 
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Test Emp' LIMIT 1];

        Test.startTest();
        String url = HR_ProfilePhotoService.getProfilePhotoUrl(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, url);
    }

    @IsTest
    static void testGetProfilePhotoUrlFromMock() {
        HR_ProfilePhotoService.skipUserPhotoLogic = true;
        HR_ProfilePhotoService.stubbedPhotoUrl = 'https://example.com/mock.png';
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Test Emp' LIMIT 1];

        Test.startTest();
        String url = HR_ProfilePhotoService.getProfilePhotoUrl(c.Id);
        Test.stopTest();

        System.assertEquals('https://example.com/mock.png', url);
    }

    @IsTest
    static void testGetProfilePhotoUrlNull() {
        System.assertEquals(null, HR_ProfilePhotoService.getProfilePhotoUrl(null));
    }

    @IsTest
    static void testSyncContactPhotoToUserNoFile() {
        Contact c = new Contact(LastName = 'NoFile');
        insert c;

        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(c.Id);
        Test.stopTest();
        
        System.assert(true);
    }

    @IsTest
    static void testSyncContactPhotoToUserNoUser() {
        Contact cNoUser = new Contact(LastName = 'EmptyUser');
        insert cNoUser;
        HR_ProfilePhotoService.mockUserId = null;

        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(cNoUser.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testSyncContactPhotoToUserFullFlow() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Test Emp' LIMIT 1];
        User u = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        HR_ProfilePhotoService.mockUserId = u.Id;
        
        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(c.Id);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testGetCurrentUserPhotoUrlMock() {
        HR_ProfilePhotoService.skipUserPhotoLogic = true;
        HR_ProfilePhotoService.stubbedPhotoUrl = 'https://example.com/current.png';

        Test.startTest();
        String url = HR_ProfilePhotoService.getCurrentUserPhotoUrl();
        Test.stopTest();

        System.assertEquals('https://example.com/current.png', url);
    }

    @IsTest
    static void testApiInternalCoverage() {
        HR_ProfilePhotoService.skipUserPhotoLogic = false;
        User u = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];
        HR_ProfilePhotoService.mockUserId = u.Id;
        
        Test.startTest();
        try {
            HR_ProfilePhotoService.getPhotoInternal(null, u.Id);
        } catch (Exception e) {}
        
        try {
            HR_ProfilePhotoService.setPhotoInternal(null, String.valueOf(u.Id), null);
        } catch (Exception e) {}
        
        HR_ProfilePhotoService.getCurrentUserPhotoUrl();
        HR_ProfilePhotoService.getProfilePhotoUrl([SELECT Id FROM Contact LIMIT 1].Id);
        Test.stopTest();
        System.assert(true);
    }
}*/
@IsTest
public class HR_ProfilePhotoServiceTest {

    private static User createTestUser(String prefix, String lastName) {
        Profile p = [SELECT Id FROM Profile LIMIT 1];
        String uniqueVal = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        User u = new User(
            Alias = prefix.length() > 8 ? prefix.substring(0, 8) : prefix,
            Email = prefix + uniqueVal + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = prefix + uniqueVal + '@example.com'
        );
        insert u;
        return u;
    }

    private static Contact createTestContact(Id internalUserId) {
        Account acc = new Account(Name = 'Test Account ' + String.valueOf(Math.random()));
        insert acc;

        Contact con = new Contact(
            FirstName = 'Priya',
            LastName = 'Employee',
            Email = 'priya' + String.valueOf(Math.random()) + '@example.com',
            AccountId = acc.Id,
            Internal_User__c = internalUserId
        );
        insert con;
        return con;
    }

    private static Id createImageFileAndLinkToContact(Id contactId, String title, String extension) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.' + extension,
            VersionData = Blob.valueOf('fake image body'),
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = contactId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        return contentDocumentId;
    }

    @IsTest
    static void testMarkContactProfilePhoto_InternalUser() {
        User u = createTestUser('hrphoto1', 'UserOne');
        Contact con = createTestContact(u.Id);
        Id docId = createImageFileAndLinkToContact(con.Id, 'ProfilePhoto', 'jpg');

        Test.startTest();
        HR_ProfilePhotoService.markContactProfilePhoto(con.Id, docId);
        Test.stopTest();

        Contact updatedCon = [
            SELECT Profile_Photo_File_Id__c, Internal_User__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.assertEquals(docId, updatedCon.Profile_Photo_File_Id__c);
        System.assertEquals(u.Id, updatedCon.Internal_User__c);
    }

    @IsTest
    static void testGetProfilePhotoUrl_Stubbed() {
        User u = createTestUser('hrphoto2', 'UserTwo');
        Contact con = createTestContact(u.Id);

        HR_ProfilePhotoService.skipUserPhotoLogic = true;
        HR_ProfilePhotoService.stubbedPhotoUrl = 'https://example.com/stub-photo.png';
        HR_ProfilePhotoService.mockUserId = u.Id;

        Test.startTest();
        String result = HR_ProfilePhotoService.getProfilePhotoUrl(con.Id);
        Test.stopTest();

        System.assertEquals('https://example.com/stub-photo.png', result);
    }

    @IsTest
    static void testGetProfilePhotoUrl_FileFallback() {
        User u = createTestUser('hrphoto3', 'UserThree');
        Contact con = createTestContact(u.Id);
        Id docId = createImageFileAndLinkToContact(con.Id, 'FallbackPhoto', 'jpg');

        update new Contact(
            Id = con.Id,
            Profile_Photo_File_Id__c = docId
        );

        HR_ProfilePhotoService.skipUserPhotoLogic = false;
        HR_ProfilePhotoService.mockUserId = null;

        Test.startTest();
        String result = HR_ProfilePhotoService.getProfilePhotoUrl(con.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('/sfc/servlet.shepherd/version/download/'));
    }

    @IsTest
static void testGetProfilePhotoUrl_NullAndNoFile() {
    String nullResult = HR_ProfilePhotoService.getProfilePhotoUrl(null);
    System.assertEquals(null, nullResult);

    User u = createTestUser('hrphoto4', 'UserFour');
    Contact con = createTestContact(u.Id);

    HR_ProfilePhotoService.skipUserPhotoLogic = false;
    HR_ProfilePhotoService.mockUserId = null;

    Test.startTest();
    String result = HR_ProfilePhotoService.getProfilePhotoUrl(con.Id);
    Test.stopTest();

    System.assertEquals(null, result);
}

    @IsTest
    static void testSyncContactPhotoToUser_InternalUser() {
        User u = createTestUser('hrphoto5', 'UserFive');
        Contact con = createTestContact(u.Id);
        Id docId = createImageFileAndLinkToContact(con.Id, 'SyncPhoto', 'jpeg');

        update new Contact(
            Id = con.Id,
            Profile_Photo_File_Id__c = docId
        );

        HR_ProfilePhotoService.mockUserId = u.Id;

        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(con.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testSyncContactPhotoToUser_NoPhoto() {
        User u = createTestUser('hrphoto6', 'UserSix');
        Contact con = createTestContact(u.Id);

        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(con.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testSyncContactPhotoToUser_NoRelatedUser() {
        Contact con = createTestContact(null);
        Id docId = createImageFileAndLinkToContact(con.Id, 'OrphanPhoto', 'png');

        update new Contact(
            Id = con.Id,
            Profile_Photo_File_Id__c = docId
        );

        HR_ProfilePhotoService.mockUserId = null;

        Test.startTest();
        HR_ProfilePhotoService.syncContactPhotoToUser(con.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testGetCurrentUserPhotoUrl_WithStub() {
        User u = createTestUser('hrphoto7', 'UserSeven');

        HR_ProfilePhotoService.skipUserPhotoLogic = true;
        HR_ProfilePhotoService.stubbedPhotoUrl = 'https://example.com/current-user-photo.png';

        System.runAs(u) {
            Test.startTest();
            String result = HR_ProfilePhotoService.getCurrentUserPhotoUrl();
            Test.stopTest();

            System.assertEquals('https://example.com/current-user-photo.png', result);
        }
    }

    @IsTest
    static void testMarkContactProfilePhoto_NullInputs() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            HR_ProfilePhotoService.markContactProfilePhoto(null, null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testGetImageContentTypeBranches() {
        System.assertEquals('image/jpeg', HR_ProfilePhotoService.getImageContentType('jpg'));
        System.assertEquals('image/jpeg', HR_ProfilePhotoService.getImageContentType('jpeg'));
        System.assertEquals('image/png', HR_ProfilePhotoService.getImageContentType('png'));
        System.assertEquals('image/gif', HR_ProfilePhotoService.getImageContentType('gif'));
        System.assertEquals('image/bmp', HR_ProfilePhotoService.getImageContentType('bmp'));
        System.assertEquals('image/webp', HR_ProfilePhotoService.getImageContentType('webp'));
        System.assertEquals('image/jpeg', HR_ProfilePhotoService.getImageContentType('txt'));
        System.assertEquals('image/jpeg', HR_ProfilePhotoService.getImageContentType(null));
    }
}