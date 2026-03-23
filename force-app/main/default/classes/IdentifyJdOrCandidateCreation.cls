public class IdentifyJdOrCandidateCreation {	
     public class InputWrapper {
        @InvocableVariable(required=true)
        public Id recordId;
    }   
    @InvocableMethod(label='Generate Prompt Responses ')
    public static List<String> getPDDPromptResponses(List<InputWrapper> inputs) {
        List<String> result = new List<String>();
        
        if (inputs == null || inputs.isEmpty()) {
            return result;
        }       
        Id recordId;
        if(inputs.size()>0 && inputs[0] != null){
            recordId = inputs[0].recordId;
        }      
        String responseString = '';       
        List<ContentDocumentLink> serviceFiles = [SELECT ContentDocumentId,ContentDocument.Title, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =:recordId];
        Map<String, ContentDocumentLink> serviceFilesMap =new Map<String, ContentDocumentLink>();
        for(ContentDocumentLink sM:serviceFiles){
            serviceFilesMap.put(Sm.ContentDocument.Title,SM);
        }
        for (Service__c doc : [
            SELECT Id,emailfrom__c, Name
            FROM Service__c
            WHERE Id = :recordId ]) {
             Map<String, String> experienceSession = new Map<String, String>();
        experienceSession.put('id', doc.Id);
        ConnectApi.WrappedValue experienceSessionValue = new ConnectApi.WrappedValue();
        experienceSessionValue.value = experienceSession;
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:Document', experienceSessionValue);    
            // Configure invocation parameters
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;
        try {
            // Call the service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Identify_JD_or_Candidate',
                executeTemplateInput
            );       
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
              String promptResult = response.text;
			  result.add(promptResult);	              
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }       
        }       
        return result;      
    }    
}

/*public class IdentifyJdOrCandidateCreation {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Generate Prompt Responses')
    public static List<String> getPDDPromptResponses(List<InputWrapper> inputs) {
        List<String> result = new List<String>();

        if (inputs == null || inputs.isEmpty() || inputs[0] == null || inputs[0].recordId == null)
            return result;

        Id recordId = inputs[0].recordId;

        // 🧪 In tests, skip API and return dummy
        if (Test.isRunningTest()) {
            result.add('{"Candidate": true}');
            return result;
        }

        try {
            List<Service__c> serviceList = [
                SELECT Id, emailfrom__c, Name FROM Service__c WHERE Id = :recordId
            ];

            if (serviceList.isEmpty()) return result;

            for (Service__c doc : serviceList) {
                Map<String, String> experienceSession = new Map<String, String>{ 'id' => doc.Id };
                ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
                wrapped.value = experienceSession;

                Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>{
                    'Input:Document' => wrapped
                };

                ConnectApi.EinsteinPromptTemplateGenerationsInput execInput =
                    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                execInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
                execInput.additionalConfig.applicationName = 'PromptBuilderPreview';
                execInput.isPreview = false;
                execInput.inputParams = params;

                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation genOutput;

                try {
                    genOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                        'Identify_JD_or_Candidate', execInput
                    );
                } catch (Exception e) {
                    System.debug('⚠️ Prompt API failed: ' + e.getMessage());
                    continue;
                }

                if (genOutput != null && genOutput.generations != null && !genOutput.generations.isEmpty()) {
                    ConnectApi.EinsteinLLMGenerationItemOutput response = genOutput.generations[0];
                    if (response != null && !String.isBlank(response.text)) {
                        result.add(response.text);
                    }
                } else {
                    System.debug('⚠️ No generations returned from Identify JD/Candidate.');
                }
            }
        } catch (Exception e) {
            System.debug('❌ Error in IdentifyJdOrCandidateCreation: ' + e.getMessage());
        }
        return result;
    }
}*/