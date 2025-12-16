public with sharing class AttendanceSummaryController {
    
   	/**
 * ✅ UPDATED: Get comprehensive monthly summary with multiple sessions support
 * @param userId Current user ID
 * @return Map containing monthly summary statistics
 */
@AuraEnabled
public static Map<String, Object> getMonthlySummary(String userId) {
    Map<String, Object> summary = new Map<String, Object>();
    
    try {
        Date today = Date.today();
        Date monthStart = today.toStartOfMonth();
        
        Integer totalDays = monthStart.daysBetween(today) + 1;
        
        // ✅ Query all attendance records (including multiple sessions per day)
        List<Employee_Attendance__c> monthlyRecords = [
            SELECT Id, Date__c, Check_In_Time__c, Check_Out_Time__c, 
                   Hours_Worked__c, Status__c, Employee_Name__c,
                   Session_Number__c, Is_Multiple_Session__c
            FROM Employee_Attendance__c 
            WHERE Employee_Name__c = :userId 
            AND Date__c >= :monthStart 
            AND Date__c <= :today
            ORDER BY Date__c ASC, Session_Number__c ASC
        ];
        
        // ✅ UPDATED: Calculate metrics with session awareness
        Map<String, Integer> calculations = calculateMonthlyMetricsWithSessions(monthlyRecords, totalDays);
        Decimal totalHours = calculateTotalHoursAllSessions(monthlyRecords);
        Decimal avgHoursPerDay = calculateAverageHoursPerDay(monthlyRecords);
        Decimal attendanceRate = calculateAttendanceRate(calculations.get('presentDays'), totalDays);
        
        String monthName = getMonthName(monthStart);
        
        summary.put('success', true);
        summary.put('presentDays', calculations.get('presentDays'));
        summary.put('lateDays', calculations.get('lateDays'));
        summary.put('absentDays', calculations.get('absentDays'));
        summary.put('totalHours', totalHours.setScale(1).toPlainString());
        summary.put('avgHoursPerDay', avgHoursPerDay.setScale(1).toPlainString());
        summary.put('attendanceRate', attendanceRate.setScale(1).toPlainString());
        summary.put('totalWorkingDays', totalDays);
        summary.put('monthName', monthName);
        summary.put('recordsFound', monthlyRecords.size());
        summary.put('totalSessions', monthlyRecords.size()); // ✅ NEW
        
        System.debug('Monthly Summary Calculated with ' + monthlyRecords.size() + ' sessions');
        
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
 * ✅ NEW: Calculate metrics with multiple sessions support
 * Counts unique DATES with check-in (not total sessions)
 */
private static Map<String, Integer> calculateMonthlyMetricsWithSessions(
    List<Employee_Attendance__c> records, 
    Integer totalDays
) {
    Map<String, Integer> metrics = new Map<String, Integer>();
    
    // ✅ Track unique dates with attendance
    Set<Date> datesWithAttendance = new Set<Date>();
    Set<Date> datesWithLate = new Set<Date>();
    
    for (Employee_Attendance__c record : records) {
        if (record.Check_In_Time__c != null && record.Date__c != null) {
            datesWithAttendance.add(record.Date__c);
            
            if (record.Status__c == 'Late') {
                datesWithLate.add(record.Date__c);
            }
        }
    }
    
    Integer presentDays = datesWithAttendance.size();
    Integer lateDays = datesWithLate.size();
    Integer absentDays = totalDays - presentDays;
    
    if (absentDays < 0) {
        absentDays = 0;
    }
    
    metrics.put('presentDays', presentDays);
    metrics.put('lateDays', lateDays);
    metrics.put('absentDays', absentDays);
    
    System.debug('=== ATTENDANCE METRICS (MULTI-SESSION) ===');
    System.debug('Total Days: ' + totalDays);
    System.debug('Unique Present Days: ' + presentDays);
    System.debug('Days with Late: ' + lateDays);
    System.debug('Absent Days: ' + absentDays);
    System.debug('Total Sessions: ' + records.size());
    
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
    
    System.debug('Total hours across all sessions: ' + totalHours);
    
    return totalHours;
}

/**
 * ✅ UPDATED: Calculate average hours per DAY (not per session)
 * Sums all session hours per day, then averages across days
 */
private static Decimal calculateAverageHoursPerDay(List<Employee_Attendance__c> records) {
    // Group sessions by date and sum hours
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
    
    Decimal avgHours = totalHours / hoursPerDay.size();
    
    System.debug('Average hours per day: ' + avgHours + ' (across ' + hoursPerDay.size() + ' days)');
    
    return avgHours;
}
    /**
     * ✅ REMOVED: calculateWorkingDaysInMonth method - No longer needed
     * We now use simple daysBetween calculation in getMonthlySummary
     */
    
    /**
     * Calculate monthly metrics: present days, late days, absent days
     * ✅ UPDATED: Now uses total calendar days instead of working days
     * Absent Days = Total Days (from month start to today) - Present Days
     * @param records List of attendance records
     * @param totalDays Total calendar days from month start to today
     * @return Map with presentDays, lateDays, absentDays
     */
    public static Map<String, Integer> calculateMonthlyMetrics(List<Employee_Attendance__c> records, Integer totalDays) {
        Map<String, Integer> metrics = new Map<String, Integer>();
        
        Integer presentDays = 0;
        Integer lateDays = 0;
        Integer absentDays = 0;
        
        // Count actual present days (where user checked in)
        for (Employee_Attendance__c record : records) {
            if (record.Check_In_Time__c != null) {
                presentDays++;
                
                // Check if late
                if (record.Status__c == 'Late') {
                    lateDays++;
                }
            }
        }
        
        // ✅ CHANGED: Calculate absent days using total calendar days
        // Total Days includes ALL days (weekdays + weekends) from month start to today
        absentDays = totalDays - presentDays;
        
        // Ensure absent days is never negative
        if (absentDays < 0) {
            absentDays = 0;
        }
        
        metrics.put('presentDays', presentDays);
        metrics.put('lateDays', lateDays);
        metrics.put('absentDays', absentDays);
        
        System.debug('=== ATTENDANCE METRICS ===');
        System.debug('Total Days (including weekends, from month start to today): ' + totalDays);
        System.debug('Present Days (Check-in recorded): ' + presentDays);
        System.debug('Late Days: ' + lateDays);
        System.debug('Absent Days (Days without check-in): ' + absentDays);
        System.debug('=========================');
        
        return metrics;
    }
    
    /**
     * Calculate total hours worked in the month
     * ✅ UNCHANGED
     */
    public static Decimal calculateTotalHours(List<Employee_Attendance__c> records) {
        Decimal totalHours = 0;
        
        for (Employee_Attendance__c record : records) {
            if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
                totalHours += record.Hours_Worked__c;
            }
        }
        
        return totalHours;
    }
    
    /**
     * Calculate average hours per working day
     * ✅ UNCHANGED
     */
    public static Decimal calculateAverageHours(List<Employee_Attendance__c> records) {
        Decimal totalHours = 0;
        Integer daysWithHours = 0;
        
        for (Employee_Attendance__c record : records) {
            if (record.Hours_Worked__c != null && record.Hours_Worked__c > 0) {
                totalHours += record.Hours_Worked__c;
                daysWithHours++;
            }
        }
        
        return daysWithHours > 0 ? totalHours / daysWithHours : 0;
    }
    
    /**
     * Calculate attendance rate percentage
     * ✅ UPDATED: Now calculates based on total days instead of working days
     * @param presentDays Number of days user checked in
     * @param totalDays Total calendar days from month start to today
     * @return Attendance percentage
     */
    private static Decimal calculateAttendanceRate(Integer presentDays, Integer totalDays) {
        if (totalDays == 0) return 0;
        
        return (Decimal.valueOf(presentDays) / Decimal.valueOf(totalDays)) * 100;
    }
    
    /**
     * Get month name from date
     * ✅ UNCHANGED
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
     * ✅ UPDATED: Uses total days instead of working days
     */
    @AuraEnabled
    public static List<Map<String, Object>> getAllUsersMonthlySummary() {
        List<Map<String, Object>> allUsersSummary = new List<Map<String, Object>>();
        
        try {
            // Get all active users who have attendance records
            Set<String> usersWithAttendance = new Set<String>();
            
            Date today = Date.today();
            Date monthStart = today.toStartOfMonth();
            
            // ✅ Query up to today
            for (Employee_Attendance__c record : [
                SELECT Employee_Name__c FROM Employee_Attendance__c 
                WHERE Date__c >= :monthStart AND Date__c <= :today
            ]) {
                usersWithAttendance.add(record.Employee_Name__c);
            }
            
            // Get user details for those with attendance
            List<User> activeUsers = [
                SELECT Id, Name, Email, Profile.Name 
                FROM User 
                WHERE Id IN :usersWithAttendance
                AND IsActive = true 
                LIMIT 100
            ];
            
            // Calculate summary for each user
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
}