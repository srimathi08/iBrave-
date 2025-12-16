public with sharing class SOQLController {

    /**
     * Build and run dynamic SOQL safely.
     * @param objApi     Object API name (e.g., 'Employee_Attendance__c')
     * @param fieldList  Comma-delimited fields (validated)
     * @param whereClause optional WHERE (no need to include 'WHERE')
     * @return List<SObject>  –  generic result set
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> queryRecords(
        String objApi,
        String fieldList,
        String whereClause
    ){
        // Whitelist fields to prevent injection
        Set<String> allowed =
            Schema.getGlobalDescribe().get(objApi)
                  .getDescribe().fields.getMap().keyset();
        List<String> requested = fieldList.split(',');
        for(String f : requested){
            if(!allowed.contains(f.trim())) {
                throw new AuraHandledException('Field '+f+' not allowed');
            }
        }

        String soql = 'SELECT ' + String.join(requested, ',') +
                      ' FROM ' + objApi;
        if(String.isNotBlank(whereClause)){
            soql += ' WHERE ' + whereClause;
        }
        return Database.query(soql);
    }
}