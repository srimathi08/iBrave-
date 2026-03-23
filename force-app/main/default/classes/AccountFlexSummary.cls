public with sharing class AccountFlexSummary {
    @AuraEnabled(cacheable=true)
    public static SummaryWrapper getInterviewSummary(Id accountId) {
        Integer interviewCount = [
            SELECT COUNT() 
            FROM Interview__c 
            WHERE Candidate_Name__c = :accountId
        ];

        Account acc = [SELECT Name FROM Account WHERE Id = :accountId];

        return new SummaryWrapper(acc.Name, interviewCount);
    }

    public class SummaryWrapper {
        @AuraEnabled public String accountName;
        @AuraEnabled public Integer interviewCount;

        public SummaryWrapper(String accountName, Integer interviewCount) {
            this.accountName = accountName;
            this.interviewCount = interviewCount;
        }
    }
}