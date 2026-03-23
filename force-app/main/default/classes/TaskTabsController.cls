public with sharing class TaskTabsController {

    @AuraEnabled(cacheable=true)
    public static List<Task> getTasks(String viewName, String sortOrder) {
        Date today = Date.today();
        String orderDir = (sortOrder == 'DESC') ? 'DESC' : 'ASC';

        String soql =
            'SELECT Id, Subject, Status, Priority, ActivityDate, Description, Owner.Name ' +
            'FROM Task WHERE IsDeleted = false';

        if (viewName == 'OPEN') {
            soql += ' AND Status != \'Completed\'';
        } else if (viewName == 'OPEN_HIGH') {
            soql += ' AND Status != \'Completed\' AND Priority = \'High\'';
        } else if (viewName == 'OPEN_MEDIUM') {
            soql += ' AND Status != \'Completed\' AND Priority = \'Medium\'';
        } else if (viewName == 'OPEN_NORMAL') {
            soql += ' AND Status != \'Completed\' AND Priority = \'Normal\'';
        } else if (viewName == 'OVERDUE') {
            soql += ' AND Status != \'Completed\' AND ActivityDate < :today';
        } else {
            soql += ' AND Status != \'Completed\'';
        }

        soql += ' ORDER BY ActivityDate ' + orderDir + ' NULLS LAST LIMIT 500';
        return Database.query(soql);
    }

    @AuraEnabled
    public static void deleteTask(Id taskId) {
        delete [SELECT Id FROM Task WHERE Id = :taskId LIMIT 1];
    }

    @AuraEnabled
    public static void updateTask(Id taskId, String field, Object value) {
        Task t = new Task(Id = taskId);

        if (field == 'Subject') t.Subject = (String)value;
        else if (field == 'Status') t.Status = (String)value;
        else if (field == 'Priority') t.Priority = (String)value;
        else if (field == 'Description') t.Description = (String)value;
        else if (field == 'ActivityDate') t.ActivityDate = Date.valueOf((String)value);

        update t;
    }
}