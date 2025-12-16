/**
 * Service class to create and manage employee leave balances based on eligibility
 * ALL eligibility logic is handled in Apex (no formula fields)
 * FIXED: Proration logic and marriage leave eligibility
 */
public class LeaveBalanceService {
    
    /**
     * Main method to create eligible leave balances for an employee
     */
    public static void createEligibleBalancesForEmployee(Id employeeId, String year) {
        try {
            // Get employee details
            User emp = [
                SELECT Id, Name, Date_of_Joining__c, Gender__c, Marital_Status__c, 
                       Number_of_Children__c, Employment_Type__c, Email
                FROM User 
                WHERE Id = :employeeId 
                LIMIT 1
            ];
            
            if (emp.Date_of_Joining__c == null) {
                System.debug('Employee has no Date of Joining: ' + emp.Name);
                return;
            }
            
            // Calculate service months
            Integer serviceMonths = calculateServiceMonths(emp.Date_of_Joining__c);
            
            // Get all active leave types
            List<Leave_Type__c> leaveTypes = [
                SELECT Id, Leave_Type_Name__c, Leave_Code__c, Default_Allocation__c,
                       Minimum_Service_Months__c, Applicable_Gender__c, 
                       Requires_Marital_Status__c, Max_Lifetime_Occurrences__c,
                       Accrual_Type__c, Accrual_Start_Type__c,
                       Applicable_Employment_Types__c, Is_Fallback_Leave__c,
                       Carry_Forward_Allowed__c, Max_Carry_Forward_Days__c
                FROM Leave_Type__c 
                WHERE Is_Active__c = true
                ORDER BY Sort_Order__c NULLS LAST
            ];
            
            // Get existing balances for this employee and year
            Map<Id, Employee_Leave_Balance__c> existingBalancesMap = new Map<Id, Employee_Leave_Balance__c>();
            List<Employee_Leave_Balance__c> existingBalances = [
                SELECT Id, Leave_Type__c, Total_Allocated__c, Used__c, Booked__c,
                       Pending_Approval__c, Lifetime_Usage_Count__c, Carried_Forward__c,
                       Is_Eligible__c, Eligibility_Reason__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId 
                AND Year__c = :year
            ];
            
            for (Employee_Leave_Balance__c bal : existingBalances) {
                existingBalancesMap.put(bal.Leave_Type__c, bal);
            }
            
            // Check if all non-fallback leaves are exhausted
            Boolean allLeavesExhausted = checkIfAllLeavesExhausted(existingBalancesMap, leaveTypes);
            
            List<Employee_Leave_Balance__c> balancesToUpsert = new List<Employee_Leave_Balance__c>();
            
            for (Leave_Type__c lt : leaveTypes) {
                // Check basic eligibility
                EligibilityResult eligibility = checkEligibility(emp, lt, serviceMonths);
                
                // Special handling for LOP (Loss of Pay) - only if all leaves exhausted
                if (lt.Is_Fallback_Leave__c && !allLeavesExhausted) {
                    eligibility.isEligible = false;
                    eligibility.reason = 'Available only when all other leaves are exhausted';
                }
                
                Employee_Leave_Balance__c balance = existingBalancesMap.get(lt.Id);
                
                if (balance == null) {
                    // Create new balance
                    balance = createNewBalance(emp, lt, year, serviceMonths, eligibility);
                    balancesToUpsert.add(balance);
                } else {
                    // Update existing balance eligibility and allocation
                    balance.Is_Eligible__c = eligibility.isEligible;
                    balance.Eligibility_Reason__c = eligibility.reason;
                    
                    // Recalculate allocation (important for proration)
                    Decimal newAllocation = calculateAllocation(emp, lt, year, serviceMonths);
                    
                    // Only update allocation if it hasn't been used yet
                    if (balance.Used__c == 0 && balance.Booked__c == 0 && balance.Pending_Approval__c == 0) {
                        balance.Total_Allocated__c = newAllocation;
                    }
                    
                    balancesToUpsert.add(balance);
                }
            }
            
            if (!balancesToUpsert.isEmpty()) {
                upsert balancesToUpsert;
                System.debug('Created/Updated ' + balancesToUpsert.size() + ' leave balances for ' + emp.Name);
            }
            
        } catch (Exception e) {
            System.debug('Error in createEligibleBalancesForEmployee: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating leave balances: ' + e.getMessage());
        }
    }
    
    /**
     * Eligibility Result Wrapper
     */
    public class EligibilityResult {
        public Boolean isEligible { get; set; }
        public String reason { get; set; }
        
        public EligibilityResult(Boolean eligible, String msg) {
            this.isEligible = eligible;
            this.reason = msg;
        }
    }
    
    /**
     * Check if employee is eligible for a leave type
     * Returns EligibilityResult with boolean and reason
     * FIXED: Marriage leave now checks for Single status only
     */
    private static EligibilityResult checkEligibility(User emp, Leave_Type__c lt, Integer serviceMonths) {
        // 1. Service months check
        if (lt.Minimum_Service_Months__c != null && serviceMonths < lt.Minimum_Service_Months__c) {
            return new EligibilityResult(false, 
                'Requires ' + lt.Minimum_Service_Months__c + ' months of service. Current: ' + serviceMonths + ' months');
        }
        
        // 2. Gender check
        if (String.isNotBlank(lt.Applicable_Gender__c) && 
            lt.Applicable_Gender__c != 'All' && 
            lt.Applicable_Gender__c != emp.Gender__c) {
            return new EligibilityResult(false, 
                'Applicable only for ' + lt.Applicable_Gender__c + ' employees');
        }
        
        // 3. Marital status check - FIXED
        // If leave requires specific marital status (e.g., Marriage Leave requires Single)
        if (String.isNotBlank(lt.Requires_Marital_Status__c) && 
            lt.Requires_Marital_Status__c != 'Any') {
            
            // Check if employee's marital status matches required status
            if (String.isBlank(emp.Marital_Status__c) || 
                lt.Requires_Marital_Status__c != emp.Marital_Status__c) {
                return new EligibilityResult(false, 
                    'Requires marital status: ' + lt.Requires_Marital_Status__c + '. Your status: ' + 
                    (String.isNotBlank(emp.Marital_Status__c) ? emp.Marital_Status__c : 'Not Set'));
            }
        }
        
        // 4. Employment type check (Multi-select picklist)
        if (String.isNotBlank(lt.Applicable_Employment_Types__c) && String.isNotBlank(emp.Employment_Type__c)) {
            Set<String> applicableTypes = new Set<String>();
            for (String type : lt.Applicable_Employment_Types__c.split(';')) {
                applicableTypes.add(type.trim());
            }
            
            if (!applicableTypes.contains(emp.Employment_Type__c)) {
                return new EligibilityResult(false, 
                    'Not applicable for ' + emp.Employment_Type__c + ' employees. Required: ' + lt.Applicable_Employment_Types__c);
            }
        }
        
        // All checks passed
        return new EligibilityResult(true, 'Eligible - All criteria met');
    }
    
    /**
     * Create new balance record with eligibility
     */
    private static Employee_Leave_Balance__c createNewBalance(User emp, Leave_Type__c lt, String year, 
                                                               Integer serviceMonths, EligibilityResult eligibility) {
        Decimal allocation = calculateAllocation(emp, lt, year, serviceMonths);
        
        Employee_Leave_Balance__c balance = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = year,
            Total_Allocated__c = allocation,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 0,
            Carried_Forward__c = 0,
            Lifetime_Usage_Count__c = 0,
            Is_Active__c = true,
            Auto_Created__c = true,
            Eligible_From_Date__c = calculateEligibleFromDate(emp.Date_of_Joining__c, lt),
            Is_Eligible__c = eligibility.isEligible,
            Eligibility_Reason__c = eligibility.reason
        );
        
        return balance;
    }
    
    /**
     * Calculate allocation based on leave type and joining date
     * FIXED: Proper proration calculation for mid-year joiners
     */
    private static Decimal calculateAllocation(User emp, Leave_Type__c lt, String year, Integer serviceMonths) {
        Decimal allocation = lt.Default_Allocation__c != null ? lt.Default_Allocation__c : 0;
        
        Integer joinYear = emp.Date_of_Joining__c.year();
        Integer currentYear = Integer.valueOf(year);
        
        // Handle prorated allocation for mid-year joiners (CL, SL)
        if (joinYear == currentYear && (lt.Leave_Code__c == 'CL' || lt.Leave_Code__c == 'SL')) {
            // Joined mid-year - prorate based on remaining months INCLUDING current month
            Integer joinMonth = emp.Date_of_Joining__c.month(); // Nov = 11, Dec = 12
            
            // Calculate remaining months in the year (including joining month)
            // For November (11): 12 - 11 + 1 = 2 months (Nov + Dec)
            // For September (9): 12 - 9 + 1 = 4 months (Sep, Oct, Nov, Dec)
            Integer remainingMonths = 12 - joinMonth + 1;
            
            // Calculate prorated allocation
            allocation = (lt.Default_Allocation__c / 12) * remainingMonths;
            allocation = Math.floor(allocation); // Round down to whole number
            
            System.debug('=== PRORATION CALCULATION ===');
            System.debug('Leave Type: ' + lt.Leave_Type_Name__c);
            System.debug('Join Month: ' + joinMonth);
            System.debug('Remaining Months: ' + remainingMonths);
            System.debug('Default Allocation: ' + lt.Default_Allocation__c);
            System.debug('Prorated Allocation: ' + allocation + ' days');
        }
        
        // Special handling for Earned Leave (monthly accrual after 1 year)
        if (lt.Leave_Code__c == 'EL' && lt.Accrual_Type__c == 'Monthly') {
            if (serviceMonths >= 12) {
                // Calculate months in current year after completing 1 year
                Date anniversaryDate = emp.Date_of_Joining__c.addYears(1);
                
                // Check if anniversary date is in current year
                if (anniversaryDate.year() == currentYear) {
                    // Anniversary is this year - calculate months from anniversary to year end
                    Integer anniversaryMonth = anniversaryDate.month();
                    allocation = 12 - anniversaryMonth + 1; // Months remaining including anniversary month
                    allocation = Math.min(allocation, 12); // Max 12 per year
                } else if (anniversaryDate.year() < currentYear) {
                    // Anniversary was in previous year - full 12 months
                    allocation = 12;
                } else {
                    // Anniversary is next year - not eligible yet
                    allocation = 0;
                }
            } else {
                allocation = 0; // Not completed 1 year yet
            }
        }
        
        return allocation;
    }
    
    /**
     * Calculate service months from date of joining
     */
    private static Integer calculateServiceMonths(Date doj) {
        if (doj == null) return 0;
        Integer days = doj.daysBetween(Date.today());
        return Integer.valueOf(days / 30);
    }
    
    /**
     * Calculate eligible from date
     */
    private static Date calculateEligibleFromDate(Date doj, Leave_Type__c lt) {
        if (doj == null || lt.Minimum_Service_Months__c == null || lt.Minimum_Service_Months__c == 0) {
            return doj != null ? doj : Date.today();
        }
        return doj.addMonths(Integer.valueOf(lt.Minimum_Service_Months__c));
    }
    
    /**
     * Check if all non-fallback leaves are exhausted
     */
    private static Boolean checkIfAllLeavesExhausted(Map<Id, Employee_Leave_Balance__c> balancesMap, List<Leave_Type__c> allLeaveTypes) {
        if (balancesMap.isEmpty()) {
            return false; // No balances yet
        }
        
        for (Leave_Type__c lt : allLeaveTypes) {
            // Skip fallback leaves (LOP)
            if (lt.Is_Fallback_Leave__c) {
                continue;
            }
            
            Employee_Leave_Balance__c balance = balancesMap.get(lt.Id);
            if (balance != null && balance.Is_Eligible__c) {
                // Calculate available
                Decimal available = balance.Total_Allocated__c - balance.Used__c - balance.Booked__c - balance.Pending_Approval__c + balance.Carried_Forward__c;
                
                if (available > 0) {
                    return false; // Found a leave with balance
                }
            }
        }
        
        return true; // All leaves exhausted
    }
    
    /**
     * Create balances for all active employees
     */
    public static void createBalancesForAllEmployees(String year) {
        List<User> activeEmployees = [
            SELECT Id, Name, Date_of_Joining__c, Gender__c, Marital_Status__c, 
                   Number_of_Children__c, Employment_Type__c
            FROM User 
            WHERE IsActive = true 
            AND Employee_Id__c != null
            AND Date_of_Joining__c != null
            LIMIT 200
        ];
        
        for (User emp : activeEmployees) {
            try {
                createEligibleBalancesForEmployee(emp.Id, year);
            } catch (Exception e) {
                System.debug('Error processing employee ' + emp.Name + ': ' + e.getMessage());
            }
        }
        
        System.debug('Processed ' + activeEmployees.size() + ' employees');
    }
    
    /**
     * Reset balances for new calendar year (Runs on Jan 1st)
     */
    public static void resetBalancesForNewYear(String newYear) {
        String previousYear = String.valueOf(Integer.valueOf(newYear) - 1);
        
        // Get all balances from previous year with carry forward allowed
        List<Employee_Leave_Balance__c> previousYearBalances = [
            SELECT Id, Employee__c, Leave_Type__c, 
                   Total_Allocated__c, Used__c, Booked__c, Pending_Approval__c, Carried_Forward__c,
                   Leave_Type__r.Carry_Forward_Allowed__c, 
                   Leave_Type__r.Max_Carry_Forward_Days__c,
                   Leave_Type__r.Leave_Code__c
            FROM Employee_Leave_Balance__c
            WHERE Year__c = :previousYear
            AND Is_Active__c = true
            AND Leave_Type__r.Carry_Forward_Allowed__c = true
        ];
        
        Map<String, Decimal> carryForwardMap = new Map<String, Decimal>();
        
        for (Employee_Leave_Balance__c bal : previousYearBalances) {
            // Calculate available
            Decimal available = bal.Total_Allocated__c - bal.Used__c - bal.Booked__c - bal.Pending_Approval__c + bal.Carried_Forward__c;
            
            if (available > 0) {
                Decimal carryForward = available;
                
                // Apply max carry forward limit
                if (bal.Leave_Type__r.Max_Carry_Forward_Days__c != null) {
                    carryForward = Math.min(carryForward, bal.Leave_Type__r.Max_Carry_Forward_Days__c);
                }
                
                String key = String.valueOf(bal.Employee__c) + '_' + String.valueOf(bal.Leave_Type__c);
                carryForwardMap.put(key, carryForward);
            }
        }
        
        // Create new year balances with full allocation (12 days for CL/SL)
        List<User> activeEmployees = [
            SELECT Id FROM User 
            WHERE IsActive = true 
            AND Employee_Id__c != null
            AND Date_of_Joining__c != null
            LIMIT 200
        ];
        
        for (User emp : activeEmployees) {
            try {
                createEligibleBalancesForEmployee(emp.Id, newYear);
            } catch (Exception e) {
                System.debug('Error processing employee for new year: ' + e.getMessage());
            }
        }
        
        // Update carry forward amounts
        List<Employee_Leave_Balance__c> newYearBalances = [
            SELECT Id, Employee__c, Leave_Type__c, Carried_Forward__c
            FROM Employee_Leave_Balance__c
            WHERE Year__c = :newYear
        ];
        
        List<Employee_Leave_Balance__c> toUpdate = new List<Employee_Leave_Balance__c>();
        
        for (Employee_Leave_Balance__c bal : newYearBalances) {
            String key = String.valueOf(bal.Employee__c) + '_' + String.valueOf(bal.Leave_Type__c);
            if (carryForwardMap.containsKey(key)) {
                bal.Carried_Forward__c = carryForwardMap.get(key);
                toUpdate.add(bal);
            }
        }
        
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('Applied carry forward to ' + toUpdate.size() + ' balances');
        }
        
        System.debug('✅ New year reset complete. All CL/SL balances reset to 12 days.');
    }
}