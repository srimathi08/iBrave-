public class OpportunityMatchBatch 
       implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private Id oppId;

    public OpportunityMatchBatch(Id opportunityId) {
        this.oppId = opportunityId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM Account ' +
            'WHERE RecordType.DeveloperName IN (\'Employee\', \'Candidates\', \'Contractor\')'
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {

        List<Id> accountIds = new List<Id>();
        for (Account a : scope) {
            accountIds.add(a.Id);
        }

        // 👉 Only process 100 accounts per batch — safe from CPU limit
        OpportunityMatchHelper.generateMatchesForSubset(oppId, accountIds);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('🎉 Matching job completed for Opportunity ' + oppId);
    }
}