Public class LwcFileBatch{

/*global class LwcFileBatch implements Database.Batchable<SObject> {

    global Id serviceId;

    global LwcFileBatch(Id serviceId) {
        this.serviceId = serviceId;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {

        // Fetch ONLY files linked to the Service__c record
        return Database.getQueryLocator([
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :serviceId
            AND ContentDocumentId != null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        // Batch size = 1, so scope always contains exactly 1 CDL
        ContentDocumentLink file = (ContentDocumentLink)scope[0];

        if (file.ContentDocumentId == null) return;

        // Prepare wrapper
        CandidateCreationPrompt.InputWrapper wrap =
            new CandidateCreationPrompt.InputWrapper();

        wrap.recordId = file.LinkedEntityId;     // Service__c Id
        wrap.fileId   = file.ContentDocumentId;  // ONE file only

        // Call the prompt builder
        List<String> response =
            CandidateCreationPrompt.getPDDPromptResponses(
                new List<CandidateCreationPrompt.InputWrapper>{ wrap }
            );

        System.debug('Response for file ' + file.ContentDocumentId + ': ' + response);
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch Complete for Service=' + serviceId);
    }  */
}