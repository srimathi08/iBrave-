public with sharing class EditController {

    /**
     * Updates attendance record with check-out data including photo
     */
    @AuraEnabled
    public static Map<String, Object> updateAttendance(Id recordId, Map<String,Object> changes) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            Employee_Attendance__c updateRec = new Employee_Attendance__c(Id = recordId);
            
            // Set basic fields with proper data type handling
            for (String fieldName : changes.keySet()) {
                if (fieldName != 'Check_Out_Photo_B64' && fieldName != 'Check_Out_Photo_Name') {
                    Object fieldValue = changes.get(fieldName);
                    
                    // Handle DateTime fields properly
                    if (fieldName == 'Check_Out_Time__c') {
                        if (fieldValue instanceof String) {
                            String datetimeStr = (String) fieldValue;
                            // Parse the datetime string properly
                            updateRec.Check_Out_Time__c = DateTime.valueOf(datetimeStr);
                        } else if (fieldValue instanceof DateTime) {
                            updateRec.Check_Out_Time__c = (DateTime) fieldValue;
                        }
                    } else {
                        // Handle other fields normally
                        updateRec.put(fieldName, fieldValue);
                    }
                }
            }
            
            // Handle Check-out photo
            if (changes.containsKey('Check_Out_Photo_B64') && changes.containsKey('Check_Out_Photo_Name')) {
                String contentDocumentId = createContentDocument(
                    (String) changes.get('Check_Out_Photo_B64'),
                    (String) changes.get('Check_Out_Photo_Name'),
                    'Check-out Photo for record ' + recordId
                );
                updateRec.Check_Out_Photo_Id__c = contentDocumentId;
                
                // Create ContentDocumentLink to link the file to the attendance record
                createContentDocumentLink(contentDocumentId, recordId);
            }
            
            update updateRec;
            
            // Get updated record
            Employee_Attendance__c updatedRecord = [
                SELECT LastModifiedDate FROM Employee_Attendance__c WHERE Id = :recordId LIMIT 1
            ];
            
            result.put('success', true);
            result.put('lastModifiedDate', updatedRecord.LastModifiedDate);
            result.put('message', 'Attendance record updated successfully');
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
            result.put('stackTrace', e.getStackTraceString());
            System.debug('Error updating attendance: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Creates a ContentDocument from base64 image data
     */
    private static String createContentDocument(String base64Data, String fileName, String title) {
        try {
            // Create ContentVersion first
            ContentVersion cv = new ContentVersion();
            cv.Title = title;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.ContentLocation = 'S'; // 'S' for Salesforce
            cv.IsMajorVersion = true;
            
            insert cv;
            
            // Get the ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            return cv.ContentDocumentId;
            
        } catch (Exception e) {
            System.debug('Error creating ContentDocument: ' + e.getMessage());
            throw new AuraHandledException('Failed to create photo document: ' + e.getMessage());
        }
    }
    
    /**
     * Creates ContentDocumentLink to associate file with record
     */
    private static void createContentDocumentLink(String contentDocumentId, Id recordId) {
        try {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            
        } catch (Exception e) {
            System.debug('Error creating ContentDocumentLink: ' + e.getMessage());
            // Don't throw exception here as the main record is already created
        }
    }
}