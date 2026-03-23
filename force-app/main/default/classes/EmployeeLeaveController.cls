/**
 * Controller for Employee Leave Management Component
 * Handles leave balances, holidays, and leave request operations
 */
public without sharing class EmployeeLeaveController {
    
    /**
     * Get Employee Leave Balances - ONLY ELIGIBLE ONES
     * Auto-creates balances if they don't exist
     */
    @AuraEnabled(cacheable=false)
    public static List<Employee_Leave_Balance__c> getEmployeeLeaveBalances(Id employeeId, String year) {
        try {
            // First, ensure balances are created for this employee
            LeaveBalanceService.createEligibleBalancesForEmployee(employeeId, year);
            
            // Return only eligible balances
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, 
                       Total_Allocated__c, 
                       Used__c, 
                       Booked__c, 
                       Pending_Approval__c, 
                       Carried_Forward__c,
                       Available__c,
                       Leave_Type__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Icon_Name__c,
                       Leave_Type__r.Color_Code__c,
                       Leave_Type__r.Sort_Order__c,
                       Leave_Type__r.Is_Fallback_Leave__c,
                       Is_Eligible__c,
                       Eligibility_Reason__c,
                       Lifetime_Usage_Count__c,
                       Eligible_From_Date__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Year__c = :year
                AND Is_Active__c = true
                AND Is_Eligible__c = true
                ORDER BY Leave_Type__r.Sort_Order__c ASC NULLS LAST, Leave_Type__r.Leave_Type_Name__c ASC
            ];
            
            System.debug('Found ' + balances.size() + ' eligible leave balances for employee: ' + employeeId);
            return balances;
            
        } catch (Exception e) {
            System.debug('Error in getEmployeeLeaveBalances: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching leave balances: ' + e.getMessage());
        }
    }
    
    /**
     * Get Upcoming Holidays
     */
    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getUpcomingHolidays() {
        try {
            return [
                SELECT Id, 
                       Name, 
                       Holiday_Date__c, 
                       Holiday_Type__c,
                       Icon_Name__c,
                       Color_Code__c,
                       Description__c,
                       Applicable_Departments__c
                FROM Holiday__c
                WHERE Holiday_Date__c >= TODAY
                AND Is_Active__c = true
                ORDER BY Holiday_Date__c ASC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('Error in getUpcomingHolidays: ' + e.getMessage());
            throw new AuraHandledException('Error fetching holidays: ' + e.getMessage());
        }
    }
    
    /**
     * Get Upcoming Leaves and Holidays (Combined view)
     */
    @AuraEnabled
    public static List<Map<String, Object>> getUpcomingLeavesAndHolidays(Id employeeId) {
        try {
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            Date today = Date.today();
            
            // Get upcoming leave requests
            List<Leave_Request__c> leaves = [
                SELECT Id, Start_Date__c, End_Date__c, Total_Days__c, 
                       Reason__c, Status__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Icon_Name__c
                FROM Leave_Request__c
                WHERE Employee__c = :employeeId
                AND Start_Date__c >= :today
                AND Status__c IN ('Approved', 'Pending')
                AND Is_Active__c = true
                ORDER BY Start_Date__c ASC
                LIMIT 50
            ];
            
            for (Leave_Request__c lr : leaves) {
                Map<String, Object> item = new Map<String, Object>();
                item.put('Id', lr.Id);
                item.put('Start_Date__c', lr.Start_Date__c);
                item.put('End_Date__c', lr.End_Date__c);
                item.put('Total_Days__c', lr.Total_Days__c);
                item.put('Reason__c', lr.Reason__c);
                item.put('Status__c', lr.Status__c);
                item.put('Leave_Type__r', lr.Leave_Type__r);
                item.put('recordType', 'Leave');
                results.add(item);
            }
            
            // Get upcoming holidays
            List<Holiday__c> holidays = [
                SELECT Id, Name, Holiday_Date__c, Description__c,
                       Holiday_Type__c, Icon_Name__c
                FROM Holiday__c
                WHERE Holiday_Date__c >= :today
                AND Is_Active__c = true
                ORDER BY Holiday_Date__c ASC
                LIMIT 50
            ];
            
            for (Holiday__c h : holidays) {
                Map<String, Object> item = new Map<String, Object>();
                item.put('Id', h.Id);
                item.put('Name', h.Name);
                item.put('Holiday_Date__c', h.Holiday_Date__c);
                item.put('Description__c', h.Description__c);
                item.put('Holiday_Type__c', h.Holiday_Type__c);
                item.put('Icon_Name__c', h.Icon_Name__c);
                item.put('recordType', 'Holiday');
                results.add(item);
            }
            
            return results;
            
        } catch (Exception e) {
            System.debug('Error in getUpcomingLeavesAndHolidays: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get Past Leaves and Holidays
     */
    @AuraEnabled
    public static List<Map<String, Object>> getPastLeavesAndHolidays(Id employeeId) {
        try {
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            Date today = Date.today();
            
            List<Leave_Request__c> leaves = [
                SELECT Id, Start_Date__c, End_Date__c, Total_Days__c,
                       Reason__c, Status__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Icon_Name__c
                FROM Leave_Request__c
                WHERE Employee__c = :employeeId
                AND End_Date__c < :today
                AND Status__c = 'Completed'
                AND Is_Active__c = true
                ORDER BY Start_Date__c DESC
                LIMIT 50
            ];
            
            for (Leave_Request__c lr : leaves) {
                Map<String, Object> item = new Map<String, Object>();
                item.put('Id', lr.Id);
                item.put('Start_Date__c', lr.Start_Date__c);
                item.put('End_Date__c', lr.End_Date__c);
                item.put('Total_Days__c', lr.Total_Days__c);
                item.put('Reason__c', lr.Reason__c);
                item.put('Status__c', lr.Status__c);
                item.put('Leave_Type__r', lr.Leave_Type__r);
                item.put('recordType', 'Leave');
                results.add(item);
            }
            
            return results;
            
        } catch (Exception e) {
            System.debug('Error in getPastLeavesAndHolidays: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get Leave Balance for a specific leave type
     * Used when applying for leave to check availability
     */
    @AuraEnabled
    public static Map<String, Object> getLeaveBalance(Id employeeId, Id leaveTypeId, String year) {
        try {
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Total_Allocated__c, Used__c, Booked__c, 
                       Pending_Approval__c, Available__c, Carried_Forward__c,
                       Is_Eligible__c, Eligibility_Reason__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Max_Lifetime_Occurrences__c,
                       Lifetime_Usage_Count__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Leave_Type__c = :leaveTypeId
                AND Year__c = :year
                AND Is_Active__c = true
                LIMIT 1
            ];
            
            if (!balances.isEmpty()) {
                Employee_Leave_Balance__c bal = balances[0];
                
                Map<String, Object> result = new Map<String, Object>();
                result.put('balance', bal);
                result.put('Available__c', bal.Available__c);
                
                return result;
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error in getLeaveBalance: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Check if all leaves are exhausted (for LOP visibility)
     */
    @AuraEnabled
    public static Boolean areAllLeavesExhausted(Id employeeId, String year) {
        try {
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Available__c, Leave_Type__r.Is_Fallback_Leave__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Year__c = :year
                AND Is_Active__c = true
                AND Is_Eligible__c = true
            ];
            
            for (Employee_Leave_Balance__c bal : balances) {
                // Skip fallback leaves (LOP)
                if (bal.Leave_Type__r.Is_Fallback_Leave__c) {
                    continue;
                }
                
                // If any non-fallback leave has balance, return false
                if (bal.Available__c > 0) {
                    return false;
                }
            }
            
            return true; // All leaves exhausted
            
        } catch (Exception e) {
            System.debug('Error in areAllLeavesExhausted: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Refresh employee leave balances
     * Can be called manually to recreate balances
     */
    @AuraEnabled
    public static String refreshLeaveBalances(Id employeeId, String year) {
        try {
            LeaveBalanceService.createEligibleBalancesForEmployee(employeeId, year);
            return 'Leave balances refreshed successfully';
        } catch (Exception e) {
            System.debug('Error in refreshLeaveBalances: ' + e.getMessage());
            throw new AuraHandledException('Error refreshing balances: ' + e.getMessage());
        }
    }
    
    /**
     * Get employee details with leave eligibility info
     */
    @AuraEnabled
    public static Map<String, Object> getEmployeeDetails(Id employeeId) {
        try {
            User emp = [
                SELECT Id, Name, Email, Date_of_Joining__c, Gender__c, 
                       Marital_Status__c, Number_of_Children__c, Employment_Type__c,
                       Department, ManagerId, Manager.Name
                FROM User 
                WHERE Id = :employeeId 
                LIMIT 1
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('employee', emp);
            
            // Calculate service months
            if (emp.Date_of_Joining__c != null) {
                Integer serviceMonths = emp.Date_of_Joining__c.daysBetween(Date.today()) / 30;
                result.put('serviceMonths', serviceMonths);
                result.put('serviceDays', emp.Date_of_Joining__c.daysBetween(Date.today()));
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in getEmployeeDetails: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get all leave types (for admin/display purposes)
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Type__c> getAllLeaveTypes() {
        try {
            return [
                SELECT Id, Leave_Type_Name__c, Leave_Code__c, 
                       Default_Allocation__c, Icon_Name__c, Color_Code__c,
                       Minimum_Service_Months__c, Applicable_Gender__c,
                       Requires_Marital_Status__c, Applicable_Employment_Types__c,
                       Is_Active__c, Sort_Order__c
                FROM Leave_Type__c
                WHERE Is_Active__c = true
                ORDER BY Sort_Order__c ASC NULLS LAST, Leave_Type_Name__c ASC
            ];
        } catch (Exception e) {
            System.debug('Error in getAllLeaveTypes: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get leave balance summary for dashboard/cards
     */
    @AuraEnabled
    public static Map<String, Object> getLeaveBalanceSummary(Id employeeId, String year) {
        try {
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Total_Allocated__c, Used__c, Booked__c, Available__c,
                       Leave_Type__r.Leave_Type_Name__c, Leave_Type__r.Leave_Code__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Year__c = :year
                AND Is_Active__c = true
                AND Is_Eligible__c = true
            ];
            
            Decimal totalAllocated = 0;
            Decimal totalUsed = 0;
            Decimal totalAvailable = 0;
            
            for (Employee_Leave_Balance__c bal : balances) {
                totalAllocated += (bal.Total_Allocated__c != null ? bal.Total_Allocated__c : 0);
                // Booked__c = deducted from available (what portal labels as "Used")
                totalUsed += (bal.Booked__c != null ? bal.Booked__c : 0);
                totalAvailable += (bal.Available__c != null ? bal.Available__c : 0);
            }
            
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('totalAllocated', totalAllocated);
            summary.put('totalUsed', totalUsed);
            summary.put('totalAvailable', totalAvailable);
            summary.put('leaveTypesCount', balances.size());
            summary.put('balances', balances);
            
            return summary;
            
        } catch (Exception e) {
            System.debug('Error in getLeaveBalanceSummary: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get leave requests count by status
     */
    @AuraEnabled
    public static Map<String, Integer> getLeaveRequestsCountByStatus(Id employeeId, String year) {
        try {
            Map<String, Integer> counts = new Map<String, Integer>();
            counts.put('Pending', 0);
            counts.put('Approved', 0);
            counts.put('Rejected', 0);
            counts.put('Cancelled', 0);
            counts.put('Completed', 0);
            
            List<AggregateResult> results = [
                SELECT Status__c, COUNT(Id) cnt
                FROM Leave_Request__c
                WHERE Employee__c = :employeeId
                AND Year__c = :year
                AND Is_Active__c = true
                GROUP BY Status__c
            ];
            
            for (AggregateResult ar : results) {
                String status = (String)ar.get('Status__c');
                Integer count = (Integer)ar.get('cnt');
                counts.put(status, count);
            }
            
            return counts;
            
        } catch (Exception e) {
            System.debug('Error in getLeaveRequestsCountByStatus: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Check if employee can apply for a specific leave type
     */
    @AuraEnabled
    public static Map<String, Object> canApplyForLeave(Id employeeId, Id leaveTypeId, String year) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            result.put('canApply', false);
            result.put('message', '');
            
            // Get balance
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Is_Eligible__c, Eligibility_Reason__c, Available__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Max_Lifetime_Occurrences__c,
                       Lifetime_Usage_Count__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Leave_Type__c = :leaveTypeId
                AND Year__c = :year
                AND Is_Active__c = true
                LIMIT 1
            ];
            
            if (balances.isEmpty()) {
                result.put('message', 'You do not have this leave type allocated.');
                return result;
            }
            
            Employee_Leave_Balance__c balance = balances[0];
            
            if (!balance.Is_Eligible__c) {
                result.put('message', balance.Eligibility_Reason__c);
                return result;
            }
            
            if (balance.Available__c <= 0) {
                result.put('message', 'No leave balance available for ' + balance.Leave_Type__r.Leave_Type_Name__c);
                return result;
            }
            
            // Check lifetime occurrence limit
            if (balance.Leave_Type__r.Max_Lifetime_Occurrences__c != null && 
                balance.Lifetime_Usage_Count__c >= balance.Leave_Type__r.Max_Lifetime_Occurrences__c) {
                result.put('message', 'Maximum lifetime usage reached for ' + balance.Leave_Type__r.Leave_Type_Name__c);
                return result;
            }
            
            result.put('canApply', true);
            result.put('message', 'You can apply for this leave');
            result.put('availableBalance', balance.Available__c);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in canApplyForLeave: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Get holidays for a specific date range
     */
    @AuraEnabled
    public static List<Holiday__c> getHolidaysBetweenDates(Date startDate, Date endDate) {
        try {
            return [
                SELECT Id, Name, Holiday_Date__c, Holiday_Type__c,
                       Description__c, Icon_Name__c
                FROM Holiday__c
                WHERE Holiday_Date__c >= :startDate
                AND Holiday_Date__c <= :endDate
                AND Is_Active__c = true
                ORDER BY Holiday_Date__c ASC
            ];
        } catch (Exception e) {
            System.debug('Error in getHolidaysBetweenDates: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate working days between two dates (excluding holidays)
     */
    @AuraEnabled
    public static Integer calculateWorkingDays(Date startDate, Date endDate) {
        try {
            if (startDate == null || endDate == null || startDate > endDate) {
                return 0;
            }
            
            // Get holidays in date range
            Set<Date> holidayDates = new Set<Date>();
            List<Holiday__c> holidays = getHolidaysBetweenDates(startDate, endDate);
            
            for (Holiday__c h : holidays) {
                holidayDates.add(h.Holiday_Date__c);
            }
            
            // Count working days
            Integer workingDays = 0;
            Date currentDate = startDate;
            
            while (currentDate <= endDate) {
                // Check if it's a weekend (Saturday = 7, Sunday = 1)
                Datetime dt = Datetime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
                String dayOfWeek = dt.format('u'); // 1=Monday, 7=Sunday
                
                Boolean isWeekend = (dayOfWeek == '6' || dayOfWeek == '7'); // Saturday or Sunday
                Boolean isHoliday = holidayDates.contains(currentDate);
                
                if (!isWeekend && !isHoliday) {
                    workingDays++;
                }
                
                currentDate = currentDate.addDays(1);
            }
            
            return workingDays;
            
        } catch (Exception e) {
            System.debug('Error in calculateWorkingDays: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled(cacheable=true)
public static Map<String, Object> getLeaveBalanceSummary1(Id employeeId, String year) {
    try {
        List<Employee_Leave_Balance__c> balances = [
            SELECT Available__c
            FROM Employee_Leave_Balance__c
            WHERE Employee__c = :employeeId
            AND Year__c = :year
            AND Is_Active__c = true
            AND Is_Eligible__c = true
            AND Leave_Type__r.Leave_Type_Name__c IN ('Sick Leave','Casual Leave','Earned Leave','Loss of Pay')
        ];

        Decimal totalAvailable = 0;

        for (Employee_Leave_Balance__c bal : balances) {
            totalAvailable += (bal.Available__c != null ? bal.Available__c : 0);
        }

        return new Map<String, Object>{
            'totalAvailable' => totalAvailable
        };

    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}

}