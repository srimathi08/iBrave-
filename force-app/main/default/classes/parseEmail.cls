/**
 * @class parseEmail
 * @implements Messaging.InboundEmailHandler
 * 
 * @desc
 *   Handles inbound emails sent to a Salesforce Email Service address.
 *   - Creates a `Service__c` record with email metadata (from, subject, body)
 *   - Uploads all email attachments (text & binary) as `ContentVersion` files
 *   - Links each file to the created `Service__c` via `ContentDocumentLink`
 *   - Triggers the Einstein Prompt via `CandidateCreationPrompt` after saving
 * 
 * @usecase
 *   Used in resume processing workflows triggered by email with attached PDFs or resumes.
 * 
 * @author Afrose Ahamed
 */


global class parseEmail implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            /* --------------------------------------------------
             * 1. CREATE SERVICE RECORD
             * -------------------------------------------------- */
            Service__c s = new Service__c();
            s.EmailFrom__c = email.fromAddress;

            if (String.isNotBlank(email.subject)) {
                s.Name = email.subject.length() > 80
                    ? email.subject.substring(0, 80)
                    : email.subject;
                s.Email_Subject__c = email.subject;
            } else {
                s.Name = 'Email Resume';
            }

            s.Email_Body__c = email.plainTextBody;
            insert s;

            /* --------------------------------------------------
             * 2. SAVE ATTACHMENTS (IF ANY)
             * -------------------------------------------------- */
            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {

                for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {

                    ContentVersion cv = new ContentVersion(
                        Title        = att.fileName,
                        PathOnClient = att.fileName,
                        VersionData  = att.body
                    );
                    insert cv;

                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];

                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId    = s.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    );
                    insert cdl;
                }
            }

            /* --------------------------------------------------
             * 3. IDENTIFY CANDIDATE VS JOB DESCRIPTION
             * -------------------------------------------------- */
            List<IdentifyJdOrCandidateCreation.InputWrapper> identifyParams =
                new List<IdentifyJdOrCandidateCreation.InputWrapper>();

            IdentifyJdOrCandidateCreation.InputWrapper iw =
                new IdentifyJdOrCandidateCreation.InputWrapper();
            iw.recordId = s.Id;
            identifyParams.add(iw);

            List<String> identifyResp =
                IdentifyJdOrCandidateCreation.getPDDPromptResponses(identifyParams);

           if (identifyResp == null || identifyResp.isEmpty()) {
    throw new AuraHandledException('Empty response from Identify Prompt');
}

            String cleanedJson = identifyResp[0]
                .replaceAll('\u00A0', '')
                .replaceAll('```json?', '')
                .replaceAll('```', '')
                .trim();

            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

            /* --------------------------------------------------
             * 4. IF CANDIDATE → ALWAYS TRIGGER BATCH
             * -------------------------------------------------- */
            if (
                parsed != null &&
                parsed.containsKey('Candidate') &&
                (Boolean) parsed.get('Candidate') == true
            ) {

                System.debug('Candidate identified → starting batch');

                Database.executeBatch(
                    new AsynCandidateCreationBatch(s.Id),
                    1   // DO NOT CHANGE
                );
            }

            /* --------------------------------------------------
             * 5. IF JOB DESCRIPTION → JD FLOW
             * -------------------------------------------------- */
            else if (
                parsed != null &&
                parsed.containsKey('JobDescription') &&
                (Boolean) parsed.get('JobDescription') == true
            ) {

                List<JobDescriptionCreationPrompt.InputWrapper> jdParams =
                    new List<JobDescriptionCreationPrompt.InputWrapper>();

                JobDescriptionCreationPrompt.InputWrapper jd =
                    new JobDescriptionCreationPrompt.InputWrapper();
                jd.recordId = s.Id;
                jdParams.add(jd);

                JobDescriptionCreationPrompt.getJDPromptResponses(jdParams);
            }

            result.success = true;
            result.message = 'Email processed successfully';

        } catch (Exception e) {
            UtilityClass.createElog(e);
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
        }

        return result;
    }
}



/*global class parseEmail implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            
            Service__c s = new Service__c();
            s.emailfrom__c = email.fromAddress;

            if (String.isNotBlank(email.subject)) {
                s.Name = email.subject.length() > 80
                    ? email.subject.substring(0, 80)
                    : email.subject;
                s.Email_Subject__c = email.subject;
            } else {
                s.Name = 'Email Resume';
            }

            s.Email_Body__c = email.plainTextBody;
            insert s;

            
            Boolean hasAttachments = false;

            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {

                for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {

                    ContentVersion cv = new ContentVersion(
                        Title        = att.fileName,
                        PathOnClient = att.fileName,
                        VersionData  = att.body
                    );
                    insert cv;

                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];

                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId    = s.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    );
                    insert cdl;

                    hasAttachments = true;
                }
            }

            
            List<IdentifyJdOrCandidateCreation.InputWrapper> identifyParams =
                new List<IdentifyJdOrCandidateCreation.InputWrapper>();

            IdentifyJdOrCandidateCreation.InputWrapper iw =
                new IdentifyJdOrCandidateCreation.InputWrapper();
            iw.recordId = s.Id;
            identifyParams.add(iw);

            List<String> identifyResp =
                IdentifyJdOrCandidateCreation.getPDDPromptResponses(identifyParams);

            String cleanedJson = identifyResp[0]
                .replaceAll('\u00A0', '')
                .replaceAll('```json?', '')
                .replaceAll('```', '')
                .trim();

            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

            
            if (
                hasAttachments &&
                parsed != null &&
                parsed.containsKey('Candidate') &&
                (Boolean) parsed.get('Candidate') == true
            ) {
                System.debug('Candidate resume identified → starting batch');

                // ✅ EXACTLY SAME AS FILE UPLOAD FLOW
                Database.executeBatch(
                    new AsynCandidateCreationBatch(s.Id),
                    1 // one resume at a time
                );
            }

           
            else if (
                parsed != null &&
                parsed.containsKey('JobDescription') &&
                (Boolean) parsed.get('JobDescription') == true
            ) {

                List<JobDescriptionCreationPrompt.InputWrapper> jdParams =
                    new List<JobDescriptionCreationPrompt.InputWrapper>();

                JobDescriptionCreationPrompt.InputWrapper jd =
                    new JobDescriptionCreationPrompt.InputWrapper();
                jd.recordId = s.Id;
                jdParams.add(jd);

                JobDescriptionCreationPrompt.getJDPromptResponses(jdParams);
            }

            result.success = true;
            result.message = 'Email processed successfully';

        } catch (Exception e) {
            UtilityClass.createElog(e);
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
        }

        return result;
    }
} */







/*global class parseEmail implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
           
            Service__c s = new Service__c();
            s.EmailFrom__c = email.fromAddress;

            if (String.isNotBlank(email.subject)) {
                s.Name = email.subject.length() > 80
                    ? email.subject.substring(0, 80)
                    : email.subject;
                s.Email_Subject__c = email.subject;
            } else {
                s.Name = 'Email Resume';
            }

            s.Email_Body__c = email.plainTextBody;
            insert s;

            
            Boolean hasAttachments = false;

            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {

                for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {

                    ContentVersion cv = new ContentVersion(
                        Title        = att.fileName,
                        PathOnClient = att.fileName,
                        VersionData  = att.body
                    );
                    insert cv;

                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];

                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId    = s.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    );
                    insert cdl;

                    hasAttachments = true;
                }
            }

            
            List<IdentifyJdOrCandidateCreation.InputWrapper> identifyParams =
                new List<IdentifyJdOrCandidateCreation.InputWrapper>();

            IdentifyJdOrCandidateCreation.InputWrapper iw =
                new IdentifyJdOrCandidateCreation.InputWrapper();
            iw.recordId = s.Id;
            identifyParams.add(iw);

           // List<String> identifyResp =
             //   IdentifyJdOrCandidateCreation.getPDDPromptResponses(identifyParams);


List<String> identifyResp = new List<String>();

if (!Test.isRunningTest()) {
    identifyResp =
        IdentifyJdOrCandidateCreation.getPDDPromptResponses(identifyParams);
} else {
    // Dummy safe response for tests
    identifyResp.add('{"Candidate":false,"JobDescription":false}');
}



            //String cleanedJson = identifyResp[0]
            //    .replaceAll('\u00A0', '')
              //  .replaceAll('```json?', '')
              //  .replaceAll('```', '')
              //  .trim();

String cleanedJson = '{}';

if (!identifyResp.isEmpty()) {
    cleanedJson = identifyResp[0]
        .replaceAll('\u00A0', '')
        .replaceAll('```json?', '')
        .replaceAll('```', '')
        .trim();
}



            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

            
            if (
                hasAttachments &&
                parsed != null &&
                parsed.containsKey('Candidate') &&
                (Boolean) parsed.get('Candidate') == true
            ) {

                System.debug('Candidate resume identified → starting batch');

                // ✅ DO NOT RUN BATCH IN TEST CONTEXT
                if (!Test.isRunningTest()) {
                    Database.executeBatch(
                        new AsynCandidateCreationBatch(s.Id),
                        1
                    );
                }
            }

            
            else if (
                parsed != null &&
                parsed.containsKey('JobDescription') &&
                (Boolean) parsed.get('JobDescription') == true
            ) {

                List<JobDescriptionCreationPrompt.InputWrapper> jdParams =
                    new List<JobDescriptionCreationPrompt.InputWrapper>();

                JobDescriptionCreationPrompt.InputWrapper jd =
                    new JobDescriptionCreationPrompt.InputWrapper();
                jd.recordId = s.Id;
                jdParams.add(jd);

                //JobDescriptionCreationPrompt.getJDPromptResponses(jdParams);
                     if (!Test.isRunningTest()) {
    JobDescriptionCreationPrompt.getJDPromptResponses(jdParams);
}


            }

            result.success = true;
            result.message = 'Email processed successfully';

        } catch (Exception e) {
            UtilityClass.createElog(e);
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
        }

        return result;
    }
}  */



/*global class parseEmail implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        try {
            
            Service__c s = new Service__c();
            s.emailfrom__c  = email.fromAddress;

            if (String.isNotBlank(email.subject)) {
                s.Name = email.subject.length() > 80
                    ? email.subject.substring(0, 80)
                    : email.subject;
                s.Email_Subject__c  = email.subject;
            } else {
                s.Name = 'Email Resume';
            }

            s.Email_Body__c = email.plainTextBody;
            insert s;

            
            Boolean hasAttachments = false;

            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {

                for (Messaging.InboundEmail.BinaryAttachment att : email.binaryAttachments) {

                    ContentVersion cv = new ContentVersion(
                        Title        = att.fileName,
                        PathOnClient = att.fileName,
                        VersionData  = att.body
                    );
                    insert cv;

                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];

                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId    = s.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    );
                    insert cdl;

                    hasAttachments = true;
                }
            }

           
            List<IdentifyJdOrCandidateCreation.InputWrapper> identifyParams =
                new List<IdentifyJdOrCandidateCreation.InputWrapper>();

            IdentifyJdOrCandidateCreation.InputWrapper iw =
                new IdentifyJdOrCandidateCreation.InputWrapper();
            iw.recordId = s.Id;
            identifyParams.add(iw);

            List<String> identifyResp =
                IdentifyJdOrCandidateCreation.getPDDPromptResponses(identifyParams);

            String cleanedJson = identifyResp[0]
                .replaceAll('\u00A0', '')
                .replaceAll('```json?', '')
                .replaceAll('```', '')
                .trim();

            Map<String, Object> parsed =
                (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

            
            if (
                hasAttachments &&
                parsed != null &&
                parsed.containsKey('Candidate') &&
                (Boolean) parsed.get('Candidate') == true
            ) {
                System.debug('Candidate resume identified → starting batch');

                // ✅ EXACTLY SAME AS FILE UPLOAD FLOW
                Database.executeBatch(
                    new AsynCandidateCreationBatch(s.Id),
                    1 // one resume at a time
                );
            }

            
            else if (
                parsed != null &&
                parsed.containsKey('JobDescription') &&
                (Boolean) parsed.get('JobDescription') == true
            ) {

                List<JobDescriptionCreationPrompt.InputWrapper> jdParams =
                    new List<JobDescriptionCreationPrompt.InputWrapper>();

                JobDescriptionCreationPrompt.InputWrapper jd =
                    new JobDescriptionCreationPrompt.InputWrapper();
                jd.recordId = s.Id;
                jdParams.add(jd);

                JobDescriptionCreationPrompt.getJDPromptResponses(jdParams);
            }

            result.success = true;
            result.message = 'Email processed successfully';

        } catch (Exception e) {
            UtilityClass.createElog(e);
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
        }

        return result;
    }
}  */