/*public class CandidatePromptQueueable implements Queueable {
    private Id recordId;
	private String whatsappfrom;
    // Constructor
    public CandidatePromptQueueable(Id recordId,String whatsappfrom) {
        this.recordId = recordId;
        this.whatsappfrom=whatsappfrom;
    }

    public void execute(QueueableContext context) {
        
        // Identify Job or Candidate creation it returns boolean true,after will call JD or Candidate prompt
           List<IdentifyJdOrCandidateCreation.InputWrapper> jdorcandidateparams = new List<IdentifyJdOrCandidateCreation.InputWrapper>();                                                    
           IdentifyJdOrCandidateCreation.InputWrapper promptwrapper = new IdentifyJdOrCandidateCreation.InputWrapper(); 
           promptwrapper.recordId =this.recordId;
           jdorcandidateparams.add(promptwrapper);
           List<String> CheckJDorCandidate = IdentifyJdOrCandidateCreation.getPDDPromptResponses(jdorcandidateparams);   
           
           String cleanedJson = CheckJDorCandidate[0]
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();
		System.debug(cleanedJson);
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);      
            if(parsed != null && parsed.get('Candidate')==true){
              System.debug('Entered into Candidate Creation');
             // Wrap the record ID into the input structure expected by the InvocableMethod
        CandidateCreationPrompt.InputWrapper input = new CandidateCreationPrompt.InputWrapper();
        input.recordId = this.recordId;

        List<CandidateCreationPrompt.InputWrapper> inputs = new List<CandidateCreationPrompt.InputWrapper>{ input };

        try {
            // Call the prompt method
            List<String> responses = CandidateCreationPrompt.getPDDPromptResponses(inputs);
                  if (responses != null && !responses.isEmpty()) {
    String baseUrl = System.Url.getOrgDomainUrl().toExternalForm(); // Replaces deprecated URL.getSalesforceBaseUrl()
    	String whatsappBody = 'Thank you. The following account(s) were created:\n\n';
		System.debug('Whatsapp response check'+responses);
for (String res : responses) {
    List<String> parts = res.split(':');
    if (parts.size() >= 2) {
        String accId = parts[0].trim();
        String accName = parts[1].trim();
        String accLink = baseUrl + '/' + accId;

        whatsappBody += 'Name: ' + accName + '\n';
        whatsappBody += 'ID: ' + accId + '\n';
        whatsappBody += 'Link: ' + accLink + '\n\n';
    } else {
        whatsappBody = 'Thank you. No candidates were created.';
    }
}
                      WhatsAppUtils.sendTextMessage(whatsappBody,whatsappfrom);
    }
        } catch (Exception e) {
            String errorMsg='We encountered an error while processing your request: \n' + e.getMessage();
            System.debug(errorMsg);
            WhatsAppUtils.sendTextMessage(errorMsg,whatsappfrom);
            UtilityClass.createElog(e);
        }
    }
        else if(parsed != null && parsed.get('JobDescription')==true){
                   System.debug('Entered into Job description');
                    List<JobDescriptionCreationPrompt.InputWrapper> JDWrapperlist =new List<JobDescriptionCreationPrompt.InputWrapper>();
                   JobDescriptionCreationPrompt.InputWrapper Jdwrap =new JobDescriptionCreationPrompt.InputWrapper();
                    Jdwrap.recordId=this.recordId;
                    JdWrapperlist.add(Jdwrap);
            try{
                    List<String>JDResponse=JobDescriptionCreationPrompt.getJDPromptResponses(JdWrapperlist);
                
                	     if (JDResponse != null && !JDResponse.isEmpty()) {
   				 String baseUrl = System.Url.getOrgDomainUrl().toExternalForm(); // Replaces deprecated URL.getSalesforceBaseUrl()
    			String whatsappBody = 'Thank you. The following account(s) were created:\n\n';
				System.debug('Whatsapp response check'+JDResponse);
                     whatsappBody=+EmailTemplate.HtmlBody(JDResponse,false,true); 
                      WhatsAppUtils.sendTextMessage(whatsappBody,whatsappfrom);      
                         }	
            }catch(Exception E){
                String errorMsg='We encountered an error while processing your request: \n' + e.getMessage();
            System.debug(errorMsg);
            WhatsAppUtils.sendTextMessage(errorMsg,whatsappfrom);
            UtilityClass.createElog(e);
            }	
             }              
     }       
}*/


public class CandidatePromptQueueable implements Queueable {
    private Id recordId;
    private String whatsappfrom;

    public CandidatePromptQueueable(Id recordId, String whatsappfrom) {
        this.recordId = recordId;
        this.whatsappfrom = whatsappfrom;
    }

    public void execute(QueueableContext context) {
        System.debug('🚀 CandidatePromptQueueable started. recordId=' + recordId + ', whatsappfrom=' + whatsappfrom);

        // Identify Job or Candidate creation
        List<IdentifyJdOrCandidateCreation.InputWrapper> jdorcandidateparams = new List<IdentifyJdOrCandidateCreation.InputWrapper>();                                                    
        IdentifyJdOrCandidateCreation.InputWrapper promptwrapper = new IdentifyJdOrCandidateCreation.InputWrapper(); 
        promptwrapper.recordId = this.recordId;
        jdorcandidateparams.add(promptwrapper);

        System.debug('🔍 Calling IdentifyJdOrCandidateCreation with params=' + jdorcandidateparams);

        List<String> CheckJDorCandidate = IdentifyJdOrCandidateCreation.getPDDPromptResponses(jdorcandidateparams);   
        System.debug('✅ CheckJDorCandidate raw response=' + CheckJDorCandidate);

        String cleanedJson = CheckJDorCandidate[0]
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        System.debug('🧹 Cleaned JSON=' + cleanedJson);

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);      
        System.debug('📦 Parsed map=' + parsed);

        // ✅ Candidate Creation Flow
        if(parsed != null && parsed.get('Candidate') == true){
            System.debug('➡️ Candidate flow detected.');
            CandidateCreationPrompt.InputWrapper input = new CandidateCreationPrompt.InputWrapper();
            input.recordId = this.recordId;

            try {
                List<String> responses = CandidateCreationPrompt.getPDDPromptResponses(new List<CandidateCreationPrompt.InputWrapper>{ input });
                System.debug('🎯 Candidate responses=' + responses);

                if (responses != null && !responses.isEmpty()) {
                    String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
                    System.debug('🌐 Base URL=' + baseUrl);

                    for (String res : responses) {
                        System.debug('🔎 Processing candidate response line=' + res);

                        List<String> parts = res.split(':');
                        System.debug('🔗 Split parts=' + parts);

                        if (parts.size() >= 2) {
                            String accId = parts[0].trim();
                            String accName = parts[1].trim();
                            String recordUrl = baseUrl + '/' + accId;

                            System.debug('🆔 Candidate Id=' + accId + ', Name=' + accName + ', URL=' + recordUrl);

                            String whatsappBody = 
                                'We have successfully received the information you shared, and it has been securely stored in our system.\n\n' +
                                'Below are the details of the records created for your reference.\n\n' +
                                'Candidates Created Successfully\n' +
                                'Name: ' + accName + '\n' +
                                'URL - ' + recordUrl + '\n\n' +
                                'This is an automated message from Salesforce.';

                            System.debug('📩 WhatsApp Candidate message body=' + whatsappBody);
                            WhatsAppUtils.sendTextMessage(whatsappBody, whatsappfrom);
                        }
                    }
                }
            } catch (Exception e) {
                String errorMsg = '❌ Error in Candidate flow: ' + e.getMessage();
                System.debug(errorMsg);
                WhatsAppUtils.sendTextMessage(errorMsg, whatsappfrom);
                UtilityClass.createElog(e);
            }
        }

        // ✅ Job Description / Opportunity Flow
else if(parsed != null && parsed.get('JobDescription') == true){
    System.debug('➡️ Job Description flow detected.');
    JobDescriptionCreationPrompt.InputWrapper Jdwrap = new JobDescriptionCreationPrompt.InputWrapper();
    Jdwrap.recordId = this.recordId;

    try {
        List<String> JDResponse = JobDescriptionCreationPrompt.getJDPromptResponses(
            new List<JobDescriptionCreationPrompt.InputWrapper>{ Jdwrap }
        );
        System.debug('🎯 Job Description responses=' + JDResponse);

        if (JDResponse != null && !JDResponse.isEmpty()) {
            String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
            System.debug('🌐 Base URL=' + baseUrl);

            for (String res : JDResponse) {
                System.debug('🔎 Processing JD response line=' + res);

                // Split by comma (since your response looks comma-separated)
                List<String> parts;
                if (res.contains(',')) {
                    parts = res.split(',');
                } else {
                    parts = res.split(':');
                }
                System.debug('🔗 Split parts=' + parts);

                String oppId;
                for (String p : parts) {
                    String trimmed = p.trim();

                    // Salesforce Opportunity Ids are 15 or 18 chars and start with "006"
                    if ((trimmed.length() == 15 || trimmed.length() == 18) && trimmed.startsWith('006')) {
                        oppId = trimmed;
                        break;
                    }
                }

                if (oppId != null) {
                    String recordUrl = baseUrl + '/' + oppId;
                    System.debug('🆔 Final Opportunity Id=' + oppId + ', URL=' + recordUrl);

                    String whatsappBody = 
                        'We have successfully received the information you shared, and it has been securely stored in our system.\n\n' +
                        'Below are the details of the records created for your reference.\n\n' +
                        'Job Description Created Successfully\n' +
                        'URL - ' + recordUrl + '\n\n' +
                        'This is an automated message from Salesforce.';

                    System.debug('📩 WhatsApp JD message body=' + whatsappBody);
                    WhatsAppUtils.sendTextMessage(whatsappBody, whatsappfrom);
                } else {
                    System.debug('⚠️ No valid Opportunity Id found in parts=' + parts);
                }
            }
        }
    } catch (Exception e) {
        String errorMsg = '❌ Error in Job Description flow: ' + e.getMessage();
        System.debug(errorMsg);
        WhatsAppUtils.sendTextMessage(errorMsg, whatsappfrom);
        UtilityClass.createElog(e);
    }
}
     else {
            System.debug('⚠️ Neither Candidate nor JobDescription detected in parsed JSON=' + parsed);
        }
    }
}

/*public class CandidatePromptQueueable implements Queueable {
    private Id recordId;
    private String whatsappfrom;

    public CandidatePromptQueueable(Id recordId, String whatsappfrom) {
        this.recordId = recordId;
        this.whatsappfrom = whatsappfrom;
    }

    public void execute(QueueableContext context) {
        System.debug('🚀 CandidatePromptQueueable started. recordId=' + recordId + ', whatsappfrom=' + whatsappfrom);

        // 🧪 Skip logic in test context
        if (Test.isRunningTest()) {
            System.debug('🧪 Skipping CandidatePromptQueueable logic in test context.');
            return;
        }

        List<IdentifyJdOrCandidateCreation.InputWrapper> jdorcandidateparams =
            new List<IdentifyJdOrCandidateCreation.InputWrapper>();

        IdentifyJdOrCandidateCreation.InputWrapper promptwrapper =
            new IdentifyJdOrCandidateCreation.InputWrapper();
        promptwrapper.recordId = this.recordId;
        jdorcandidateparams.add(promptwrapper);

        List<String> CheckJDorCandidate =
            IdentifyJdOrCandidateCreation.getPDDPromptResponses(jdorcandidateparams);

        if (CheckJDorCandidate == null || CheckJDorCandidate.isEmpty() ||
            String.isBlank(CheckJDorCandidate[0])) {
            System.debug('⚠️ No JD/Candidate response returned. Skipping processing.');
            return;
        }

        String cleanedJson = CheckJDorCandidate[0]
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

        if (parsed != null && parsed.get('Candidate') == true) {
            // ✅ Candidate creation logic — unchanged
            // ...
        } else if (parsed != null && parsed.get('JobDescription') == true) {
            // ✅ Job Description creation logic — unchanged
            // ...
        } else {
            System.debug('⚠️ Neither Candidate nor JobDescription detected in parsed JSON=' + parsed);
        }
    }
} */