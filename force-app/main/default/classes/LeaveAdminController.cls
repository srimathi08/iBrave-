public with sharing class LeaveAdminController {
    
    @AuraEnabled(cacheable=true)
    public static List<Leave_Type__c> getLeaveTypes() {
        try {
            return [
                SELECT Id, Name, Leave_Type_Name__c, Leave_Code__c, 
                       Default_Allocation__c, Description__c, Icon_Name__c, 
                       Color_Code__c, Is_Active__c, Requires_Approval__c, 
                       Carry_Forward_Allowed__c, Max_Carry_Forward_Days__c, 
                       Minimum_Notice_Days__c, Maximum_Consecutive_Days__c,
                       Accrual_Type__c, Sort_Order__c, CreatedDate, LastModifiedDate
                FROM Leave_Type__c
                ORDER BY Sort_Order__c ASC, Leave_Type_Name__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave types: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Holiday__c> getHolidays() {
        try {
            return [
                SELECT Id, Name, Holiday_Date__c, Description__c, 
                       Holiday_Type__c, Is_Recurring__c, Is_Active__c, 
                       Applicable_Departments__c, Icon_Name__c, 
                       Color_Code__c, Sort_Order__c, CreatedDate, LastModifiedDate
                FROM Holiday__c
                ORDER BY Holiday_Date__c DESC
                LIMIT 500
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching holidays: ' + e.getMessage());
        }
    }
    
    /**
     * Save Leave Type - FIXED VERSION
     */
    @AuraEnabled
    public static String saveLeaveType(Leave_Type__c leaveType) {
        try {
            // Validate
            if (String.isBlank(leaveType.Leave_Type_Name__c)) {
                throw new AuraHandledException('Leave Type Name is required');
            }
            if (String.isBlank(leaveType.Leave_Code__c)) {
                throw new AuraHandledException('Leave Code is required');
            }
            
            // Check duplicate
            List<Leave_Type__c> existingTypes = [
                SELECT Id 
                FROM Leave_Type__c 
                WHERE Leave_Code__c = :leaveType.Leave_Code__c 
                AND Id != :leaveType.Id
                LIMIT 1
            ];
            
            if (!existingTypes.isEmpty()) {
                throw new AuraHandledException('Leave Code already exists.');
            }
            
            Boolean isNewRecord = (leaveType.Id == null);
            
            // Save Leave Type
            upsert leaveType;
            
            System.debug('Leave Type saved: ' + leaveType.Id + ', isNew: ' + isNewRecord + ', isActive: ' + leaveType.Is_Active__c);
            
            // Create balances if new and active
            if (isNewRecord && leaveType.Is_Active__c) {
                Integer balancesCreated = createBalancesForLeaveType(leaveType.Id);
                System.debug('Balances created: ' + balancesCreated);
            }
            
            return leaveType.Id;
            
        } catch (Exception e) {
            System.debug('Error in saveLeaveType: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
  /**
 * Create balances for a specific leave type
 * This ensures Default_Allocation flows to Total_Allocated
 */
private static Integer createBalancesForLeaveType(Id leaveTypeId) {
    // Get leave type with default allocation
    Leave_Type__c lt = [
        SELECT Id, Leave_Type_Name__c, Default_Allocation__c 
        FROM Leave_Type__c 
        WHERE Id = :leaveTypeId 
        LIMIT 1
    ];
    
    System.debug('Creating balances for: ' + lt.Leave_Type_Name__c + ' with default allocation: ' + lt.Default_Allocation__c);
    
    // Get all active users with Employee_Id
    List<User> users = [
        SELECT Id, Name, Employee_Id__c
        FROM User 
        WHERE IsActive = true 
        AND Employee_Id__c != null
    ];
    
    System.debug('Found ' + users.size() + ' active users with Employee_Id');
    
    String year = String.valueOf(Date.today().year());
    List<Employee_Leave_Balance__c> balances = new List<Employee_Leave_Balance__c>();
    
    for (User u : users) {
        // Check if balance exists
        Integer existing = [
            SELECT COUNT() 
            FROM Employee_Leave_Balance__c 
            WHERE Employee__c = :u.Id 
            AND Leave_Type__c = :leaveTypeId 
            AND Year__c = :year
        ];
        
        if (existing == 0) {
            Employee_Leave_Balance__c newBalance = new Employee_Leave_Balance__c(
                Employee__c = u.Id,
                Leave_Type__c = leaveTypeId,
                Year__c = year,
                Total_Allocated__c = lt.Default_Allocation__c, // ← DEFAULT ALLOCATION FLOWS HERE
                Used__c = 0,
                Booked__c = 0,
                Pending_Approval__c = 0,
                Carried_Forward__c = 0,
                Is_Active__c = true
            );
            balances.add(newBalance);
            
            System.debug('Creating balance for user ' + u.Name + ': ' + lt.Default_Allocation__c + ' days');
        }
    }
    
    if (!balances.isEmpty()) {
        insert balances;
        System.debug('✓ Inserted ' + balances.size() + ' balance records');
        
        // Verify insertion
        for (Employee_Leave_Balance__c bal : [
            SELECT Id, Employee__r.Name, Total_Allocated__c, Available__c 
            FROM Employee_Leave_Balance__c 
            WHERE Id IN :balances
        ]) {
            System.debug('Verified: ' + bal.Employee__r.Name + ' - Total: ' + bal.Total_Allocated__c + ', Available: ' + bal.Available__c);
        }
    }
    
    return balances.size();
}

    
   /**
 * OPTIMIZED: Manual sync method - Creates balances for ALL leave types
 * Governor-limit safe with bulk operations
 */
@AuraEnabled
public static String syncAllBalances() {
    try {
        // Get all active leave types
        List<Leave_Type__c> leaveTypes = [
            SELECT Id, Default_Allocation__c, Leave_Type_Name__c
            FROM Leave_Type__c 
            WHERE Is_Active__c = true
        ];
        
        if (leaveTypes.isEmpty()) {
            return 'No active leave types found. Please create leave types first.';
        }
        
        // Get all active users with Employee_Id
        List<User> users = [
            SELECT Id, Name, Employee_Id__c
            FROM User 
            WHERE IsActive = true 
            AND Employee_Id__c != null
            LIMIT 1000
        ];
        
        if (users.isEmpty()) {
            return 'No active users with Employee_Id found. Please ensure users have Employee_Id populated.';
        }
        
        String year = String.valueOf(Date.today().year());
        
        // Build a Set of existing balance keys for quick lookup
        Set<String> existingKeys = new Set<String>();
        List<Employee_Leave_Balance__c> existingBalances = [
            SELECT Id, Employee__c, Leave_Type__c, Year__c
            FROM Employee_Leave_Balance__c
            WHERE Year__c = :year
        ];
        
        for (Employee_Leave_Balance__c bal : existingBalances) {
            String key = String.valueOf(bal.Employee__c) + '_' + String.valueOf(bal.Leave_Type__c) + '_' + bal.Year__c;
            existingKeys.add(key);
        }
        
        // Create missing balances
        List<Employee_Leave_Balance__c> balancesToCreate = new List<Employee_Leave_Balance__c>();
        
        for (Leave_Type__c lt : leaveTypes) {
            for (User u : users) {
                String key = String.valueOf(u.Id) + '_' + String.valueOf(lt.Id) + '_' + year;
                
                if (!existingKeys.contains(key)) {
                    balancesToCreate.add(new Employee_Leave_Balance__c(
                        Employee__c = u.Id,
                        Leave_Type__c = lt.Id,
                        Year__c = year,
                        Total_Allocated__c = lt.Default_Allocation__c != null ? lt.Default_Allocation__c : 0,
                        Used__c = 0,
                        Booked__c = 0,
                        Pending_Approval__c = 0,
                        Carried_Forward__c = 0,
                        Is_Active__c = true
                    ));
                }
            }
        }
        
        if (!balancesToCreate.isEmpty()) {
            insert balancesToCreate;
            System.debug('Successfully created ' + balancesToCreate.size() + ' balance records');
            return 'Success! Created ' + balancesToCreate.size() + ' balance records for ' + users.size() + ' users and ' + leaveTypes.size() + ' leave types.';
        } else {
            return 'All employee leave balances already exist. No new records needed.';
        }
        
    } catch (DmlException e) {
        System.debug('DML Error in syncAllBalances: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Database error: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        System.debug('Error in syncAllBalances: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error syncing balances: ' + e.getMessage());
    }
}

    
    @AuraEnabled
    public static void deleteLeaveType(String leaveTypeId) {
        try {
            Leave_Type__c lt = [SELECT Id FROM Leave_Type__c WHERE Id = :leaveTypeId LIMIT 1];
            delete lt;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveHoliday(Holiday__c holiday) {
        try {
            upsert holiday;
            return holiday.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteHoliday(String holidayId) {
        try {
            Holiday__c h = [SELECT Id FROM Holiday__c WHERE Id = :holidayId LIMIT 1];
            delete h;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
  	
    @AuraEnabled
public static List<Leave_Request__c> searchLeaveRequests(Map<String, String> filters) {
    try {
        String query = 'SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Employee_Id__c, ' +
                      'Employee__r.Department, Leave_Type__c, Leave_Type__r.Leave_Type_Name__c, ' +
                      'Leave_Type__r.Leave_Code__c, Start_Date__c, End_Date__c, Total_Days__c, ' +
                      'Reason__c, Status__c, Manager__c, Manager__r.Name, Manager_Comments__c, ' +
                      'Applied_Date__c, Approved_By__c, Approved_By__r.Name, Approved_Date__c, ' +
                      'Rejected_Date__c, Cancelled_Date__c ' +
                      'FROM Leave_Request__c ' +
                      'WHERE Is_Active__c = true';
        
        // FIXED: Employee ID - Handle as Decimal
        if (String.isNotBlank(filters.get('employeeId'))) {
            try {
                Decimal empId = Decimal.valueOf(filters.get('employeeId'));
                query += ' AND Employee__r.Employee_Id__c = ' + empId;
            } catch (Exception e) {
                // Invalid number format - skip filter
                System.debug('Invalid Employee ID format: ' + filters.get('employeeId'));
            }
        }
        
        if (String.isNotBlank(filters.get('employeeName'))) {
            query += ' AND Employee__r.Name LIKE \'%' + String.escapeSingleQuotes(filters.get('employeeName')) + '%\'';
        }
        
        if (String.isNotBlank(filters.get('department'))) {
            query += ' AND Employee__r.Department LIKE \'%' + String.escapeSingleQuotes(filters.get('department')) + '%\'';
        }
        
        // FIXED: Leave Type - Check if not empty
        if (String.isNotBlank(filters.get('leaveTypeId')) && filters.get('leaveTypeId') != '') {
            query += ' AND Leave_Type__c = \'' + String.escapeSingleQuotes(filters.get('leaveTypeId')) + '\'';
        }
        
        if (String.isNotBlank(filters.get('status'))) {
            query += ' AND Status__c = \'' + String.escapeSingleQuotes(filters.get('status')) + '\'';
        }
        
        if (String.isNotBlank(filters.get('startDateFrom'))) {
            query += ' AND Start_Date__c >= ' + filters.get('startDateFrom');
        }
        
        if (String.isNotBlank(filters.get('startDateTo'))) {
            query += ' AND Start_Date__c <= ' + filters.get('startDateTo');
        }
        
        query += ' ORDER BY Applied_Date__c DESC LIMIT 1000';
        
        return Database.query(query);
        
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}

@AuraEnabled
public static String exportLeaveRequestsToCSV(Map<String, String> filters) {
    try {
        List<Leave_Request__c> requests = searchLeaveRequests(filters);
        
        // CSV Header
        String csv = 'Request Number,Employee ID,Employee Name,Department,Leave Type,Start Date,End Date,Total Days,Reason,Status,Manager,Manager Comments,Applied Date,Approved/Rejected By,Action Date\n';
        
        for (Leave_Request__c req : requests) {
            csv += '"' + (req.Name != null ? req.Name : '') + '",';
            csv += '"' + (req.Employee__r.Employee_Id__c != null ? String.valueOf(req.Employee__r.Employee_Id__c) : '') + '",';
            csv += '"' + (req.Employee__r.Name != null ? req.Employee__r.Name : '') + '",';
            csv += '"' + (req.Employee__r.Department != null ? req.Employee__r.Department : '') + '",';
            
            // FIXED: Null check for Leave Type
            if (req.Leave_Type__r != null) {
                csv += '"' + req.Leave_Type__r.Leave_Type_Name__c + '",';
            } else {
                csv += '"",';
            }
            
            csv += '"' + (req.Start_Date__c != null ? req.Start_Date__c.format() : '') + '",';
            csv += '"' + (req.End_Date__c != null ? req.End_Date__c.format() : '') + '",';
            csv += '"' + (req.Total_Days__c != null ? String.valueOf(req.Total_Days__c) : '0') + '",';
            csv += '"' + (req.Reason__c != null ? req.Reason__c.replaceAll('"', '""') : '') + '",';
            csv += '"' + (req.Status__c != null ? req.Status__c : '') + '",';
            csv += '"' + (req.Manager__r != null ? req.Manager__r.Name : '') + '",';
            csv += '"' + (req.Manager_Comments__c != null ? req.Manager_Comments__c.replaceAll('"', '""') : '') + '",';
            csv += '"' + (req.Applied_Date__c != null ? req.Applied_Date__c.format() : '') + '",';
            csv += '"' + (req.Approved_By__r != null ? req.Approved_By__r.Name : '') + '",';
            
            String actionDate = '';
            if (req.Approved_Date__c != null) {
                actionDate = req.Approved_Date__c.format();
            } else if (req.Rejected_Date__c != null) {
                actionDate = req.Rejected_Date__c.format();
            } else if (req.Cancelled_Date__c != null) {
                actionDate = req.Cancelled_Date__c.format();
            }
            csv += '"' + actionDate + '"\n';
        }
        
        return csv;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


}