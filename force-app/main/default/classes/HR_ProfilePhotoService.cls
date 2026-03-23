/*public with sharing class HR_ProfilePhotoService {
    @TestVisible private static Boolean skipUserPhotoLogic = false;
    @TestVisible private static String stubbedPhotoUrl = 'https://example.com/testphoto.png';
    @TestVisible private static Id mockUserId;

    // For HR LWC: save file id on Contact and sync to related User
    @AuraEnabled
    public static void markContactProfilePhoto(Id contactId, Id contentDocumentId) {
        if (contactId == null || contentDocumentId == null) {
            throw new AuraHandledException('Contact and file are required.');
        }

        // 1) Update Contact field
        Contact c = new Contact(
            Id = contactId,
            Profile_Photo_File_Id__c = contentDocumentId
        );
        update c;

        // 2) Sync to User
        syncContactPhotoToUser(contactId);
    }

    // Used by HR LWC to show preview from Contact/User
    @AuraEnabled(cacheable=true)
    public static String getProfilePhotoUrl(Id contactId) {
        if (contactId == null) return null;

        Contact c = [
            SELECT Profile_Photo_File_Id__c,Internal_User__c,
                   (SELECT Id FROM Users LIMIT 1)
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        // Prefer User profile photo (if already set)
        if (Test.isRunningTest() && skipUserPhotoLogic) {
            return stubbedPhotoUrl;
        }

        if (!c.Users.isEmpty() || mockUserId != null) {
            Id userId = mockUserId != null ? mockUserId : c.Users[0].Id;
            Id communityId = null; // internal app
            try {
                ConnectApi.Photo p = getPhotoInternal(communityId, userId);
                if (p != null && !String.isBlank(p.largePhotoUrl)) {
                    return p.largePhotoUrl;
                }
            } catch (Exception e) {
                // Handle or skip in test
            }
        }

        // Fallback: direct file URL from ContentVersion
        if (!String.isBlank(c.Profile_Photo_File_Id__c)) {
            ContentVersion cv = [
                SELECT Id, ContentDocumentId, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :c.Profile_Photo_File_Id__c
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];
            // Standard file download URL
            URL orgUrl = URL.getOrgDomainUrl();
            return orgUrl.toExternalForm()
                + '/sfc/servlet.shepherd/version/download/' + cv.Id;

        }
        return null;
    }

    // Core: copy Contact file → User profile photo
    public static void syncContactPhotoToUser(Id contactId) {
        Contact c = [
            SELECT Id, Profile_Photo_File_Id__c,
                   (SELECT Id FROM Users LIMIT 1)
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (String.isBlank(c.Profile_Photo_File_Id__c)) {
            return;
        }
        if (c.Users.isEmpty() && mockUserId == null) {
            return;
        }

        Id userId = mockUserId != null ? mockUserId : c.Users[0].Id;

        // Get latest version of the file
        ContentVersion cv = [
            SELECT Id, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :c.Profile_Photo_File_Id__c
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];

        // Build BinaryInput from Blob
        Blob fileBlob = cv.VersionData;
        String fileName = cv.Title + '.' + cv.FileExtension;
        String contentType = 'image/' + cv.FileExtension.toLowerCase(); // e.g. image/jpeg

        ConnectApi.BinaryInput bin =
            new ConnectApi.BinaryInput(fileBlob, contentType, fileName);

        // For Experience Cloud, use Network.getNetworkId(); for internal, null
        String communityId = Network.getNetworkId(); // or null if only internal
        String userIdStr   = String.valueOf(userId);

        setPhotoInternal(communityId, userIdStr, bin);
    }


    // Helper for community use – get current logged-in user's photo
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserPhotoUrl() {
        if (Test.isRunningTest() && skipUserPhotoLogic) {
            return stubbedPhotoUrl;
        }
        Id communityId = Network.getNetworkId();
        Id userId = UserInfo.getUserId();
        try {
            ConnectApi.Photo p = getPhotoInternal(communityId, userId);
            return p != null ? p.largePhotoUrl : null;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static ConnectApi.Photo getPhotoInternal(String communityId, String userId) {
        return ConnectApi.UserProfiles.getPhoto(communityId, userId);
    }

    @TestVisible
    private static void setPhotoInternal(String communityId, String userId, ConnectApi.BinaryInput bin) {
        if (!Test.isRunningTest()) {
            ConnectApi.UserProfiles.setPhoto(communityId, userId, bin);
        }
    }
}*/
public with sharing class HR_ProfilePhotoService {
    @TestVisible private static Boolean skipUserPhotoLogic = false;
    @TestVisible private static String stubbedPhotoUrl = 'https://example.com/testphoto.png';
    @TestVisible private static Id mockUserId;

    @AuraEnabled
    public static void markContactProfilePhoto(Id contactId, Id contentDocumentId) {
        if (contactId == null || contentDocumentId == null) {
            throw new AuraHandledException('Contact and file are required.');
        }

        Contact c = new Contact(
            Id = contactId,
            Profile_Photo_File_Id__c = contentDocumentId
        );
        update c;

        syncContactPhotoToUser(contactId);
    }

    @AuraEnabled(cacheable=true)
    public static String getProfilePhotoUrl(Id contactId) {
        if (contactId == null) {
            return null;
        }

        Contact c = [
            SELECT Id,
                   Profile_Photo_File_Id__c,
                   Internal_User__c,
                   (SELECT Id FROM Users LIMIT 1)
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (Test.isRunningTest() && skipUserPhotoLogic) {
            return stubbedPhotoUrl;
        }

        Id userId = getRelatedUserId(c);

        if (userId != null) {
            try {
                String communityId = (c.Internal_User__c != null) ? null : Network.getNetworkId();
                ConnectApi.Photo p = getPhotoInternal(communityId, String.valueOf(userId));
                if (p != null && !String.isBlank(p.largePhotoUrl)) {
                    return p.largePhotoUrl;
                }
            } catch (Exception e) {
                System.debug('Unable to fetch user profile photo: ' + e.getMessage());
            }
        }

        if (String.isNotBlank(c.Profile_Photo_File_Id__c)) {
            ContentVersion cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId = :c.Profile_Photo_File_Id__c
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];

            URL orgUrl = URL.getOrgDomainUrl();
            return orgUrl.toExternalForm()
                + '/sfc/servlet.shepherd/version/download/' + cv.Id;
        }

        return null;
    }

    public static void syncContactPhotoToUser(Id contactId) {
        Contact c = [
            SELECT Id,
                   Profile_Photo_File_Id__c,
                   Internal_User__c,
                   (SELECT Id FROM Users LIMIT 1)
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (String.isBlank(c.Profile_Photo_File_Id__c)) {
            return;
        }

        Id userId = getRelatedUserId(c);
        if (userId == null) {
            return;
        }

        ContentVersion cv = [
            SELECT Id, VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :c.Profile_Photo_File_Id__c
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];

        Blob fileBlob = cv.VersionData;
        String extension = String.isNotBlank(cv.FileExtension) ? cv.FileExtension.toLowerCase() : 'jpg';
        String fileName = cv.Title + '.' + extension;
        String contentType = getImageContentType(extension);

        ConnectApi.BinaryInput bin = new ConnectApi.BinaryInput(fileBlob, contentType, fileName);

        String communityId = null;

        if (c.Internal_User__c == null && !c.Users.isEmpty()) {
            communityId = Network.getNetworkId();
        }

        try {
            setPhotoInternal(communityId, String.valueOf(userId), bin);
        } catch (Exception e) {
            System.debug('Photo sync failed for user ' + userId + ': ' + e.getMessage());
            throw e;
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserPhotoUrl() {
        if (Test.isRunningTest() && skipUserPhotoLogic) {
            return stubbedPhotoUrl;
        }

        String communityId = Network.getNetworkId();
        Id userId = UserInfo.getUserId();

        try {
            ConnectApi.Photo p = getPhotoInternal(communityId, String.valueOf(userId));
            return (p != null) ? p.largePhotoUrl : null;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static Id getRelatedUserId(Contact c) {
        if (mockUserId != null) {
            return mockUserId;
        }
        if (c.Internal_User__c != null) {
            return c.Internal_User__c;
        }
        if (c.Users != null && !c.Users.isEmpty()) {
            return c.Users[0].Id;
        }
        return null;
    }

    @TestVisible
    private static String getImageContentType(String extension) {
        if (String.isBlank(extension)) {
            return 'image/jpeg';
        }

        extension = extension.toLowerCase();

        if (extension == 'jpg' || extension == 'jpeg') {
            return 'image/jpeg';
        }
        if (extension == 'png') {
            return 'image/png';
        }
        if (extension == 'gif') {
            return 'image/gif';
        }
        if (extension == 'bmp') {
            return 'image/bmp';
        }
        if (extension == 'webp') {
            return 'image/webp';
        }

        return 'image/jpeg';
    }

    @TestVisible
    private static ConnectApi.Photo getPhotoInternal(String communityId, String userId) {
        return ConnectApi.UserProfiles.getPhoto(communityId, userId);
    }

    @TestVisible
    private static void setPhotoInternal(String communityId, String userId, ConnectApi.BinaryInput bin) {
        if (!Test.isRunningTest()) {
            ConnectApi.UserProfiles.setPhoto(communityId, userId, bin);
        }
    }
}