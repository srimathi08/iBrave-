public with sharing class ProjectTimelineController {
    @AuraEnabled(cacheable=true)
    public static List<ProjectExperienceWrapper> getProjectExperiences(Id accountId) {
        List<ProjectExperienceWrapper> result = new List<ProjectExperienceWrapper>();

        List<Project_Experience__c> records = [
            SELECT Id, Project_Name__c, Start_Date__c, End_Date__c,
                   Task__c, Skills_Applied__c, Tools_Used__c, Learning_Outcome__c,
                   Employee_Name__r.Date_of_Joining__c
            FROM Project_Experience__c
            WHERE Employee_Name__c = :accountId
            AND Start_Date__c != NULL
            ORDER BY Start_Date__c ASC
        ];

        for (Project_Experience__c proj : records) {
            result.add(new ProjectExperienceWrapper(
                proj.Id,
                proj.Project_Name__c,
                proj.Start_Date__c,
                proj.End_Date__c,
                proj.Employee_Name__r.Date_of_Joining__c,
                proj.Task__c,
                proj.Skills_Applied__c,
                proj.Tools_Used__c,
                proj.Learning_Outcome__c
            ));
        }

        return result;
    }

    public class ProjectExperienceWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String projectName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Date joiningDate;
        @AuraEnabled public String task;
        @AuraEnabled public String skillsApplied;
        @AuraEnabled public String toolsUsed;
        @AuraEnabled public String learningOutcome;

        public ProjectExperienceWrapper(Id id, String projectName, Date startDate, Date endDate, Date joiningDate,
            String task, String skillsApplied, String toolsUsed, String learningOutcome) {
            this.id = id;
            this.projectName = projectName;
            this.startDate = startDate;
            this.endDate = endDate;
            this.joiningDate = joiningDate;
            this.task = task;
            this.skillsApplied = skillsApplied;
            this.toolsUsed = toolsUsed;
            this.learningOutcome = learningOutcome;
        }
    }
}