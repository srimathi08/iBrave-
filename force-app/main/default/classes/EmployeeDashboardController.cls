public with sharing class EmployeeDashboardController {
    //@AuraEnabled
    /*public static Map<String, Object> fetchDashboardData(Id userId) {
        Map<String, Object> result = new Map<String, Object>();

        // Employee profile (standard User fields)
        User usr = [SELECT Id, Name, Title, EmployeeId__c, Department, HireDate__c, SmallPhotoUrl 
                    FROM User WHERE Id = :userId LIMIT 1];
        Map<String, Object> profile = new Map<String, Object>{
            'name' => usr.Name,
            'title' => usr.Title,
            'employeeId' => usr.EmployeeId__c,
            'department' => usr.Department,
            'hireDate' => usr.HireDate__c,
            'photoUrl' => usr.SmallPhotoUrl
        };
        result.put('profile', profile);

        // Timesheet data (custom object Timesheet__c)
        List<Map<String, Object>> timesheetList = new List<Map<String, Object>>();
        for (Timesheet__c t : [
            SELECT Id, Date__c, Hours__c 
            FROM Timesheet__c 
            WHERE Employee__c = :userId 
            ORDER BY Date__c DESC LIMIT 5
        ]) {
            timesheetList.add(new Map<String, Object>{
                'id' => t.Id,
                'date' => String.valueOf(t.Date__c),
                'hours' => t.Hours__c
            });
        }
        result.put('timesheets', timesheetList);

        // Project status (custom object Project__c)
        List<Map<String, Object>> projectList = new List<Map<String, Object>>();
        for (Project__c p : [
            SELECT Id, Name, Status__c 
            FROM Project__c 
            WHERE AssignedTo__c = :userId
        ]) {
            projectList.add(new Map<String, Object>{
                'id' => p.Id,
                'name' => p.Name,
                'status' => p.Status__c
            });
        }
        result.put('projects', projectList);

        // Optionally: AI chat history (custom object AiChat__c or integrate with live service)
        result.put('aiChatWelcome', 'How can I assist you today?');
        return result;
    }*/
}