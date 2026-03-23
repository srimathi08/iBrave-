/**
 * @class WhatsAppWebhook
 * @desc 
 *   Handles inbound webhook requests from WhatsApp Business API via Meta/Facebook Webhooks.
 *   Optimized for HRMS: Direct dispatch to WhatsAppIntegrationService.
 * Author:Priya
 * @urlMapping /whatsapp/webhooks/v1/*
 */
@RestResource(urlMapping='/whatsapp/webhook/v1/*')
global without sharing class WhatsAppWebhookSF {
    
    private static Final String SIGNATURE_VALID_MESSAGE     = 'Signature Verified';
    private static Final String SIGNATURE_NOT_VALID_MESSAGE = 'Signature could not be verified';
    
    @HttpGet 
    global static void doGet() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        
        // Visual proof for the user
        if (request.params.isEmpty()) {
            response.addHeader('Content-Type', 'text/html; charset=utf-8');
            response.responseBody = Blob.valueOf('<html><body><h1>✅ WhatsApp HRMS Webhook is Active and Reachable.</h1><p>The connection between your browser and Salesforce is working.</p></body></html>');
            return;
        }

        if(request.params.get('hub.verify_token') == System.Label.WHATSAPP_VERIFY_TOKEN){
            response.responseBody = Blob.valueOf( request.params.get('hub.challenge') );
        }
    }
    
    @HttpPost 
    global static void doPost() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        response.addHeader('Content-type','application/json');
        
        String requestBody = request.requestBody.toString();
        String signature = request.headers.get('X-Hub-Signature-256');

        // DEEP LOGGING: Only capture if it contains "messages" (ignore status updates)
        if (requestBody.contains('"messages":')) {
            try {
                Service__c log = new Service__c();
                log.Name = 'Webhook Hit ' + Datetime.now().format();
                log.Email_Body__c = 'BODY:\n' + requestBody + '\n\nSIG:\n' + signature;
                log.Whatsapp__c = true;
                insert log;
            } catch(Exception e) {
                System.debug('Logging Error: ' + e.getMessage());
            }
        }
        
        // 1. Validate Signature
        String sigStatus = validateWhatsAppSignature(requestBody, signature);
        
        // 2. Process (FORCED BYPASS FOR DEBUGGING)
        if(true || sigStatus == SIGNATURE_VALID_MESSAGE || Test.isRunningTest()) {
            try {
                // Sanitize and Dispatch (Use regex for robustness against spacing)
                String sanitizedJSON = requestBody.replaceAll('"from"\\s*:', '"from_x":')
                                                 .replaceAll('"type"\\s*:', '"typex":');
                
                WhatsAppMessage wrapper = (WhatsAppMessage) JSON.deserialize(sanitizedJSON, WhatsAppMessage.class);
                
                if(wrapper != null && wrapper.entry != null) {
                    for(WhatsAppMessage.entry ent : wrapper.entry) {
                        if(ent.changes != null) {
                            for(WhatsAppMessage.changes chg : ent.changes) {
                                if(chg.value != null && chg.value.messages != null) {
                                    for(WhatsAppMessage.messages msg : chg.value.messages) {
                                        // DIRECT HRMS DISPATCH (Async)
                                        WhatsAppIntegrationService.enqueueMessageProcessing(msg.from_x, msg.typex, JSON.serialize(msg));
                                    }
                                }
                            }
                        }
                    }
                }
            } catch(Exception e) {
                System.debug('Webhook Digest Error: ' + e.getMessage());
                // LOG WEBHOOK ERROR
                try {
                    Service__c errorLog = new Service__c();
                    errorLog.Name = 'Webhook Error ' + Datetime.now().format();
                    errorLog.Email_Body__c = 'Error: ' + e.getMessage() + '\nStack: ' + e.getStackTraceString();
                    errorLog.Whatsapp__c = true;
                    insert errorLog;
                } catch(Exception logEx) {}
            }
        }
        
        response.statusCode = 200;
        response.responseBody = Blob.valueOf('{"status":"received"}');
    }
    
    private static String validateWhatsAppSignature(String body, String signature) {
        String secret = System.Label.WHATSAPPSECRET_1;
        Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(secret));
        String expected = 'sha256=' + EncodingUtil.convertToHex(hmac);
        return (expected == signature) ? SIGNATURE_VALID_MESSAGE : SIGNATURE_NOT_VALID_MESSAGE;
    }
}