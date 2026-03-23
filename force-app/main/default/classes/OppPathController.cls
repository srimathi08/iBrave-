/*public with sharing class OppPathController {
    @AuraEnabled(cacheable=true)
    public static String getOpportunityStage(Id recordId) {
        if (recordId == null) return null;
        return [SELECT StageName FROM Opportunity WHERE Id = :recordId LIMIT 1].StageName;
    }
}*/


public with sharing class OppPathController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getOpportunityInfo(Id recordId) {
        if (recordId == null) return null;
        Opportunity opp = [
            SELECT StageName, RecordType.DeveloperName
            FROM Opportunity
            WHERE Id = :recordId
            LIMIT 1
        ];
        return new Map<String, String>{
            'StageName' => opp.StageName,
            'RecordType' => opp.RecordType.DeveloperName
        };
    }
}