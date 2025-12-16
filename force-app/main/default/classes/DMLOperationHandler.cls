public with sharing class DMLOperationHandler {
    
    public static List<SObject> insertRecords(List<SObject> recordsToInsert) {
        try {
            Database.SaveResult[] saveResults = Database.insert(recordsToInsert, false);
            List<SObject> successfulInserts = new List<SObject>();
            
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    successfulInserts.add(recordsToInsert[i]);
                }
            }
            return successfulInserts;
        } catch (Exception e) {
            throw new AuraHandledException('Error inserting records: ' + e.getMessage());
        }
    }
    
    public static List<SObject> updateRecords(List<SObject> recordsToUpdate) {
        try {
            Database.SaveResult[] saveResults = Database.update(recordsToUpdate, false);
            List<SObject> successfulUpdates = new List<SObject>();
            
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    successfulUpdates.add(recordsToUpdate[i]);
                }
            }
            return successfulUpdates;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating records: ' + e.getMessage());
        }
    }
    
    public static void deleteRecords(List<SObject> recordsToDelete) {
        try {
            Database.delete(recordsToDelete, false);
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting records: ' + e.getMessage());
        }
    }
}