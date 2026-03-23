public class InterviewQuestionRelatedOpp {
    @AuraEnabled(cacheable=true)
    public static List<String> getInterviewQuestions(Id opportunityId) {
        List<String> questionTexts = new List<String>();

        if (opportunityId == null) {
            return questionTexts;
        }
        
        List<Interview_Question__c> questions = [
            SELECT Question__c 
            FROM Interview_Question__c
            WHERE Opportunity_Name__c = :opportunityId
        ];
        
        for (Interview_Question__c q : questions) {
            questionTexts.add(q.Question__c);
        }
        
        return questionTexts;
    }
}