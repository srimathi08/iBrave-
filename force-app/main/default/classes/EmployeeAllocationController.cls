public with sharing class EmployeeAllocationController {

    private static final Integer PAGE_SIZE = 10;

    /* =====================================================
     * PAGINATED EMPLOYEES WITH BALANCES
     * ===================================================== */
    @AuraEnabled
    public static PaginatedResult getEmployeesWithBalancesPaginated(
        Integer pageNumber,
        String searchKey
    ) {
        try {
            String currentYear = String.valueOf(Date.today().year());

            /* ---------- WHERE CLAUSE ---------- */
            String whereClause = ' WHERE IsActive = true AND Employee_IDs__c != null';

            if (String.isNotBlank(searchKey)) {
                String escapedKey = String.escapeSingleQuotes(searchKey);
                String searchPattern = '%' + escapedKey + '%';

                whereClause +=
                    ' AND (' +
                    ' Name LIKE \'' + searchPattern + '\'' +
                    ' OR Email LIKE \'' + searchPattern + '\'' +
                    ' OR Employee_IDs__c LIKE \'' + searchPattern + '\'' +
                    ' )';
            }

            /* ---------- COUNT QUERY ---------- */
            Integer totalRecords = Database.countQuery(
                'SELECT COUNT() FROM User' + whereClause
            );

            Integer offset = (pageNumber - 1) * PAGE_SIZE;

            /* ---------- USER QUERY ---------- */
            String userQuery =
                'SELECT Id, Name, Email, Employee_IDs__c, SmallPhotoUrl ' +
                'FROM User ' +
                whereClause +
                ' ORDER BY Name ' +
                'LIMIT ' + PAGE_SIZE +
                ' OFFSET ' + offset;

            List<User> users = Database.query(userQuery);

            List<EmployeeWithBalances> employees = new List<EmployeeWithBalances>();

            /* ---------- FETCH BALANCES ---------- */
            for (User usr : users) {

                List<Employee_Leave_Balance__c> balances = [
                    SELECT Id,
                           Total_Allocated__c,
                           Used__c,
                           Booked__c,
                           Pending_Approval__c,
                           Available__c,
                           Leave_Type__r.Leave_Type_Name__c,
                           Leave_Type__r.Leave_Code__c,
                           Leave_Type__r.Sort_Order__c
                    FROM Employee_Leave_Balance__c
                    WHERE Employee__c = :usr.Id
                    AND Year__c = :currentYear
                    AND Is_Active__c = true
                    ORDER BY Leave_Type__r.Sort_Order__c
                ];

                EmployeeWithBalances emp = new EmployeeWithBalances();
                emp.Id = usr.Id;
                emp.Name = usr.Name;
                emp.Email = usr.Email;
                emp.EmployeeId = usr.Employee_IDs__c; // TEXT
                emp.photoUrl = usr.SmallPhotoUrl;
                emp.balances = balances;

                employees.add(emp);
            }

            /* ---------- RESULT ---------- */
            PaginatedResult result = new PaginatedResult();
            result.employees = employees;
            result.totalRecords = totalRecords;
            result.pageSize = PAGE_SIZE;
            result.pageNumber = pageNumber;
            result.totalPages =
                (Integer) Math.ceil((Decimal) totalRecords / PAGE_SIZE);

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error fetching employees: ' + e.getMessage());
        }
    }

    /* =====================================================
     * LEGACY METHOD
     * ===================================================== */
    @AuraEnabled
    public static List<EmployeeWithBalances> getEmployeesWithBalances() {
        return getEmployeesWithBalancesPaginated(1, null).employees;
    }

    /* =====================================================
     * UPDATE BALANCES
     * ===================================================== */
    @AuraEnabled
    public static void updateEmployeeBalances(
        List<Employee_Leave_Balance__c> balances
    ) {
        if (balances == null || balances.isEmpty()) {
            throw new AuraHandledException('No balances to update');
        }

        try {
            update balances;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error updating balances: ' + e.getMessage()
            );
        }
    }

    /* =====================================================
     * WRAPPERS
     * ===================================================== */
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
        @AuraEnabled public String EmployeeId; // ✅ TEXT
        @AuraEnabled public String photoUrl;
        @AuraEnabled public List<Employee_Leave_Balance__c> balances;
    }
}