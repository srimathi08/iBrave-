public with sharing class TodayFilesController {

    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getTodayUploadedFiles() {

        return [
            SELECT Id,
                   Title,
                   FileType,
                   CreatedDate,
                   CreatedBy.Name
            FROM ContentVersion
            WHERE CreatedDate = TODAY
            ORDER BY CreatedDate DESC
        ];
    }
}