/**
 * @description Enhanced NewController with Client Place and Field Work Details support
 * @author Salesforce Consultant
 * @date 2025-10-08
 * @version 4.0 - Added Client Place and Field Work Details fields + WFH Approval support
 */
public with sharing class NewController {
@AuraEnabled
public static Map<String, Object> createAttendance(Map<String, Object> payload) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        System.debug('=== CREATING ATTENDANCE RECORD WITH BRANCH SELECTION ===');
        System.debug('Full payload received: ' + JSON.serializePretty(payload));
        
        // Input validation
        if (payload == null || payload.isEmpty()) {
            throw new AuraHandledException('Payload is required');
        }
        
        if (!payload.containsKey('Employee_Name__c') || payload.get('Employee_Name__c') == null) {
            throw new AuraHandledException('Employee ID is required');
        }
        
        // Create the attendance record
        Employee_Attendance__c att = new Employee_Attendance__c();
        
        // Set basic attendance fields
        att.Employee_Name__c = (Id) payload.get('Employee_Name__c');
        System.debug('Employee ID: ' + att.Employee_Name__c);
        
        if (payload.containsKey('Date__c')) {
            String dateStr = (String) payload.get('Date__c');
            att.Date__c = Date.valueOf(dateStr);
            System.debug('Date: ' + att.Date__c);
        }
        
        // Fix DateTime parsing for Check-in Time
        if (payload.containsKey('Check_In_Time__c')) {
            String datetimeStr = (String) payload.get('Check_In_Time__c');
            att.Check_In_Time__c = DateTime.valueOf(datetimeStr.replace('T', ' ').replace('Z', ''));
            System.debug('Check-in Time: ' + att.Check_In_Time__c);
        }
        
        // Fix DateTime parsing for Check-out Time (if provided during check-in)
        if (payload.containsKey('Check_Out_Time__c')) {
            String datetimeStr = (String) payload.get('Check_Out_Time__c');
            att.Check_Out_Time__c = DateTime.valueOf(datetimeStr.replace('T', ' ').replace('Z', ''));
            System.debug('Check-out Time: ' + att.Check_Out_Time__c);
        }
        
        // Status
        if (payload.containsKey('Status__c')) {
            att.Status__c = (String) payload.get('Status__c');
            System.debug('Status: ' + att.Status__c);
        }
        
        if (payload.containsKey('Notes__c')) {
            att.Notes__c = (String) payload.get('Notes__c');
        }
        
        // ✅ NEW: Work Location
        if (payload.containsKey('Work_Location__c')) {
            att.Work_Location__c = (String) payload.get('Work_Location__c');
            System.debug('✅ Work Location: ' + att.Work_Location__c);
        }
        
        // ✅ NEW: Branch Name (Lookup to Branch__c)
        // This is populated when user selects "Work from Office"
        if (payload.containsKey('Branch_Name__c') && payload.get('Branch_Name__c') != null) {
            String branchIdStr = (String) payload.get('Branch_Name__c');
            if (String.isNotBlank(branchIdStr)) {
                att.Branch__c = (Id) branchIdStr;
                System.debug('✅ BRANCH ID CAPTURED: ' + att.Branch__c);
                
                // Verify branch exists
                try {
                    List<Branch__c> branchCheck = [
                        SELECT Id, Branch_Name__c, City__c, State__c 
                        FROM Branch__c 
                        WHERE Id = :att.Branch__c 
                        LIMIT 1
                    ];
                    
                    if (!branchCheck.isEmpty()) {
                        System.debug('✅ Branch verified: ' + branchCheck[0].Branch_Name__c);
                    } else {
                        System.debug('⚠️ WARNING: Branch ID provided but record not found');
                    }
                } catch (Exception branchEx) {
                    System.debug('⚠️ Could not verify branch: ' + branchEx.getMessage());
                }
            }
        }
        
        // ✅ NEW: Client Place Details (if Work Location = Client Place)
        if (payload.containsKey('Client_Place_Details__c') && 
            payload.get('Client_Place_Details__c') != null) {
            String clientDetails = (String) payload.get('Client_Place_Details__c');
            if (String.isNotBlank(clientDetails)) {
                att.Client_Place_Details__c = clientDetails;
                System.debug('📍 Client Place Details: ' + att.Client_Place_Details__c);
            }
        }
        
        // ✅ NEW: Field Work Details (if Work Location = Field Work)
        if (payload.containsKey('Field_Work_Details__c') && 
            payload.get('Field_Work_Details__c') != null) {
            String fieldDetails = (String) payload.get('Field_Work_Details__c');
            if (String.isNotBlank(fieldDetails)) {
                att.Field_Work_Details__c = fieldDetails;
                System.debug('🏗️ Field Work Details: ' + att.Field_Work_Details__c);
            }
        }
        
        // ✅ NEW: WFH Reason (Optional - if Work Location = Work from Home)
        if (payload.containsKey('WFH_Reason__c') && 
            payload.get('WFH_Reason__c') != null) {
            String wfhReason = (String) payload.get('WFH_Reason__c');
            if (String.isNotBlank(wfhReason)) {
                att.WFH_Reason__c = wfhReason;
                System.debug('🏠 WFH Reason: ' + att.WFH_Reason__c);
            }
        }
        
        // Insert the attendance record first
        System.debug('Attempting to insert attendance record...');
        insert att;
        System.debug('✅ Attendance record inserted successfully with ID: ' + att.Id);
        
        // ✅ Enhanced logging for what was captured
        if (att.Work_Location__c == 'Work from Office' && att.Branch__c != null) {
            System.debug('🏢 OFFICE ATTENDANCE - Branch captured successfully');
        } else if (att.Work_Location__c == 'Client Place' && String.isNotBlank(att.Client_Place_Details__c)) {
            System.debug('📍 CLIENT PLACE VISIT - Details captured');
        } else if (att.Work_Location__c == 'Field Work' && String.isNotBlank(att.Field_Work_Details__c)) {
            System.debug('🏗️ FIELD WORK - Details captured');
        } else if (att.Work_Location__c == 'Work from Home') {
            System.debug('🏠 WORK FROM HOME - Reason: ' + (String.isNotBlank(att.WFH_Reason__c) ? 'Provided' : 'Not provided'));
        }
        
        // Handle Check-in photo
        if (payload.containsKey('Check_In_Photo_B64') && 
            payload.containsKey('Check_In_Photo_Name')) {
            try {
                System.debug('Processing check-in photo...');
                String contentDocumentId = createContentDocument(
                    (String) payload.get('Check_In_Photo_B64'),
                    (String) payload.get('Check_In_Photo_Name'),
                    'Check-in Photo for ' + att.Employee_Name__c
                );
                att.Check_In_Photo_Id__c = contentDocumentId;
                System.debug('✅ Check-in photo ContentDocument created: ' + contentDocumentId);
                
                createContentDocumentLink(contentDocumentId, att.Id);
                System.debug('✅ Check-in photo linked to attendance record');
            } catch (Exception photoEx) {
                System.debug('⚠️ Warning: Check-in photo processing failed: ' + photoEx.getMessage());
            }
        }
        
        // Handle Check-out photo (if provided)
        if (payload.containsKey('Check_Out_Photo_B64') && 
            payload.containsKey('Check_Out_Photo_Name')) {
            try {
                System.debug('Processing check-out photo...');
                String contentDocumentId = createContentDocument(
                    (String) payload.get('Check_Out_Photo_B64'),
                    (String) payload.get('Check_Out_Photo_Name'),
                    'Check-out Photo for ' + att.Employee_Name__c
                );
                att.Check_Out_Photo_Id__c = contentDocumentId;
                System.debug('✅ Check-out photo ContentDocument created: ' + contentDocumentId);
                
                createContentDocumentLink(contentDocumentId, att.Id);
                System.debug('✅ Check-out photo linked to attendance record');
            } catch (Exception photoEx) {
                System.debug('⚠️ Warning: Check-out photo processing failed: ' + photoEx.getMessage());
            }
        }
        
        // Update the record with ContentDocument IDs if any photos were attached
        if (att.Check_In_Photo_Id__c != null || att.Check_Out_Photo_Id__c != null) {
            System.debug('Updating attendance record with photo IDs...');
            update att;
            System.debug('✅ Attendance record updated with photo references');
        }
        
        // Build success response
        result.put('success', true);
        result.put('recordId', att.Id);
        result.put('employeeId', att.Employee_Name__c);
        result.put('date', att.Date__c);
        result.put('checkInTime', att.Check_In_Time__c);
        result.put('workLocation', att.Work_Location__c);
        result.put('status', att.Status__c);
        
        // ✅ NEW: Include branch information in response if applicable
        if (att.Work_Location__c == 'Work from Office' && att.Branch__c != null) {
            result.put('branchId', att.Branch__c);
            result.put('hasBranch', true);
        } else {
            result.put('hasBranch', false);
        }
        
        // ✅ NEW: Include location details in response
        if (String.isNotBlank(att.Client_Place_Details__c)) {
            result.put('clientPlaceDetails', att.Client_Place_Details__c);
            result.put('hasClientPlaceDetails', true);
        } else {
            result.put('hasClientPlaceDetails', false);
        }
        
        if (String.isNotBlank(att.Field_Work_Details__c)) {
            result.put('fieldWorkDetails', att.Field_Work_Details__c);
            result.put('hasFieldWorkDetails', true);
        } else {
            result.put('hasFieldWorkDetails', false);
        }
        
        if (String.isNotBlank(att.WFH_Reason__c)) {
            result.put('wfhReason', att.WFH_Reason__c);
            result.put('hasWFHReason', true);
        } else {
            result.put('hasWFHReason', false);
        }
        
        // Build success message
        String successMessage = 'Attendance record created successfully';
        if (att.Work_Location__c == 'Work from Office') {
            successMessage += ' - Office attendance with branch';
        } else if (att.Work_Location__c == 'Client Place') {
            successMessage += ' - Client visit details captured';
        } else if (att.Work_Location__c == 'Field Work') {
            successMessage += ' - Field work details captured';
        } else if (att.Work_Location__c == 'Work from Home') {
            successMessage += ' - Work from home';
        }
        
        if (att.Check_In_Photo_Id__c != null) {
            successMessage += ' with photo';
        }
        
        result.put('message', successMessage);
        
        System.debug('=== ATTENDANCE CREATION SUCCESSFUL ===');
        System.debug('Success Response: ' + JSON.serializePretty(result));
        
    } catch (DmlException dmlEx) {
        System.debug('❌ DML EXCEPTION in createAttendance');
        System.debug('Error Message: ' + dmlEx.getMessage());
        System.debug('Stack Trace: ' + dmlEx.getStackTraceString());
        System.debug('DML Fields: ' + dmlEx.getDmlFieldNames(0));
        System.debug('DML Message: ' + dmlEx.getDmlMessage(0));
        
        result.put('success', false);
        result.put('error', 'Database error: ' + dmlEx.getMessage());
        result.put('errorType', 'DML_EXCEPTION');
        result.put('dmlFields', dmlEx.getDmlFieldNames(0));
        
    } catch (AuraHandledException ahe) {
        System.debug('❌ AURA HANDLED EXCEPTION in createAttendance');
        System.debug('Error Message: ' + ahe.getMessage());
        
        result.put('success', false);
        result.put('error', ahe.getMessage());
        result.put('errorType', 'VALIDATION_ERROR');
        
    } catch (Exception e) {
        System.debug('❌ GENERAL EXCEPTION in createAttendance');
        System.debug('Error Message: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        System.debug('Exception Type: ' + e.getTypeName());
        
        result.put('success', false);
        result.put('error', 'Unexpected error: ' + e.getMessage());
        result.put('errorType', e.getTypeName());
    }
    
    return result;
}
    /**
     * @description Creates a ContentDocument from base64 image data
     * @param base64Data Base64 encoded image data
     * @param fileName Name of the file
     * @param title Title for the ContentVersion
     * @return String ContentDocumentId of the created document
     */
    private static String createContentDocument(String base64Data, String fileName, String title) {
        try {
            System.debug('Creating ContentVersion...');
            System.debug('File Name: ' + fileName);
            System.debug('Title: ' + title);
            
            // Create ContentVersion first
            ContentVersion cv = new ContentVersion();
            cv.Title = title;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.ContentLocation = 'S'; // 'S' for Salesforce
            cv.IsMajorVersion = true;
            
            insert cv;
            System.debug('ContentVersion created: ' + cv.Id);
            
            // Get the ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            System.debug('ContentDocumentId retrieved: ' + cv.ContentDocumentId);
            
            return cv.ContentDocumentId;
            
        } catch (Exception e) {
            System.debug('❌ Error creating ContentDocument: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to create photo document: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates ContentDocumentLink to associate file with record
     * @param contentDocumentId The ContentDocument ID to link
     * @param recordId The record ID to link to
     */
    private static void createContentDocumentLink(String contentDocumentId, Id recordId) {
        try {
            System.debug('Creating ContentDocumentLink...');
            System.debug('ContentDocumentId: ' + contentDocumentId);
            System.debug('LinkedEntityId: ' + recordId);
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            System.debug('ContentDocumentLink created: ' + cdl.Id);
            
        } catch (Exception e) {
            System.debug('❌ Error creating ContentDocumentLink: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception here as the main record is already created
        }
    }
    
    /**
     * ✅ NEW: Test helper method to verify new field access
     * @return Map containing test results for Client Place and Field Work fields
     */
    @AuraEnabled
    public static Map<String, Object> testNewFieldsAccess() {
        Map<String, Object> testResult = new Map<String, Object>();
        
        try {
            System.debug('=== TESTING NEW FIELDS ACCESS ===');
            
            // Test if we can access the Employee_Attendance__c object
            Schema.DescribeSObjectResult objDescribe = Employee_Attendance__c.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            testResult.put('objectName', objDescribe.getName());
            testResult.put('objectLabel', objDescribe.getLabel());
            testResult.put('objectAccessible', objDescribe.isAccessible());
            testResult.put('objectCreatable', objDescribe.isCreateable());
            testResult.put('objectUpdateable', objDescribe.isUpdateable());
            
            // Check if new fields exist
            Boolean hasClientPlaceField = fieldMap.containsKey('Client_Place_Details__c');
            Boolean hasFieldWorkField = fieldMap.containsKey('Field_Work_Details__c');
            Boolean hasWFHReasonField = fieldMap.containsKey('WFH_Reason__c');
            Boolean hasWFHApprovalStatusField = fieldMap.containsKey('WFH_Approval_Status__c');
            Boolean hasSubmittedForApprovalField = fieldMap.containsKey('Submitted_For_Approval__c');
            
            testResult.put('hasClientPlaceDetailsField', hasClientPlaceField);
            testResult.put('hasFieldWorkDetailsField', hasFieldWorkField);
            testResult.put('hasWFHReasonField', hasWFHReasonField);
            testResult.put('hasWFHApprovalStatusField', hasWFHApprovalStatusField);
            testResult.put('hasSubmittedForApprovalField', hasSubmittedForApprovalField);
            
            // Check Client Place Details field properties
            if (hasClientPlaceField) {
                Schema.DescribeFieldResult clientPlaceDescribe = fieldMap.get('Client_Place_Details__c').getDescribe();
                Map<String, Object> clientPlaceInfo = new Map<String, Object>();
                clientPlaceInfo.put('label', clientPlaceDescribe.getLabel());
                clientPlaceInfo.put('type', String.valueOf(clientPlaceDescribe.getType()));
                clientPlaceInfo.put('accessible', clientPlaceDescribe.isAccessible());
                clientPlaceInfo.put('createable', clientPlaceDescribe.isCreateable());
                clientPlaceInfo.put('updateable', clientPlaceDescribe.isUpdateable());
                clientPlaceInfo.put('length', clientPlaceDescribe.getLength());
                testResult.put('clientPlaceDetails', clientPlaceInfo);
                System.debug('✅ Client Place Details field found and accessible');
            } else {
                System.debug('⚠️ Client Place Details field NOT FOUND - Please create this field');
            }
            
            // Check Field Work Details field properties
            if (hasFieldWorkField) {
                Schema.DescribeFieldResult fieldWorkDescribe = fieldMap.get('Field_Work_Details__c').getDescribe();
                Map<String, Object> fieldWorkInfo = new Map<String, Object>();
                fieldWorkInfo.put('label', fieldWorkDescribe.getLabel());
                fieldWorkInfo.put('type', String.valueOf(fieldWorkDescribe.getType()));
                fieldWorkInfo.put('accessible', fieldWorkDescribe.isAccessible());
                fieldWorkInfo.put('createable', fieldWorkDescribe.isCreateable());
                fieldWorkInfo.put('updateable', fieldWorkDescribe.isUpdateable());
                fieldWorkInfo.put('length', fieldWorkDescribe.getLength());
                testResult.put('fieldWorkDetails', fieldWorkInfo);
                System.debug('✅ Field Work Details field found and accessible');
            } else {
                System.debug('⚠️ Field Work Details field NOT FOUND - Please create this field');
            }
            
            // Check WFH fields
            if (hasWFHReasonField) {
                Schema.DescribeFieldResult wfhReasonDescribe = fieldMap.get('WFH_Reason__c').getDescribe();
                Map<String, Object> wfhReasonInfo = new Map<String, Object>();
                wfhReasonInfo.put('label', wfhReasonDescribe.getLabel());
                wfhReasonInfo.put('accessible', wfhReasonDescribe.isAccessible());
                wfhReasonInfo.put('createable', wfhReasonDescribe.isCreateable());
                testResult.put('wfhReasonDetails', wfhReasonInfo);
                System.debug('✅ WFH Reason field found');
            }
            
            testResult.put('success', true);
            testResult.put('message', 'Field access test completed successfully');
            
            // Summary message
            List<String> missingFields = new List<String>();
            if (!hasClientPlaceField) missingFields.add('Client_Place_Details__c');
            if (!hasFieldWorkField) missingFields.add('Field_Work_Details__c');
            if (!hasWFHReasonField) missingFields.add('WFH_Reason__c');
            if (!hasWFHApprovalStatusField) missingFields.add('WFH_Approval_Status__c');
            if (!hasSubmittedForApprovalField) missingFields.add('Submitted_For_Approval__c');
            
            if (!missingFields.isEmpty()) {
                testResult.put('missingFields', missingFields);
                testResult.put('warning', 'Some required fields are missing. Please create them first.');
                System.debug('⚠️ MISSING FIELDS: ' + String.join(missingFields, ', '));
            } else {
                testResult.put('allFieldsPresent', true);
                System.debug('✅ ALL REQUIRED FIELDS ARE PRESENT');
            }
            
            System.debug('=== FIELD ACCESS TEST COMPLETED ===');
            System.debug('Test Results: ' + JSON.serializePretty(testResult));
            
        } catch (Exception e) {
            System.debug('❌ ERROR in field access test: ' + e.getMessage());
            testResult.put('success', false);
            testResult.put('error', e.getMessage());
            testResult.put('stackTrace', e.getStackTraceString());
        }
        
        return testResult;
    }
    
    /**
     * ✅ NEW: Debug helper to check a specific attendance record
     * @param recordId The attendance record ID to check
     * @return Map containing record details with new fields
     */
    @AuraEnabled
    public static Map<String, Object> debugAttendanceRecord(String recordId) {
        Map<String, Object> debugInfo = new Map<String, Object>();
        
        try {
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Record ID is required');
            }
            
            System.debug('=== DEBUGGING ATTENDANCE RECORD ===');
            System.debug('Record ID: ' + recordId);
            
            // Query the record with all fields
            List<Employee_Attendance__c> records = [
                SELECT Id, Name, Employee_Name__c, Employee_Name__r.Name, Date__c,
                       Check_In_Time__c, Check_Out_Time__c, Work_Location__c, Status__c,
                       Client_Place_Details__c, Field_Work_Details__c,
                       WFH_Reason__c, WFH_Approval_Status__c, Submitted_For_Approval__c,
                       Check_In_Location_Name__c, Check_In_State__c,
                       Notes__c, CreatedDate, LastModifiedDate
                FROM Employee_Attendance__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (records.isEmpty()) {
                throw new AuraHandledException('Record not found with ID: ' + recordId);
            }
            
            Employee_Attendance__c record = records[0];
            
            debugInfo.put('success', true);
            debugInfo.put('recordId', record.Id);
            debugInfo.put('recordName', record.Name);
            debugInfo.put('employeeName', record.Employee_Name__r?.Name);
            debugInfo.put('date', record.Date__c);
            debugInfo.put('workLocation', record.Work_Location__c);
            debugInfo.put('status', record.Status__c);
            
            // New fields
            debugInfo.put('clientPlaceDetails', record.Client_Place_Details__c);
            debugInfo.put('hasClientPlaceDetails', String.isNotBlank(record.Client_Place_Details__c));
            debugInfo.put('fieldWorkDetails', record.Field_Work_Details__c);
            debugInfo.put('hasFieldWorkDetails', String.isNotBlank(record.Field_Work_Details__c));
            debugInfo.put('wfhReason', record.WFH_Reason__c);
            debugInfo.put('wfhApprovalStatus', record.WFH_Approval_Status__c);
            debugInfo.put('submittedForApproval', record.Submitted_For_Approval__c);
            
            debugInfo.put('locationName', record.Check_In_Location_Name__c);
            debugInfo.put('state', record.Check_In_State__c);
            debugInfo.put('notes', record.Notes__c);
            
            System.debug('✅ Record details retrieved successfully');
            System.debug('Debug Info: ' + JSON.serializePretty(debugInfo));
            
        } catch (Exception e) {
            System.debug('❌ Error in debugAttendanceRecord: ' + e.getMessage());
            debugInfo.put('success', false);
            debugInfo.put('error', e.getMessage());
        }
        
        return debugInfo;
    }
}