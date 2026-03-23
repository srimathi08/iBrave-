public class ChatbotActionOrchestrator {

    public static ChatResponse process(String userMessage) {
		
       
        // 1️⃣ Intent classification
        IntentClassificationService.IntentResult intent =IntentClassificationService.classify(userMessage);
		System.debug('intent'+intent);	
        
         if (intent == null || intent.confidence < 0.90) {
            return new ChatResponse(false,
                'Could you please rephrase what you want to do?'
            );
        }
        
        if (intent.message_type == 'HELP') {
         return new ChatResponse(false, 'Hi i help with Creating,Update,Deleting and Fetching');
         }

        // 2️⃣ Extract actions
        ActionExtractionResult extracted =
            ActionObjectSelector.classify(userMessage);

        if (extracted == null || extracted.actions.isEmpty()) {
           return  new ChatResponse(false,
                'What would you like me to do?'
            );
        }

        // 3️⃣ Loop each action
        for (ActionExtractionResult.ActionItem action : extracted.actions) {

            // Resolve object
            ObjectResolver.ResolutionResult obj =
                ObjectResolver.resolve(action.objectName);
			
            if (!obj.resolved) {
               return new ChatResponse(
        false,
        'I could not identify the object you want to create.'
    );          
            }
				if (action.intent == 'CREATE') {
                
                return CreateHandler.handle(obj.objectApiName, userMessage);
            }
            }
       	return new ChatResponse(false, 'No valid action found.');		
}
}