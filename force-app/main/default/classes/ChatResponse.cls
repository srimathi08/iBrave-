public class ChatResponse {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String message;
    @AuraEnabled public String type; // INFO | ERROR | CONFIRM
    @AuraEnabled public Map<String, Object> data;

    public ChatResponse(Boolean success, String message) {
        this.success = success;
        this.message = message;
        this.type = 'INFO';
    }
}