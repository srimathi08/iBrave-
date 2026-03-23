/*public with sharing class OpportunityFileController {

    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getStageFiles(Id opportunityId, String stageName) {
        // Step 1: Collect file IDs linked to the Opportunity
        List<Id> docIds = new List<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :opportunityId
        ]) {
            docIds.add(link.ContentDocumentId);
        }

        // Step 2: If no files found, return empty list
        if (docIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        // Step 3: Fetch ContentVersion files for that stage
        return [
            SELECT Id, Title, FileExtension, ContentDocumentId, Related_Stage__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
            AND Related_Stage__c = :stageName
        ];
    }

    @AuraEnabled
    public static void updateFileStage(Id contentDocumentId, Id opportunityId) {
        Opportunity opp = [
            SELECT StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];

        List<ContentVersion> versions = [
            SELECT Id FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId
        ];

        for (ContentVersion cv : versions) {
            cv.Related_Stage__c = opp.StageName;
        }

        update versions;
    }
}*/

public with sharing class OpportunityFileController {

    // Get Files for the Opportunity and Stage
    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getStageFiles(Id opportunityId, String stageName) {
        // Step 1: Get file document IDs linked to this Opportunity
        List<Id> docIds = new List<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
        ]) {
            docIds.add(link.ContentDocumentId);
        }

        // If no files, return empty list
        if (docIds.isEmpty()) {
            return new List<ContentVersion>();
        }

        // Step 2: Get latest file versions tagged with current stage
        return [
            SELECT Id, Title, FileExtension, ContentDocumentId, Related_Stage__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
            AND Related_Stage__c = :stageName
        ];
    }

    // Tag uploaded file with the current Opportunity Stage
    @AuraEnabled
    public static void updateFileStage(Id contentDocumentId, Id opportunityId) {
        Opportunity opp = [
            SELECT StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];

        List<ContentVersion> versions = [
            SELECT Id FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId
        ];

        for (ContentVersion cv : versions) {
            cv.Related_Stage__c = opp.StageName;
        }

        update versions;
    }
}