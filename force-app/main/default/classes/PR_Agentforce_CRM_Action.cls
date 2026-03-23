public without sharing class PR_Agentforce_CRM_Action {

    @InvocableMethod(
        label='Execute HR Assistant CRM Action'
        description='Handles HR-related commands such as logging timesheets, applying for leave, and check-in/out by processing natural language text.'
    )
    public static List<Response> execute(List<Request> requests) {
        System.debug('🤖 AGENTFORCE TOOL CALL DETECTED! Total requests: ' + requests.size());
        List<Response> responses = new List<Response>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            
            // Auto-extract UserId from context if present in the text
            String finalUserId = req.userId;
            String processedText = req.text;
            
            if (String.isNotBlank(req.text) && req.text.contains('[CONTEXT: UserID=')) {
                try {
                    Integer startIdx = req.text.indexOf('UserID=') + 7;
                    Integer endIdx = req.text.indexOf(']', startIdx);
                    if (endIdx > startIdx) {
                        finalUserId = req.text.substring(startIdx, endIdx);
                        System.debug('💡 Extracted UserId from context: ' + finalUserId);
                        
                        // ✅ STRIP context block so AI only sees the user's actual question
                        processedText = req.text.substring(endIdx + 1).trim();
                    }
                } catch (Exception e) {
                    System.debug('⚠️ Context extraction failed: ' + e.getMessage());
                }
            }

            if (String.isBlank(finalUserId)) {
                finalUserId = UserInfo.getUserId();
            }

            System.debug('📥 Request #' + (i+1) + ': Text=[' + processedText + '], UserId=[' + finalUserId + ']');
            
            // DIAGNOSTIC LOG: See what the Agent is actually passing!
            try {
                Service__c agentLog = new Service__c();
                agentLog.Name = 'AGENT TOOL CALL ' + Datetime.now().format();
                agentLog.Email_Body__c = 'RAW REQ TEXT: ' + req.text + '\nRAW REQ USERID: ' + req.userId + '\nPROCESSED TEXT: ' + processedText + '\nFINAL USERID: ' + finalUserId;
                agentLog.Whatsapp__c = true;
                insert agentLog;
            } catch(Exception logEx) {}
            
            Response res = new Response();
            try {
                // STEP 1: Parse intent from natural language (calls Sarvam AI)
                String parsedJson = VoiceAssistantController.processVoiceCommandJson(
                    processedText,
                    finalUserId
                );
                System.debug('🔍 Parsed Intent JSON: ' + parsedJson);
                
                // STEP 2: Execute the action — actually creates/updates Salesforce records
                String actionResult = VoiceAssistantController.executeVoiceActionFromJson(
                    parsedJson,
                    finalUserId
                );
                System.debug('✅ Action Result: ' + actionResult);
                
                res.resultJson = actionResult;
                res.success = true;
            } catch (Exception e) {
                System.debug('❌ Error: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
                res.resultJson = 'Error: ' + e.getMessage();
                res.errorMessage = e.getMessage();
                res.success = false;
            }
            responses.add(res);
        }
        return responses;
    }
 
    
    public class Request {
        @InvocableVariable(required=true)
        public String text;
        @InvocableVariable(required=false)
        public String userId;
    }
 
    public class Response {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String resultJson;
        @InvocableVariable public String errorMessage;
    }
    
    
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> sendMessage(String userMessage, String sessionId, String UserId) {
 
        Invocable.Action action = Invocable.Action.createCustomAction(
            'generateAiAgentResponse',
            'ProHRM_AI_Assistant'
        );
 
        // Prepend UserId to message as a context block for the Agent
        String prompt = userMessage;
        if (String.isNotBlank(UserId)) {
            prompt = '[CONTEXT: UserID=' + UserId + '] ' + userMessage;
        }

        action.setInvocationParameter('userMessage', prompt);
        if(!String.isBlank(sessionId)){
            action.setInvocationParameter('sessionId', sessionId);
        }
        List<Invocable.Action.Result> results = action.invoke();
        Invocable.Action.Result result = results[0];
 		System.debug('result'+result);
        if (!result.isSuccess()) {
            throw new AuraHandledException(
                result.getErrors()[0].getMessage()
            );
        }
 
        
        return result.getOutputParameters();
    }
    
}