/*global class AsynCandidateCreationBatch implements Database.Batchable<sObject>
	{
    private String Serviceids;
    
     public AsynCandidateCreationBatch(String Serviceids){
         this.Serviceids = Serviceids;
   }    
        
    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        return Database.getQueryLocator([ SELECT Id, ContentDocumentId, LinkedEntityId 
   FROM ContentDocumentLink WHERE LinkedEntityId=:serviceIds]); 
    }
    global void execute(Database.BatchableContext BC, List<ContentDocumentLink> scope)
    {		for(ContentDocumentLink s:scope){
    		CandidateCreationPrompt.getPDDPromptResponses(s.ContentDocumentId);	
			}	  
    }
    global void finish(Database.BatchableContext BC) {
    }
} */


/* works but does not accept email body for resume 
global class AsynCandidateCreationBatch
    implements Database.Batchable<ContentDocumentLink> {

    private Id serviceId;

    global AsynCandidateCreationBatch(Id serviceId) {
        this.serviceId = serviceId;
    }

    // Use Iterable to avoid metadata cache issues
    global Iterable<ContentDocumentLink> start(Database.BatchableContext bc) {
        return [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :serviceId
        ];
    }

    global void execute(
        Database.BatchableContext bc,
        List<ContentDocumentLink> scope
    ) {
        for (ContentDocumentLink cdl : scope) {
            // 🔑 EXACT MATCH with your method signature
            CandidateCreationPrompt.getPDDPromptResponses(
                String.valueOf(cdl.ContentDocumentId)
            );
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('AsyncCandidateCreationBatch completed');
    }
} */



global class AsynCandidateCreationBatch
    implements Database.Batchable<SObject> {

    private Id serviceId;

    global AsynCandidateCreationBatch(Id serviceId) {
        this.serviceId = serviceId;
    }

    /* --------------------------------------------------
     * START: Service + Attachments
     * -------------------------------------------------- */
    global Iterable<SObject> start(Database.BatchableContext bc) {

        List<SObject> records = new List<SObject>();

        // ✉️ Service (email body)
        records.add([
            SELECT Id, Email_Body__c
            FROM Service__c
            WHERE Id = :serviceId
            LIMIT 1
        ]);

        // 📄 Attachments
        records.addAll([
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :serviceId
        ]);

        return records;
    }

    /* --------------------------------------------------
     * EXECUTE: Body + Attachments
     * -------------------------------------------------- */
    global void execute(
        Database.BatchableContext bc,
        List<SObject> scope
    ) {

        for (SObject obj : scope) {

            /* -------------------------------
             * ✉️ EMAIL BODY → TEMP FILE
             * ------------------------------- */
            if (obj instanceof Service__c) {

                Service__c svc = (Service__c) obj;

                if (String.isNotBlank(svc.Email_Body__c)) {

                    System.debug('Creating temp file from email body');

                    // 1️⃣ Create temp ContentVersion
                    ContentVersion cv = new ContentVersion(
                        Title        = 'Email_Body_Resume',
                        PathOnClient = 'Email_Body_Resume.txt',
                        VersionData  = Blob.valueOf(svc.Email_Body__c)
                    );
                    insert cv;

                    // 2️⃣ Fetch ContentDocumentId
                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];

                    // 3️⃣ Call EXISTING prompt method (UNCHANGED)
                    CandidateCreationPrompt.getPDDPromptResponses(
                        String.valueOf(cv.ContentDocumentId)
                    );
                }
            }

            /* -------------------------------
             * 📄 ATTACHMENT PROCESSING
             * ------------------------------- */
            else if (obj instanceof ContentDocumentLink) {

                ContentDocumentLink cdl =
                    (ContentDocumentLink) obj;

                System.debug(
                    'Processing attachment: ' +
                    cdl.ContentDocumentId
                );

                CandidateCreationPrompt.getPDDPromptResponses(
                    String.valueOf(cdl.ContentDocumentId)
                );
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('AsynCandidateCreationBatch completed');
    }
}