public with sharing class QueryOperationHandler {
    
    public static List<SObject> getRecords(String objectName, List<String> fields, String whereClause, String orderBy, Integer limitCount) {
        try {
            String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectName;
            
            if (String.isNotBlank(whereClause)) {
                query += ' WHERE ' + whereClause;
            }
            
            if (String.isNotBlank(orderBy)) {
                query += ' ORDER BY ' + orderBy;
            }
            
            if (limitCount != null && limitCount > 0) {
                query += ' LIMIT ' + limitCount;
            }
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error querying records: ' + e.getMessage());
        }
    }
    
    public static SObject getRecordById(String objectName, List<String> fields, String recordId) {
        try {
            List<SObject> records = getRecords(objectName, fields, 'Id = \'' + recordId + '\'', null, 1);
            return records.isEmpty() ? null : records[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error getting record by Id: ' + e.getMessage());
        }
    }
    
    public static Integer getRecordCount(String objectName, String whereClause) {
        try {
            String query = 'SELECT COUNT() FROM ' + objectName;
            if (String.isNotBlank(whereClause)) {
                query += ' WHERE ' + whereClause;
            }
            return Database.countQuery(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error getting record count: ' + e.getMessage());
        }
    }
}