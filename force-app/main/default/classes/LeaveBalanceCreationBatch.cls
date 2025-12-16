/**
 * Batch class to create leave balances for all employees
 */
public class LeaveBalanceCreationBatch implements Database.Batchable<SObject> {
    
    private String year;
    
    public LeaveBalanceCreationBatch(String year) {
        this.year = year;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Date_of_Joining__c, Gender__c, Marital_Status__c, 
                   Number_of_Children__c, Employment_Type__c, Email
            FROM User 
            WHERE IsActive = true 
            AND Employee_Id__c != null
            AND Date_of_Joining__c != null
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<User> scope) {
        for (User emp : scope) {
            try {
                LeaveBalanceService.createEligibleBalancesForEmployee(emp.Id, this.year);
            } catch (Exception e) {
                System.debug('Error processing employee ' + emp.Name + ': ' + e.getMessage());
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('Leave balance creation batch completed for year: ' + this.year);
    }
}