public with sharing class DMLManager {
    
    /**
     * Generic insert operation for any sObject type
     * @param records List of sObjects to insert
     * @return List<Id> Inserted record IDs
     */
    public static List<Id> insertRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Id>();
        }
        
        try {
            insert records;
            List<Id> insertedIds = new List<Id>();
            for (SObject record : records) {
                insertedIds.add(record.Id);
            }
            return insertedIds;
        } catch (DMLException e) {
            System.debug('Insert failed: ' + e.getMessage());
            throw new AuraHandledException('Insert operation failed: ' + e.getMessage());
        }
    }
    
    /**
     * Generic update operation for any sObject type
     * @param records List of sObjects to update (must have Id populated)
     * @return Boolean Success status
     */
    public static Boolean updateRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return false;
        }
        
        try {
            update records;
            return true;
        } catch (DMLException e) {
            System.debug('Update failed: ' + e.getMessage());
            throw new AuraHandledException('Update operation failed: ' + e.getMessage());
        }
    }
    
    /**
     * Generic upsert operation based on record Id
     * If Id is present - updates, if not - inserts
     * @param records List of sObjects to upsert
     * @return List<Id> Record IDs
     */
    public static List<Id> upsertRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return new List<Id>();
        }
        
        List<SObject> toInsert = new List<SObject>();
        List<SObject> toUpdate = new List<SObject>();
        
        // Separate records based on Id presence
        for (SObject record : records) {
            if (record.Id != null) {
                toUpdate.add(record);
            } else {
                toInsert.add(record);
            }
        }
        
        List<Id> resultIds = new List<Id>();
        
        // Insert new records
        if (!toInsert.isEmpty()) {
            resultIds.addAll(insertRecords(toInsert));
        }
        
        // Update existing records
        if (!toUpdate.isEmpty()) {
            updateRecords(toUpdate);
            for (SObject record : toUpdate) {
                resultIds.add(record.Id);
            }
        }
        
        return resultIds;
    }
    
    /**
     * Generic delete operation with error handling
     * @param records List of sObjects to delete (must have Id)
     * @return Boolean Success status
     */
    public static Boolean deleteRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return false;
        }
        
        try {
            delete records;
            return true;
        } catch (DMLException e) {
            System.debug('Delete failed: ' + e.getMessage());
            throw new AuraHandledException('Delete operation failed: ' + e.getMessage());
        }
    }
    
    /**
     * Safe delete - doesn't throw exceptions, just logs errors
     * Useful for cleanup operations where failure shouldn't break the flow
     * @param records List of sObjects to delete
     * @return Boolean Success status
     */
    public static Boolean safeDelete(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return false;
        }
        
        try {
            delete records;
            return true;
        } catch (DMLException e) {
            System.debug('Safe delete failed: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Bulk DML operation with partial success handling
     * @param records List of sObjects to insert
     * @param allowPartialSuccess Whether to allow partial success
     * @return Database.SaveResult[] Results of the operation
     */
    public static Database.SaveResult[] insertRecordsWithResults(
        List<SObject> records, 
        Boolean allowPartialSuccess
    ) {
        if (records == null || records.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        
        Database.SaveResult[] results = Database.insert(records, allowPartialSuccess);
        
        // Log any failures
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug('Record ' + i + ' failed: ' + results[i].getErrors());
            }
        }
        
        return results;
    }
    
    /**
     * Bulk update with partial success handling
     * @param records List of sObjects to update
     * @param allowPartialSuccess Whether to allow partial success
     * @return Database.SaveResult[] Results of the operation
     */
    public static Database.SaveResult[] updateRecordsWithResults(
        List<SObject> records, 
        Boolean allowPartialSuccess
    ) {
        if (records == null || records.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        
        Database.SaveResult[] results = Database.update(records, allowPartialSuccess);
        
        // Log any failures
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug('Update record ' + i + ' failed: ' + results[i].getErrors());
            }
        }
        
        return results;
    }
    
    /**
     * Get object type from records for logging/debugging
     * @param records List of sObjects
     * @return String Object API name
     */
    private static String getObjectType(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return 'Unknown';
        }
        return records[0].getSObjectType().getDescribe().getName();
    }
}