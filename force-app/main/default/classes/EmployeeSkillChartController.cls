public with sharing class EmployeeSkillChartController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getCategoryCounts(Id accountId) {
        Map<String, Integer> resultMap = new Map<String, Integer>();
        try {
            for (AggregateResult ar : [
                SELECT Skill__r.Category__c category, COUNT(Id)
                FROM Employee_Skill__c
                WHERE Employee_Name__c = :accountId
                GROUP BY Skill__r.Category__c
            ]) {
                String category = (String)ar.get('category');
                Integer count = (Integer)ar.get('expr0'); // COUNT(Id) result
                resultMap.put(category, count);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
        return resultMap;
    }
}