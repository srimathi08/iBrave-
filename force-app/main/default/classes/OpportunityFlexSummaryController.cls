public with sharing class OpportunityFlexSummaryController {
    @AuraEnabled(cacheable=true)
    public static SummaryWrapper getCountsForOpportunity(Id opportunityId) {
        Integer interviewCount = [
            SELECT COUNT() FROM Interview__c
            WHERE Opportunity__c = :opportunityId
        ];

        Integer eligibleCount = [
            SELECT COUNT() FROM Job_Match__c
            WHERE Opportunity_Name__c = :opportunityId
            AND Match_Score__c >= 7

        ];

        Integer representedCount = [
            SELECT COUNT() FROM Presented_Candidate__c
            WHERE Opportunity__c = :opportunityId
            AND Status__c = 'Represented'
        ];

        Opportunity opp = [SELECT Name FROM Opportunity WHERE Id = :opportunityId];

        return new SummaryWrapper(opp.Name, interviewCount, eligibleCount, representedCount);
    }

    public class SummaryWrapper {
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Integer interviewCount;
        @AuraEnabled public Integer eligibleCount;
        @AuraEnabled public Integer representedCount;

        public SummaryWrapper(String opportunityName, Integer interviewCount, Integer eligibleCount, Integer representedCount) {
            this.opportunityName = opportunityName;
            this.interviewCount = interviewCount;
            this.eligibleCount = eligibleCount;
            this.representedCount = representedCount;
        }
    }

// 🔹 Represented Candidates
    @AuraEnabled(cacheable=true)
    public static List<Presented_Candidate__c> getPresentedCandidates(Id opportunityId) {
        return [
            SELECT Id, Name, Opportunity__r.Name, Status__c, Candidate_Name__r.Name
            FROM Presented_Candidate__c
            WHERE Opportunity__c = :opportunityId 
        ];
    }

    // 🔹 Eligible Candidates (Match Score >= 6)
    @AuraEnabled(cacheable=true)
    public static List<Job_Match__c> getEligibleCandidates(Id opportunityId) {
        return [
            SELECT Id, Opportunity_Name__r.Name, Candidate_Name__r.Name, Match_Score__c
            FROM Job_Match__c
            WHERE Opportunity_Name__c = :opportunityId AND Match_Score__c >= 7 ORDER BY Match_Score__c DESC NULLS LAST
        ];
    }

    // 🔹 Interviews Scheduled
    @AuraEnabled(cacheable=true)
    public static List<Interview__c> getInterviewRecords(Id opportunityId) {
        return [
            SELECT Id, Opportunity__r.Name, Candidate_Name__r.Name, Interview_Stage__c, Interviewer_Name__r.Name
            FROM Interview__c
            WHERE Opportunity__c = :opportunityId
        ];
    }

@AuraEnabled
public static void deleteJobMatchRecord(Id recordId) {
    delete [SELECT Id FROM Job_Match__c WHERE Id = :recordId LIMIT 1];
}

}