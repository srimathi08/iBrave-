public with sharing class EmployeeResumeController {

    // Row wrapper used by the LWC datatable
    public class EmployeeRow {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Designation;       // from Account.Designation__c
        @AuraEnabled public String YearsOfExperience; // from Account.Years_of_Experience__c
        @AuraEnabled public String Description;
        @AuraEnabled public String Certifications;    // comma-separated certification names
    }

    /**
     * Returns one row per Person Account employee who has at least one Certification
     * whose Name matches the given keyword. Each row includes ALL their certification
     * names as a comma-separated string.
     */
    @AuraEnabled(cacheable=true)
    public static List<EmployeeRow> getEmployeesByCertification(String keyword) {
        String term = (keyword == null) ? '' : keyword.trim();
        if (String.isBlank(term)) {
            return new List<EmployeeRow>();
        }

        // 1) Find matching employees
        List<Account> employees = [
            SELECT Id, Name, Designation__c, Years_of_Experience__c, Description
            FROM Account
           WHERE RecordType.DeveloperName IN ('Candidates', 'Employee', 'Contractor')
            AND Id IN (
                SELECT Candidate_Name__c
                FROM Certification__c
                WHERE Name LIKE :('%' + term + '%')
            )
        ];
        if (employees.isEmpty()) return new List<EmployeeRow>();

        // 2) Fetch ALL certifications for those employees
        Set<Id> empIds = new Set<Id>();
        for (Account a : employees) empIds.add(a.Id);

        Map<Id, List<String>> empIdToCertNames = new Map<Id, List<String>>();
        for (Certification__c c : [
            SELECT Id, Name, Candidate_Name__c
            FROM Certification__c
            WHERE Candidate_Name__c IN :empIds
            ORDER BY Name
        ]) {
            if (!empIdToCertNames.containsKey(c.Candidate_Name__c)) {
                empIdToCertNames.put(c.Candidate_Name__c, new List<String>());
            }
            empIdToCertNames.get(c.Candidate_Name__c).add(c.Name);
        }

        // 3) Build wrapper rows
        List<EmployeeRow> rows = new List<EmployeeRow>();
        for (Account a : employees) {
            EmployeeRow r = new EmployeeRow();
            r.Id = a.Id;
            r.Name = a.Name;
            r.Description = a.Description;

            // Cast via dynamic access to avoid type mismatches in different orgs
            r.Designation = (String) a.get('Designation__c');
            r.YearsOfExperience = String.valueOf(a.get('Years_of_Experience__c'));

            List<String> certs = empIdToCertNames.get(a.Id);
            r.Certifications = (certs == null || certs.isEmpty())
                ? '—'
                : String.join(certs, ', ');

            rows.add(r);
        }
        return rows;
    }

    /**
     * Returns a map containing:
     *  - 'employees' : List<Account>
     *  - 'projects'  : List<Project_Experience__c>
     *  - 'skills'    : List<Employee_Skill__c>
     *  - 'certifications' : List<Certification__c>
     */
    @AuraEnabled
    public static Map<String, Object> getEmployeeFullProfile(List<Id> employeeIds) {
        Map<String, Object> result = new Map<String, Object>();
        if (employeeIds == null || employeeIds.isEmpty()) {
            result.put('employees', new List<Account>());
            result.put('projects', new List<Project_Experience__c>());
            result.put('skills', new List<Employee_Skill__c>());
            result.put('certifications', new List<Certification__c>());
            return result;
        }

        // Employees (Person Accounts)
        List<Account> employees = [
            SELECT Id, Name, Years_of_Experience__c, Description, Designation__c
            FROM Account
            WHERE Id IN :employeeIds 
        ];
        result.put('employees', employees);

        // Projects
        List<Project_Experience__c> projects = [
            SELECT Id, Name, Action__c, Employee_Name__r.Name, Learning_Outcome__c,
                   Project_Name__c, Result__c, Situtation__c, Skills_Applied__c, Task__c, Tools_Used__c
            FROM Project_Experience__c
            WHERE Employee_Name__c IN :employeeIds
        ];
        result.put('projects', projects);

        // Skills
        List<Employee_Skill__c> skills = [
            SELECT Id, Name, Employee_Name__r.Name
            FROM Employee_Skill__c
            WHERE Employee_Name__c IN :employeeIds
        ];
        result.put('skills', skills);

        // Certifications
        List<Certification__c> certs = [
            SELECT Id, Name, Candidate_Name__r.Name
            FROM Certification__c
            WHERE Candidate_Name__c IN :employeeIds
        ];
        result.put('certifications', certs);

        return result;
    }

    @AuraEnabled
    public static String getEmployeeFullProfileJSON(List<Id> employeeIds) {
        Map<String, Object> profile = getEmployeeFullProfile(employeeIds);
        return JSON.serialize(profile);
    }
}