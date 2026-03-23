public without sharing class VoiceAssistantAgentAction {
    public class ActionInput {
        @InvocableVariable(label='User Command Text' description='The natural language command from the user.' required=true)
        public String userText;
    }

    public class ActionOutput {
        @InvocableVariable(label='Assistant Response Message' description='The feedback message from the HR Assistant.')
        public String responseMessage;
    }

    @InvocableMethod(label='HR Assistant: Process Voice Command' description='Processes HR commands like timesheets and attendance using Sarvam AI.')
    public static List<ActionOutput> processVoiceCommand(List<ActionInput> inputs) {
        List<ActionOutput> outputs = new List<ActionOutput>();
        
        for (ActionInput input : inputs) {
            ActionOutput output = new ActionOutput();
            try {
                // 1. Process the text via Sarvam AI (Intent Extraction)
                VoiceAssistantController.VoiceResponse res = VoiceAssistantController.processVoiceCommand(input.userText, UserInfo.getUserId());
                
                // 2. Execute the detected action (Record Creation)
                output.responseMessage = VoiceAssistantController.executeVoiceAction(res, UserInfo.getUserId());
            } catch (Exception e) {
                output.responseMessage = 'Sorry, I encountered an error: ' + e.getMessage();
            }
            outputs.add(output);
        }
        
        return outputs;
    }
}