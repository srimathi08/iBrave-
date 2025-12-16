/**
 * @description Enhanced Controller class to retrieve Employee Attendance records with WFH approval status and location details
 * @author Salesforce Consultant
 * @date 2025-10-08
 * @version 4.0 - Added Client Place and Field Work Details support + Enhanced WFH approval status
 */
public with sharing class AttendanceViewController {
@AuraEnabled(cacheable=false)
public static Map<String, Object> getEmployeeAttendanceRecords(String employeeId, Integer limitRecords) {
    Map<String, Object> response = new Map<String, Object>();
    
    try {
        System.debug('=== GETTING EMPLOYEE ATTENDANCE RECORDS WITH BRANCH INFO ===');
        System.debug('Employee ID: ' + employeeId);
        System.debug('Limit: ' + limitRecords);
        
        // Input validation
        if (String.isBlank(employeeId)) {
            throw new AuraHandledException('Employee ID is required');
        }
        
        if (limitRecords == null || limitRecords <= 0) {
            limitRecords = 200;
        }
        
        // Validate employee exists and is active
        List<User> users = [SELECT Id, Name, IsActive FROM User WHERE Id = :employeeId LIMIT 1];
        if (users.isEmpty()) {
            throw new AuraHandledException('Employee not found');
        }
        if (!users[0].IsActive) {
            throw new AuraHandledException('Employee is inactive');
        }
        
        // ✅ UPDATED: Query with Branch lookup relationship
        List<Employee_Attendance__c> records = new List<Employee_Attendance__c>();
        
        try {
            records = [
                SELECT Id, Employee_Name__c, Employee_Name__r.Name, Employee_Name__r.Email,
                       Date__c, Check_In_Time__c, Check_Out_Time__c, 
                       Hours_Worked__c, Status__c, Notes__c, 
                       Work_Location__c,
                       Branch__c, Branch__r.Branch_Name__c, 
                       Branch__r.City__c, Session_Number__c, Is_Multiple_Session__c,
                       Branch__r.State__c,
                       Client_Place_Details__c, Field_Work_Details__c, WFH_Reason__c,
                       Check_In_Photo_Id__c, Check_Out_Photo_Id__c,
                       CreatedDate, LastModifiedDate, 
                       CreatedBy.Name, LastModifiedBy.Name
                FROM Employee_Attendance__c 
                WHERE Employee_Name__c = :employeeId 
                ORDER BY Date__c DESC, CreatedDate DESC 
                LIMIT :limitRecords
            ];
        } catch (Exception queryException) {
            System.debug('❌ Query Exception: ' + queryException.getMessage());
            throw new AuraHandledException('Unable to access attendance records: ' + queryException.getMessage());
        }
        
        System.debug('Found ' + records.size() + ' attendance records');
        
        // Format the records for Lightning Web Component
        List<Map<String, Object>> formattedRecords = new List<Map<String, Object>>();
        
        Integer recordIndex = 0;
        for (Employee_Attendance__c record : records) {
            recordIndex++;
            Map<String, Object> formattedRecord = new Map<String, Object>();
            
            // Basic record information
            formattedRecord.put('recordId', record.Id);
            formattedRecord.put('employeeName', record.Employee_Name__r?.Name);
            formattedRecord.put('employeeEmail', record.Employee_Name__r?.Email);
            
            // ✅ In formatting loop, add:
			formattedRecord.put('sessionNumber', record.Session_Number__c != null ? record.Session_Number__c.intValue() : 1);
			formattedRecord.put('isMultipleSession', record.Is_Multiple_Session__c == true);
			formattedRecord.put('sessionDisplay', 'Session ' + (record.Session_Number__c != null ? String.valueOf(record.Session_Number__c.intValue()) : '1'));
            
            // Handle Date
            if (record.Date__c != null) {
                formattedRecord.put('attendanceDate', record.Date__c.format());
                formattedRecord.put('displayDate', record.Date__c.format());
            } else {
                formattedRecord.put('attendanceDate', '--');
                formattedRecord.put('displayDate', '--');
            }
            
            // Handle Times
            if (record.Check_In_Time__c != null) {
                formattedRecord.put('checkInTime', formatTime(record.Check_In_Time__c));
                formattedRecord.put('displayCheckIn', formatTime(record.Check_In_Time__c));
            } else {
                formattedRecord.put('checkInTime', '--');
                formattedRecord.put('displayCheckIn', '--');
            }
            
            if (record.Check_Out_Time__c != null) {
                formattedRecord.put('checkOutTime', formatTime(record.Check_Out_Time__c));
                formattedRecord.put('displayCheckOut', formatTime(record.Check_Out_Time__c));
            } else {
                formattedRecord.put('checkOutTime', '--');
                formattedRecord.put('displayCheckOut', '--');
            }
            
            // Handle Hours Worked
            if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
                formattedRecord.put('hoursWorked', String.valueOf(record.Hours_Worked__c.setScale(1)) + 'h');
                formattedRecord.put('displayHours', String.valueOf(record.Hours_Worked__c.setScale(1)) + 'h');
            } else {
                formattedRecord.put('hoursWorked', '--');
                formattedRecord.put('displayHours', '--');
            }
            
            // Handle Status
            String statusValue = String.isNotBlank(record.Status__c) ? record.Status__c : 'Present';
            formattedRecord.put('status', statusValue);
            formattedRecord.put('displayStatus', statusValue);
            formattedRecord.put('statusBadgeClass', getStatusClass(statusValue));
            
            // ✅ UPDATED: Work Location
            String workLocation = record.Work_Location__c != null ? record.Work_Location__c : 'Work from Office';
            formattedRecord.put('workLocation', workLocation);
            
            // ✅ UPDATED: Handle Branch Information and Location Display
            String locationDisplay = '--';
            Boolean hasBranch = false;
            
            if (workLocation == 'Work from Office' && record.Branch__c != null) {
                // Office work with branch selected
                String branchName = record.Branch__r?.Branch_Name__c;
                String branchCity = record.Branch__r?.City__c;
                
                if (String.isNotBlank(branchName)) {
                    locationDisplay = branchName;
                    if (String.isNotBlank(branchCity)) {
                        locationDisplay += ' (' + branchCity + ')';
                    }
                    hasBranch = true;
                    
                    formattedRecord.put('branchId', record.Branch__c);
                    formattedRecord.put('branchName', branchName);
                    formattedRecord.put('branchCity', branchCity);
                    formattedRecord.put('branchState', record.Branch__r?.State__c);
                }
            } else if (workLocation == 'Client Place') {
                if (String.isNotBlank(record.Client_Place_Details__c)) {
                    locationDisplay = record.Client_Place_Details__c.length() > 50 
                        ? record.Client_Place_Details__c.substring(0, 50) + '...' 
                        : record.Client_Place_Details__c;
                } else {
                    locationDisplay = 'Client Place';
                }
            } else if (workLocation == 'Field Work') {
                if (String.isNotBlank(record.Field_Work_Details__c)) {
                    locationDisplay = record.Field_Work_Details__c.length() > 50 
                        ? record.Field_Work_Details__c.substring(0, 50) + '...' 
                        : record.Field_Work_Details__c;
                } else {
                    locationDisplay = 'Field Work';
                }
            } else if (workLocation == 'Work from Home') {
                locationDisplay = 'Home';
            } else {
                locationDisplay = workLocation;
            }
            
            formattedRecord.put('locationDisplay', locationDisplay);
            formattedRecord.put('displayLocation', locationDisplay);
            formattedRecord.put('hasBranch', hasBranch);
            
            // Location type flags
            formattedRecord.put('isOfficeWork', workLocation == 'Work from Office');
            formattedRecord.put('isClientPlace', workLocation == 'Client Place');
            formattedRecord.put('isFieldWork', workLocation == 'Field Work');
            formattedRecord.put('isWFH', workLocation == 'Work from Home');
            
            // Details fields
            formattedRecord.put('clientPlaceDetails', record.Client_Place_Details__c);
            formattedRecord.put('fieldWorkDetails', record.Field_Work_Details__c);
            formattedRecord.put('wfhReason', record.WFH_Reason__c);
            
            // Notes
            if (String.isNotBlank(record.Notes__c)) {
                formattedRecord.put('notes', record.Notes__c);
                formattedRecord.put('displayNotes', record.Notes__c);
            } else {
                formattedRecord.put('notes', '--');
                formattedRecord.put('displayNotes', '--');
            }
            
            // System fields
            formattedRecord.put('createdDate', record.CreatedDate);
            formattedRecord.put('lastModifiedDate', record.LastModifiedDate);
            formattedRecord.put('createdBy', record.CreatedBy?.Name);
            formattedRecord.put('lastModifiedBy', record.LastModifiedBy?.Name);
            
            // Additional computed fields
            formattedRecord.put('recordNumber', recordIndex);
            formattedRecord.put('hasData', true);
            formattedRecord.put('isCompleteDay', 
                record.Check_In_Time__c != null && record.Check_Out_Time__c != null);
            
            formattedRecords.add(formattedRecord);
        }
        
        // Build successful response
        response.put('success', true);
        response.put('records', formattedRecords);
        response.put('totalCount', formattedRecords.size());
        response.put('employeeId', employeeId);
        response.put('employeeName', users[0].Name);
        response.put('recordsProcessed', recordIndex);
        response.put('limitApplied', limitRecords);
        response.put('message', 'Successfully retrieved ' + formattedRecords.size() + ' attendance records');
        
        System.debug('✅ SUCCESS: Retrieved ' + formattedRecords.size() + ' attendance records');
        
    } catch (AuraHandledException ahe) {
        System.debug('❌ AuraHandledException: ' + ahe.getMessage());
        response.put('success', false);
        response.put('error', ahe.getMessage());
        response.put('records', new List<Object>());
        response.put('totalCount', 0);
        throw ahe;
        
    } catch (Exception e) {
        System.debug('❌ Exception: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        
        response.put('success', false);
        response.put('error', 'Failed to retrieve attendance records: ' + e.getMessage());
        response.put('records', new List<Object>());
        response.put('totalCount', 0);
    }
    
    return response;
}
    
    /**
     * ✅ ENHANCED: Process WFH approval status with custom messages as per requirements
     * @param record The Employee_Attendance__c record
     * @return Map containing WFH approval status information with enhanced messages
     */
    private static Map<String, String> processWFHApprovalStatus(Employee_Attendance__c record) {
        Map<String, String> wfhStatusInfo = new Map<String, String>();
        
        String wfhApprovalStatus = record.WFH_Approval_Status__c;
        String wfhApprovalMessage = '';
        String wfhApprovalClass = '';
        
        System.debug('Processing WFH status - Work Location: ' + record.Work_Location__c + 
                    ', Submitted: ' + record.Submitted_For_Approval__c + 
                    ', Status: ' + wfhApprovalStatus);
        
        // Check if this is a WFH request that was submitted for approval
        if (record.Submitted_For_Approval__c == true && 
            record.Work_Location__c == 'Work from Home') {
            
            if (String.isBlank(wfhApprovalStatus) || wfhApprovalStatus.equals('Pending')) {
                // ✅ REQUIREMENT: "Pending" if user has applied for work from home
                wfhApprovalMessage = 'Pending Manager Approval';
                wfhApprovalClass = 'approval-badge approval-pending';
                System.debug('✅ Set WFH status: Pending Manager Approval');
                
            } else if (wfhApprovalStatus.equalsIgnoreCase('Approved')) {
                // ✅ REQUIREMENT: "Approved" if manager approved the request
                wfhApprovalMessage = 'Approved by Manager';
                wfhApprovalClass = 'approval-badge approval-approved';
                System.debug('✅ Set WFH status: Approved by Manager');
                
            } else if (wfhApprovalStatus.equalsIgnoreCase('Rejected')) {
                // ✅ REQUIREMENT: "Decline message with Loss of Pay" if manager rejected
                wfhApprovalMessage = 'Request Declined - Loss of Pay';
                wfhApprovalClass = 'approval-badge approval-rejected';
                System.debug('✅ Set WFH status: Request Declined - Loss of Pay');
                
            } else {
                // Handle any other status values
                wfhApprovalMessage = 'Status: ' + (wfhApprovalStatus != null ? wfhApprovalStatus : 'Unknown');
                wfhApprovalClass = 'approval-badge approval-pending';
                System.debug('⚠️ Unknown WFH approval status: ' + wfhApprovalStatus);
            }
            
        } else {
            // ✅ REQUIREMENT: Show "--" for non-WFH attendance records
            wfhApprovalMessage = '--';
            wfhApprovalClass = 'approval-badge approval-none';
            wfhApprovalStatus = null;
            System.debug('ℹ️ Not a WFH approval request, showing: --');
        }
        
        wfhStatusInfo.put('wfhApprovalStatus', wfhApprovalStatus);
        wfhStatusInfo.put('wfhApprovalStatusText', wfhApprovalMessage);
        wfhStatusInfo.put('wfhApprovalBadgeClass', wfhApprovalClass);
        
        return wfhStatusInfo;
    }
    
    /**
     * @description Enhanced method to include all location details (Legacy method for backward compatibility)
     * @param employeeId The ID of the employee
     * @param limitRecords Maximum number of records to retrieve
     * @return Map containing success status and formatted records with all details
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getEmployeeAttendanceRecordsWithApproval(String employeeId, Integer limitRecords) {
        // Delegate to the main enhanced method
        return getEmployeeAttendanceRecords(employeeId, limitRecords);
    }
    
    /**
     * @description Helper method to get today's attendance with all location details
     * @param employeeId The ID of the employee
     * @return Map containing today's attendance information with all location details
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getTodayAttendance(String employeeId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== GETTING TODAY\'S ATTENDANCE WITH ALL LOCATION DETAILS ===');
            System.debug('Employee ID: ' + employeeId);
            
            if (String.isBlank(employeeId)) {
                throw new AuraHandledException('Employee ID is required');
            }
            
            Date today = Date.today();
            System.debug('Today\'s date: ' + today);
            
            // ✅ ENHANCED: Query with Client Place and Field Work Details
            List<Employee_Attendance__c> todayRecords = [
                SELECT Id, Check_In_Time__c, Check_Out_Time__c, Status__c, 
                       Work_Location__c, Hours_Worked__c, Notes__c,
                       WFH_Reason__c, WFH_Approval_Status__c, Submitted_For_Approval__c,
                       Client_Place_Details__c, Field_Work_Details__c,
                       Check_In_Location_Name__c, Employee_Name__r.Name
                FROM Employee_Attendance__c 
                WHERE Employee_Name__c = :employeeId 
                AND Date__c = :today 
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!todayRecords.isEmpty()) {
                Employee_Attendance__c todayRecord = todayRecords[0];
                System.debug('Found today\'s attendance record: ' + todayRecord.Id);
                
                response.put('success', true);
                response.put('hasRecord', true);
                response.put('recordId', todayRecord.Id);
                response.put('employeeName', todayRecord.Employee_Name__r?.Name);
                response.put('isCheckedIn', todayRecord.Check_In_Time__c != null);
                response.put('isCheckedOut', todayRecord.Check_Out_Time__c != null);
                response.put('status', todayRecord.Status__c != null ? todayRecord.Status__c : 'Present');
                response.put('workLocation', todayRecord.Work_Location__c);
                response.put('notes', todayRecord.Notes__c);
                response.put('locationName', todayRecord.Check_In_Location_Name__c);
                
                if (todayRecord.Check_In_Time__c != null) {
                    response.put('checkInTime', formatTime(todayRecord.Check_In_Time__c));
                }
                
                if (todayRecord.Check_Out_Time__c != null) {
                    response.put('checkOutTime', formatTime(todayRecord.Check_Out_Time__c));
                }
                
                if (todayRecord.Hours_Worked__c != null) {
                    response.put('hoursWorked', String.valueOf(todayRecord.Hours_Worked__c.setScale(2)));
                }
                
                // ✅ NEW: Include Client Place and Field Work details
                response.put('clientPlaceDetails', todayRecord.Client_Place_Details__c);
                response.put('hasClientPlaceDetails', String.isNotBlank(todayRecord.Client_Place_Details__c));
                response.put('fieldWorkDetails', todayRecord.Field_Work_Details__c);
                response.put('hasFieldWorkDetails', String.isNotBlank(todayRecord.Field_Work_Details__c));
                
                // WFH Approval status
                response.put('submittedForApproval', todayRecord.Submitted_For_Approval__c == true);
                response.put('wfhReason', todayRecord.WFH_Reason__c);
                response.put('wfhApprovalStatus', todayRecord.WFH_Approval_Status__c);
                
                // Process WFH status
                Map<String, String> wfhStatusInfo = processWFHApprovalStatus(todayRecord);
                response.putAll(wfhStatusInfo);
                
                System.debug('✅ Today\'s attendance loaded with all location details');
                
            } else {
                response.put('success', true);
                response.put('hasRecord', false);
                response.put('message', 'No attendance record found for today');
                System.debug('ℹ️ No attendance record found for today');
            }
            
        } catch (Exception e) {
            System.debug('❌ Exception in getTodayAttendance: ' + e.getMessage());
            response.put('success', false);
            response.put('error', e.getMessage());
            response.put('hasRecord', false);
            response.put('errorType', e.getTypeName());
        }
        
        return response;
    }
    
    /**
     * @description Get attendance summary with enhanced location-based statistics
     * @param employeeId The ID of the employee
     * @param startDate Start date for summary (optional)
     * @param endDate End date for summary (optional)
     * @return Map containing attendance summary with location-based metrics
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getAttendanceSummaryWithWFH(String employeeId, Date startDate, Date endDate) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== GETTING ATTENDANCE SUMMARY WITH LOCATION METRICS ===');
            
            if (String.isBlank(employeeId)) {
                throw new AuraHandledException('Employee ID is required');
            }
            
            // Set default date range if not provided (current month)
            if (startDate == null) {
                startDate = Date.today().toStartOfMonth();
            }
            if (endDate == null) {
                endDate = Date.today();
            }
            
            System.debug('Date range: ' + startDate + ' to ' + endDate);
            
            // ✅ ENHANCED: Query with Client Place and Field Work Details
            List<Employee_Attendance__c> records = [
                SELECT Id, Date__c, Status__c, Hours_Worked__c, Work_Location__c,
                       WFH_Approval_Status__c, Submitted_For_Approval__c,
                       Client_Place_Details__c, Field_Work_Details__c,
                       Check_In_Time__c, Check_Out_Time__c
                FROM Employee_Attendance__c
                WHERE Employee_Name__c = :employeeId
                AND Date__c >= :startDate
                AND Date__c <= :endDate
                ORDER BY Date__c ASC
            ];
            
            // Calculate summary statistics
            Integer totalDays = records.size();
            Integer presentDays = 0;
            Integer lateDays = 0;
            Integer absentDays = 0;
            Integer wfhDays = 0;
            Integer wfhApprovedDays = 0;
            Integer wfhPendingDays = 0;
            Integer wfhRejectedDays = 0;
            Integer clientPlaceDays = 0;
            Integer fieldWorkDays = 0;
            Decimal totalHours = 0.0;
            
            for (Employee_Attendance__c record : records) {
                // Count by status
                if (record.Status__c == 'Present') {
                    presentDays++;
                } else if (record.Status__c == 'Late') {
                    lateDays++;
                } else if (record.Status__c == 'Absent') {
                    absentDays++;
                }
                
                // Count hours
                if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
                    totalHours += record.Hours_Worked__c;
                }
                
                // Count WFH requests and their approval statuses
                if (record.Work_Location__c == 'Work from Home') {
                    wfhDays++;
                    
                    if (record.Submitted_For_Approval__c == true) {
                        if (record.WFH_Approval_Status__c == 'Approved') {
                            wfhApprovedDays++;
                        } else if (record.WFH_Approval_Status__c == 'Rejected') {
                            wfhRejectedDays++;
                        } else {
                            wfhPendingDays++;
                        }
                    }
                }
                
                // ✅ NEW: Count Client Place visits
                if (record.Work_Location__c == 'Client Place') {
                    clientPlaceDays++;
                }
                
                // ✅ NEW: Count Field Work days
                if (record.Work_Location__c == 'Field Work') {
                    fieldWorkDays++;
                }
            }
            
            // Calculate derived metrics
            Decimal avgHoursPerDay = totalDays > 0 ? (totalHours / totalDays).setScale(2) : 0.0;
            Decimal attendanceRate = totalDays > 0 ? ((Decimal)(presentDays + lateDays) / totalDays * 100).setScale(2) : 0.0;
            Decimal wfhApprovalRate = wfhDays > 0 ? ((Decimal)wfhApprovedDays / wfhDays * 100).setScale(2) : 0.0;
            
            // Build response
            response.put('success', true);
            response.put('employeeId', employeeId);
            response.put('startDate', startDate.format());
            response.put('endDate', endDate.format());
            response.put('totalDays', totalDays);
            response.put('presentDays', presentDays);
            response.put('lateDays', lateDays);
            response.put('absentDays', absentDays);
            response.put('totalHours', totalHours.setScale(2));
            response.put('avgHoursPerDay', avgHoursPerDay);
            response.put('attendanceRate', attendanceRate);
            
            // WFH metrics
            response.put('wfhDays', wfhDays);
            response.put('wfhApprovedDays', wfhApprovedDays);
            response.put('wfhPendingDays', wfhPendingDays);
            response.put('wfhRejectedDays', wfhRejectedDays);
            response.put('wfhApprovalRate', wfhApprovalRate);
            
            // ✅ NEW: Location-based metrics
            response.put('clientPlaceDays', clientPlaceDays);
            response.put('fieldWorkDays', fieldWorkDays);
            
            String summaryMessage = String.format(
                'Processed {0} days. WFH: {1} ({2} approved, {3} pending, {4} rejected), Client Place: {5}, Field Work: {6}',
                new List<Object>{totalDays, wfhDays, wfhApprovedDays, wfhPendingDays, wfhRejectedDays, clientPlaceDays, fieldWorkDays}
            );
            response.put('summaryMessage', summaryMessage);
            
            System.debug('✅ Summary generated: ' + summaryMessage);
            
        } catch (Exception e) {
            System.debug('❌ Exception in getAttendanceSummaryWithWFH: ' + e.getMessage());
            response.put('success', false);
            response.put('error', e.getMessage());
        }
        
        return response;
    }
    
    /**
     * ✅ NEW: Test method for Client Place and Field Work field access
     * @param employeeId The employee ID to test
     * @return Map containing test results for new fields
     */
    @AuraEnabled
    public static Map<String, Object> testLocationFieldsAccess(String employeeId) {
        Map<String, Object> testResult = new Map<String, Object>();
        
        try {
            System.debug('=== TESTING LOCATION FIELDS ACCESS ===');
            System.debug('Employee ID: ' + employeeId);
            
            if (String.isBlank(employeeId)) {
                throw new AuraHandledException('Employee ID is required for testing');
            }
            
            // Test field access
            Schema.DescribeSObjectResult objDescribe = Employee_Attendance__c.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            Boolean hasClientPlaceField = fieldMap.containsKey('Client_Place_Details__c');
            Boolean hasFieldWorkField = fieldMap.containsKey('Field_Work_Details__c');
            
            testResult.put('hasClientPlaceDetailsField', hasClientPlaceField);
            testResult.put('hasFieldWorkDetailsField', hasFieldWorkField);
            
            // Get sample records with location details
            List<Employee_Attendance__c> sampleRecords = [
                SELECT Id, Date__c, Work_Location__c, 
                       Client_Place_Details__c, Field_Work_Details__c,
                       WFH_Reason__c
                FROM Employee_Attendance__c
                WHERE Employee_Name__c = :employeeId
                ORDER BY Date__c DESC
                LIMIT 5
            ];
            
            testResult.put('sampleRecordsFound', sampleRecords.size());
            
            List<Map<String, Object>> sampleData = new List<Map<String, Object>>();
            for (Employee_Attendance__c record : sampleRecords) {
                Map<String, Object> recordData = new Map<String, Object>();
                recordData.put('recordId', record.Id);
                recordData.put('date', record.Date__c.format());
                recordData.put('workLocation', record.Work_Location__c);
                recordData.put('hasClientPlaceDetails', String.isNotBlank(record.Client_Place_Details__c));
                recordData.put('hasFieldWorkDetails', String.isNotBlank(record.Field_Work_Details__c));
                recordData.put('hasWFHReason', String.isNotBlank(record.WFH_Reason__c));
                
                sampleData.add(recordData);
            }
            
            testResult.put('sampleData', sampleData);
            testResult.put('success', true);
            testResult.put('message', 'Location fields access test completed successfully');
            
            System.debug('✅ Location fields test completed');
            
        } catch (Exception e) {
            System.debug('❌ Error in testLocationFieldsAccess: ' + e.getMessage());
            testResult.put('success', false);
            testResult.put('error', e.getMessage());
        }
        
        return testResult;
    }
    
    // ===============================
    // HELPER METHODS
    // ===============================
    
    /**
     * ✅ Helper method to format DateTime values consistently for time display
     * @param dtValue DateTime value to format
     * @return Formatted time string (hh:mm a)
     */
    private static String formatTime(DateTime dtValue) {
        if (dtValue == null) {
            return '--';
        }
        
        try {
            return dtValue.format('hh:mm a');
        } catch (Exception e) {
            System.debug('Error formatting time: ' + e.getMessage());
            return dtValue.format();
        }
    }
    
	/**
 * ✅ UPDATED: Get all today's attendance sessions for an employee
 * Supports multiple check-in/check-out per day
 * @param employeeId The employee ID
 * @return Map containing all today's attendance sessions
 */
@AuraEnabled(cacheable=false)
public static Map<String, Object> getTodayAttendanceRecord(String employeeId) {
    Map<String, Object> response = new Map<String, Object>();
    
    try {
        System.debug('=== GETTING TODAY\'S ATTENDANCE SESSIONS (MULTIPLE SUPPORT) ===');
        System.debug('Employee ID: ' + employeeId);
        
        if (String.isBlank(employeeId)) {
            throw new AuraHandledException('Employee ID is required');
        }
        
        Date today = Date.today();
        System.debug('Today\'s date: ' + today);
        
        // ✅ UPDATED: Query ALL sessions for today, ordered by session number
        List<Employee_Attendance__c> todayRecords = [
            SELECT Id, Employee_Name__c, Employee_Name__r.Name,
                   Date__c, Check_In_Time__c, Check_Out_Time__c, 
                   Status__c, Work_Location__c, Hours_Worked__c, 
                   Notes__c,
                   Session_Number__c, Is_Multiple_Session__c,
                   Branch__c, Branch__r.Branch_Name__c,
                   Client_Place_Details__c, Field_Work_Details__c, WFH_Reason__c
            FROM Employee_Attendance__c 
            WHERE Employee_Name__c = :employeeId 
            AND Date__c = :today 
            ORDER BY Session_Number__c DESC, CreatedDate DESC
        ];
        
        if (!todayRecords.isEmpty()) {
            System.debug('✅ Found ' + todayRecords.size() + ' session(s) for today');
            
            response.put('success', true);
            response.put('hasRecords', true); // ✅ CHANGED from hasRecord
            response.put('totalSessions', todayRecords.size());
            
            // ✅ NEW: Get the LAST (most recent) session
            Employee_Attendance__c lastSession = todayRecords[0];
            
            // Last session details
            Map<String, Object> lastSessionData = new Map<String, Object>();
            lastSessionData.put('recordId', lastSession.Id);
            lastSessionData.put('sessionNumber', lastSession.Session_Number__c != null ? lastSession.Session_Number__c.intValue() : 1);
            lastSessionData.put('employeeName', lastSession.Employee_Name__r?.Name);
            lastSessionData.put('date', lastSession.Date__c);
            lastSessionData.put('isCheckedIn', lastSession.Check_In_Time__c != null);
            lastSessionData.put('isCheckedOut', lastSession.Check_Out_Time__c != null);
            lastSessionData.put('checkInTime', lastSession.Check_In_Time__c);
            lastSessionData.put('checkOutTime', lastSession.Check_Out_Time__c);
            lastSessionData.put('workLocation', lastSession.Work_Location__c);
            lastSessionData.put('status', lastSession.Status__c);
            lastSessionData.put('hoursWorked', lastSession.Hours_Worked__c);
            
            response.put('lastSession', lastSessionData);
            
            // ✅ NEW: Return ALL sessions for total hours calculation
            List<Map<String, Object>> allSessionsData = new List<Map<String, Object>>();
            Decimal totalDailyHours = 0;
            
            for (Employee_Attendance__c session : todayRecords) {
                Map<String, Object> sessionData = new Map<String, Object>();
                sessionData.put('recordId', session.Id);
                sessionData.put('sessionNumber', session.Session_Number__c != null ? session.Session_Number__c.intValue() : 1);
                sessionData.put('checkInTime', session.Check_In_Time__c);
                sessionData.put('checkOutTime', session.Check_Out_Time__c);
                sessionData.put('hoursWorked', session.Hours_Worked__c != null ? session.Hours_Worked__c : 0);
                sessionData.put('workLocation', session.Work_Location__c);
                sessionData.put('isCompleted', session.Check_In_Time__c != null && session.Check_Out_Time__c != null);
                
                allSessionsData.add(sessionData);
                
                // Calculate total hours
                if (session.Hours_Worked__c != null && session.Hours_Worked__c > 0) {
                    totalDailyHours += session.Hours_Worked__c;
                }
            }
            
            response.put('allSessions', allSessionsData);
            response.put('totalDailyHours', totalDailyHours.setScale(1));
            
            System.debug('Last session: ' + lastSession.Id + ' (Session #' + lastSession.Session_Number__c + ')');
            System.debug('Total sessions today: ' + todayRecords.size());
            System.debug('Total hours worked today: ' + totalDailyHours);
            
        } else {
            System.debug('ℹ️ No attendance sessions found for today');
            response.put('success', true);
            response.put('hasRecords', false); // ✅ CHANGED from hasRecord
            response.put('totalSessions', 0);
            response.put('message', 'No attendance record found for today');
        }
        
    } catch (Exception e) {
        System.debug('❌ Exception in getTodayAttendanceRecord: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        response.put('success', false);
        response.put('error', e.getMessage());
        response.put('hasRecords', false); // ✅ CHANGED from hasRecord
        response.put('totalSessions', 0);
    }
    
    return response;
}
    
    /**
     * ✅ Helper method to format DateTime values consistently for full datetime display
     * @param dtValue DateTime value to format
     * @return Formatted datetime string (MM/dd/yyyy hh:mm a)
     */
    private static String formatDateTime(DateTime dtValue) {
        if (dtValue == null) {
            return '--';
        }
        
        try {
            return dtValue.format('MM/dd/yyyy hh:mm a');
        } catch (Exception e) {
            System.debug('Error formatting datetime: ' + e.getMessage());
            return dtValue.format();
        }
    }
    /**
 * @description Get CSS class for status badge
 */
private static String getStatusClass(String status) {
    if (String.isBlank(status)) return 'status-badge status-present';
    
    switch on status.toLowerCase().trim() {
        when 'present' {
            return 'status-badge status-present';
        }
        when 'late' {
            return 'status-badge status-late';
        }
        when 'half day', 'halfday' {
            return 'status-badge status-half-day';
        }
        when 'absent' {
            return 'status-badge status-absent';
        }
        when else {
            return 'status-badge status-present';
        }
    }
}
    
    /**
     * ✅ Enhanced helper method to get location name with improved logic
     * @param record The Employee_Attendance__c record
     * @return String location name for display
     */
    private static String getEnhancedLocationName(Employee_Attendance__c record) {
        // Priority: Check_In_Location_Name__c > Work_Location__c > Default
        if (String.isNotBlank(record.Check_In_Location_Name__c)) {
            return record.Check_In_Location_Name__c;
        } else if (String.isNotBlank(record.Work_Location__c)) {
            return record.Work_Location__c;
        } else {
            return 'Office';
        }
    }
    
    /**
     * @description Test method to verify the class functionality
     */
    @TestVisible
    private static void testDataSetup() {
        System.debug('Enhanced AttendanceViewController with location fields test setup completed');
    }
  		/**
 * Check if employee has approved or pending leave for a specific date
 * Excludes Cancelled and Rejected leaves
 * @param employeeId Employee ID to check
 * @param checkDate Date to check for leave (format: YYYY-MM-DD)
 * @return Map with leave information
 */
@AuraEnabled(cacheable=false)
public static Map<String, Object> checkLeaveForDate(Id employeeId, String checkDate) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        System.debug('=== CHECKING LEAVE FOR DATE ===');
        System.debug('Employee ID: ' + employeeId);
        System.debug('Check Date: ' + checkDate);
        
        Date targetDate = Date.valueOf(checkDate);
        
        // Query leave requests - EXCLUDE Cancelled and Rejected
        List<Leave_Request__c> leaveRequests = [
            SELECT Id, Name, Leave_Type__c, Leave_Type__r.Leave_Type_Name__c,
                   Leave_Type__r.Leave_Code__c, Start_Date__c, End_Date__c,
                   Total_Days__c, Reason__c, Status__c, Is_Half_Day__c, Half_Day_Type__c
            FROM Leave_Request__c
            WHERE Employee__c = :employeeId
            AND Start_Date__c <= :targetDate
            AND End_Date__c >= :targetDate
            AND Status__c IN ('Approved', 'Pending')
            AND Is_Active__c = true
            ORDER BY Applied_Date__c DESC
            LIMIT 1
        ];
        
        if (!leaveRequests.isEmpty()) {
            Leave_Request__c leave = leaveRequests[0];
            
            result.put('hasLeave', true);
            result.put('leaveId', leave.Id);
            result.put('leaveName', leave.Name);
            result.put('leaveType', leave.Leave_Type__r.Leave_Type_Name__c);
            result.put('leaveCode', leave.Leave_Type__r.Leave_Code__c);
            result.put('startDate', leave.Start_Date__c);
            result.put('endDate', leave.End_Date__c);
            result.put('totalDays', leave.Total_Days__c);
            result.put('reason', leave.Reason__c);
            result.put('status', leave.Status__c);
            result.put('isHalfDay', leave.Is_Half_Day__c);
            result.put('halfDayType', leave.Half_Day_Type__c);
            
            String message = 'You have ' + leave.Status__c.toLowerCase() + ' ' + 
                           leave.Leave_Type__r.Leave_Type_Name__c + ' leave for this date';
            
            if (leave.Is_Half_Day__c && String.isNotBlank(leave.Half_Day_Type__c)) {
                message += ' (' + leave.Half_Day_Type__c + ')';
            }
            
            result.put('message', message);
            
            System.debug('✅ Active leave found: ' + leave.Leave_Type__r.Leave_Type_Name__c);
        } else {
            result.put('hasLeave', false);
            result.put('message', 'No active leave found for this date');
            System.debug('ℹ️ No active leave found (cancelled leaves excluded)');
        }
        
        result.put('success', true);
        
    } catch (Exception e) {
        System.debug('❌ Error checking leave: ' + e.getMessage());
        result.put('success', false);
        result.put('hasLeave', false);
        result.put('error', e.getMessage());
    }
    
    return result;
}


}