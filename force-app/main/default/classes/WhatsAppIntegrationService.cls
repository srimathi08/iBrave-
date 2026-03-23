public without sharing class WhatsAppIntegrationService {

    /**
     * Entry point from Webhook (Async to prevent timeout)
     */
    public static void enqueueMessageProcessing(String fromPhone, String msgType, String rawMsgJson) {
        System.enqueueJob(new WhatsAppProcessor(fromPhone, msgType, rawMsgJson));
    }

    public class WhatsAppProcessor implements Queueable, Database.AllowsCallouts {
        private String fromPhone;
        private String msgType;
        private String rawMsgJson;

        public WhatsAppProcessor(String fromPhone, String msgType, String rawMsgJson) {
            this.fromPhone = fromPhone;
            this.msgType = msgType;
            this.rawMsgJson = rawMsgJson;
        }

        public void execute(QueueableContext context) {
            try {
                // 1. Identify User
                if (String.isBlank(fromPhone)) {
                    System.debug('WhatsApp Processor: fromPhone is null');
                    return; 
                }
                Id userId = identifyUser(fromPhone);
                if (userId == null) {
                    sendWhatsAppTextSafe(fromPhone, 'Sorry, I couldn\'t find an employee record for your phone number (' + fromPhone + '). Please contact HR to register your number.');
                    return;
                }

                // 2. Extract Transcript
                String transcript = '';
                Map<String, Object> msgMap = (Map<String, Object>) JSON.deserializeUntyped(rawMsgJson);

                // Handle both 'typex' (from wrapper) and 'type' (standard)
                String effectiveType = msgMap.containsKey('typex') ? (String)msgMap.get('typex') : (String)msgMap.get('type');

                if ('text'.equals(effectiveType)) {
                    Map<String, Object> textObj = (Map<String, Object>) msgMap.get('text');
                    transcript = (String) textObj.get('body');
                } else if ('audio'.equals(effectiveType)) {
                    Map<String, Object> audioObj = (Map<String, Object>) msgMap.get('audio');
                    String mediaId = (String) audioObj.get('id');
                    
                    // Transcribe FIRST to avoid DML conflict with "Processing..." message
                    transcript = downloadAndTranscribe(mediaId, userId);
                    
                    if (String.isNotBlank(transcript)) {
                        sendWhatsAppTextSafe(fromPhone, '📝 I heard: "' + transcript + '"');
                    } else {
                        sendWhatsAppTextSafe(fromPhone, '⚠️ Sorry, I couldn\'t transcribe that voice note.');
                    }
                }

                if (String.isBlank(transcript)) return;

                // 3. Process via Agentforce Agent
                Map<String, Object> agentResult = PR_Agentforce_CRM_Action.sendMessage(transcript, null, userId);
                String resultMessage = '';
                
                if (agentResult.containsKey('agentResponse')) {
                    Object respObj = agentResult.get('agentResponse');
                    Map<String, Object> respMap;
                    
                    if (respObj instanceof String) {
                        respMap = (Map<String, Object>) JSON.deserializeUntyped((String)respObj);
                    } else if (respObj instanceof Map<String, Object>) {
                        respMap = (Map<String, Object>) respObj;
                    }

                    if (respMap != null && respMap.containsKey('value')) {
                        resultMessage = (String) respMap.get('value');
                    } else {
                        resultMessage = 'Agent reached but no text response was found in the data.';
                    }
                } else {
                    resultMessage = 'Agent reached but no response was returned.';
                }
                
                // 4. Send Confirmation Asynchronously to avoid "Uncommitted work pending" error
                sendWhatsAppTextSafe(fromPhone, resultMessage);

            } catch (Exception e) {
                System.debug('WhatsApp Processor Error: ' + e.getMessage());
                // LOG BACKGROUND ERROR
                try {
                    Service__c errorLog = new Service__c();
                    errorLog.Name = 'Async Error ' + Datetime.now().format();
                    errorLog.Email_Body__c = 'Error: ' + e.getMessage() + '\nStack: ' + e.getStackTraceString();
                    errorLog.Whatsapp__c = true;
                    insert errorLog;
                } catch(Exception logEx) {}
            }
        }
    }

    // ─── HELPERS ──────────────────────────────────────────────────────────

    @future(callout=true)
    public static void sendWhatsAppTextAsync(String toPhone, String message) {
        sendWhatsAppText(toPhone, message);
    }

    public static Id identifyUser(String phone) {
        if (String.isBlank(phone)) return null;
        String leanPhone = phone.replaceAll('[^0-9]', '');
        
        // Match full or last 10 digits
        String last10 = leanPhone.length() >= 10 ? leanPhone.substring(leanPhone.length() - 10) : leanPhone;
        String wildcard = '%' + last10;

        List<User> users = [SELECT Id FROM User WHERE 
            (Phone = :phone OR MobilePhone = :phone OR Phone = :leanPhone OR MobilePhone = :leanPhone OR Phone LIKE :wildcard OR MobilePhone LIKE :wildcard) 
            AND IsActive = true LIMIT 1];
        
        if (!users.isEmpty()) return users[0].Id;
        return null;
    }

    private static String downloadAndTranscribe(String mediaId, Id userId) {
        String token = System.Label.WhatsAppToken;
        
        // 1. Get Media URL
        Http h = new Http();
        HttpRequest req1 = new HttpRequest();
        req1.setEndpoint('https://graph.facebook.com/v20.0/' + mediaId);
        req1.setMethod('GET');
        req1.setHeader('Authorization', 'Bearer ' + token);
        
        HttpResponse res1 = h.send(req1);
        if (res1.getStatusCode() != 200) return 'Error fetching media info';
        
        Map<String, Object> mediaInfo = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
        String downloadUrl = (String) mediaInfo.get('url');
        String mimeType = (String) mediaInfo.get('mime_type');

        // 2. Download File
        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint(downloadUrl);
        req2.setMethod('GET');
        req2.setHeader('Authorization', 'Bearer ' + token);
        
        HttpResponse res2 = h.send(req2);
        if (res2.getStatusCode() != 200) return 'Error downloading audio';
        
        // 3. Transcribe via VoiceAssistantController binary method
        return VoiceAssistantController.transcribeBlob(res2.getBodyAsBlob(), mimeType);
    }

    public static void sendWhatsAppTextSafe(String toPhone, String message) {
        try {
            // Attempt sync. If fails with "Uncommitted work", go async.
            sendWhatsAppText(toPhone, message);
        } catch (Exception e) {
            if (e.getMessage().contains('uncommitted work')) {
                sendWhatsAppTextAsync(toPhone, message);
            } else {
                throw e;
            }
        }
    }

    public static void sendWhatsAppText(String toPhone, String message) {
        String phoneId = System.Label.WHATSAPP_PHONE_ID;
        String token = System.Label.WhatsAppToken;

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://graph.facebook.com/v20.0/' + phoneId + '/messages');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'messaging_product' => 'whatsapp',
            'to' => toPhone,
            'type' => 'text',
            'text' => new Map<String, String>{ 'body' => message }
        };
        req.setBody(JSON.serialize(body));
        
        if (!Test.isRunningTest()) http.send(req);
    }

    public static Boolean verifySignature(String signature, String body) {
        if (String.isBlank(signature) || String.isBlank(body)) return false;
        // signature comes as sha256=HASH
        String expectedHash = signature.replace('sha256=', '');
        String appSecret = System.Label.WHATSAPPSECRET_1; 
        
        if (String.isBlank(appSecret) || 'YOUR_APP_SECRET'.equals(appSecret)) return true; 
        
        Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(appSecret));
        String actualHash = EncodingUtil.convertToHex(hmac);
        
        return actualHash.equals(expectedHash);
    }
}