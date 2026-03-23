public class ActionObjectSelector {
	
    	public static ActionExtractionResult classify(String userMessage) {

        /* -----------------------------
           1️⃣ Build input parameters
        ------------------------------*/

        

        ConnectApi.WrappedValue wrappedInput = new ConnectApi.WrappedValue();
        wrappedInput.value = userMessage;

        Map<String, ConnectApi.WrappedValue> inputParams =
            new Map<String, ConnectApi.WrappedValue>{
                'Input:Text' => wrappedInput
            };

        /* -----------------------------
           2️⃣ Configure prompt execution
        ------------------------------*/

        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();

        promptInput.inputParams = inputParams;
        promptInput.isPreview = false;

        promptInput.additionalConfig =
            new ConnectApi.EinsteinLlmAdditionalConfigInput();
        promptInput.additionalConfig.applicationName =
            'PromptBuilderPreview';

        /* -----------------------------
           3️⃣ Execute prompt
        ------------------------------*/

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Action_Object_Selector',   // Prompt API Name
                promptInput
            );

        /* -----------------------------
           4️⃣ Read response
        ------------------------------*/
		
        String aiText = result.generations[0].text;
        aiText = aiText.replace('\u00A0', ' ').trim();    
        
		System.debug('aiText'+aiText);
        /* -----------------------------
           5️⃣ Parse JSON
        ------------------------------*/

        return (ActionExtractionResult) JSON.deserialize(aiText, ActionExtractionResult.class);
    }
}