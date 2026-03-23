/*public with sharing class TimesheetAdminController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardStats(String startDate, String endDate) {
        try {
System.debug('getDashboardStats called with startDate: ' + startDate + ', endDate: ' + endDate);
            Date sDate = Date.valueOf(startDate);
            Date eDate = Date.valueOf(endDate);
            
            List<TimesheetEntry__c> entries = [
                SELECT Id, Total_Hours__c, Approval_Status__c, Timesheet__r.Employee__c,Project__c
                FROM TimesheetEntry__c 
                WHERE Date__c >= :sDate AND Date__c <= :eDate
            ];
            System.debug('Found ' + entries.size() + ' timesheet entries');
            Decimal totalHours = 0;
            Decimal approvedHours = 0;
            Integer pendingCount = 0;
            Integer rejectedCount = 0;
            Set<Id> employeeIds = new Set<Id>();
            Set<Id> projectIds = new Set<Id>();
            
            for(TimesheetEntry__c entry : entries) {
                totalHours += entry.Total_Hours__c != null ? entry.Total_Hours__c : 0;
                
                if(entry.Approval_Status__c == 'Approved') {
                    approvedHours += entry.Total_Hours__c != null ? entry.Total_Hours__c : 0;
                } else if(entry.Approval_Status__c == 'Pending') {
                    pendingCount++;
                } else if(entry.Approval_Status__c == 'Rejected') {
                    rejectedCount++;
                }
                
                if(entry.Timesheet__r.Employee__c != null) {
                    employeeIds.add(entry.Timesheet__r.Employee__c);
                }
                if(entry.Project__c != null) {
                    projectIds.add(entry.Project__c);
                }
            }
            
            Map<String, Object> stats = new Map<String, Object>();
            stats.put('totalHours', totalHours);
            stats.put('pendingApprovals', pendingCount);
            stats.put('approvedHours', approvedHours);
            stats.put('rejectedEntries', rejectedCount);
            stats.put('totalEmployees', employeeIds.size());
            stats.put('activeProjects', projectIds.size());
            System.debug('Stats: ' + stats);
            return stats;
        } catch (Exception e) {
System.debug('Error in getDashboardStats: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching dashboard stats: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TimesheetEntryWrapper> getTimesheetEntries(
        String startDate, 
        String endDate, 
        String employeeFilter,
        String departmentFilter,
        String projectFilter,
        String statusFilter
    ) {
        try {
            Date sDate = Date.valueOf(startDate);
            Date eDate = Date.valueOf(endDate);
            
            String query = 'SELECT Id, Timesheet__r.Employee__r.Name, ' +
                          'Timesheet__r.Employee__r.Department, ' +
                          'Project__r.Name, Date__c, Total_Hours__c, Task__c, Approval_Status__c ' +
                          'FROM TimesheetEntry__c ' +
                          'WHERE Date__c >= :sDate AND Date__c <= :eDate';
            
            if(employeeFilter != 'All Employees') {
                query += ' AND Timesheet__r.Employee__r.Name = :employeeFilter';
            }
            
            if(departmentFilter != 'All Departments') {
                query += ' AND Timesheet__r.Employee__r.Department = :departmentFilter';
            }
            
            if(projectFilter != 'All Projects') {
                query += ' AND Project__r.Name = :projectFilter';
            }
            
            if(statusFilter != 'All Status') {
                query += ' AND Approval_Status__c = :statusFilter';
            }
            
            query += ' ORDER BY Date__c DESC, Timesheet__r.Employee__r.Name';
            System.debug('Final Query: ' + query);
            List<TimesheetEntry__c> entries = Database.query(query);
System.debug('Query returned ' + entries.size() + ' records');
            List<TimesheetEntryWrapper> wrappers = new List<TimesheetEntryWrapper>();
            
            for(TimesheetEntry__c entry : entries) {
                TimesheetEntryWrapper wrapper = new TimesheetEntryWrapper();
                wrapper.id = entry.Id;
                wrapper.employeeName = entry.Timesheet__r.Employee__r.Name;
                wrapper.department = entry.Timesheet__r.Employee__r.Department;
                wrapper.projectName = entry.Project__r.Name;
                wrapper.entryDate = entry.Date__c;
                wrapper.hours = entry.Total_Hours__c;
                wrapper.description = entry.Task__c;
                wrapper.status = entry.Approval_Status__c;
                wrappers.add(wrapper);
            }
            System.debug('Returning ' + wrappers.size() + ' wrappers');
            return wrappers;
        } catch (Exception e) {
 System.debug('ERROR in getTimesheetEntries: ' + e.getMessage());
            throw new AuraHandledException('Error fetching timesheet entries: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String approveTimesheetEntry(String entryId) {
        try {
            TimesheetEntry__c entry = [SELECT Id, Approval_Status__c FROM TimesheetEntry__c WHERE Id = :entryId];
            entry.Approval_Status__c = 'Approved';
            entry.Approved_By__c = UserInfo.getUserId();
            entry.Approved_Date__c = System.now();
            update entry;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error approving entry: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String rejectTimesheetEntry(String entryId, String reason) {
        try {
            TimesheetEntry__c entry = [SELECT Id, Approval_Status__c FROM TimesheetEntry__c WHERE Id = :entryId];
            entry.Approval_Status__c = 'Rejected';
            /*entry.Rejection_Reason__c = reason;
            entry.Rejected_By__c = UserInfo.getUserId();
            entry.Rejection_Date__c = System.now();
            update entry;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting entry: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getFilterOptions(String filterType) {
        List<String> options = new List<String>();
        
        try {
            System.debug('getFilterOptions called for: ' + filterType);
            
            if(filterType == 'employees') {
                options.add('All Employees');
                
                // Get users who have timesheet entries
                Set<Id> employeeIds = new Set<Id>();
                for(Timesheet__c ts : [SELECT Employee__c FROM Timesheet__c WHERE Employee__c != null]) {
                    employeeIds.add(ts.Employee__c);
                }
                
                if(!employeeIds.isEmpty()) {
                    for(User u : [SELECT Name FROM User WHERE Id IN :employeeIds ORDER BY Name]) {
                        options.add(u.Name);
                    }
                }
            } else if(filterType == 'departments') {
                options.add('All Departments');
                
                // Get distinct departments from users with timesheets
                Set<String> departments = new Set<String>();
                for(User u : [
                    SELECT Department 
                    FROM User 
                    WHERE Id IN (SELECT Employee__c FROM Timesheet__c WHERE Employee__c != null)
                    AND Department != null
                ]) {
                    if(String.isNotBlank(u.Department)) {
                        departments.add(u.Department);
                    }
                }
                
                List<String> deptList = new List<String>(departments);
                deptList.sort();
                options.addAll(deptList);
                
            } else if(filterType == 'projects') {
                options.add('All Projects');
                for(Project__c p : [SELECT Name FROM Project__c WHERE Status__c = 'Active' ORDER BY Name]) {
                    options.add(p.Name);
                }
            } else if(filterType == 'status') {
                options.addAll(new List<String>{'All Status', 'Pending', 'Approved', 'Rejected'});
            }
System.debug('Filter options for ' + filterType + ': ' + options);
        } catch (Exception e) {
System.debug('Error in getFilterOptions: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Return at least the default option
            if(options.isEmpty()) {
                options.add('All ' + filterType);
            }
            //throw new AuraHandledException('Error getting filter options: ' + e.getMessage());
        }
        
        return options;
    }
    
    public class TimesheetEntryWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String department;
        @AuraEnabled public String projectName;
        @AuraEnabled public Date entryDate;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public String status;
    }
}*/
/*Used one */
public with sharing class TimesheetAdminController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardStats(String startDate, String endDate) {
        try {
            System.debug('getDashboardStats called with startDate: ' + startDate + ', endDate: ' + endDate);
            Date sDate = Date.valueOf(startDate);
            Date eDate = Date.valueOf(endDate);
            
            List<TimesheetEntry__c> entries = [
                SELECT Id, Total_Hours__c, Approval_Status__c, Timesheet__r.Employee__c, Project__c
                FROM TimesheetEntry__c 
                WHERE Date__c >= :sDate AND Date__c <= :eDate
            ];
            System.debug('Found ' + entries.size() + ' timesheet entries');
            
            Decimal totalHours = 0;
            Decimal approvedHours = 0;
            Integer pendingCount = 0;
            Integer rejectedCount = 0;
            Set<Id> employeeIds = new Set<Id>();
            Set<Id> projectIds = new Set<Id>();
            
            for(TimesheetEntry__c entry : entries) {
                totalHours += entry.Total_Hours__c != null ? entry.Total_Hours__c : 0;
                
                if(entry.Approval_Status__c == 'Approved') {
                    approvedHours += entry.Total_Hours__c != null ? entry.Total_Hours__c : 0;
                } else if(entry.Approval_Status__c == 'Pending') {
                    pendingCount++;
                } else if(entry.Approval_Status__c == 'Rejected') {
                    rejectedCount++;
                }
                
                if(entry.Timesheet__r.Employee__c != null) {
                    employeeIds.add(entry.Timesheet__r.Employee__c);
                }
                if(entry.Project__c != null) {
                    projectIds.add(entry.Project__c);
                }
            }
            
            Map<String, Object> stats = new Map<String, Object>();
            stats.put('totalHours', totalHours);
            stats.put('pendingApprovals', pendingCount);
            stats.put('approvedHours', approvedHours);
            stats.put('rejectedEntries', rejectedCount);
            stats.put('totalEmployees', employeeIds.size());
            stats.put('activeProjects', projectIds.size());
            System.debug('Stats: ' + stats);
            
            return stats;
        } catch (Exception e) {
            System.debug('Error in getDashboardStats: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching dashboard stats: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TimesheetEntryWrapper> getTimesheetEntries(
        String startDate, 
        String endDate, 
        String employeeFilter,
        String departmentFilter,
        String projectFilter,
        String statusFilter
    ) {
        try {
            Date sDate = Date.valueOf(startDate);
            Date eDate = Date.valueOf(endDate);
            
            // Build dynamic query with proper filter handling
            String query = 'SELECT Id, Timesheet__r.Employee__r.Name, ' +
                          'Timesheet__r.Employee__r.Department, ' +
                          'Project__r.Name, Date__c, Total_Hours__c, Task__c, Approval_Status__c ' +
                          'FROM TimesheetEntry__c ' +
                          'WHERE Date__c >= :sDate AND Date__c <= :eDate';
            
            // FIXED: Handle empty/null filter values properly
            if(String.isNotBlank(employeeFilter) && employeeFilter != '' && employeeFilter != 'All Employees') {
                query += ' AND Timesheet__r.Employee__r.Name = :employeeFilter';
            }
           
            if(String.isNotBlank(departmentFilter) && departmentFilter != '' && departmentFilter != 'All Departments') {
                query += ' AND Timesheet__r.Employee__r.Department = :departmentFilter';
            }
            
            if(String.isNotBlank(projectFilter) && projectFilter != '' && projectFilter != 'All Projects') {
                query += ' AND Project__r.Name = :projectFilter';
            }
          
            if(String.isNotBlank(statusFilter) && statusFilter != '' && statusFilter != 'All Status') {
                query += ' AND Approval_Status__c = :statusFilter';
            }
            
            query += ' ORDER BY Date__c DESC, Timesheet__r.Employee__r.Name';
            System.debug('Final Query: ' + query);
            System.debug('Filter params - Employee: ' + employeeFilter + ', Department: ' + departmentFilter + 
                        ', Project: ' + projectFilter + ', Status: ' + statusFilter);
            
            List<TimesheetEntry__c> entries = Database.query(query);
            System.debug('Query returned ' + entries.size() + ' records');
            
            List<TimesheetEntryWrapper> wrappers = new List<TimesheetEntryWrapper>();
            
            for(TimesheetEntry__c entry : entries) {
                TimesheetEntryWrapper wrapper = new TimesheetEntryWrapper();
                wrapper.id = entry.Id;
                wrapper.employeeName = entry.Timesheet__r.Employee__r.Name != null ? 
                                      entry.Timesheet__r.Employee__r.Name : 'N/A';
                wrapper.department = entry.Timesheet__r.Employee__r.Department != null ? 
                                    entry.Timesheet__r.Employee__r.Department : 'N/A';
                wrapper.projectName = entry.Project__r.Name != null ? 
                                     entry.Project__r.Name : 'N/A';
                wrapper.entryDate = entry.Date__c;
                wrapper.hours = entry.Total_Hours__c != null ? entry.Total_Hours__c : 0;
                wrapper.status = entry.Approval_Status__c != null ? entry.Approval_Status__c : 'Pending';
                wrappers.add(wrapper);
            }
            System.debug('Returning ' + wrappers.size() + ' wrappers');
            
            return wrappers;
        } catch (Exception e) {
            System.debug('ERROR in getTimesheetEntries: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching timesheet entries: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String approveTimesheetEntry(String entryId) {
        try {
            TimesheetEntry__c entry = [SELECT Id, Approval_Status__c FROM TimesheetEntry__c WHERE Id = :entryId];
            entry.Approval_Status__c = 'Approved';
            entry.Approved_By__c = UserInfo.getUserId();
            entry.Approved_Date__c = System.now();
            update entry;
            System.debug('Entry ' + entryId + ' approved successfully');
            return 'Success';
        } catch (Exception e) {
            System.debug('Error approving entry: ' + e.getMessage());
            throw new AuraHandledException('Error approving entry: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String rejectTimesheetEntry(String entryId, String reason) {
        try {
            TimesheetEntry__c entry = [SELECT Id, Approval_Status__c FROM TimesheetEntry__c WHERE Id = :entryId];
            entry.Approval_Status__c = 'Rejected';
            // UNCOMMENT these fields if they exist on your TimesheetEntry__c object
            // entry.Rejection_Reason__c = reason;
            // entry.Rejected_By__c = UserInfo.getUserId();
            // entry.Rejection_Date__c = System.now();
            update entry;
            System.debug('Entry ' + entryId + ' rejected with reason: ' + reason);
            return 'Success';
        } catch (Exception e) {
            System.debug('Error rejecting entry: ' + e.getMessage());
            throw new AuraHandledException('Error rejecting entry: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getFilterOptions(String filterType) {
        List<String> options = new List<String>();
        
        try {
            System.debug('getFilterOptions called for: ' + filterType);
            
            if(filterType == 'employees') {
                // Get distinct employee names with timesheet entries using Set
                Set<String> employeeNames = new Set<String>();
                
                for(TimesheetEntry__c te : [
                    SELECT Timesheet__r.Employee__r.Name 
                    FROM TimesheetEntry__c 
                    WHERE Timesheet__r.Employee__r.Name != null
                ]) {
                    if(String.isNotBlank(te.Timesheet__r.Employee__r.Name)) {
                        employeeNames.add(te.Timesheet__r.Employee__r.Name);
                    }
                }
                
                List<String> empList = new List<String>(employeeNames);
                empList.sort();
                options.addAll(empList);
                
            } else if(filterType == 'departments') {
                // Get distinct departments from timesheet entries using Set to eliminate duplicates
                Set<String> departments = new Set<String>();
                
                for(TimesheetEntry__c te : [
                    SELECT Timesheet__r.Employee__r.Department 
                    FROM TimesheetEntry__c 
                    WHERE Timesheet__r.Employee__r.Department != null
                ]) {
                    if(String.isNotBlank(te.Timesheet__r.Employee__r.Department)) {
                        departments.add(te.Timesheet__r.Employee__r.Department);
                    }
                }
                
                List<String> deptList = new List<String>(departments);
                deptList.sort();
                options.addAll(deptList);
                
            } else if(filterType == 'projects') {
                // Get active projects with timesheet entries using Set
                Set<String> projectNames = new Set<String>();
                
                for(TimesheetEntry__c te : [
                    SELECT Project__r.Name 
                    FROM TimesheetEntry__c 
                    WHERE Project__r.Name != null
                ]) {
                    if(String.isNotBlank(te.Project__r.Name)) {
                        projectNames.add(te.Project__r.Name);
                    }
                }
                
                List<String> projList = new List<String>(projectNames);
                projList.sort();
                options.addAll(projList);
                
            } else if(filterType == 'status') {
                options.addAll(new List<String>{'Pending', 'Approved', 'Rejected'});
            }
            
            System.debug('Filter options for ' + filterType + ': ' + options);
        } catch (Exception e) {
            System.debug('Error in getFilterOptions: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        
        return options;
    }
   @AuraEnabled(cacheable=true)
public static List<String> searchFilterOptions(String filterType, String searchTerm) {
    List<String> results = new List<String>();
    try {
        String likeTerm = '%' + searchTerm.toLowerCase() + '%';
        if (filterType == 'employees') {
            for (User u : [
                SELECT Name FROM User 
                WHERE IsActive = true AND Name LIKE :likeTerm 
                ORDER BY Name LIMIT 50
            ]) {
                results.add(u.Name);
            }
        } else if (filterType == 'departments') {
            Set<String> uniqueDepartments = new Set<String>();
            // Replace 'Department__c' with your actual API field name if different
            for (User u : [
                SELECT Department__c FROM User 
                WHERE IsActive = true AND Department__c != null
            ]) {
                if (!String.isBlank(u.Department__c) && 
                    u.Department__c.toLowerCase().contains(searchTerm.toLowerCase())) {
                    uniqueDepartments.add(u.Department__c);
                }
            }
            results.addAll(uniqueDepartments);
        } else if (filterType == 'projects') {
            for (Project__c p : [
                SELECT Name FROM Project__c 
                WHERE Name LIKE :likeTerm 
                ORDER BY Name LIMIT 50
            ]) {
                results.add(p.Name);
            }
        }
        return results;
    } catch (Exception e) {
        System.debug('Error in searchFilterOptions: ' + e.getMessage());
        throw new AuraHandledException('Error searching filter options: ' + e.getMessage());
    }
}


    public class TimesheetEntryWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String department;
        @AuraEnabled public String projectName;
        @AuraEnabled public Date entryDate;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public String status;
    }
}