public with sharing class EmployeeAllocationController {
    
    private static final Integer PAGE_SIZE = 10; // Show 10 employees per page
    
    /**
     * Get paginated employees with balances
     */
   @AuraEnabled
public static PaginatedResult getEmployeesWithBalancesPaginated(Integer pageNumber, String searchKey) {
    try {
        String currentYear = String.valueOf(Date.today().year());
        
        // Build dynamic query
        String whereClause = 'WHERE IsActive = true AND Employee_Id__c != null';
        
        // FIXED: Add search filter INCLUDING Employee_Id__c
        if (String.isNotBlank(searchKey)) {
            String searchPattern = '%' + searchKey + '%';
            
            // Try to parse as number for Employee_Id search
            Decimal employeeIdSearch = null;
            try {
                employeeIdSearch = Decimal.valueOf(searchKey);
            } catch (Exception e) {
                // Not a number, skip numeric search
            }
            
            // Search by Name, Email, OR Employee_Id__c
            if (employeeIdSearch != null) {
                whereClause += ' AND (Name LIKE :searchPattern OR Email LIKE :searchPattern OR Employee_Id__c = :employeeIdSearch)';
            } else {
                whereClause += ' AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)';
            }
        }
        
        // Get total count
        String countQuery = 'SELECT COUNT() FROM User ' + whereClause;
        Integer totalRecords = Database.countQuery(countQuery);
        
        // Calculate offset
        Integer offset = (pageNumber - 1) * PAGE_SIZE;
        
        // Get paginated users
        String query = 'SELECT Id, Name, Email, Employee_Id__c, SmallPhotoUrl ' +
                      'FROM User ' + whereClause + ' ' +
                      'ORDER BY Name LIMIT :PAGE_SIZE OFFSET :offset';
        
        List<User> users = Database.query(query);
        
        List<EmployeeWithBalances> employees = new List<EmployeeWithBalances>();
        
        for (User usr : users) {
            // Get balances for this employee
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Total_Allocated__c, Used__c, Booked__c, 
                       Pending_Approval__c, Available__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Leave_Code__c,
                       Leave_Type__r.Sort_Order__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :usr.Id
                AND Year__c = :currentYear
                AND Is_Active__c = true
                ORDER BY Leave_Type__r.Sort_Order__c
            ];
            
            EmployeeWithBalances empData = new EmployeeWithBalances();
            empData.Id = usr.Id;
            empData.Name = usr.Name;
            empData.Email = usr.Email;
            empData.EmployeeId = usr.Employee_Id__c;
            empData.photoUrl = usr.SmallPhotoUrl;
            empData.balances = balances;
            
            employees.add(empData);
        }
        
        // Build paginated result
        PaginatedResult result = new PaginatedResult();
        result.employees = employees;
        result.totalRecords = totalRecords;
        result.pageSize = PAGE_SIZE;
        result.pageNumber = pageNumber;
        result.totalPages = (Integer) Math.ceil((Decimal) totalRecords / PAGE_SIZE);
        
        return result;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}

    /**
     * Legacy method (for backward compatibility)
     */
    @AuraEnabled
    public static List<EmployeeWithBalances> getEmployeesWithBalances() {
        PaginatedResult result = getEmployeesWithBalancesPaginated(1, null);
        return result.employees;
    }
    
    @AuraEnabled
    public static void updateEmployeeBalances(List<Employee_Leave_Balance__c> balances) {
        try {
            if (balances == null || balances.isEmpty()) {
                throw new AuraHandledException('No balances to update');
            }
            
            update balances;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating balances: ' + e.getMessage());
        }
    }
    
    // Wrapper classes
    public class PaginatedResult {
        @AuraEnabled public List<EmployeeWithBalances> employees;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer totalPages;
    }
    
    public class EmployeeWithBalances {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Email;
        @AuraEnabled public Double EmployeeId;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public List<Employee_Leave_Balance__c> balances;
    }
}