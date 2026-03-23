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
                       Number_of_Children__c, Employment_Type__c, Email,
                       Employee_IDs__c
                FROM User
                WHERE Id = :employeeId
                LIMIT 1
            ];

            if (emp.Date_of_Joining__c == null) {
                System.debug('Employee has no Date of Joining: ' + emp.Name);
                return;
            }

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

            // Existing balances
            Map<Id, Employee_Leave_Balance__c> existingBalancesMap = new Map<Id, Employee_Leave_Balance__c>();
            for (Employee_Leave_Balance__c bal : [
                SELECT Id, Leave_Type__c, Total_Allocated__c, Used__c, Booked__c,
                       Pending_Approval__c, Lifetime_Usage_Count__c, Carried_Forward__c,
                       Is_Eligible__c, Eligibility_Reason__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Year__c = :year
            ]) {
                existingBalancesMap.put(bal.Leave_Type__c, bal);
            }

            Boolean allLeavesExhausted = checkIfAllLeavesExhausted(existingBalancesMap, leaveTypes);
            List<Employee_Leave_Balance__c> balancesToUpsert = new List<Employee_Leave_Balance__c>();

            for (Leave_Type__c lt : leaveTypes) {
                EligibilityResult eligibility = checkEligibility(emp, lt, serviceMonths);

                if (lt.Is_Fallback_Leave__c && !allLeavesExhausted) {
                    eligibility.isEligible = false;
                    eligibility.reason = 'Available only when all other leaves are exhausted';
                }

                Employee_Leave_Balance__c balance = existingBalancesMap.get(lt.Id);

                if (balance == null) {
			
						if(!eligibility.isEligible){
        continue; // Skip creation
    }
                    balancesToUpsert.add(
                        createNewBalance(emp, lt, year, serviceMonths, eligibility)
                    );
                } else {
                    balance.Is_Eligible__c = eligibility.isEligible;
                    balance.Eligibility_Reason__c = eligibility.reason;

                    Decimal newAllocation = calculateAllocation(emp, lt, year, serviceMonths);

                    if (balance.Used__c == 0 && balance.Booked__c == 0 && balance.Pending_Approval__c == 0) {
                        balance.Total_Allocated__c = newAllocation;
                    }
                    balancesToUpsert.add(balance);
                }
            }

            if (!balancesToUpsert.isEmpty()) {
                upsert balancesToUpsert;
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error creating leave balances: ' + e.getMessage());
        }
    }

    /**
     * Eligibility Result Wrapper
     */
    public class EligibilityResult {
        public Boolean isEligible;
        public String reason;

        public EligibilityResult(Boolean eligible, String msg) {
            isEligible = eligible;
            reason = msg;
        }
    }

    /**
     * Eligibility check logic
     */
    private static EligibilityResult checkEligibility(User emp, Leave_Type__c lt, Integer serviceMonths) {

        if (lt.Minimum_Service_Months__c != null && serviceMonths < lt.Minimum_Service_Months__c) {
            return new EligibilityResult(false,
                'Requires ' + lt.Minimum_Service_Months__c + ' months of service');
        }

        if (String.isNotBlank(lt.Applicable_Gender__c) &&
            lt.Applicable_Gender__c != 'All' &&
            lt.Applicable_Gender__c != emp.Gender__c) {
            return new EligibilityResult(false, 'Applicable only for ' + lt.Applicable_Gender__c);
        }

        if (String.isNotBlank(lt.Requires_Marital_Status__c) &&
            lt.Requires_Marital_Status__c != 'Any') {

            if (String.isBlank(emp.Marital_Status__c) ||
                emp.Marital_Status__c != lt.Requires_Marital_Status__c) {
                return new EligibilityResult(false,
                    'Requires marital status: ' + lt.Requires_Marital_Status__c);
            }
        }

        if (String.isNotBlank(lt.Applicable_Employment_Types__c) &&
            String.isNotBlank(emp.Employment_Type__c)) {

            Set<String> allowedTypes = new Set<String>(lt.Applicable_Employment_Types__c.split(';'));
            if (!allowedTypes.contains(emp.Employment_Type__c)) {
                return new EligibilityResult(false,
                    'Not applicable for ' + emp.Employment_Type__c);
            }
        }

        return new EligibilityResult(true, 'Eligible');
    }

    /**
     * Create new balance
     */
    private static Employee_Leave_Balance__c createNewBalance(
        User emp, Leave_Type__c lt, String year,
        Integer serviceMonths, EligibilityResult eligibility
    ) {
        return new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = year,
            Total_Allocated__c = calculateAllocation(emp, lt, year, serviceMonths),
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
    }

    /**
     * Allocation calculation
     */
    private static Decimal calculateAllocation(User emp, Leave_Type__c lt, String year, Integer serviceMonths) {
        Decimal allocation = lt.Default_Allocation__c == null ? 0 : lt.Default_Allocation__c;
        Integer joinYear = emp.Date_of_Joining__c.year();
        Integer currentYear = Integer.valueOf(year);

        if (joinYear == currentYear && (lt.Leave_Code__c == 'CL' || lt.Leave_Code__c == 'SL')) {
            Integer remainingMonths = 12 - emp.Date_of_Joining__c.month() + 1;
            allocation = Math.floor((lt.Default_Allocation__c / 12) * remainingMonths);
        }

 if (lt.Leave_Code__c == 'EL') {
            if (serviceMonths < 12) {
                // No earned leave until 1 full year of service is completed
                allocation = 0;
            } else {
                // From month 13 onwards, 1 EL is earned per month beyond the first 12
                // Examples:
                //   13 months of service → 1 EL
                //   14 months of service → 2 EL
                //   24 months of service → 12 EL
                //   57 months of service → 45 EL  (cap reached)
                //   72 months of service → 45 EL  (still capped at 45)
                Integer monthsEarning = serviceMonths - 12;
                allocation = Math.min(monthsEarning, 45);
            }
        }

        return allocation;
    }

    private static Integer calculateServiceMonths(Date doj) {
        return doj == null ? 0 : doj.daysBetween(Date.today()) / 30;
    }

    private static Date calculateEligibleFromDate(Date doj, Leave_Type__c lt) {
        return (doj == null || lt.Minimum_Service_Months__c == null)
            ? doj
            : doj.addMonths(Integer.valueOf(lt.Minimum_Service_Months__c));
    }

    /**
     * Check if all non-fallback leaves exhausted
     */
    private static Boolean checkIfAllLeavesExhausted(
        Map<Id, Employee_Leave_Balance__c> balancesMap,
        List<Leave_Type__c> leaveTypes
    ) {
        for (Leave_Type__c lt : leaveTypes) {
            if (lt.Is_Fallback_Leave__c) continue;

            Employee_Leave_Balance__c bal = balancesMap.get(lt.Id);
            if (bal != null && bal.Is_Eligible__c) {
                Decimal available =
                    bal.Total_Allocated__c - bal.Used__c - bal.Booked__c -
                    bal.Pending_Approval__c + bal.Carried_Forward__c;
                if (available > 0) return false;
            }
        }
        return true;
    }

    /**
     * Create balances for all active employees
     */
    public static void createBalancesForAllEmployees(String year) {
        for (User emp : [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Employee_IDs__c != null
            AND Date_of_Joining__c != null
            LIMIT 200
        ]) {
            createEligibleBalancesForEmployee(emp.Id, year);
        }
    }

    /**
     * Reset balances for new year
     */
    public static void resetBalancesForNewYear(String newYear) {
        List<User> employees = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Employee_IDs__c != null
            AND Date_of_Joining__c != null
            LIMIT 200
        ];

        for (User emp : employees) {
            createEligibleBalancesForEmployee(emp.Id, newYear);
        }
    }
}