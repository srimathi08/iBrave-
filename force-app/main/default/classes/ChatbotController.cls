public with sharing class ChatbotController {

    @AuraEnabled
    public static ChatResponse sendMessage(String userMessage) {
        if (String.isBlank(userMessage)) {
            return new ChatResponse(false, 'Message cannot be empty');
        }

        try {
            return ChatbotActionOrchestrator.process(userMessage);

        } catch (Exception e) {
            return new ChatResponse(
                false,
                '❌ ' + e.getMessage()
            );
        }
    }
}