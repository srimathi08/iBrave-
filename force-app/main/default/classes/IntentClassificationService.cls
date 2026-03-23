public class IntentClassificationService {
	public class IntentResult {
    public String message_type;
    public Decimal confidence;
}

    
    public static IntentResult classify(String userMessage) {

        /* -----------------------------
           1️⃣ Build input parameters
        ------------------------------*/

        

        ConnectApi.WrappedValue wrappedInput = new ConnectApi.WrappedValue();
        wrappedInput.value = userMessage;

        Map<String, ConnectApi.WrappedValue> inputParams =
            new Map<String, ConnectApi.WrappedValue>{
                'Input:intent' => wrappedInput
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
                'intent_classification',   // Prompt API Name
                promptInput
            );

        /* -----------------------------
           4️⃣ Read response
        ------------------------------*/
		
        String aiText = result.generations[0].text;
        
        /* -----------------------------
           5️⃣ Parse JSON
        ------------------------------*/

        return (IntentResult) JSON.deserialize(aiText, IntentResult.class);
    }
}