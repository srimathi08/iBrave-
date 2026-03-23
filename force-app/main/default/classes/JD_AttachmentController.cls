public class JD_AttachmentController {

    @AuraEnabled
    public static List<String> getPrompt(String recordId) {
        System.debug('==== START getPrompt ====');
        System.debug('Incoming recordId: ' + recordId);

        try {
            List<JobDescriptionCreationPrompt.InputWrapper> params = new List<JobDescriptionCreationPrompt.InputWrapper>();
            JobDescriptionCreationPrompt.InputWrapper w = new JobDescriptionCreationPrompt.InputWrapper();
            w.recordId = recordId;
            params.add(w);

            System.debug('Prepared params for Prompt: ' + params);

            List<String> responses = JobDescriptionCreationPrompt.getJDPromptResponses(params);

            System.debug('Prompt Response: ' + responses);
            System.debug('==== END getPrompt ====');
            return responses;
        } catch (Exception e) {
            System.debug('Error in getPrompt: ' + e.getMessage());
            UtilityClass.createElog(e);
            throw new AuraHandledException('Error while generating prompt: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createParent(String fileName) {
        System.debug('==== START createParent ====');
        System.debug('Incoming fileName: ' + fileName);

        Service__c jdSample = new Service__c();
        jdSample.Name = fileName;

        insert jdSample;
        System.debug('Inserted Service__c record: ' + jdSample);

        System.debug('==== END createParent ====');
        return jdSample.Id;
    }

    @AuraEnabled
    public static String uploadFile(String base64, String filename, String recordId) {
        System.debug('==== START uploadFile ====');
        System.debug('Incoming base64 length: ' + (base64 != null ? base64.length() : 0));
        System.debug('Incoming filename: ' + filename);
        System.debug('Incoming recordId: ' + recordId);

        ContentVersion cv = createContentVersion(base64, filename);
        System.debug('Created ContentVersion: ' + cv);

        ContentDocumentLink cdl = createContentLink(cv != null ? cv.Id : null, recordId);
        System.debug('Created ContentDocumentLink: ' + cdl);

        if (cv == null || cdl == null) {
            System.debug('Either ContentVersion or ContentDocumentLink creation failed.');
            return null;
        }

        System.debug('==== END uploadFile ====');
        return cdl.Id;
    }

    private static ContentVersion createContentVersion(String base64, String filename) {
        System.debug('---- START createContentVersion ----');
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64);
        cv.Title = filename;
        cv.PathOnClient = filename;

        try {
            insert cv;
            System.debug('Inserted ContentVersion: ' + cv);
            System.debug('---- END createContentVersion ----');
            return cv;
        } catch (DmlException e) {
            System.debug('Error inserting ContentVersion: ' + e.getMessage());
            return null;
        }
    }

    public static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        System.debug('---- START createContentLink ----');
        System.debug('Incoming contentVersionId: ' + contentVersionId);
        System.debug('Incoming recordId: ' + recordId);

        if (contentVersionId == null || recordId == null) {
            System.debug('contentVersionId or recordId is null, skipping.');
            return null;
        }

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
        ].ContentDocumentId;
        System.debug('Fetched ContentDocumentId: ' + contentDocumentId);

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';

        try {
            insert cdl;
            System.debug('Inserted ContentDocumentLink: ' + cdl);
            System.debug('---- END createContentLink ----');
            return cdl;
        } catch (DmlException e) {
            System.debug('Error inserting ContentDocumentLink: ' + e.getMessage());
            return null;
        }
    }
}