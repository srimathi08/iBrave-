/**
 * Scheduled job to run daily and create eligible leave balances
 * Schedule: Run daily at 2 AM
 * System.schedule('Daily Leave Balance Check', '0 0 2 * * ?', new LeaveBalanceScheduler());
 */
public class LeaveBalanceScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        String currentYear = String.valueOf(Date.today().year());
        
        // Check if it's January 1st - trigger year-end reset
        if (Date.today().month() == 1 && Date.today().day() == 1) {
            LeaveBalanceService.resetBalancesForNewYear(currentYear);
        } else {
            // Regular daily check - create balances for newly eligible employees
            LeaveBalanceCreationBatch batch = new LeaveBalanceCreationBatch(currentYear);
            Database.executeBatch(batch, 50);
        }
    }
}