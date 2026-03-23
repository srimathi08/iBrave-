/**
 * @description Admin Attendance View Controller - Enhanced with Dropdown Filters
 * @author Salesforce Consultant
 * @date 2025-10-17
 * @version 2.0 - Added Employee ID and Name dropdown filters
 * 
 * Features:
 * - Dynamic SOQL query builder for flexible filtering
 * - Employee ID dropdown with all employee IDs
 * - Employee Name dropdown with all employee names
 * - Department dropdown filter
 * - Date Range filters
 * - Pagination support with configurable page sizes
 * - Sorting capabilities for all columns
 * - Universal profile access
 * - CSV export functionality
 */
public without sharing class AdminAttendanceViewController {
    
    /**
     * @description Main method to retrieve filtered attendance records for admin view
     * @param filterParams Map containing all filter parameters
     * @return Map containing attendance records, total count, and metadata
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getAdminAttendanceRecords(Map<String, Object> filterParams) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== ADMIN ATTENDANCE VIEW - GET RECORDS ===');
            System.debug('Filter Parameters: ' + JSON.serializePretty(filterParams));
            System.debug('Current User: ' + UserInfo.getName() + ' (' + UserInfo.getProfileId() + ')');
            
            // Validate admin permissions
            if (!hasAdminPermission()) {
                throw new AuraHandledException('Access Denied: You do not have permission to view admin attendance data');
            }
            
            // Extract filter parameters
            String employeeId = getFilterValue(filterParams, 'employeeId');
            String employeeName = getFilterValue(filterParams, 'employeeName');
            String department = getFilterValue(filterParams, 'department');
            Date startDate = getDateValue(filterParams, 'startDate');
            Date endDate = getDateValue(filterParams, 'endDate');
            
            // Pagination parameters
            Integer pageSize = getIntegerValue(filterParams, 'pageSize', 20);
            Integer pageNumber = getIntegerValue(filterParams, 'pageNumber', 1);
            Integer offset = (pageNumber - 1) * pageSize;
            
            // Sorting parameters
            String sortField = getFilterValue(filterParams, 'sortField');
            String sortDirection = getFilterValue(filterParams, 'sortDirection');
            if (String.isBlank(sortField)) {
                sortField = 'Date__c';
                sortDirection = 'DESC';
            }
            
            System.debug('Filters Applied:');
            System.debug('  - Employee ID: ' + employeeId);
            System.debug('  - Employee Name: ' + employeeName);
            System.debug('  - Department: ' + department);
            System.debug('  - Start Date: ' + startDate);
            System.debug('  - End Date: ' + endDate);
            System.debug('Pagination: PageSize=' + pageSize + ', PageNumber=' + pageNumber + ', Offset=' + offset);
            System.debug('Sorting: Field=' + sortField + ', Direction=' + sortDirection);
            
            // Build dynamic SOQL query
            String queryString = buildAttendanceQuery(
                employeeId, 
                employeeName, 
                department, 
                startDate, 
                endDate, 
                sortField, 
                sortDirection,
                pageSize,
                offset
            );
            
            System.debug('Dynamic Query: ' + queryString);
            
            // Execute query
            List<Employee_Attendance__c> attendanceRecords = Database.query(queryString);
            
            // Get total count (without pagination)
            Integer totalCount = getTotalRecordCount(employeeId, employeeName, department, startDate, endDate);
            
            System.debug('Records Retrieved: ' + attendanceRecords.size());
            System.debug('Total Count: ' + totalCount);
            
            // Format records for LWC display
            List<Map<String, Object>> formattedRecords = formatAttendanceRecords(attendanceRecords);
            
            // Build success response
            response.put('success', true);
            response.put('records', formattedRecords);
            response.put('totalRecords', totalCount);
            response.put('pageSize', pageSize);
            response.put('pageNumber', pageNumber);
            response.put('totalPages', Math.ceil(Decimal.valueOf(totalCount) / Decimal.valueOf(pageSize)).intValue());
            response.put('hasRecords', !formattedRecords.isEmpty());
            response.put('message', 'Successfully retrieved ' + formattedRecords.size() + ' records');
            
            // Add filter summary for debugging
            Map<String, Object> appliedFilters = new Map<String, Object>();
            appliedFilters.put('employeeId', employeeId);
            appliedFilters.put('employeeName', employeeName);
            appliedFilters.put('department', department);
            appliedFilters.put('startDate', startDate);
            appliedFilters.put('endDate', endDate);
            response.put('appliedFilters', appliedFilters);
            
            System.debug('✅ SUCCESS: Admin attendance records retrieved successfully');
            
        } catch (AuraHandledException ahe) {
            System.debug('❌ AuraHandledException: ' + ahe.getMessage());
            response.put('success', false);
            response.put('error', ahe.getMessage());
            response.put('records', new List<Object>());
            response.put('totalRecords', 0);
            throw ahe;
            
        } catch (QueryException qe) {
            System.debug('❌ QueryException: ' + qe.getMessage());
            System.debug('Stack Trace: ' + qe.getStackTraceString());
            response.put('success', false);
            response.put('error', 'Database query error: ' + qe.getMessage());
            response.put('records', new List<Object>());
            response.put('totalRecords', 0);
            
        } catch (Exception e) {
            System.debug('❌ Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            response.put('success', false);
            response.put('error', 'Unexpected error: ' + e.getMessage());
            response.put('records', new List<Object>());
            response.put('totalRecords', 0);
        }
        
        return response;
    }
    
    /**
     * @description Build dynamic SOQL query based on filter parameters
     * @param employeeId Employee ID filter (exact match)
     * @param employeeName Employee Name filter (from User object Name)
     * @param department Department filter
     * @param startDate Start date for date range
     * @param endDate End date for date range
     * @param sortField Field to sort by
     * @param sortDirection Sort direction (ASC/DESC)
     * @param limitRecords Limit number of records
     * @param offset Offset for pagination
     * @return String Complete SOQL query
     */
    private static String buildAttendanceQuery(
        String employeeId, 
        String employeeName, 
        String department, 
        Date startDate, 
        Date endDate,
        String sortField,
        String sortDirection,
        Integer limitRecords,
        Integer offset
    ) {
        // Base query with all required fields
        String query = 'SELECT Id, Name, ' +
                      'Employee_Name__c, Employee_Name__r.Name, Employee_Name__r.Email, ' +
                      'Employee_Name__r.Employee_IDs__c, Employee_Name__r.Department, ' +
                      'Employee_Name__r.Manager.Name, ' +
                      'Date__c, Check_In_Time__c, Check_Out_Time__c, Hours_Worked__c, ' +
                      'Work_Location__c, Check_In_Location_Name__c, Check_Out_Location_Name__c, ' +
                      'WFH_Reason__c, WFH_Approval_Status__c, ' +
                      'CreatedDate, LastModifiedDate ' +
                      'FROM Employee_Attendance__c ';
        
        // Build WHERE clause dynamically
        List<String> whereConditions = new List<String>();
        
        // ✅ FIXED: Employee ID filter - Exact match (Number field - no quotes, no LIKE)
        if (String.isNotBlank(employeeId)) {
            String searchTerm = String.escapeSingleQuotes(employeeId);
            // Employee_IDs__c is a Number field, so no quotes needed
            whereConditions.add('Employee_Name__r.Employee_IDs__c = \'' + searchTerm + '\'');
        }
        
        // ✅ FIXED: Employee Name filter - Exact match (String field - needs quotes)
        if (String.isNotBlank(employeeName)) {
            String searchTerm = String.escapeSingleQuotes(employeeName);
            whereConditions.add('Employee_Name__r.Name = \'' + searchTerm + '\'');
        }
        
        // ✅ FIXED: Department filter - Exact match (String field - needs quotes, no LIKE)
        if (String.isNotBlank(department)) {
            String deptSearchTerm = String.escapeSingleQuotes(department);
            whereConditions.add('Employee_Name__r.Department = \'' + deptSearchTerm + '\'');
        }
        
        // Date range filters
        if (startDate != null) {
            whereConditions.add('Date__c >= ' + String.valueOf(startDate));
        }
        
        if (endDate != null) {
            whereConditions.add('Date__c <= ' + String.valueOf(endDate));
        }
        
        // Add WHERE clause if conditions exist
        if (!whereConditions.isEmpty()) {
            query += 'WHERE ' + String.join(whereConditions, ' AND ') + ' ';
        }
        
        // Add ORDER BY clause
        query += 'ORDER BY ' + sortField + ' ' + sortDirection + ' ';
        
        // Add LIMIT and OFFSET
        query += 'LIMIT ' + limitRecords + ' ';
        query += 'OFFSET ' + offset;
        
        return query;
    }
    
    /**
     * @description Get total count of records without pagination
     * @param employeeId Employee ID filter
     * @param employeeName Employee Name filter
     * @param department Department filter
     * @param startDate Start date
     * @param endDate End date
     * @return Integer Total record count
     */
    private static Integer getTotalRecordCount(
        String employeeId, 
        String employeeName, 
        String department, 
        Date startDate, 
        Date endDate
    ) {
        String countQuery = 'SELECT COUNT() FROM Employee_Attendance__c ';
        
        List<String> whereConditions = new List<String>();
        
        // ✅ FIXED: Employee ID - Number field (no quotes, no LIKE)
        if (String.isNotBlank(employeeId)) {
            //whereConditions.add('Employee_Name__r.Employee_IDs__c = ' + employeeId);
             String searchTerm = String.escapeSingleQuotes(employeeId);
            whereConditions.add('Employee_Name__r.Employee_IDs__c = \'' + searchTerm + '\'');
        }
        
        // ✅ FIXED: Employee Name - String field (with quotes, exact match)
        if (String.isNotBlank(employeeName)) {
            String searchTerm = String.escapeSingleQuotes(employeeName);
            whereConditions.add('Employee_Name__r.Name = \'' + searchTerm + '\'');
        }
        
        // ✅ FIXED: Department - String field (with quotes, exact match, no LIKE)
        if (String.isNotBlank(department)) {
            String deptSearchTerm = String.escapeSingleQuotes(department);
            whereConditions.add('Employee_Name__r.Department = \'' + deptSearchTerm + '\'');
        }
        
        // Date filters
        if (startDate != null) {
            whereConditions.add('Date__c >= ' + String.valueOf(startDate));
        }
        
        if (endDate != null) {
            whereConditions.add('Date__c <= ' + String.valueOf(endDate));
        }
        
        if (!whereConditions.isEmpty()) {
            countQuery += 'WHERE ' + String.join(whereConditions, ' AND ');
        }
        
        System.debug('Count Query: ' + countQuery);
        
        return Database.countQuery(countQuery);
    }
    
    /**
     * @description Format attendance records for LWC display
     * @param records List of Employee_Attendance__c records
     * @return List<Map<String, Object>> Formatted records
     */
    private static List<Map<String, Object>> formatAttendanceRecords(List<Employee_Attendance__c> records) {
        List<Map<String, Object>> formattedRecords = new List<Map<String, Object>>();
        
        Integer recordIndex = 0;
        for (Employee_Attendance__c record : records) {
            recordIndex++;
            Map<String, Object> formattedRecord = new Map<String, Object>();
            
            // Basic record information
            formattedRecord.put('recordId', record.Id);
            formattedRecord.put('recordName', record.Name);
            formattedRecord.put('recordNumber', recordIndex);
            
            // Employee information
            formattedRecord.put('employeeId', record.Employee_Name__r?.Employee_IDs__c);
            formattedRecord.put('employeeName', record.Employee_Name__r?.Name);
            formattedRecord.put('employeeEmail', record.Employee_Name__r?.Email);
            formattedRecord.put('department', record.Employee_Name__r?.Department);
            formattedRecord.put('managerName', record.Employee_Name__r?.Manager?.Name);
            
            // Date and time information
            if (record.Date__c != null) {
                formattedRecord.put('date', record.Date__c.format());
                formattedRecord.put('dateValue', record.Date__c);
            } else {
                formattedRecord.put('date', '--');
                formattedRecord.put('dateValue', null);
            }
            
            // Check-in time
            if (record.Check_In_Time__c != null) {
                formattedRecord.put('checkInTime', formatDateTime(record.Check_In_Time__c));
                formattedRecord.put('checkInTimeValue', record.Check_In_Time__c);
            } else {
                formattedRecord.put('checkInTime', '--');
                formattedRecord.put('checkInTimeValue', null);
            }
            
            // Check-out time
            if (record.Check_Out_Time__c != null) {
                formattedRecord.put('checkOutTime', formatDateTime(record.Check_Out_Time__c));
                formattedRecord.put('checkOutTimeValue', record.Check_Out_Time__c);
            } else {
                formattedRecord.put('checkOutTime', '--');
                formattedRecord.put('checkOutTimeValue', null);
            }
            
            // Hours worked
            if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
                Decimal hours = record.Hours_Worked__c;
                formattedRecord.put('hoursWorked', formatHoursWorked(hours));
                formattedRecord.put('hoursWorkedValue', hours);
            } else {
                formattedRecord.put('hoursWorked', '00h 00m');
                formattedRecord.put('hoursWorkedValue', 0);
            }
            
            // Location information
            formattedRecord.put('workLocation', record.Work_Location__c);
            formattedRecord.put('checkInLocationName', record.Check_In_Location_Name__c);
            formattedRecord.put('checkOutLocationName', record.Check_Out_Location_Name__c);
            
            // Determine display location
            String displayLocation = record.Check_In_Location_Name__c;
            if (String.isBlank(displayLocation)) {
                displayLocation = record.Work_Location__c;
            }
            if (String.isBlank(displayLocation)) {
                displayLocation = 'Office';
            }
            formattedRecord.put('location', displayLocation);
            
            // WFH information
            formattedRecord.put('wfhReason', record.WFH_Reason__c);
            
            // Process WFH Approval Status with custom display logic
            Map<String, String> wfhStatusInfo = processWFHApprovalStatus(record);
            formattedRecord.put('wfhApprovalStatus', wfhStatusInfo.get('status'));
            formattedRecord.put('wfhApprovalStatusText', wfhStatusInfo.get('displayText'));
            formattedRecord.put('wfhApprovalStatusClass', wfhStatusInfo.get('cssClass'));
            
            // System fields
            formattedRecord.put('createdDate', record.CreatedDate);
            formattedRecord.put('lastModifiedDate', record.LastModifiedDate);
            
            // Computed fields
            formattedRecord.put('isWFHRequest', record.Work_Location__c == 'Work from Home');
            formattedRecord.put('hasWFHReason', String.isNotBlank(record.WFH_Reason__c));
            formattedRecord.put('isCompleteDay', record.Check_In_Time__c != null && record.Check_Out_Time__c != null);
            
            formattedRecords.add(formattedRecord);
        }
        
        return formattedRecords;
    }
    
    /**
     * @description Process WFH approval status with custom display logic
     * @param record Employee_Attendance__c record
     * @return Map containing status, displayText, and cssClass
     */
    private static Map<String, String> processWFHApprovalStatus(Employee_Attendance__c record) {
        Map<String, String> statusInfo = new Map<String, String>();
        
        String status = record.WFH_Approval_Status__c;
        String displayText = '--';
        String cssClass = 'wfh-badge wfh-none';
        
        // Only show WFH status if Work Location is "Work from Home"
        if (record.Work_Location__c == 'Work from Home' && String.isNotBlank(record.WFH_Reason__c)) {
            
            if (String.isBlank(status) || status.equalsIgnoreCase('Pending')) {
                displayText = 'Pending';
                cssClass = 'wfh-badge wfh-pending';
                
            } else if (status.equalsIgnoreCase('Approved')) {
                displayText = 'Approved';
                cssClass = 'wfh-badge wfh-approved';
                
            } else if (status.equalsIgnoreCase('Rejected')) {
                displayText = 'Rejected';
                cssClass = 'wfh-badge wfh-rejected';
                
            } else {
                displayText = status;
                cssClass = 'wfh-badge wfh-unknown';
            }
        }
        
        statusInfo.put('status', status);
        statusInfo.put('displayText', displayText);
        statusInfo.put('cssClass', cssClass);
        
        return statusInfo;
    }
    
    // ============================================
    // DROPDOWN DATA METHODS
    // ============================================
    
    /**
     * @description Get all unique Employee IDs for dropdown filter
     * @return List<Map<String, Object>> List of employee IDs with label and value
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmployeeIds() {
        List<Map<String, Object>> employeeIdOptions = new List<Map<String, Object>>();
        
        try {
            System.debug('=== FETCHING EMPLOYEE IDs FOR DROPDOWN ===');
            
            // Query all active users with Employee IDs
            List<User> users = [
                SELECT Employee_IDs__c, Name
                FROM User 
                WHERE Employee_IDs__c != null 
                AND IsActive = true
                ORDER BY Employee_IDs__c ASC
                LIMIT 1000
            ];
            
            System.debug('Users with Employee IDs found: ' + users.size());
            
            for (User u : users) {
                Map<String, Object> option = new Map<String, Object>();
                option.put('label', String.valueOf(u.Employee_IDs__c) + ' - ' + u.Name);
                option.put('value', String.valueOf(u.Employee_IDs__c));
                employeeIdOptions.add(option);
            }
            
            System.debug('✅ Employee ID options created: ' + employeeIdOptions.size());
            
        } catch (Exception e) {
            System.debug('❌ Error fetching Employee IDs: ' + e.getMessage());
        }
        
        return employeeIdOptions;
    }
    
    /**
     * @description Get all unique Employee Names for dropdown filter
     * @return List<Map<String, Object>> List of employee names with label and value
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmployeeNames() {
        List<Map<String, Object>> employeeNameOptions = new List<Map<String, Object>>();
        
        try {
            System.debug('=== FETCHING EMPLOYEE NAMES FOR DROPDOWN ===');
            
            // Query all active users
            List<User> users = [
                SELECT Id, Name, Employee_IDs__c, Department
                FROM User 
                WHERE IsActive = true
                ORDER BY Name ASC
                LIMIT 1000
            ];
            
            System.debug('Active users found: ' + users.size());
            
            for (User u : users) {
                Map<String, Object> option = new Map<String, Object>();
                // Show Employee ID in label if available
                String label = u.Name;
                if (u.Employee_IDs__c != null) {
                    label += ' (' + String.valueOf(u.Employee_IDs__c) + ')';
                }
                option.put('label', label);
                option.put('value', u.Name);
                option.put('employeeId', u.Employee_IDs__c);
                option.put('department', u.Department);
                employeeNameOptions.add(option);
            }
            
            System.debug('✅ Employee Name options created: ' + employeeNameOptions.size());
            
        } catch (Exception e) {
            System.debug('❌ Error fetching Employee Names: ' + e.getMessage());
        }
        
        return employeeNameOptions;
    }
    
    /**
     * @description Get unique departments for filter dropdown
     * @return List<String> List of unique departments
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDepartments() {
        List<String> departments = new List<String>();
        
        try {
            System.debug('=== FETCHING DEPARTMENTS FOR DROPDOWN ===');
            
            // Query unique departments from User object
            List<AggregateResult> results = [
                SELECT Department 
                FROM User 
                WHERE Department != null 
                AND IsActive = true
                GROUP BY Department 
                ORDER BY Department ASC
                LIMIT 500
            ];
            
            for (AggregateResult ar : results) {
                String dept = (String) ar.get('Department');
                if (String.isNotBlank(dept)) {
                    departments.add(dept);
                }
            }
            
            System.debug('✅ Unique Departments Retrieved: ' + departments.size());
            
        } catch (Exception e) {
            System.debug('❌ Error retrieving departments: ' + e.getMessage());
        }
        
        return departments;
    }
    
    /**
     * @description Get employee search suggestions (for autocomplete)
     * @param searchTerm Search term for employee name
     * @return List<Map<String, Object>> List of matching employees
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> searchEmployees(String searchTerm) {
        List<Map<String, Object>> employees = new List<Map<String, Object>>();
        
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return employees;
            }
            
            String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            
            List<User> users = [
                SELECT Id, Name, Email, Employee_IDs__c, Department 
                FROM User 
                WHERE IsActive = true 
                AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)
                ORDER BY Name ASC
                LIMIT 10
            ];
            
            for (User u : users) {
                Map<String, Object> emp = new Map<String, Object>();
                emp.put('userId', u.Id);
                emp.put('name', u.Name);
                emp.put('email', u.Email);
                emp.put('employeeId', u.Employee_IDs__c);
                emp.put('department', u.Department);
                emp.put('label', u.Name + (u.Employee_IDs__c != null ? ' (' + u.Employee_IDs__c + ')' : ''));
                employees.add(emp);
            }
            
        } catch (Exception e) {
            System.debug('Error searching employees: ' + e.getMessage());
        }
        
        return employees;
    }
    
    // ============================================
    // HELPER METHODS
    // ============================================
    
    /**
     * @description Check if current user has admin permission
     * @return Boolean True if user has admin access
     */
    private static Boolean hasAdminPermission() {
        System.debug('✅ Permission Check: Allowing all profiles to access admin view');
        System.debug('Current User Profile: ' + UserInfo.getProfileId());
        System.debug('Current User Name: ' + UserInfo.getName());
        
        return true;
    }
    
    /**
     * @description Get string value from filter params map
     * @param params Filter parameters map
     * @param key Parameter key
     * @return String Parameter value or empty string
     */
    private static String getFilterValue(Map<String, Object> params, String key) {
        if (params == null || !params.containsKey(key)) {
            return '';
        }
        Object value = params.get(key);
        return value != null ? String.valueOf(value).trim() : '';
    }
    
    /**
     * @description Get date value from filter params map
     * @param params Filter parameters map
     * @param key Parameter key
     * @return Date Parameter value or null
     */
    private static Date getDateValue(Map<String, Object> params, String key) {
        if (params == null || !params.containsKey(key)) {
            return null;
        }
        Object value = params.get(key);
        if (value == null) {
            return null;
        }
        try {
            return Date.valueOf(String.valueOf(value));
        } catch (Exception e) {
            System.debug('Error parsing date for key ' + key + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Get integer value from filter params map
     * @param params Filter parameters map
     * @param key Parameter key
     * @param defaultValue Default value if not found
     * @return Integer Parameter value or default
     */
    private static Integer getIntegerValue(Map<String, Object> params, String key, Integer defaultValue) {
        if (params == null || !params.containsKey(key)) {
            return defaultValue;
        }
        Object value = params.get(key);
        if (value == null) {
            return defaultValue;
        }
        try {
            return Integer.valueOf(value);
        } catch (Exception e) {
            System.debug('Error parsing integer for key ' + key + ': ' + e.getMessage());
            return defaultValue;
        }
    }
    
    /**
     * @description Format DateTime to time string (HH:mm a)
     * @param dt DateTime value
     * @return String Formatted time string
     */
    private static String formatDateTime(DateTime dt) {
        if (dt == null) {
            return '--';
        }
        try {
            return dt.format('hh:mm a');
        } catch (Exception e) {
            return dt.format();
        }
    }
    
    /**
     * @description Format hours worked to "HHh MMm" format
     * @param hours Decimal hours value
     * @return String Formatted hours string
     */
    private static String formatHoursWorked(Decimal hours) {
        if (hours == null || hours <= 0) {
            return '00h 00m';
        }
        
        Integer totalMinutes = (hours * 60).intValue();
        Integer h = totalMinutes / 60;
        Integer m = Math.mod(totalMinutes, 60);
        
        return String.format('{0}h {1}m', new List<Object>{
            String.valueOf(h).leftPad(2, '0'),
            String.valueOf(m).leftPad(2, '0')
        });
    }
    
    /**
     * @description Export attendance data to CSV format
     * @param filterParams Filter parameters for export
     * @return String CSV formatted data
     */
    @AuraEnabled
    public static String exportAttendanceToCSV(Map<String, Object> filterParams) {
        try {
            System.debug('=== EXPORTING ATTENDANCE DATA TO CSV ===');
            
            // Get all records without pagination
            filterParams.put('pageSize', 10000);
            filterParams.put('pageNumber', 1);
            
            Map<String, Object> response = getAdminAttendanceRecords(filterParams);
            
            if (!(Boolean) response.get('success')) {
                throw new AuraHandledException('Failed to retrieve records for export');
            }
            
            List<Object> records = (List<Object>) response.get('records');
            
            // Build CSV
            String csv = buildCSVContent(records);
            
            System.debug('✅ CSV export completed: ' + records.size() + ' records');
            
            return csv;
            
        } catch (Exception e) {
            System.debug('❌ CSV Export Error: ' + e.getMessage());
            throw new AuraHandledException('CSV Export failed: ' + e.getMessage());
        }
    }
    
    /**
     * @description Build CSV content from records
     * @param records List of formatted records
     * @return String CSV content
     */
    private static String buildCSVContent(List<Object> records) {
        // CSV Header
        String csv = 'Employee ID,Employee Name,Manager,Department,Date,Check-in Time,Check-out Time,Hours Worked,Location,WFH Approval,WFH Reason\n';
        
        // CSV Rows
        for (Object obj : records) {
            Map<String, Object> record = (Map<String, Object>) obj;
            
            csv += csvEscape(record.get('employeeId')) + ',';
            csv += csvEscape(record.get('employeeName')) + ',';
            csv += csvEscape(record.get('managerName')) + ',';
            csv += csvEscape(record.get('department')) + ',';
            csv += csvEscape(record.get('date')) + ',';
            csv += csvEscape(record.get('checkInTime')) + ',';
            csv += csvEscape(record.get('checkOutTime')) + ',';
            csv += csvEscape(record.get('hoursWorked')) + ',';
            csv += csvEscape(record.get('location')) + ',';
            csv += csvEscape(record.get('wfhApprovalStatusText')) + ',';
            csv += csvEscape(record.get('wfhReason')) + '\n';
        }
        
        return csv;
    }
    
    /**
     * @description Escape CSV special characters
     * @param value Field value
     * @return String Escaped value
     */
    private static String csvEscape(Object value) {
        if (value == null) {
            return '';
        }
        String str = String.valueOf(value);
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
            str = '"' + str.replace('"', '""') + '"';
        }
        return str;
    }
    

    
    /**
 * @description Enhanced Admin Access Controller with Employee Category Check
 * @author Salesforce Consultant
 * @date 2025-01-10
 * @version 3.0 - Added Employee_Category__c based access control
 * 
 * Access Rules:
 * - HR Manager: Full access to Admin Attendance & Admin Leave
 * - HR Team: Full access to Admin Attendance & Admin Leave
 * - All other categories: No access (Access Restricted message)
 */

// Add this method to your existing AdminAttendanceViewController class

/**
 * @description Check if current user has admin access based on Employee_Category__c
 * @param userId User ID to check
 * @return Map containing access status and user details
 */
@AuraEnabled(cacheable=false)
public static Map<String, Object> checkAdminAccess(Id userId) {
    Map<String, Object> accessInfo = new Map<String, Object>();
    
    try {
        System.debug('=== CHECKING ADMIN ACCESS FOR USER ===');
        System.debug('User ID: ' + userId);
        
        // Query user with Employee_Category__c field
        User currentUser = [
            SELECT Id, Name, Email, Employee_Category__c, 
                   Employee_IDs__c, Department, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        System.debug('User Name: ' + currentUser.Name);
        System.debug('Employee Category: ' + currentUser.Employee_Category__c);
        System.debug('Department: ' + currentUser.Department);
        System.debug('Profile: ' + currentUser.Profile.Name);
        
        // Determine access based on Employee_Category__c
        Boolean hasAccess = false;
        String accessLevel = '';
        String categoryType = '';
        
        if (currentUser.Employee_Category__c == 'HR Manager') {
            hasAccess = true;
            accessLevel = 'Full Admin Access';
            categoryType = 'HR Manager';
            
        } else if (currentUser.Employee_Category__c == 'HR Team') {
            hasAccess = true;
            accessLevel = 'Full Admin Access';
            categoryType = 'HR Team (Assistant HR)';
            
        } else {
            hasAccess = false;
            accessLevel = 'No Access';
            categoryType = currentUser.Employee_Category__c != null ? 
                          currentUser.Employee_Category__c : 'Not Set';
        }
        
        // Build response
        accessInfo.put('hasAccess', hasAccess);
        accessInfo.put('userName', currentUser.Name);
        accessInfo.put('userEmail', currentUser.Email);
        accessInfo.put('employeeCategory', currentUser.Employee_Category__c);
        accessInfo.put('categoryType', categoryType);
        accessInfo.put('accessLevel', accessLevel);
        accessInfo.put('department', currentUser.Department);
        accessInfo.put('profileName', currentUser.Profile.Name);
        accessInfo.put('employeeId', currentUser.Employee_IDs__c);
        
        // Access message
        if (hasAccess) {
            accessInfo.put('message', 'Access granted as ' + categoryType);
        } else {
            accessInfo.put('message', 'Access restricted. Only HR Manager and HR Team members can view this section.');
        }
        
        System.debug('✅ Access Check Result: ' + (hasAccess ? 'GRANTED' : 'DENIED'));
        System.debug('Access Level: ' + accessLevel);
        System.debug('Category Type: ' + categoryType);
        
    } catch (Exception e) {
        System.debug('❌ Error checking admin access: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        
        // Default to no access on error
        accessInfo.put('hasAccess', false);
        accessInfo.put('message', 'Error checking access permissions');
        accessInfo.put('error', e.getMessage());
    }
    
    return accessInfo;
}

/**
 * @description Legacy method - Now uses Employee_Category__c instead of Admin__c checkbox
 * @param userId User ID to check
 * @return Boolean True if user is HR Manager or HR Team
 */
@AuraEnabled(cacheable=false)
public static Boolean isCurrentUserAdmin(Id userId) {
    try {
        User u = [
            SELECT Employee_Category__c
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        // Check if user is HR Manager or HR Team
        return (u.Employee_Category__c == 'HR Manager' || 
                u.Employee_Category__c == 'HR Team');
                
    } catch (Exception e) {
        System.debug('Error in isCurrentUserAdmin: ' + e.getMessage());
        return false;
    }
}

/**
 * @description Get detailed access information for UI display
 * @param userId User ID to check
 * @return Map containing detailed access info
 */
@AuraEnabled(cacheable=false)
public static Map<String, Object> getAdminAccessDetails(Id userId) {
    Map<String, Object> details = new Map<String, Object>();
    
    try {
        User u = [
            SELECT Name, Email, Employee_Category__c, Employee_IDs__c, 
                   Department, Profile.Name, ManagerId, Manager.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        Boolean isHRManager = u.Employee_Category__c == 'HR Manager';
        Boolean isHRTeam = u.Employee_Category__c == 'HR Team';
        Boolean hasAdminAccess = isHRManager || isHRTeam;
        
        details.put('hasAccess', hasAdminAccess);
        details.put('isHRManager', isHRManager);
        details.put('isHRTeam', isHRTeam);
        details.put('userName', u.Name);
        details.put('userEmail', u.Email);
        details.put('employeeCategory', u.Employee_Category__c);
        details.put('employeeId', u.Employee_IDs__c);
        details.put('department', u.Department);
        details.put('profileName', u.Profile.Name);
        details.put('managerName', u.Manager?.Name);
        
        // Determine access message
        if (isHRManager) {
            details.put('accessMessage', 'Full Admin Access - HR Manager');
            details.put('accessIcon', 'utility:shield');
            details.put('accessVariant', 'success');
        } else if (isHRTeam) {
            details.put('accessMessage', 'Full Admin Access - HR Team');
            details.put('accessIcon', 'utility:user');
            details.put('accessVariant', 'success');
        } else {
            details.put('accessMessage', 'Access Restricted - Not an HR Admin');
            details.put('accessIcon', 'utility:block_visitor');
            details.put('accessVariant', 'error');
        }
        
        // List of allowed categories
        List<String> allowedCategories = new List<String>{'HR Manager', 'HR Team'};
        details.put('allowedCategories', allowedCategories);
        
        // List of restricted categories
        List<String> restrictedCategories = new List<String>{
            'Management', 
            'On-Role(Manager)', 
            'On-Role(Team Member)', 
            'Intern-Stipend', 
            'Unpaid Intern'
        };
        details.put('restrictedCategories', restrictedCategories);
        
    } catch (Exception e) {
        System.debug('Error getting admin access details: ' + e.getMessage());
        details.put('hasAccess', false);
        details.put('error', e.getMessage());
    }
    
    return details;
}
    
    
    
/**
 * @description Search employees for autocomplete (lightweight version)
 * @param searchType Type of search: 'employeeId' or 'name'
 * @param searchTerm Search term entered by user
 * @return List of matching employees with minimal data
 */
@AuraEnabled(cacheable=true)
public static List<Map<String, Object>> searchEmployeesLightweight(String searchType, String searchTerm) {
    List<Map<String, Object>> employees = new List<Map<String, Object>>();
    
    try {
        if (String.isBlank(searchTerm) || searchTerm.length() < 1) {
            return employees;
        }
        
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<User> users = new List<User>();
        
        if (searchType == 'employeeId') {
            // Search by Employee ID (number field)
            String numericSearch = searchTerm.replaceAll('[^0-9]', '');
            
            if (String.isNotBlank(numericSearch)) {
                String empIdNum = String.valueOf(numericSearch);
                users = [
                    SELECT Id, Name, Employee_IDs__c, Department, Email
                    FROM User
                    WHERE  IsActive = true
                    AND (Employee_IDs__c = :empIdNum OR Name LIKE :searchPattern)
                    ORDER BY Employee_IDs__c ASC NULLS LAST
                    LIMIT 10
                ];
            } else {
                users = [
                    SELECT Id, Name, Employee_IDs__c, Department, Email
                    FROM User
                    WHERE IsActive = true
                    AND Name LIKE :searchPattern
                    ORDER BY Name ASC
                    LIMIT 10
                ];
            }
        } else if (searchType == 'name') {
            // Search by Name
            users = [
                SELECT Id, Name, Employee_IDs__c, Department, Email
                FROM User
                WHERE IsActive = true
                AND Name LIKE :searchPattern
                ORDER BY Name ASC
                LIMIT 10
            ];
        }
        
        // Format results
        for (User u : users) {
            Map<String, Object> emp = new Map<String, Object>();
            emp.put('Id', u.Id);
            emp.put('Name', u.Name);
            emp.put('Employee_IDs__c', u.Employee_IDs__c);
            emp.put('Department', u.Department);
            emp.put('Email', u.Email);
            employees.add(emp);
        }
        
        System.debug('Search results: ' + employees.size() + ' employees found');
        
    } catch (Exception e) {
        System.debug('Error searching employees: ' + e.getMessage());
    }
    
    return employees;
}

}