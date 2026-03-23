public with sharing class AccountFileController {

    @AuraEnabled
    public static void updateDocumentType(List<Id> contentVersionIds, String documentType) {
        List<ContentVersion> versionsToUpdate = [
            SELECT Id, ContentDocumentId, Document_Type__c 
            FROM ContentVersion 
            WHERE Id IN :contentVersionIds
        ];
        for (ContentVersion v : versionsToUpdate) {
            v.Document_Type__c = documentType;
        }
        if (!versionsToUpdate.isEmpty()) update versionsToUpdate;
    }

    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getAccountFiles(Id accountId) {
        List<FileWrapper> fileList = new List<FileWrapper>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, ContentDocument.Title, 
                   ContentDocument.CreatedDate, 
                   ContentDocument.CreatedBy.Name,
                   ContentDocument.LatestPublishedVersion.Document_Type__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            fileList.add(new FileWrapper(
                link.ContentDocumentId,
                link.ContentDocument.Title,
                link.ContentDocument.CreatedBy.Name,
                link.ContentDocument.CreatedDate,
                link.ContentDocument.LatestPublishedVersion.Document_Type__c
            ));
        }
        return fileList;
    }

    public class FileWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Title;
        @AuraEnabled public String UploadedBy;
        @AuraEnabled public Datetime CreatedDate;
        @AuraEnabled public String DocumentType;
        public FileWrapper(String Id, String Title, String UploadedBy, Datetime CreatedDate, String DocumentType) {
            this.Id = Id;
            this.Title = Title;
            this.UploadedBy = UploadedBy;
            this.CreatedDate = CreatedDate;
            this.DocumentType = DocumentType;
        }
    }
}