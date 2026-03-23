public with sharing class UploadDocsController {

    @AuraEnabled
    public static void updatePhotoOnAccount(Id recordId, String contentDocId) {

        // Build URL to download the image
        String imageUrl = '/sfc/servlet.shepherd/document/download/' + contentDocId;

        // Build HTML for Rich Text Area field
        String imgHtml = '<img src="' + imageUrl + '" style="width:120px;height:120px;border-radius:8px;" />';

        // Update Account field
        Account acc = new Account(
            Id = recordId,
            Image__c = imgHtml
        );

        update acc;
    }
}