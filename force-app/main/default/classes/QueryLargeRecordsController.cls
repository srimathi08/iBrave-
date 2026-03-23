public class QueryLargeRecordsController {
	private static final Integer BATCH_SIZE = 1;
    
  @AuraEnabled
    public static List<Account> getAccountsBatch() {
        return [Select id, Name , Active__c, Current_Location__c ,Date_of_Joining__c , Designation__c , LinkedIn__c , Years_of_Experience__c ,(Select id, Amount, CloseDate, Experience_Required__c, Job_Description__c , Job_Location__c , Name , Role_Required__c , Skills_Required__c , StageName , Probability from Opportunities),(Select id , Name , AccountId , Email , Phone from contacts), (Select id ,Name , Candidate_Name__c, Candidate_Name__r.name , Issuing_Organization__c  from certifications__r),(select id, Name , Category__c, Employee_Name__c , Employee_Name__r.name  from employee_skills__r), (select id , Name, Area_Of_Improvement__c , Candidate_Name__c, Candidate_Name__r.name, Interview__c , Interview_Date__c , Interview_Status__c, Interviewer_Name__c, Opportunity__c, Opportunity__r.name , Strength__c, Weakness__c from Feedbacks__r),(select id, Name , Project_Name__c , 	Project_Phase__c , Project_Role__c, Skills_Applied__c, Tools_Used__c, Task__c, Employee_Name__c,Employee_Name__r.name , Action__c from Project_Experiences__r),(Select id, Name , Candidate_Name__c, Candidate_Name__r.name , Interview_Round__c, Interview_Stage__c , Interviewer_Name__c, Interviewer_Name__r.name , Job_Description__c , 	Opportunity__c, 	Opportunity__r.name , Scheduled_Date_Time__c from Interviews__r) from Account ORDER BY CreatedDate DESC];
                     
               
    }
        
}