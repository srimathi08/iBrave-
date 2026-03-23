// ProHRM Stealth Bridge - Force Refresh: 2026-02-25T10:10
public without sharing class ProHRM_DataBridge {

    @AuraEnabled
    public static String checkStatus(String p1) {
        try {
            return 'Bridge Status: OK | ' + p1;
        } catch (Exception e) {
            return 'Check Error: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String processData(String p1, String p2) {
        try {
            return VoiceAssistantController.processVoiceCommandJson(p1, p2);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String submitData(String p1, String p2) {
        try {
            return VoiceAssistantController.executeVoiceActionFromJson(p1, p2);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String uploadData(String p1, String p2) {
        try {
            String result = VoiceAssistantController.transcribeAudio(p1, p2);
            if (result == null) return null;
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}