/**
 * Controller for Leave Balance Matrix Report Component
 * Provides employee leave balances in matrix format for reporting
 */
public with sharing class LeaveBalanceMatrixController {
    
    /**
     * Get Leave Balance Matrix Data
     * Returns ONLY ELIGIBLE employee leave balances for specified year
     * Non-eligible leave types will show as N/A in the UI
     */
    @AuraEnabled
    public static List<Employee_Leave_Balance__c> getLeaveBalanceMatrix(String month, String year) {
        try {
            // Validate inputs
            if (String.isBlank(year)) {
                throw new AuraHandledException('Year is required');
            }
            
            // Query ONLY ELIGIBLE employee leave balances for the specified year
            // This ensures we only get leave types the employee is actually eligible for
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, 
                       Employee__c,
                       Employee__r.Name,
                       Employee__r.Email,
                       Employee__r.Employee_Id__c,
                       Employee__r.Department,
                       Employee__r.Gender__c,
                       Employee__r.Marital_Status__c,
                       Leave_Type__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Sort_Order__c,
                       Total_Allocated__c,
                       Available__c,
                       Used__c,
                       Booked__c,
                       Pending_Approval__c,
                       Carried_Forward__c,
                       Is_Eligible__c,
                       Eligibility_Reason__c,
                       Is_Active__c
                FROM Employee_Leave_Balance__c
                WHERE Year__c = :year
                AND Is_Active__c = true
                AND Is_Eligible__c = true  // ✅ CRITICAL: Only eligible leave types
                AND Employee__r.IsActive = true
                ORDER BY Employee__r.Name ASC, Leave_Type__r.Sort_Order__c ASC NULLS LAST
            ];
            
            System.debug('✅ Found ' + balances.size() + ' ELIGIBLE leave balance records for ' + year);
            System.debug('   These are only the leave types each employee is eligible for');
            System.debug('   Non-eligible types (e.g., Maternity for males) will show as N/A in UI');
            
            return balances;
            
        } catch (Exception e) {
            System.debug('❌ Error in getLeaveBalanceMatrix: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching matrix data: ' + e.getMessage());
        }
    }
    
    /**
     * Get All Active Leave Types (for column headers)
     * Returns ALL leave types regardless of employee eligibility
     * This ensures all columns are shown in the matrix
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Type__c> getAllActiveLeaveTypes() {
        try {
            List<Leave_Type__c> leaveTypes = [
                SELECT Id, 
                       Leave_Type_Name__c, 
                       Leave_Code__c,
                       Sort_Order__c,
                       Icon_Name__c,
                       Color_Code__c,
                       Is_Fallback_Leave__c
                FROM Leave_Type__c
                WHERE Is_Active__c = true
                AND Is_Fallback_Leave__c = false  // ✅ Exclude LOP from matrix
                ORDER BY Sort_Order__c ASC NULLS LAST, Leave_Type_Name__c ASC
            ];
            
            System.debug('✅ Found ' + leaveTypes.size() + ' active leave types for matrix columns');
            
            return leaveTypes;
            
        } catch (Exception e) {
            System.debug('❌ Error in getAllActiveLeaveTypes: ' + e.getMessage());
            throw new AuraHandledException('Error fetching leave types: ' + e.getMessage());
        }
    }
    
    /**
     * Get Matrix Summary Statistics
     */
    @AuraEnabled
    public static Map<String, Object> getMatrixSummary(String month, String year) {
        try {
            Map<String, Object> summary = new Map<String, Object>();
            
            // Count active employees with leave balances
            List<AggregateResult> empCount = [
                SELECT COUNT_DISTINCT(Employee__c) empCount
                FROM Employee_Leave_Balance__c
                WHERE Year__c = :year
                AND Is_Active__c = true
                AND Employee__r.IsActive = true
            ];
            
            summary.put('totalEmployees', empCount[0].get('empCount'));
            
            // Count active leave types (excluding fallback leaves like LOP)
            Integer leaveTypeCount = [
                SELECT COUNT() 
                FROM Leave_Type__c 
                WHERE Is_Active__c = true
                AND Is_Fallback_Leave__c = false
            ];
            
            summary.put('totalLeaveTypes', leaveTypeCount);
            
            // Total allocated days across all employees
            List<AggregateResult> totalAllocated = [
                SELECT SUM(Total_Allocated__c) totalDays
                FROM Employee_Leave_Balance__c
                WHERE Year__c = :year
                AND Is_Active__c = true
                AND Is_Eligible__c = true
            ];
            
            summary.put('totalAllocatedDays', totalAllocated[0].get('totalDays'));
            
            return summary;
            
        } catch (Exception e) {
            System.debug('❌ Error in getMatrixSummary: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}