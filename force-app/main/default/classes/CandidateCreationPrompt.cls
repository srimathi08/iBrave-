/**
* Author: Afrose Ahamed
* @method getPDDPromptResponses(List<InputWrapper>) [public static]
* @desc 
*   This method receives a list of input records (typically a Service__c record), 
*   fetches related uploaded files, and sends those to the Einstein Prompt Builder 
*   for AI-based candidate extraction. It then uses the result to create Account 
*   records and links the original uploaded files to these newly created Accounts.
* 
* @param {List<InputWrapper>} inputs - A list of InputWrapper objects, each containing a recordId 
*   referencing the Service__c record whose files and data will be used.
* 
* @return {List<String>} - A list of result strings, each containing the name and ID of created 
*   Account(s), along with the AI-generated prompt result.
* 
* @throws {Exception} - Throws any exceptions encountered during prompt generation or DML operations.
* 
* @notes 
*   - Files must be uploaded to the Service__c record before this method is called.
*   - Only runs for Service__c records without `emailfrom__c` field populated.
*   - Associates uploaded files to the newly created Account based on filename matching.
*   - Uses 'candidate_creation' as the Prompt Template API name in Einstein Prompt Builder.
*/


public without sharing class CandidateCreationPrompt {    
    
    public static List<Account> getPDDPromptResponses(String Contentids) {
        try{
            List<String> result = new List<String>();
            if (Contentids == null ) {
            return null;
        }
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            
            ConnectApi.WrappedValue docValue = new ConnectApi.WrappedValue();
            
            docValue.value = new Map<String, String>{
                'id' => Contentids,
                    'type' => 'ContentDocument'
                    };
                        
                        
                        inputParams.put('Input:File', docValue);
            
            promptInput.inputParams = inputParams;
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.isPreview = false;
            
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Candidate_CreationFile', promptInput);
            ConnectApi.EinsteinLLMGenerationItemOutput promptResponse = response.generations[0];
            
            List<Account> Acc=CandidateCreationController.createCandidates(promptResponse.text,Contentids);

			return Acc;
        }Catch(exception E){
            System.debug(e.getMessage());
            throw e;
        }
        
    }
}