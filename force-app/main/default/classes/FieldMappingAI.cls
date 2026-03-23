public class FieldMappingAI {

    public static Map<String, Object> getmap(String userMessage,List<FieldResolver.FieldInfo> schema) {
		
        ConnectApi.WrappedValue userText = new ConnectApi.WrappedValue();
        userText.value = userMessage;

        ConnectApi.WrappedValue fieldSchema = new ConnectApi.WrappedValue();
        fieldSchema.value = JSON.serialize(schema);
		System.debug(fieldSchema);
        Map<String, ConnectApi.WrappedValue> inputParams =
            new Map<String, ConnectApi.WrappedValue>{
                'Input:userInput' => userText,
                'Input:fieldSchema' => fieldSchema
            };

        ConnectApi.EinsteinPromptTemplateGenerationsInput input =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();

        input.inputParams = inputParams;
        input.isPreview = false;
        input.additionalConfig =
            new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptBuilderPreview';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation res =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Field_Resolver',
                input
            );

        String aiText = res.generations[0].text
            .replace('\u00A0',' ')
            .trim();
	    System.debug(aiText);    
		if (aiText.startsWith('```')) {
        aiText = aiText
            .replaceFirst('```json', '')
            .replaceFirst('```', '')
            .trim();
    }
		if (aiText.startsWith('```')) {
        aiText = aiText
            .replaceFirst('```json', '')
            .replaceFirst('```', '')
            .trim();
    }
		Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(aiText);
				
        return parsed;
    }
}