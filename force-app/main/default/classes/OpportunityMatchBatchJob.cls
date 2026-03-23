public class OpportunityMatchBatchJob implements Queueable, Database.AllowsCallouts {

    private Id opportunityId;
    private List<Id> allAccountIds;
    private Integer startIndex;

    public OpportunityMatchBatchJob(Id oppId, List<Id> ids, Integer start) {
        this.opportunityId = oppId;
        this.allAccountIds = ids;
        this.startIndex = start;
    }

    public void execute(QueueableContext ctx) {

        Integer batchSize = 50;

        // Extract batch manually
        List<Id> chunk = new List<Id>();
        for (Integer i = startIndex; i < Math.min(startIndex + batchSize, allAccountIds.size()); i++) {
            chunk.add(allAccountIds[i]);
        }

        // Process batch
        OpportunityMatchHelper.generateMatchesForSubset(opportunityId, chunk);

        // Chain next batch if more remain
        Integer nextIndex = startIndex + batchSize;
        if (nextIndex < allAccountIds.size()) {
            System.enqueueJob(
                new OpportunityMatchBatchJob(opportunityId, allAccountIds, nextIndex)
            );
        }
    }
}