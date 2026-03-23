public without sharing class JobDescriptionCreationPrompt {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Generate JD Prompt Responses')
    public static List<String> getJDPromptResponses(List<InputWrapper> inputs) {
        List<String> result = new List<String>();

        try {
            System.debug('---- JobDescriptionCreationPrompt START ----');

            if (inputs == null || inputs.isEmpty()) {
                System.debug('No input parameters provided.');
                return result;
            }

            Id recordId = inputs[0] != null ? inputs[0].recordId : null;
            System.debug('Incoming recordId: ' + recordId);

            if (recordId == null) {
                throw new AuraHandledException('No recordId provided to Prompt.');
            }

            // Check if JD_Sample__c exists
            Service__c jdSample;
            try {
                jdSample = [
                    SELECT Id, Name
                    FROM Service__c
                    WHERE Id = :recordId
                    LIMIT 1
                ];
            } catch (Exception soqlEx) {
                System.debug('SOQL error: ' + soqlEx.getMessage());
                throw new AuraHandledException('Service__c record not found for Id: ' + recordId);
            }

            System.debug('Found Service__c: ' + jdSample);

            // Prepare Prompt Builder input
            Map<String, String> experienceSession = new Map<String, String>();
            experienceSession.put('id', jdSample.Id);

            ConnectApi.WrappedValue expVal = new ConnectApi.WrappedValue();
            expVal.value = experienceSession;

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:Document', expVal);

            ConnectApi.EinsteinPromptTemplateGenerationsInput execInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            execInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            execInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            execInput.isPreview = false;
            execInput.inputParams = inputParams;

            // Run Prompt Template
            String promptName = 'JD_Prompt'; // CHECK this matches exact API name
            System.debug('Running Prompt Template: ' + promptName);

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    promptName,
                    execInput
                );

            System.debug('Prompt Output (raw): ' +output);

            if (output == null || output.generations.isEmpty() || String.isBlank(output.generations[0].text)) {
                throw new AuraHandledException('No response generated from Prompt Builder.');
            }

            String promptResult = output.generations[0].text;
            System.debug('Prompt Result (JSON): ' + promptResult);

            // Create Job Descriptions
            List<String> jds = JobDescriptionCreationController.createJobDescriptions(promptResult, recordId);
        	return jds;	   
           
        } catch (AuraHandledException ahe) {
            System.debug('AuraHandledException: ' + ahe.getMessage());
            throw ahe;
        } catch (Exception e) {
            System.debug('Unexpected Exception: ' + e.getMessage());
            throw new AuraHandledException('Error in JD Prompt: ' + e.getMessage());
        }

       
    }
}