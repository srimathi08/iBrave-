public class OpportunityMatchJob implements Queueable, Database.AllowsCallouts {
    private Id opportunityId;

    public OpportunityMatchJob(Id oppId) {
        this.opportunityId = oppId;
    }

    public void execute(QueueableContext context) {
        System.debug('🚀 Queueable started for Opportunity: ' + opportunityId);

        // 👉 Start the Batch — this will do all the heavy processing
        Database.executeBatch(new OpportunityMatchBatch(opportunityId), 100);

        System.debug('✅ Batch launched for Opportunity: ' + opportunityId);
    }
}




/*public class OpportunityMatchJob implements Queueable, Database.AllowsCallouts {
    private Id opportunityId;

    public OpportunityMatchJob(Id oppId) {
        this.opportunityId = oppId;
    }

    public void execute(QueueableContext context) {
        System.debug('🚀 Queueable started for Opportunity: ' + opportunityId);

        // Step 1: Get all valid candidate Accounts (you can chunk this later)
        List<Account> candidateAccounts = [
            SELECT Id
            FROM Account
            WHERE RecordType.DeveloperName IN ('Employee','Candidates','Contractor')
            LIMIT 2000  // ⚠️ Add LIMIT while testing
        ];

        List<Id> accountIds = new List<Id>();
        for (Account acc : candidateAccounts) {
            accountIds.add(acc.Id);
        }

        // Step 2: Call subset-based method
        OpportunityMatchHelper.generateMatchesForSubset(opportunityId, accountIds);

        System.debug('✅ Finished Queueable for Opportunity: ' + opportunityId);
    }
}*/