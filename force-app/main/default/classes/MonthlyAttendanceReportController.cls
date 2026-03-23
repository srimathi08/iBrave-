/**
 * @description Comprehensive Monthly Attendance & Leave Report Controller
 * @author Salesforce Consultant
 * @date 2025-11-11
 * @version 3.2 - Added Days Payable calculation
 */
public with sharing class MonthlyAttendanceReportController {
    
    /**
     * @description Generate complete monthly attendance report for all employees
     */
    @AuraEnabled
    public static Map<String, Object> generateMonthlyReport(
        Integer month, 
        Integer year,
        String departmentFilter,
        String managerFilter
    ) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== GENERATING MONTHLY ATTENDANCE REPORT (v3.2 - Days Payable) ===');
            System.debug('Month: ' + month + ', Year: ' + year);
            System.debug('Department Filter: ' + departmentFilter);
            System.debug('Manager Filter: ' + managerFilter);
            
            // Validate input
            if (month == null || month < 1 || month > 12) {
                throw new AuraHandledException('Invalid month. Must be between 1 and 12.');
            }
            
            if (year == null || year < 2000 || year > 2100) {
                throw new AuraHandledException('Invalid year.');
            }
            
            // Calculate date range for the month
            Date monthStart = Date.newInstance(year, month, 1);
            Date monthEnd = monthStart.addMonths(1).addDays(-1);
            Integer totalDaysInMonth = monthEnd.day();
            
            System.debug('Date Range: ' + monthStart + ' to ' + monthEnd);
            System.debug('Total Days in Month: ' + totalDaysInMonth);
            
            // Get all active employees with filters
            List<User> employees = getFilteredEmployeesWithDOJ(departmentFilter, managerFilter);
            System.debug('Total Employees Found: ' + employees.size());
            
            if (employees.isEmpty()) {
                response.put('success', true);
                response.put('employees', new List<Object>());
                response.put('totalEmployees', 0);
                response.put('message', 'No employees found matching the filters');
                return response;
            }
            
            // Get holidays for the month
            Map<Date, Holiday__c> holidayMap = getHolidaysForMonth(monthStart, monthEnd);
            System.debug('Holidays Found: ' + holidayMap.size());
            
            // Get all attendance records for the month
            Set<Id> employeeIds = new Set<Id>();
            for (User emp : employees) {
                employeeIds.add(emp.Id);
            }
            
            Map<String, Employee_Attendance__c> attendanceMap = getAttendanceRecords(
                employeeIds, 
                monthStart, 
                monthEnd
            );
            System.debug('Attendance Records Found: ' + attendanceMap.size());
            
            // Get all approved leave requests for the month
            Map<String, Leave_Request__c> leaveMap = getApprovedLeaveRequests(
                employeeIds, 
                monthStart, 
                monthEnd
            );
            System.debug('Approved Leave Requests Found: ' + leaveMap.size());
            
            // Generate date headers
            List<Map<String, Object>> dateHeaders = generateDateHeaders(
                monthStart, 
                totalDaysInMonth, 
                holidayMap
            );
            
            // Calculate working days and weekends
            Map<String, Integer> monthStats = calculateMonthStatistics(
                monthStart, 
                totalDaysInMonth, 
                holidayMap
            );
            
            // Process each employee's data
            List<Map<String, Object>> employeeReportData = new List<Map<String, Object>>();
            
            for (User employee : employees) {
                Map<String, Object> employeeData = processEmployeeAttendance(
                    employee,
                    monthStart,
                    totalDaysInMonth,
                    attendanceMap,
                    leaveMap,
                    holidayMap
                );
                employeeReportData.add(employeeData);
            }
            
            // Build success response
            response.put('success', true);
            response.put('employees', employeeReportData);
            response.put('dateHeaders', dateHeaders);
            response.put('totalEmployees', employees.size());
            response.put('totalWorkingDays', monthStats.get('workingDays'));
            response.put('totalHolidays', monthStats.get('holidays'));
            response.put('totalWeekends', monthStats.get('weekends'));
            response.put('totalDaysInMonth', totalDaysInMonth);
            response.put('monthName', getMonthName(month));
            response.put('year', year);
            response.put('message', 'Report generated successfully');
            
            System.debug('✅ Report Generated Successfully');
            System.debug('Total Employees in Report: ' + employeeReportData.size());
            
        } catch (Exception e) {
            System.debug('❌ Error generating report: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            
            response.put('success', false);
            response.put('error', e.getMessage());
            response.put('errorType', e.getTypeName());
            response.put('stackTrace', e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * @description Get filtered list of active employees with Date of Joining
     * ✅ USES: Date_of_Joining__c field from User object
     */
    private static List<User> getFilteredEmployeesWithDOJ(String departmentFilter, String managerFilter) {
        String query = 'SELECT Id, Name, Email, Department, ManagerId, ' +
                       'Employee_IDs__c, Date_of_Joining__c ' +
                       'FROM User ' +
                       'WHERE IsActive = true ';
        
        // Add department filter
        if (String.isNotBlank(departmentFilter)) {
            query += 'AND Department = :departmentFilter ';
        }
        
        // Add manager filter
        if (String.isNotBlank(managerFilter)) {
            query += 'AND ManagerId = :managerFilter ';
        }
        
        query += 'ORDER BY Name ASC LIMIT 1000';
        
        System.debug('Employee Query: ' + query);
        
        return Database.query(query);
    }
    
    /**
     * @description Get holidays for the specified month
     */
    private static Map<Date, Holiday__c> getHolidaysForMonth(Date monthStart, Date monthEnd) {
        Map<Date, Holiday__c> holidayMap = new Map<Date, Holiday__c>();
        
        try {
            List<Holiday__c> holidays = [
                SELECT Id, Name, Holiday_Date__c, Icon_Name__c, Description__c
                FROM Holiday__c
                WHERE Holiday_Date__c >= :monthStart 
                AND Holiday_Date__c <= :monthEnd
                ORDER BY Holiday_Date__c ASC
            ];
            
            for (Holiday__c holiday : holidays) {
                holidayMap.put(holiday.Holiday_Date__c, holiday);
            }
        } catch (Exception e) {
            System.debug('Warning: Could not load holidays - ' + e.getMessage());
            // Continue without holidays if object doesn't exist
        }
        
        return holidayMap;
    }
    
    /**
     * @description Get all attendance records for employees in the month
     * @return Map with key format: 'employeeId_yyyy-MM-dd'
     */
    private static Map<String, Employee_Attendance__c> getAttendanceRecords(
        Set<Id> employeeIds, 
        Date monthStart, 
        Date monthEnd
    ) {
        Map<String, Employee_Attendance__c> attendanceMap = new Map<String, Employee_Attendance__c>();
        
        try {
            List<Employee_Attendance__c> attendanceRecords = [
                SELECT Id, Employee_Name__c, Date__c, Check_In_Time__c, Check_Out_Time__c,
                       Status__c, Hours_Worked__c, Work_Location__c,
                       Notes__c, Branch__c, Branch__r.Branch_Name__c, Branch__r.City__c
                FROM Employee_Attendance__c
                WHERE Employee_Name__c IN :employeeIds
                AND Date__c >= :monthStart
                AND Date__c <= :monthEnd
                ORDER BY Date__c ASC
            ];
            
            for (Employee_Attendance__c att : attendanceRecords) {
                String key = att.Employee_Name__c + '_' + att.Date__c.format();
                attendanceMap.put(key, att);
            }
            
            System.debug('Attendance Map Size: ' + attendanceMap.size());
        } catch (Exception e) {
            System.debug('Error loading attendance records: ' + e.getMessage());
            // Return empty map if there's an error
        }
        
        return attendanceMap;
    }
    
    /**
     * @description Get all approved leave requests for employees in the month
     * @return Map with key format: 'employeeId_yyyy-MM-dd'
     */
    private static Map<String, Leave_Request__c> getApprovedLeaveRequests(
        Set<Id> employeeIds,
        Date monthStart,
        Date monthEnd
    ) {
        Map<String, Leave_Request__c> leaveMap = new Map<String, Leave_Request__c>();
        
        try {
            List<Leave_Request__c> leaveRequests = [
                SELECT Id, Employee__c, Start_Date__c, End_Date__c, Status__c,
                       Leave_Type__c, Leave_Type__r.Leave_Code__c, Leave_Type__r.Leave_Type_Name__c,
                       Is_Half_Day__c, Half_Day_Type__c, Total_Days__c
                FROM Leave_Request__c
                WHERE Employee__c IN :employeeIds
                AND Status__c = 'Approved'
                AND (
                    (Start_Date__c >= :monthStart AND Start_Date__c <= :monthEnd)
                    OR
                    (End_Date__c >= :monthStart AND End_Date__c <= :monthEnd)
                    OR
                    (Start_Date__c < :monthStart AND End_Date__c > :monthEnd)
                )
                ORDER BY Start_Date__c ASC
            ];
            
            // Map each leave day to the employee
            for (Leave_Request__c leave : leaveRequests) {
                Date currentDate = leave.Start_Date__c;
                Date endDate = leave.End_Date__c;
                
                // Ensure we only process dates within the month
                if (currentDate < monthStart) {
                    currentDate = monthStart;
                }
                if (endDate > monthEnd) {
                    endDate = monthEnd;
                }
                
                // Loop through each day of the leave
                while (currentDate <= endDate) {
                    String key = leave.Employee__c + '_' + currentDate.format();
                    leaveMap.put(key, leave);
                    currentDate = currentDate.addDays(1);
                }
            }
            
            System.debug('Leave Map Size: ' + leaveMap.size());
        } catch (Exception e) {
            System.debug('Error loading leave requests: ' + e.getMessage());
            // Return empty map if there's an error
        }
        
        return leaveMap;
    }
    
    /**
     * @description Generate date headers for the table
     */
    private static List<Map<String, Object>> generateDateHeaders(
        Date monthStart,
        Integer totalDays,
        Map<Date, Holiday__c> holidayMap
    ) {
        List<Map<String, Object>> headers = new List<Map<String, Object>>();
        
        for (Integer i = 1; i <= totalDays; i++) {
            Date currentDate = monthStart.addDays(i - 1);
            DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(12, 0, 0, 0));
            String dayOfWeek = dt.format('EEE');
            
            Boolean isWeekend = (dayOfWeek == 'Sat' || dayOfWeek == 'Sun');
            Boolean isHoliday = holidayMap.containsKey(currentDate);
            
            Map<String, Object> header = new Map<String, Object>();
            header.put('day', dayOfWeek);
            header.put('number', i);
            header.put('date', currentDate);
            header.put('dateKey', currentDate.format());
            header.put('value', i);
            header.put('isWeekend', isWeekend);
            header.put('isHoliday', isHoliday);
            
            if (isHoliday) {
                header.put('holidayName', holidayMap.get(currentDate).Name);
            }
            
            headers.add(header);
        }
        
        return headers;
    }
    
    /**
     * @description Calculate month statistics (working days, weekends, holidays)
     */
    private static Map<String, Integer> calculateMonthStatistics(
        Date monthStart,
        Integer totalDays,
        Map<Date, Holiday__c> holidayMap
    ) {
        Integer workingDays = 0;
        Integer weekends = 0;
        Integer holidays = 0;
        
        for (Integer i = 1; i <= totalDays; i++) {
            Date currentDate = monthStart.addDays(i - 1);
            DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(12, 0, 0, 0));
            String dayOfWeek = dt.format('EEE');
            
            Boolean isWeekend = (dayOfWeek == 'Sat' || dayOfWeek == 'Sun');
            Boolean isHoliday = holidayMap.containsKey(currentDate);
            
            if (isWeekend) {
                weekends++;
            } else if (isHoliday) {
                holidays++;
            } else {
                workingDays++;
            }
        }
        
        Map<String, Integer> stats = new Map<String, Integer>();
        stats.put('workingDays', workingDays);
        stats.put('weekends', weekends);
        stats.put('holidays', holidays);
        
        return stats;
    }
    
    /**
     * @description Process individual employee's attendance for the month
     * ✅ UPDATED v3.2: Added Days Payable calculation
     * Days Payable = Present + Holidays + Weekends + Valid Leaves (excluding LOP)
     */
    private static Map<String, Object> processEmployeeAttendance(
        User employee,
        Date monthStart,
        Integer totalDays,
        Map<String, Employee_Attendance__c> attendanceMap,
        Map<String, Leave_Request__c> leaveMap,
        Map<Date, Holiday__c> holidayMap
    ) {
        Map<String, Object> employeeData = new Map<String, Object>();
        
        // Get manager name if manager exists
        String managerName = 'N/A';
        if (employee.ManagerId != null) {
            try {
                User manager = [SELECT Name FROM User WHERE Id = :employee.ManagerId LIMIT 1];
                managerName = manager.Name;
            } catch (Exception e) {
                System.debug('Could not load manager for: ' + employee.Name);
            }
        }
        
        // ✅ Employee basic info
        employeeData.put('Id', employee.Id);
        employeeData.put('employeeId', employee.Employee_IDs__c != null ? 
            String.valueOf(employee.Employee_IDs__c) : 'N/A');
        employeeData.put('employeeName', employee.Name);
        employeeData.put('managerName', managerName);
        
        // ✅ Date of Joining from User.Date_of_Joining__c
        if (employee.Date_of_Joining__c != null) {
            employeeData.put('dateOfJoining', employee.Date_of_Joining__c.format());
        } else {
            employeeData.put('dateOfJoining', 'N/A');
        }
        
        // ✅ Determine primary work location with branch details
        String workLocationDetails = determineWorkLocation(employee.Id, attendanceMap, monthStart, totalDays);
        employeeData.put('workLocationDetails', workLocationDetails);
        
        // Initialize counters
        Integer presentDays = 0;
        Integer absentDays = 0;
        Integer totalLeaves = 0;
        Integer workingDaysCount = 0;
        Integer holidayCount = 0;
        Integer weekendCount = 0;
        
        // ✅ NEW v3.2: Days Payable calculation
        Integer daysPayable = 0;
        Integer lopDays = 0; // Track Loss of Pay days separately
        
        // Process daily attendance
        List<Map<String, Object>> dailyAttendance = new List<Map<String, Object>>();
        
        for (Integer i = 1; i <= totalDays; i++) {
            Date currentDate = monthStart.addDays(i - 1);
            String dateKey = currentDate.format();
            String attKey = employee.Id + '_' + dateKey;
            
            DateTime dt = DateTime.newInstance(currentDate, Time.newInstance(12, 0, 0, 0));
            String dayOfWeek = dt.format('EEE');
            
            Boolean isWeekend = (dayOfWeek == 'Sat' || dayOfWeek == 'Sun');
            Boolean isHoliday = holidayMap.containsKey(currentDate);
            
            Map<String, Object> dayData = new Map<String, Object>();
            dayData.put('dateKey', dateKey);
            dayData.put('date', currentDate);
            dayData.put('isWeekend', isWeekend);
            dayData.put('isHoliday', isHoliday);
            
            String statusCode = '';
            Boolean isPayable = false; // ✅ Track if day is payable
            
            // Determine status
            if (isWeekend) {
                statusCode = 'W';
                weekendCount++;
                isPayable = true; // ✅ Weekends are payable
                daysPayable++;
            } else if (isHoliday) {
                statusCode = 'H';
                holidayCount++;
                isPayable = true; // ✅ Holidays are payable
                daysPayable++;
            } else {
                // Check if employee has attendance record
                Employee_Attendance__c attRecord = attendanceMap.get(attKey);
                Leave_Request__c leaveRecord = leaveMap.get(attKey);
                
                if (attRecord != null && attRecord.Check_In_Time__c != null) {
                    // Present
                    if (attRecord.Status__c == 'Late') {
                        statusCode = 'P*'; // Present but late
                        presentDays++;
                    } else {
                        statusCode = 'P';
                        presentDays++;
                    }
                    isPayable = true; // ✅ Present days are payable
                    daysPayable++;
                } else if (leaveRecord != null) {
                    // On approved leave
                    String leaveCode = leaveRecord.Leave_Type__r.Leave_Code__c;
                    String leaveTypeName = leaveRecord.Leave_Type__r.Leave_Type_Name__c;
                    
                    // ✅ Check if it's Loss of Pay leave
                    Boolean isLOP = (leaveTypeName != null && 
                                    (leaveTypeName.containsIgnoreCase('Loss of Pay') || 
                                     leaveTypeName.containsIgnoreCase('LOP') ||
                                     leaveTypeName.containsIgnoreCase('Leave Without Pay') ||
                                     leaveTypeName.containsIgnoreCase('LWP') ||
                                     leaveCode == 'LOP' ||
                                     leaveCode == 'LWP'));
                    
                    // Check if it's a half day leave
                    if (leaveRecord.Is_Half_Day__c == true) {
                        statusCode = leaveCode + '-H'; // e.g., CL-H for half day casual leave
                    } else {
                        statusCode = leaveCode;
                    }
                    
                    totalLeaves++; // ✅ Count all leaves together
                    
                    // ✅ Only count as payable if NOT Loss of Pay
                    if (!isLOP) {
                        isPayable = true;
                        daysPayable++;
                    } else {
                        lopDays++; // Track LOP separately
                        isPayable = false;
                    }
                } else {
                    // Absent
                    statusCode = 'A';
                    absentDays++;
                    isPayable = false; // ✅ Absent days are NOT payable
                }
                
                workingDaysCount++;
            }
            
            dayData.put('statusCode', statusCode);
            dayData.put('isPayable', isPayable); // ✅ Add payable flag
            dailyAttendance.add(dayData);
        }
        
        // Add daily attendance array
        employeeData.put('dailyAttendance', dailyAttendance);
        
        // ✅ Add summary data - v3.2 with Days Payable
        employeeData.put('totalDays', totalDays);
        employeeData.put('workingDays', workingDaysCount);
        employeeData.put('presentDays', presentDays);
        employeeData.put('absentDays', absentDays);
        employeeData.put('totalLeaves', totalLeaves);
        employeeData.put('holidayCount', holidayCount);
        employeeData.put('weekendCount', weekendCount);
        employeeData.put('daysPayable', daysPayable); // ✅ NEW: Days Payable
        employeeData.put('lopDays', lopDays); // ✅ NEW: Loss of Pay days
        
        System.debug('Employee: ' + employee.Name + 
                     ' | Days Payable: ' + daysPayable + 
                     ' (Present: ' + presentDays + 
                     ' + Holidays: ' + holidayCount + 
                     ' + Weekends: ' + weekendCount + 
                     ' + Valid Leaves: ' + (totalLeaves - lopDays) + ')' +
                     ' | LOP Days: ' + lopDays);
        
        return employeeData;
    }
    
    /**
     * @description Determine employee's primary work location
     * ✅ Shows "Work from Home" or "Work from Office - Branch Name (City)"
     */
    private static String determineWorkLocation(
        Id employeeId,
        Map<String, Employee_Attendance__c> attendanceMap,
        Date monthStart,
        Integer totalDays
    ) {
        Map<String, Integer> locationCount = new Map<String, Integer>();
        
        // Count each work location type
        for (Integer i = 1; i <= totalDays; i++) {
            Date currentDate = monthStart.addDays(i - 1);
            String key = employeeId + '_' + currentDate.format();
            
            Employee_Attendance__c att = attendanceMap.get(key);
            
            if (att != null && att.Work_Location__c != null) {
                String location = att.Work_Location__c;
                String locationDisplay = '';
                
                if (location == 'Work from Home') {
                    locationDisplay = 'Work from Home';
                } else if (location == 'Work from Office') {
                    if (att.Branch__c != null && att.Branch__r != null) {
                        String branchName = att.Branch__r.Branch_Name__c;
                        String branchCity = att.Branch__r.City__c;
                        
                        if (String.isNotBlank(branchCity)) {
                            locationDisplay = 'Work from Office - ' + branchName + ' (' + branchCity + ')';
                        } else {
                            locationDisplay = 'Work from Office - ' + branchName;
                        }
                    } else {
                        locationDisplay = 'Work from Office';
                    }
                } else {
                    locationDisplay = location; // Client Place, Field Work, etc.
                }
                
                // Count occurrences
                Integer count = locationCount.containsKey(locationDisplay) ? 
                    locationCount.get(locationDisplay) : 0;
                locationCount.put(locationDisplay, count + 1);
            }
        }
        
        // Find most frequent location
        String mostFrequentLocation = 'N/A';
        Integer maxCount = 0;
        
        for (String loc : locationCount.keySet()) {
            Integer count = locationCount.get(loc);
            if (count > maxCount) {
                maxCount = count;
                mostFrequentLocation = loc;
            }
        }
        
        return mostFrequentLocation;
    }
    
    /**
     * @description Get list of departments
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDepartments() {
        Set<String> deptSet = new Set<String>();
        
        try {
            List<User> users = [
                SELECT Department 
                FROM User 
                WHERE IsActive = true 
                AND Department != null
                LIMIT 1000
            ];
            
            for (User u : users) {
                if (String.isNotBlank(u.Department)) {
                    deptSet.add(u.Department);
                }
            }
        } catch (Exception e) {
            System.debug('Error loading departments: ' + e.getMessage());
        }
        
        List<String> departments = new List<String>(deptSet);
        departments.sort();
        
        return departments;
    }
    
    /**
     * @description Get list of managers
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getManagers() {
        List<Map<String, String>> managers = new List<Map<String, String>>();
        
        try {
            // First, get all unique manager IDs
            Set<Id> managerIds = new Set<Id>();
            
            List<User> allUsers = [
                SELECT ManagerId 
                FROM User 
                WHERE IsActive = true 
                AND ManagerId != null
                LIMIT 5000
            ];
            
            for (User u : allUsers) {
                if (u.ManagerId != null) {
                    managerIds.add(u.ManagerId);
                }
            }
            
            // Then query the manager details
            List<User> managerUsers = [
                SELECT Id, Name
                FROM User
                WHERE Id IN :managerIds
                AND IsActive = true
                ORDER BY Name ASC
                LIMIT 200
            ];
            
            for (User mgr : managerUsers) {
                Map<String, String> managerMap = new Map<String, String>();
                managerMap.put('Id', mgr.Id);
                managerMap.put('Name', mgr.Name);
                managers.add(managerMap);
            }
        } catch (Exception e) {
            System.debug('Error loading managers: ' + e.getMessage());
        }
        
        return managers;
    }
    
    /**
     * @description Export report to Excel format
     * ✅ UPDATED v3.2: Includes Days Payable column
     */
    @AuraEnabled
    public static Map<String, Object> exportReportToExcel(
        Integer month,
        Integer year,
        String departmentFilter,
        String managerFilter
    ) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            System.debug('=== EXPORTING REPORT TO EXCEL (v3.2) ===');
            
            // Generate report data
            Map<String, Object> reportData = generateMonthlyReport(
                month, 
                year, 
                departmentFilter, 
                managerFilter
            );
            
            if (reportData.get('success') != true) {
                throw new AuraHandledException('Failed to generate report data');
            }
            
            // Build Excel XML
            String excelXML = buildExcelXML(reportData);
            
            // Convert to Base64
            Blob excelBlob = Blob.valueOf(excelXML);
            String base64Data = EncodingUtil.base64Encode(excelBlob);
            
            // Build file name
            String fileName = 'Attendance_Report_' + 
                            getMonthName(month) + '_' + 
                            year + '_' + 
                            DateTime.now().format('yyyyMMdd_HHmmss') + 
                            '.xls';
            
            response.put('success', true);
            response.put('fileData', base64Data);
            response.put('fileName', fileName);
            response.put('message', 'Excel file generated successfully');
            
            System.debug('✅ Excel Export Successful: ' + fileName);
            
        } catch (Exception e) {
            System.debug('❌ Excel Export Error: ' + e.getMessage());
            response.put('success', false);
            response.put('error', e.getMessage());
        }
        
        return response;
    }
    
    /**
     * @description Build Excel XML from report data
     * ✅ UPDATED v3.2: Includes Days Payable column
     */
    private static String buildExcelXML(Map<String, Object> reportData) {
        String xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
        xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ';
        xml += 'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">';
        xml += '<Worksheet ss:Name="Attendance Report"><Table>';
        
        // Get data
        List<Object> employees = (List<Object>) reportData.get('employees');
        List<Object> dateHeaders = (List<Object>) reportData.get('dateHeaders');
        
        // Header Row
        xml += '<Row>';
        xml += '<Cell><Data ss:Type="String">Emp ID</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Employee Name</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">DOJ</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Work Location</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Reporting Manager</Data></Cell>';
        
        // Date columns
        for (Object headerObj : dateHeaders) {
            Map<String, Object> header = (Map<String, Object>) headerObj;
            xml += '<Cell><Data ss:Type="String">' + header.get('number') + '</Data></Cell>';
        }
        
        // Summary columns
        xml += '<Cell><Data ss:Type="String">Total Days</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Working Days</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Present</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Absent</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Leaves</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Holidays</Data></Cell>';
        xml += '<Cell><Data ss:Type="String">Days Payable</Data></Cell>'; // ✅ NEW
        xml += '<Cell><Data ss:Type="String">LOP Days</Data></Cell>'; // ✅ NEW
        xml += '</Row>';
        
        // Data Rows
        for (Object empObj : employees) {
            Map<String, Object> emp = (Map<String, Object>) empObj;
            
            xml += '<Row>';
            xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(emp.get('employeeId'))) + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(emp.get('employeeName'))) + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(emp.get('dateOfJoining'))) + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(emp.get('workLocationDetails'))) + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(emp.get('managerName'))) + '</Data></Cell>';
            
            // Daily attendance
            List<Object> dailyAtt = (List<Object>) emp.get('dailyAttendance');
            for (Object dayObj : dailyAtt) {
                Map<String, Object> day = (Map<String, Object>) dayObj;
                xml += '<Cell><Data ss:Type="String">' + escapeXML(String.valueOf(day.get('statusCode'))) + '</Data></Cell>';
            }
            
            // Summary
            xml += '<Cell><Data ss:Type="Number">' + emp.get('totalDays') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('workingDays') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('presentDays') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('absentDays') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('totalLeaves') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('holidayCount') + '</Data></Cell>';
            xml += '<Cell><Data ss:Type="Number">' + emp.get('daysPayable') + '</Data></Cell>'; // ✅ NEW
            xml += '<Cell><Data ss:Type="Number">' + emp.get('lopDays') + '</Data></Cell>'; // ✅ NEW
            xml += '</Row>';
        }
        
        xml += '</Table></Worksheet></Workbook>';
        
        return xml;
    }
    
    /**
     * @description Escape XML special characters
     */
    private static String escapeXML(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        
        return input
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
    
    /**
     * @description Get month name from number
     */
    private static String getMonthName(Integer month) {
        List<String> months = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        
        if (month >= 1 && month <= 12) {
            return months[month - 1];
        }
        
        return 'Unknown';
    }
}