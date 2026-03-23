public with sharing class AttendanceSummaryController {
    
   	/**
 * ✅ UPDATED: Get comprehensive monthly summary excluding weekends
 * @param userId Current user ID
 * @return Map containing monthly summary statistics
 */
@AuraEnabled
public static Map<String, Object> getMonthlySummary(String userId) {
    Map<String, Object> summary = new Map<String, Object>();
    
    try {
        Date today = Date.today();
        Date monthStart = today.toStartOfMonth();
        
        // ✅ Calculate weekdays only (excluding Saturdays and Sundays)
        Integer totalWeekdays = calculateWeekdaysBetween(monthStart, today);
        
        // ✅ Query all attendance records (including multiple sessions per day)
        List<Employee_Attendance__c> monthlyRecords = [
            SELECT Id, Date__c, Check_In_Time__c, Check_Out_Time__c, 
                   Hours_Worked__c, Status__c, Employee_Name__c,
                   Session_Number__c, Is_Multiple_Session__c,
                   Is_OD_Request__c, OD_Approval_Status__c, 
                   Work_Location__c, WFH_Approval_Status__c
            FROM Employee_Attendance__c 
            WHERE Employee_Name__c = :userId 
            AND Date__c >= :monthStart 
            AND Date__c <= :today
            ORDER BY Date__c ASC, Session_Number__c ASC
        ];
        
        // ✅ Query WFH requests to check true status (requested by user)
        List<Work_from_home_Request__c> wfhRequests = [
            SELECT Start_Date__c, End_Date__c, Status__c
            FROM Work_from_home_Request__c
            WHERE Employee__c = :userId
            AND ((Start_Date__c >= :monthStart AND Start_Date__c <= :today)
                 OR (End_Date__c >= :monthStart AND End_Date__c <= :today))
        ];

        // ✅ Query Approved Leaves for the breakdown
        List<Leave_Request__c> approvedLeaves = [
            SELECT Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND Status__c = 'Approved'
            AND Is_Active__c = true
            AND ((Start_Date__c >= :monthStart AND Start_Date__c <= :today)
                 OR (End_Date__c >= :monthStart AND End_Date__c <= :today))
        ];

        // ✅ Calculate Metrics with OD/WFH awareness and Leave breakdown
        Map<String, Integer> calculations = calculateMonthlyMetricsFiltered(
            monthlyRecords, 
            wfhRequests,
            approvedLeaves,
            totalWeekdays,
            monthStart,
            today
        );
        
        Decimal totalHours = calculateTotalHoursAllSessions(monthlyRecords);
        Decimal avgHoursPerDay = calculateAverageHoursPerDay(monthlyRecords);
        Decimal attendanceRate = calculateAttendanceRate(calculations.get('presentDays'), totalWeekdays);
        
        String monthName = getMonthName(monthStart);
        
        summary.put('success', true);
        summary.put('presentDays', calculations.get('presentDays'));
        summary.put('lateDays', calculations.get('lateDays'));
        summary.put('absentDays', calculations.get('absentDays'));
        summary.put('approvedLeaveDays', calculations.get('approvedLeaveDays'));
        summary.put('lopDays', calculations.get('lopDays'));
        summary.put('totalHours', totalHours.setScale(1).toPlainString());
        summary.put('avgHoursPerDay', avgHoursPerDay.setScale(1).toPlainString());
        summary.put('attendanceRate', attendanceRate.setScale(1).toPlainString());
        summary.put('totalWorkingDays', totalWeekdays);
        summary.put('monthName', monthName);
        summary.put('recordsFound', monthlyRecords.size());
        summary.put('totalSessions', monthlyRecords.size());
        
        System.debug('Monthly Summary - Total Weekdays: ' + totalWeekdays);
        System.debug('Monthly Summary - Sessions: ' + monthlyRecords.size());
        
    } catch (Exception e) {
        System.debug('Error calculating monthly summary: ' + e.getMessage());
        summary.put('success', false);
        summary.put('error', e.getMessage());
        
        // Return default values
        summary.put('presentDays', 0);
        summary.put('lateDays', 0);
        summary.put('absentDays', 0);
        summary.put('totalHours', '0.0');
        summary.put('avgHoursPerDay', '0.0');
        summary.put('attendanceRate', '0');
        summary.put('totalWorkingDays', 0);
        summary.put('monthName', getMonthName(Date.today()));
        summary.put('recordsFound', 0);
        summary.put('totalSessions', 0);
    }
    
    return summary;
}

/**
 * ✅ NEW: Calculate number of weekdays between two dates (excluding Sat & Sun)
 * @param startDate Starting date
 * @param endDate Ending date (inclusive)
 * @return Number of weekdays
 */
private static Integer calculateWeekdaysBetween(Date startDate, Date endDate) {
    Integer weekdays = 0;
    Date currentDate = startDate;
    
    while (currentDate <= endDate) {
        // Get day of week (Sunday = 0, Monday = 1, ..., Saturday = 6)
        Datetime dt = Datetime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dt.format('u'); // ISO day of week (1=Monday, 7=Sunday)
        Integer dayNum = Integer.valueOf(dayOfWeek);
        
        // Count only Monday(1) through Friday(5)
        if (dayNum >= 1 && dayNum <= 5) {
            weekdays++;
        }
        
        currentDate = currentDate.addDays(1);
    }
    
    System.debug('Weekdays between ' + startDate + ' and ' + endDate + ': ' + weekdays);
    
    return weekdays;
}

/**
 * ✅ UPDATED: Calculate metrics with OD/WFH monitoring and Leave breakdown
 */
private static Map<String, Integer> calculateMonthlyMetricsFiltered(
    List<Employee_Attendance__c> records,
    List<Work_from_home_Request__c> wfhRequests,
    List<Leave_Request__c> leaveRequests,
    Integer totalWeekdays,
    Date monthStart,
    Date today
) {
    Map<String, Integer> metrics = new Map<String, Integer>();
    
    // 1. Build WFH status map
    Map<Date, String> wfhStatusByDate = new Map<Date, String>();
    for (Work_from_home_Request__c wfh : wfhRequests) {
        Date start = wfh.Start_Date__c < monthStart ? monthStart : wfh.Start_Date__c;
        Date endRec = wfh.End_Date__c > today ? today : wfh.End_Date__c;
        for (Date d = start; d <= endRec; d = d.addDays(1)) {
            wfhStatusByDate.put(d, wfh.Status__c);
        }
    }

    // 2. Track unique dates for calculations
    Set<Date> datesWithAttendance = new Set<Date>();
    Set<Date> datesWithLate = new Set<Date>();
    
    for (Employee_Attendance__c record : records) {
        if (record.Check_In_Time__c != null && record.Date__c != null) {
            Boolean isApproved = true;
            
            // Check OD Status
            if (record.Is_OD_Request__c == true && record.OD_Approval_Status__c != 'Approved') {
                isApproved = false;
            }
            
            // Check WFH Status from separate object
            if (record.Work_Location__c == 'Work from Home') {
                String wfhStatus = wfhStatusByDate.get(record.Date__c);
                if (wfhStatus != 'Approved') {
                    isApproved = false;
                }
            }

            if (isApproved) {
                datesWithAttendance.add(record.Date__c);
                if (record.Status__c == 'Late') {
                    datesWithLate.add(record.Date__c);
                }
            }
        }
    }
    
    // 3. Calculate Approved Leave Days (Unique weekdays)
    Set<Date> leaveDates = new Set<Date>();
    for (Leave_Request__c lr : leaveRequests) {
        Date start = lr.Start_Date__c < monthStart ? monthStart : lr.Start_Date__c;
        Date endRec = lr.End_Date__c > today ? today : lr.End_Date__c;
        for (Date d = start; d <= endRec; d = d.addDays(1)) {
            // Count if it's a weekday and NOT already counted as Present
            if (!datesWithAttendance.contains(d)) {
                Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                Integer dayNum = Integer.valueOf(dt.format('u'));
                if (dayNum >= 1 && dayNum <= 5) {
                    leaveDates.add(d);
                }
            }
        }
    }

    Integer presentDays = datesWithAttendance.size();
    Integer lateDays = datesWithLate.size();
    Integer absentDays = totalWeekdays - presentDays;
    Integer approvedLeaveDays = leaveDates.size();
    Integer lopDays = absentDays - approvedLeaveDays;
    
    if (lopDays < 0) lopDays = 0;
    
    metrics.put('presentDays', presentDays);
    metrics.put('lateDays', lateDays);
    metrics.put('absentDays', absentDays);
    metrics.put('approvedLeaveDays', approvedLeaveDays);
    metrics.put('lopDays', lopDays);
    
    return metrics;
}

/**
 * ✅ UPDATED: Calculate total hours across ALL sessions
 */
private static Decimal calculateTotalHoursAllSessions(List<Employee_Attendance__c> records) {
    Decimal totalHours = 0;
    
    for (Employee_Attendance__c record : records) {
        if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
            totalHours += record.Hours_Worked__c;
        }
    }
    
    return totalHours;
}

/**
 * ✅ UPDATED: Calculate average hours per DAY
 */
private static Decimal calculateAverageHoursPerDay(List<Employee_Attendance__c> records) {
    Map<Date, Decimal> hoursPerDay = new Map<Date, Decimal>();
    
    for (Employee_Attendance__c record : records) {
        if (record.Date__c != null && record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
            Decimal currentHours = hoursPerDay.containsKey(record.Date__c) 
                ? hoursPerDay.get(record.Date__c) 
                : 0;
            hoursPerDay.put(record.Date__c, currentHours + record.Hours_Worked__c);
        }
    }
    
    if (hoursPerDay.isEmpty()) {
        return 0;
    }
    
    Decimal totalHours = 0;
    for (Decimal dayHours : hoursPerDay.values()) {
        totalHours += dayHours;
    }
    
    return totalHours / hoursPerDay.size();
}

/**
 * Calculate attendance rate percentage
 * @param presentDays Number of days user checked in
 * @param totalWeekdays Total weekdays from month start to today
 * @return Attendance percentage
 */
private static Decimal calculateAttendanceRate(Integer presentDays, Integer totalWeekdays) {
    if (totalWeekdays == 0) return 0;
    
    return (Decimal.valueOf(presentDays) / Decimal.valueOf(totalWeekdays)) * 100;
}

/**
 * Get month name from date
 */
private static String getMonthName(Date inputDate) {
    String[] months = new String[]{
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };
    
    Integer monthNumber = inputDate.month();
    Integer year = inputDate.year();
    
    return months[monthNumber - 1] + ' ' + year;
}

/**
 * Get detailed monthly breakdown for all users (Admin functionality)
 */
@AuraEnabled
public static List<Map<String, Object>> getAllUsersMonthlySummary() {
    List<Map<String, Object>> allUsersSummary = new List<Map<String, Object>>();
    
    try {
        Set<String> usersWithAttendance = new Set<String>();
        
        Date today = Date.today();
        Date monthStart = today.toStartOfMonth();
        
        for (Employee_Attendance__c record : [
            SELECT Employee_Name__c FROM Employee_Attendance__c 
            WHERE Date__c >= :monthStart AND Date__c <= :today
        ]) {
            usersWithAttendance.add(record.Employee_Name__c);
        }
        
        List<User> activeUsers = [
            SELECT Id, Name, Email, Profile.Name 
            FROM User 
            WHERE Id IN :usersWithAttendance
            AND IsActive = true 
            LIMIT 100
        ];
        
        for (User user : activeUsers) {
            Map<String, Object> userSummary = getMonthlySummary(user.Id);
            userSummary.put('userName', user.Name);
            userSummary.put('userEmail', user.Email);
            userSummary.put('userId', user.Id);
            allUsersSummary.add(userSummary);
        }
        
    } catch (Exception e) {
        System.debug('Error getting all users summary: ' + e.getMessage());
    }
    
    return allUsersSummary;
}
    
    
     @AuraEnabled(cacheable=true)
    public static Boolean shouldShowCheckInPopup() {

        // Current time
        Time nowTime = System.now().time();

        // ❌ After 12:00 PM → no popup
        if (nowTime >= Time.newInstance(12, 0, 0, 0)) {
            return false;
        }

        // Check if user has checked in today
        Integer checkInCount = [
            SELECT COUNT()
            FROM Employee_Attendance__c
            WHERE Employee_Name__c = :UserInfo.getUserId()
            AND 	Date__c = :Date.today()
            AND Check_In_Time__c != NULL
        ];

        // ✅ Show popup only if NOT checked in
        return checkInCount == 0;
    }
@AuraEnabled(cacheable=false)
public static Map<String, Integer> getMyRequestCountsForCurrentWeek() {
    Id userId = UserInfo.getUserId();
    Date today = Date.today();
    Date monthStart = today.toStartOfMonth();
    Date monthEnd = monthStart.addMonths(1).addDays(-1);
    
    Map<String, Integer> counts = new Map<String, Integer>();
    
    // 1. Pending Leave Requests (Monthly)
    // Counts requests that overlap with the current month
    Integer pendingLeave = [
        SELECT COUNT()
        FROM Leave_Request__c
        WHERE Employee__c = :userId
        AND Status__c = 'Pending'
        AND Is_Active__c = true
        AND ((Start_Date__c >= :monthStart AND Start_Date__c <= :monthEnd)
             OR (End_Date__c >= :monthStart AND End_Date__c <= :monthEnd))
    ];
    
    // 1b. Approved Leave Requests (Monthly)
    Integer approvedLeave = [
        SELECT COUNT()
        FROM Leave_Request__c
        WHERE Employee__c = :userId
        AND Status__c = 'Approved'
        AND Is_Active__c = true
        AND ((Start_Date__c >= :monthStart AND Start_Date__c <= :monthEnd)
             OR (End_Date__c >= :monthStart AND End_Date__c <= :monthEnd))
    ];
    
    // 2. Pending WFH Requests (Monthly)
    // Counts requests that overlap with the current month
    // Note: The object name from existing code is used
    Integer pendingWFH = [
        SELECT COUNT()
        FROM Work_from_home_Request__c
        WHERE Employee__c = :userId
        AND Status__c = 'Pending'
        AND Is_Active__c = true
        AND ((Start_Date__c >= :monthStart AND Start_Date__c <= :monthEnd)
             OR (End_Date__c >= :monthStart AND End_Date__c <= :monthEnd))
    ];
    
    // 3. Submitted Timesheet Entries (Monthly)
    // Counts all individual entries that are submitted but not yet approved for the current month
    Integer submittedTimesheet = [
        SELECT COUNT()
        FROM TimesheetEntry__c
        WHERE Timesheet__r.Employee__c = :userId
        AND (Approval_Status__c = 'Submitted' OR Status__c = 'Submitted')
        AND Date__c >= :monthStart
        AND Date__c <= :monthEnd
    ];
    
    // 4. Pending OD Requests (Monthly)
    Integer pendingOD = [
        SELECT COUNT()
        FROM Employee_Attendance__c
        WHERE Employee_Name__c = :userId
        AND Is_OD_Request__c = true
        AND OD_Approval_Status__c = 'Pending'
        AND Date__c >= :monthStart
        AND Date__c <= :monthEnd
    ];
    
    counts.put('pendingLeave', pendingLeave);
    counts.put('approvedLeave', approvedLeave);
    counts.put('pendingWFH', pendingWFH);
    counts.put('submittedTimesheet', submittedTimesheet);
    counts.put('pendingOD', pendingOD);
    
    return counts;
}
}