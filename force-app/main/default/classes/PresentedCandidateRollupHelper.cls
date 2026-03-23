public class PresentedCandidateRollupHelper {

    public static void updateOpportunityRollups(
        List<Presented_Candidate__c> newList,
        List<Presented_Candidate__c> oldList
    ) {
        // 🔒 Execution guard
        if (!TriggerExecutionGuard.canExecute('PresentedCandidateRollup')) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();

        if (newList != null) {
            for (Presented_Candidate__c pc : newList) {
                if (pc.Opportunity__c != null) {
                    oppIds.add(pc.Opportunity__c);
                }
            }
        }

        if (oldList != null) {
            for (Presented_Candidate__c pc : oldList) {
                if (pc.Opportunity__c != null) {
                    oppIds.add(pc.Opportunity__c);
                }
            }
        }

        if (oppIds.isEmpty()) return;

        // ✅ FIXED: Added Opportunity__c to SELECT clause
        List<Presented_Candidate__c> candidates = [
            SELECT Id, Opportunity__c, Status__c
            FROM Presented_Candidate__c
            WHERE Opportunity__c IN :oppIds
        ];

        Map<Id, Integer> presentedMap = new Map<Id, Integer>();
        Map<Id, Integer> filteredMap  = new Map<Id, Integer>();

        for (Presented_Candidate__c pc : candidates) {

            // Initialize counts
            if (!presentedMap.containsKey(pc.Opportunity__c)) {
                presentedMap.put(pc.Opportunity__c, 0);
                filteredMap.put(pc.Opportunity__c, 0);
            }

            // ✅ ALL records count as Presented
            presentedMap.put(
                pc.Opportunity__c,
                presentedMap.get(pc.Opportunity__c) + 1
            );

            // ✅ ONLY Selected count as Filtered
            if (pc.Status__c == 'Selected') {
                filteredMap.put(
                    pc.Opportunity__c,
                    filteredMap.get(pc.Opportunity__c) + 1
                );
            }
        }

        // Update Opportunities
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Id oppId : oppIds) {
            oppsToUpdate.add(new Opportunity(
                Id = oppId,
                Presented_Candidates__c = presentedMap.get(oppId),
                Filtered_Candidates__c  = filteredMap.get(oppId)
            ));
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}