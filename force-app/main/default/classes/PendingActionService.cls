public class PendingActionService {

    public static Chat_Pending_Action__c getActive() {
        List<Chat_Pending_Action__c> recs = [
            SELECT Id, Intent__c, Object__c,
                   Collected_Fields__c, Missing_Fields__c, State__c
            FROM Chat_Pending_Action__c
            WHERE User__c = :UserInfo.getUserId()
            AND State__c IN ('COLLECTING','CONFIRM')
            ORDER BY Sequence__c
            LIMIT 1
        ];
        return recs.isEmpty() ? null : recs[0];
    }

    public static Chat_Pending_Action__c create(
        String intent,
        String objectApi,
        Map<String,Object> collected,
        List<String> missing,
        Integer seq
    ) {
        Chat_Pending_Action__c rec = new Chat_Pending_Action__c(
            User__c = UserInfo.getUserId(),
            Intent__c = intent,
            Object__c = objectApi,
            Collected_Fields__c = JSON.serialize(collected),
            Missing_Fields__c = JSON.serialize(missing),
            State__c = 'COLLECTING',
            Sequence__c = seq
        );
        insert rec;
        return rec;
    }

    public static void updateFields(
        Id id,
        Map<String,Object> merged,
        List<String> missing,
        String state
    ) {
        update new Chat_Pending_Action__c(
            Id = id,
            Collected_Fields__c = JSON.serialize(merged),
            Missing_Fields__c = JSON.serialize(missing),
            State__c = state
        );
    }
}