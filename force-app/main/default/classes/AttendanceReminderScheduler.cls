/**
 * Scheduler to run AttendanceReminderBatch daily at 12 PM
 * @author Salesforce Developer
 * @date 2025-11-11
 */
public class AttendanceReminderScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        System.debug('=== ATTENDANCE REMINDER SCHEDULER EXECUTED ===');
        System.debug('Scheduled Time: ' + System.now());
        
        // Execute the batch with batch size 50
        AttendanceReminderBatch batch = new AttendanceReminderBatch();
        Database.executeBatch(batch, 50);
    }
}