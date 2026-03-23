public without sharing class VoiceServiceHarness {

    @AuraEnabled
    public static String ping() {
        return 'Harness OK';
    }

    @AuraEnabled
    public static String processAudio(String base64Data, String audioType) {
        return VoiceAssistantController.transcribeAudio(base64Data, audioType);
    }

    @AuraEnabled
    public static VoiceAssistantController.VoiceResponse processText(String text, String userId) {
        return VoiceAssistantController.processVoiceCommand(text, userId);
    }

    @AuraEnabled
    public static String execute(VoiceAssistantController.VoiceResponse res, String userId) {
        return VoiceAssistantController.executeVoiceAction(res, userId);
    }
}