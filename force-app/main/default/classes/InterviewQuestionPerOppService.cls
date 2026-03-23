public class InterviewQuestionPerOppService {
    // One-time award per (Account, Opportunity); never revoke
    private static final String ACTION = 'QuestionOnOpportunity'; // add this to Action__c picklist
    private static final Decimal POINTS_PER_OPP = 5;              // points to grant once per pair

    // Deterministic key so we never duplicate the same award
    private static String key(Id acctId, Id oppId) {
        return String.valueOf(acctId) + '-' + String.valueOf(oppId) + '-' + ACTION;
    }

    // Entry point from trigger
    public static void syncForDml() {
        if (!Trigger.isAfter) return;

        // We never remove points, so on pure delete events we can skip work
        if (Trigger.isDelete) return;

        // We only care about the NEW side (insert/update/undelete)
        List<Interview_Question__c> rows = (List<Interview_Question__c>) Trigger.new;
        if (rows == null || rows.isEmpty()) return;

        // Collect (Account, Opportunity) pairs present in NEW records
        Set<String> pairKeys = new Set<String>();
        Map<String, Id> pairToAcct = new Map<String, Id>();
        Map<String, Id> pairToOpp  = new Map<String, Id>();

        for (Interview_Question__c q : rows) {
            if (q.Candidate_Name__c == null || q.Opportunity_Name__c == null) continue;
            String pk = q.Candidate_Name__c + '-' + q.Opportunity_Name__c;
            if (!pairKeys.contains(pk)) {
                pairKeys.add(pk);
                pairToAcct.put(pk, q.Candidate_Name__c);
                pairToOpp.put(pk,  q.Opportunity_Name__c);
            }
        }
        if (pairKeys.isEmpty()) return;

        // Build filter sets
        Set<Id> acctIds = new Set<Id>();
        Set<Id> oppIds  = new Set<Id>();
        for (String pk : pairKeys) {
            acctIds.add(pairToAcct.get(pk));
            oppIds.add(pairToOpp.get(pk));
        }

        // Count questions per (Account, Opportunity) among these pairs
        Map<String, Integer> countsByPair = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Candidate_Name__c acc, Opportunity_Name__c opp, COUNT(Id) cnt
            FROM Interview_Question__c
            WHERE Candidate_Name__c IN :acctIds AND Opportunity_Name__c IN :oppIds
            GROUP BY Candidate_Name__c, Opportunity_Name__c
        ]) {
            String pk = (String)ar.get('acc') + '-' + (String)ar.get('opp');
            countsByPair.put(pk, (Integer)ar.get('cnt'));
        }

        // Load existing ledger rows for these pairs (Action = QuestionOnOpportunity)
        Map<String, Points_Ledger__c> existingByPair = new Map<String, Points_Ledger__c>();
        for (Points_Ledger__c pl : [
            SELECT Id, Account__c, Opportunity__c, Key__c
            FROM Points_Ledger__c
            WHERE Action__c = :ACTION
              AND Account__c IN :acctIds
              AND Opportunity__c IN :oppIds
        ]) {
            String pk = pl.Account__c + '-' + pl.Opportunity__c;
            existingByPair.put(pk, pl);
        }

        // Insert ONE award per pair if at least one question exists and no award yet
        List<Points_Ledger__c> toInsert = new List<Points_Ledger__c>();
        for (String pk : pairKeys) {
            Integer qCount = countsByPair.containsKey(pk) ? countsByPair.get(pk) : 0;
            if (qCount <= 0) continue;                // no questions yet → no award (and we never delete)
            if (existingByPair.containsKey(pk)) continue; // already awarded → skip

            Id a = pairToAcct.get(pk);
            Id o = pairToOpp.get(pk);

            toInsert.add(new Points_Ledger__c(
                Account__c     = a,
                Opportunity__c = o,
                Action__c      = ACTION,
                Points__c      = POINTS_PER_OPP,
                Date__c        = Date.today(),
                Key__c         = key(a, o)
            ));
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }
}