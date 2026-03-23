/**
 * @description Enhanced NewController with Client Place and Field Work Details support
 * @author Salesforce Consultant
 * @date 2025-10-08
 * @version 4.0 - Added Client Place and Field Work Details fields + WFH Approval support
 */
public without sharing class NewController {
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

	// ✅ ADD THESE 3 BLOCKS before "insert att;"

// OD Request flag
if (payload.containsKey('Is_OD_Request__c')) {
    att.Is_OD_Request__c = (Boolean) payload.get('Is_OD_Request__c');
    System.debug('Is OD Request: ' + att.Is_OD_Request__c);
}

// OD Approval Status
if (payload.containsKey('OD_Approval_Status__c') && payload.get('OD_Approval_Status__c') != null) {
    att.OD_Approval_Status__c = (String) payload.get('OD_Approval_Status__c');
    System.debug('OD Approval Status: ' + att.OD_Approval_Status__c);
}

// OD Reason
if (payload.containsKey('OD_Reason__c') && payload.get('OD_Reason__c') != null) {
    String odReason = (String) payload.get('OD_Reason__c');
    if (String.isNotBlank(odReason)) {
        att.OD_Reason__c = odReason;
        System.debug('OD Reason: ' + att.OD_Reason__c);
    }
}

// Submitted For Approval
if (payload.containsKey('Submitted_For_Approval__c')) {
    att.Submitted_For_Approval__c = (Boolean) payload.get('Submitted_For_Approval__c');
    System.debug('Submitted For Approval: ' + att.Submitted_For_Approval__c);
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


@AuraEnabled
public static Map<String, Object> createODAttendance(Map<String, Object> payload) {
    Map<String, Object> result = new Map<String, Object>();
    try {
        System.debug('=== CREATE OD ATTENDANCE ===');
        System.debug('Payload: ' + JSON.serializePretty(payload));

        payload.put('Is_OD_Request__c',         true);
        payload.put('OD_Approval_Status__c',     'Pending');
        payload.put('Submitted_For_Approval__c', true);

        result = createAttendance(payload);
        System.debug('createAttendance result: ' + JSON.serializePretty(result));

        if (result.containsKey('success') && (Boolean) result.get('success') == true) {
            String newRecordId = (String) result.get('recordId');
            Id     employeeId  = (Id)     payload.get('Employee_Name__c');
            String odReason    = payload.containsKey('OD_Reason__c')     ? (String) payload.get('OD_Reason__c')     : '';
            String odDate      = payload.containsKey('Date__c')           ? (String) payload.get('Date__c')           : '';
            String workLoc     = payload.containsKey('Work_Location__c')  ? (String) payload.get('Work_Location__c')  : '';
            String checkIn     = payload.containsKey('Check_In_Time__c')  ? (String) payload.get('Check_In_Time__c')  : '';
            String checkOut    = payload.containsKey('Check_Out_Time__c') ? (String) payload.get('Check_Out_Time__c') : '';

            System.debug('Record created: ' + newRecordId);
            System.debug('Employee ID: ' + employeeId);
            System.debug('OD Reason: ' + odReason);
            System.debug('OD Date: ' + odDate);
            System.debug('CheckIn raw: ' + checkIn);
            System.debug('CheckOut raw: ' + checkOut);

            try {
                // Query employee with manager — no IsActive filter on manager
                List<User> users = [
                    SELECT Id, Name, Email,
                           ManagerId,
                           Manager.Id,
                           Manager.Name,
                           Manager.Email,
                           Manager.IsActive
                    FROM   User
                    WHERE  Id = :employeeId
                    LIMIT  1
                ];

                System.debug('Users found: ' + users.size());
                if (!users.isEmpty()) {
                    User emp = users[0];
                    System.debug('Employee: ' + emp.Name + ' | ' + emp.Email);
                    System.debug('ManagerId: ' + emp.ManagerId);
                    System.debug('Manager object null? ' + (emp.Manager == null));
                    System.debug('Manager Name: ' + emp.Manager?.Name);
                    System.debug('Manager Email: ' + emp.Manager?.Email);
                    System.debug('Manager IsActive: ' + emp.Manager?.IsActive);
                }

                // Determine recipient
                String toEmail = null;
                String toName  = null;

                if (!users.isEmpty()
                    && users[0].ManagerId != null
                    && users[0].Manager != null
                    && String.isNotBlank(users[0].Manager.Email)) {

                    toEmail = users[0].Manager.Email;
                    toName  = users[0].Manager.Name;
                    System.debug('✅ Sending to manager: ' + toEmail);

                } else {
                    // Fallback to System Administrator
                    System.debug('⚠️ No manager email — using admin fallback');
                    List<User> admins = [
                        SELECT Id, Name, Email
                        FROM   User
                        WHERE  Profile.Name = 'System Administrator'
                        AND    IsActive = true
                        AND    Email   != null
                        ORDER BY CreatedDate ASC
                        LIMIT  1
                    ];
                    if (!admins.isEmpty()) {
                        toEmail = admins[0].Email;
                        toName  = admins[0].Name + ' (Admin)';
                        System.debug('✅ Fallback admin: ' + toEmail);
                    }
                }

                if (String.isBlank(toEmail)) {
                    System.debug('❌ No recipient found — email skipped');
                    result.put('emailSent',    false);
                    result.put('emailMessage', 'No recipient found');
                } else {
                    User emp = users[0];

                    // Format date
                    String fDate = odDate;
                    try { fDate = Date.valueOf(odDate).format(); } catch(Exception ex){
                        System.debug('Date format warn: ' + ex.getMessage());
                    }

                    // Format times
                    String fIn = '--', fOut = '--';
                    try {
                        fIn = DateTime.valueOf(checkIn.replace('T',' ').replace('Z','')).format('hh:mm a');
                    } catch(Exception ex){ System.debug('CheckIn format warn: ' + ex.getMessage()); }
                    try {
                        fOut = DateTime.valueOf(checkOut.replace('T',' ').replace('Z','')).format('hh:mm a');
                    } catch(Exception ex){ System.debug('CheckOut format warn: ' + ex.getMessage()); }

                    System.debug('Formatted date: ' + fDate);
                    System.debug('Formatted checkIn: ' + fIn);
                    System.debug('Formatted checkOut: ' + fOut);

                    // Record URL
                   //String baseUrl = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/ODSiteApproval';
                     String baseUrl =  'https://innovation-dream-9744.my.salesforce-sites.com/ODSiteApproval';
                     String approvalUrl = baseUrl + '/apex/ODvfpage?id=' + newRecordId + '&emp=' + employeeId;

                    // Build HTML email
                    String htmlBody =
                        '<html><body style="font-family:Arial,sans-serif;margin:0;padding:0;background:#f4f4f4;">' +
                        '<table width="100%" cellpadding="0" cellspacing="0" style="padding:30px 0;">' +
                        '<tr><td align="center">' +
                        '<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;overflow:hidden;">' +
                        '<tr><td style="background:#1a6bbf;padding:24px 32px;">' +
                        '<h2 style="color:#fff;margin:0;font-size:20px;">OD Attendance Approval Request</h2>' +
                        '<p style="color:#cce0ff;margin:4px 0 0;font-size:13px;">Action required — please approve or reject</p>' +
                        '</td></tr>' +
                        '<tr><td style="padding:24px 32px 0;">' +
                        '<p style="margin:0;font-size:15px;color:#333;">Dear <strong>' + toName + '</strong>,</p>' +
                        '<p style="margin:12px 0 0;font-size:14px;color:#555;line-height:1.6;">' +
                        '<strong>' + emp.Name + '</strong> has submitted an OD request for a previous working day.</p>' +
                        '</td></tr>' +
                        '<tr><td style="padding:20px 32px;">' +
                        '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f8faff;border:1px solid #dce8f8;border-radius:6px;">' +
                        '<tr><td style="background:#e8f0fe;padding:10px 16px;">' +
                        '<strong style="color:#1a6bbf;font-size:13px;">REQUEST DETAILS</strong></td></tr>' +
                        '<tr><td style="padding:12px 16px;">' +
                        '<table width="100%" cellpadding="5" cellspacing="0">' +
                        '<tr><td style="color:#888;width:130px;font-size:13px;">Employee</td><td style="font-size:13px;">' + emp.Name + '</td></tr>' +
                        '<tr style="background:#f5f5f5;"><td style="color:#888;font-size:13px;">Date</td><td style="font-size:13px;">' + fDate + '</td></tr>' +
                        '<tr><td style="color:#888;font-size:13px;">Work Location</td><td style="font-size:13px;">' + workLoc + '</td></tr>' +
                        '<tr style="background:#f5f5f5;"><td style="color:#888;font-size:13px;">Check-in</td><td style="font-size:13px;">' + fIn + '</td></tr>' +
                        '<tr><td style="color:#888;font-size:13px;">Check-out</td><td style="font-size:13px;">' + fOut + '</td></tr>' +
                        '<tr style="background:#f5f5f5;"><td style="color:#888;font-size:13px;">Status</td>' +
                        '<td><span style="background:#fff3cd;color:#856404;padding:2px 8px;border-radius:10px;font-size:12px;">Pending Approval</span></td></tr>' +
                        '</table></td></tr></table></td></tr>' +
                        '<tr><td style="padding:0 32px 20px;">' +
                        '<div style="background:#fffbf0;border:1px solid #fde8a0;border-radius:6px;padding:16px;">' +
                        '<p style="margin:0 0 8px;font-weight:700;color:#92600a;font-size:13px;">REASON FOR OD</p>' +
                        '<p style="margin:0;font-size:14px;color:#444;">' + odReason + '</p>' +
                        '</div></td></tr>' +
                        '<tr><td style="padding:0 32px 28px;">' +
                        '<a href="' + approvalUrl + '" style="display:inline-block;background:#1a6bbf;color:#fff;padding:12px 24px;border-radius:5px;text-decoration:none;font-size:14px;font-weight:600;">Review &amp; Take Action in Salesforce</a>' +
                        '<p style="margin:12px 0 0;font-size:12px;color:#666;">Open the record → set OD Approval Status to Approved or Rejected.</p>' +
                        '</td></tr>' +
                        '<tr><td style="background:#f8f8f8;border-top:1px solid #eee;padding:16px 32px;">' +
                        '<p style="margin:0;font-size:11px;color:#999;">Automated notification — Attendance Management System | Record: ' + newRecordId + '</p>' +
                        '</td></tr>' +
                        '</table></td></tr></table>' +
                        '</body></html>';

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{toEmail });
// mail.setOrgWideEmailAddressId('0D2fs00000001tl');
	OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
mail.setOrgWideEmailAddressId(owea.Id);
                    if (String.isNotBlank(emp.Email)) {
                        mail.setCcAddresses(new List<String>{ emp.Email });
                    }
                    mail.setSubject('OD Approval Required: ' + emp.Name + ' — ' + fDate);
                    mail.setHtmlBody(htmlBody);
                    mail.setSaveAsActivity(false);
                    mail.setUseSignature(false);

                    System.debug('Sending email TO: ' + toEmail);

                    Messaging.SendEmailResult[] sendRes =
                        Messaging.sendEmail(
                            new List<Messaging.SingleEmailMessage>{ mail },
                            false  // allOrNothing = false
                        );

                    System.debug('sendResults null? ' + (sendRes == null));
                    System.debug('sendResults size: ' + (sendRes != null ? sendRes.size() : 0));

                    if (sendRes != null && !sendRes.isEmpty()) {
                        Boolean emailOk = sendRes[0].isSuccess();
                        System.debug('Email isSuccess: ' + emailOk);

                        if (emailOk) {
                            System.debug('✅ Email delivered to: ' + toEmail);
                            result.put('emailSent',    true);
                            result.put('emailMessage', 'Manager notified at ' + toEmail);
                        } else {
                            String errDetail = '';
                            for (Messaging.SendEmailError e : sendRes[0].getErrors()) {
                                errDetail += e.getStatusCode() + ': ' + e.getMessage() + '; ';
                                System.debug('❌ Email error: ' + e.getStatusCode() + ' — ' + e.getMessage());
                            }
                            result.put('emailSent',  false);
                            result.put('emailError', errDetail);
                        }
                    } else {
                        System.debug('⚠️ Empty sendResults returned');
                        result.put('emailSent',  false);
                        result.put('emailError', 'Empty send results');
                    }
                }

            } catch (Exception emailEx) {
                System.debug('⚠️ Email exception: ' + emailEx.getMessage());
                System.debug('Stack: ' + emailEx.getStackTraceString());
                result.put('emailSent',  false);
                result.put('emailError', emailEx.getMessage());
            }

            result.put('message', 'OD request submitted. Email status: ' +
                (result.get('emailSent') == true ? 'Sent' : 'Failed - ' + result.get('emailError')));
        }

    } catch (Exception e) {
        System.debug('❌ createODAttendance outer error: ' + e.getMessage());
        System.debug('Stack: ' + e.getStackTraceString());
        result.put('success', false);
        result.put('error',   e.getMessage());
    }
    return result;
}
    // ===================================================================
    // ✅ PRIVATE: Send OD approval email to manager
    // ===================================================================
@TestVisible    private static void sendODApprovalEmailToManager(
        Id employeeId,
        String attendanceRecordId,
        String odReason,
        String odDate,
        String workLocation,
        String checkInTime,
        String checkOutTime
    ) {
        System.debug('=== SENDING OD APPROVAL EMAIL TO MANAGER ===');
 
        // Step 1: Get employee details and manager
        List<User> employees = [
            SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email,
                   Department, Title
            FROM User
            WHERE Id = :employeeId
            AND IsActive = true
            LIMIT 1
        ];
 
        if (employees.isEmpty()) {
            throw new AuraHandledException('Employee not found: ' + employeeId);
        }
 
        User employee = employees[0];
        System.debug('Employee: ' + employee.Name);
        System.debug('Manager ID: ' + employee.ManagerId);
        System.debug('Manager Name: ' + employee.Manager?.Name);
        System.debug('Manager Email: ' + employee.Manager?.Email);
 
        // Step 2: Check if manager exists and has email
        if (employee.ManagerId == null) {
            System.debug('⚠️ No manager assigned to employee. Sending email to HR or admin.');
            // Optionally send to a fallback HR email
            sendFallbackODEmail(employee, attendanceRecordId, odReason, odDate, workLocation, checkInTime, checkOutTime);
            return;
        }
 
        if (String.isBlank(employee.Manager?.Email)) {
            throw new AuraHandledException('Manager does not have a valid email address.');
        }
 
        // Step 3: Format the date nicely
        String formattedDate = odDate;
        try {
            Date parsedDate = Date.valueOf(odDate);
            formattedDate = parsedDate.format();
        } catch (Exception ex) {
            formattedDate = odDate;
        }
 
        // Step 4: Format times (strip seconds for display)
        String displayCheckIn  = formatTimeForEmail(checkInTime);
        String displayCheckOut = formatTimeForEmail(checkOutTime);
 
        // Step 5: Build the Salesforce record URL
       // String orgBaseUrl = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/ODSiteApproval';
        String orgBaseUrl = 'https://innovation-dream-9744.my.salesforce-sites.com/ODSiteApproval';
        String recordUrl  = orgBaseUrl + '/' + attendanceRecordId;
 
        // Step 6: Build HTML email body
        String emailBody = buildODEmailBody(
            employee.Name,
            employee.Manager.Name,
            formattedDate,
            workLocation,
            displayCheckIn,
            displayCheckOut,
            odReason,
            recordUrl,
            attendanceRecordId
        );
 
        // Step 7: Send the email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ employee.Manager.Email });
        mail.setCcAddresses(new List<String>{ employee.Email }); // CC the employee
        mail.setSubject('OD Approval Required: ' + employee.Name + ' - ' + formattedDate);
        mail.setHtmlBody(emailBody);
        mail.setSaveAsActivity(false);
 
        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail }
        );
 
        if (results != null && !results.isEmpty()) {
            if (results[0].isSuccess()) {
                System.debug('✅ OD approval email sent to: ' + employee.Manager.Email);
            } else {
                List<Messaging.SendEmailError> errors = results[0].getErrors();
                String errMsg = !errors.isEmpty() ? errors[0].getMessage() : 'Unknown email error';
                throw new AuraHandledException('Email send failed: ' + errMsg);
            }
        }
    }
 
    // ===================================================================
    // ✅ PRIVATE: Fallback email if no manager assigned
    // ===================================================================
 @TestVisible   private static void sendFallbackODEmail(
        User employee,
        String attendanceRecordId,
        String odReason,
        String odDate,
        String workLocation,
        String checkInTime,
        String checkOutTime
    ) {
        // Get org admin or HR email — query for an active admin user
        List<User> admins = [
            SELECT Id, Name, Email
            FROM User
            WHERE Profile.Name = 'System Administrator'
            AND IsActive = true
            AND Email != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
 
        if (admins.isEmpty()) {
            System.debug('⚠️ No admin user found for fallback email');
            return;
        }
 
        String formattedDate   = odDate;
        String displayCheckIn  = formatTimeForEmail(checkInTime);
        String displayCheckOut = formatTimeForEmail(checkOutTime);
        String orgBaseUrl      = URL.getOrgDomainUrl().toExternalForm();
        String recordUrl       = orgBaseUrl + '/' + attendanceRecordId;
 
        String emailBody = buildODEmailBody(
            employee.Name,
            admins[0].Name + ' (Admin - No Manager Assigned)',
            formattedDate,
            workLocation,
            displayCheckIn,
            displayCheckOut,
            odReason,
            recordUrl,
            attendanceRecordId
        );
 
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ admins[0].Email });
        mail.setCcAddresses(new List<String>{ employee.Email });
        mail.setSubject('OD Request (No Manager Assigned): ' + employee.Name + ' - ' + formattedDate);
        mail.setHtmlBody(emailBody);
        mail.setSaveAsActivity(false);
 
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        System.debug('✅ Fallback OD email sent to admin: ' + admins[0].Email);
    }
 
    // ===================================================================
    // ✅ PRIVATE: Build professional HTML email body
    // ===================================================================
 @TestVisible   private static String buildODEmailBody(
        String employeeName,
        String managerName,
        String odDate,
        String workLocation,
        String checkInTime,
        String checkOutTime,
        String odReason,
        String recordUrl,
        String recordId
    ) {
        return '<!DOCTYPE html>' +
        '<html><head><meta charset="UTF-8"></head><body style="margin:0;padding:0;font-family:Arial,sans-serif;background:#f4f4f4;">' +
        '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:30px 0;">' +
        '  <tr><td align="center">' +
        '    <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.1);">' +
        
        // Header
        '      <tr><td style="background:#1a6bbf;padding:28px 32px;">' +
        '        <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:600;">OD Attendance Approval Request</h1>' +
        '        <p style="margin:6px 0 0;color:#cce0ff;font-size:13px;">Action required — please review and approve or reject</p>' +
        '      </td></tr>' +
 
        // Greeting
        '      <tr><td style="padding:28px 32px 0;">' +
        '        <p style="margin:0;font-size:15px;color:#333;">Dear <strong>' + managerName + '</strong>,</p>' +
        '        <p style="margin:12px 0 0;font-size:14px;color:#555;line-height:1.6;">' +
        '          <strong>' + employeeName + '</strong> has submitted an OD (On Duty) attendance request ' +
        '          for a previous working day. Please review the details below and take action.' +
        '        </p>' +
        '      </td></tr>' +
 
        // Details card
        '      <tr><td style="padding:20px 32px;">' +
        '        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8faff;border:1px solid #dce8f8;border-radius:6px;overflow:hidden;">' +
        '          <tr><td style="background:#e8f0fe;padding:12px 20px;">' +
        '            <p style="margin:0;font-size:13px;font-weight:700;color:#1a6bbf;text-transform:uppercase;letter-spacing:0.5px;">Request Details</p>' +
        '          </td></tr>' +
        '          <tr><td style="padding:16px 20px;">' +
        '            <table width="100%" cellpadding="6" cellspacing="0">' +
        buildEmailRow('Employee', employeeName) +
        buildEmailRow('Date', odDate) +
        buildEmailRow('Work Location', workLocation) +
        buildEmailRow('Check-in Time', checkInTime) +
        buildEmailRow('Check-out Time', checkOutTime) +
        buildEmailRow('Status', '<span style="background:#fff3cd;color:#856404;padding:2px 10px;border-radius:12px;font-size:12px;font-weight:600;">Pending Approval</span>') +
        '            </table>' +
        '          </td></tr>' +
        '        </table>' +
        '      </td></tr>' +
 
        // Reason section
        '      <tr><td style="padding:0 32px 20px;">' +
        '        <table width="100%" cellpadding="0" cellspacing="0" style="background:#fffbf0;border:1px solid #fde8a0;border-radius:6px;">' +
        '          <tr><td style="background:#fef3c7;padding:12px 20px;">' +
        '            <p style="margin:0;font-size:13px;font-weight:700;color:#92600a;text-transform:uppercase;letter-spacing:0.5px;">Reason for OD</p>' +
        '          </td></tr>' +
        '          <tr><td style="padding:16px 20px;">' +
        '            <p style="margin:0;font-size:14px;color:#444;line-height:1.7;">' + odReason + '</p>' +
        '          </td></tr>' +
        '        </table>' +
        '      </td></tr>' +
 
        // Action buttons
        '      <tr><td style="padding:0 32px 28px;">' +
        '        <p style="margin:0 0 16px;font-size:13px;color:#666;">To approve or reject this request, please click the button below to view the record in Salesforce:</p>' +
        '        <table cellpadding="0" cellspacing="0">' +
        '          <tr>' +
        '            <td style="padding-right:12px;">' +
        '              <a href="' + recordUrl + '" style="display:inline-block;background:#1a6bbf;color:#ffffff;padding:12px 28px;border-radius:5px;text-decoration:none;font-size:14px;font-weight:600;">Review &amp; Take Action</a>' +
        '            </td>' +
        '          </tr>' +
        '        </table>' +
        '      </td></tr>' +
 
        // Info note
        '      <tr><td style="padding:0 32px 24px;">' +
        '        <table width="100%" cellpadding="0" cellspacing="0" style="background:#e8f4fd;border-left:4px solid #1a6bbf;border-radius:0 4px 4px 0;">' +
        '          <tr><td style="padding:12px 16px;">' +
        '            <p style="margin:0;font-size:13px;color:#0c5aa6;line-height:1.6;">' +
        '              <strong>Note:</strong> Once you review the record in Salesforce, update the <em>OD Approval Status</em> field to <strong>Approved</strong> or <strong>Rejected</strong>. ' +
        '              The employee will be notified of your decision.' +
        '            </p>' +
        '          </td></tr>' +
        '        </table>' +
        '      </td></tr>' +
 
        // Footer
        '      <tr><td style="background:#f8f8f8;border-top:1px solid #ebebeb;padding:20px 32px;">' +
        '        <p style="margin:0;font-size:12px;color:#888;line-height:1.6;">' +
        '          This is an automated notification from the Attendance Management System. ' +
        '          Please do not reply to this email. Record ID: ' + recordId +
        '        </p>' +
        '      </td></tr>' +
 
        '    </table>' +
        '  </td></tr>' +
        '</table>' +
        '</body></html>';
    }
 
    // ===================================================================
    // ✅ PRIVATE: Helper to build a table row in the email
    // ===================================================================
 @TestVisible   private static String buildEmailRow(String label, String value) {
        return '<tr>' +
        '  <td style="width:140px;font-size:13px;color:#888;font-weight:600;vertical-align:top;padding:4px 8px 4px 0;">' + label + '</td>' +
        '  <td style="font-size:13px;color:#333;vertical-align:top;padding:4px 0;">' + (String.isNotBlank(value) ? value : '--') + '</td>' +
        '</tr>';
    }
 
    // ===================================================================
    // ✅ PRIVATE: Format datetime string for email display
    // ===================================================================
@TestVisible    private static String formatTimeForEmail(String datetimeStr) {
        if (String.isBlank(datetimeStr)) return '--';
        try {
            // Input format: "2026-03-13 09:15:00"
            DateTime dt = DateTime.valueOf(datetimeStr.replace('T', ' ').replace('Z', ''));
            return dt.format('hh:mm a');
        } catch (Exception e) {
            // If it's already just a time like "09:15:00"
            return datetimeStr.length() >= 5 ? datetimeStr.substring(0, 5) : datetimeStr;
        }
    }
}