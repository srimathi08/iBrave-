public with sharing class InterviewQuestionController {
    @AuraEnabled
    public static void saveInterviewQuestions(Id candidateId, Id opportunityId, Date interviewDate, List<String> questions) {
        List<Interview_Question__c> records = new List<Interview_Question__c>();

        for (String q : questions) {
            Interview_Question__c rec = new Interview_Question__c();
            rec.Candidate_Name__c = candidateId;
            rec.Opportunity_Name__c = opportunityId;
            rec.Interview_Date__c = interviewDate;
            rec.Question__c = q;
            records.add(rec);
        }

        if (!records.isEmpty()) {
            insert records;
        }
    }
}