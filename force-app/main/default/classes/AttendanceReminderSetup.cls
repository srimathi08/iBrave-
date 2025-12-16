/**
 * One-time setup class to automatically schedule the attendance reminder job
 * Run this class once after deployment to schedule the daily reminder
 * @author Salesforce Developer
 * @date 2025-11-11
 */
public class AttendanceReminderSetup {
    
    /**
     * Main method to schedule the daily attendance reminder
     * Can be called from Execute Anonymous or from a custom button
     */
    @AuraEnabled
    public static Map<String, Object> setupDailyReminder() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            System.debug('=== SETTING UP DAILY ATTENDANCE REMINDER ===');
            
            // Step 1: Check if job is already scheduled
            List<CronTrigger> existingJobs = [
                SELECT Id, CronJobDetail.Name, NextFireTime, State, CronExpression
                FROM CronTrigger 
                WHERE CronJobDetail.Name = 'Daily Attendance Reminder - 12 PM'
            ];
            
            // Step 2: Delete existing job if found (to avoid duplicates)
            if (!existingJobs.isEmpty()) {
                System.debug('Found existing scheduled job(s). Removing...');
                for (CronTrigger job : existingJobs) {
                    System.abortJob(job.Id);
                    System.debug('Deleted job: ' + job.Id);
                }
                result.put('existingJobsRemoved', existingJobs.size());
            } else {
                System.debug('No existing jobs found');
                result.put('existingJobsRemoved', 0);
            }
            
            // Step 3: Schedule new job to run daily at 12:00 PM
            String cronExpression = '0 0 12 * * ? *'; // Daily at 12:00 PM
            String jobName = 'Daily Attendance Reminder - 12 PM';
            
            AttendanceReminderScheduler scheduler = new AttendanceReminderScheduler();
            String jobId = System.schedule(jobName, cronExpression, scheduler);
            
            // Step 4: Get next run time
            CronTrigger scheduledJob = [
                SELECT Id, CronJobDetail.Name, NextFireTime, State, CronExpression
                FROM CronTrigger 
                WHERE Id = :jobId
                LIMIT 1
            ];
            
            // Step 5: Build success response
            result.put('success', true);
            result.put('jobId', jobId);
            result.put('jobName', jobName);
            result.put('cronExpression', cronExpression);
            result.put('nextRunTime', scheduledJob.NextFireTime);
            result.put('state', scheduledJob.State);
            result.put('message', 'Daily attendance reminder scheduled successfully!');
            
            System.debug('✅ SUCCESS: Job scheduled successfully');
            System.debug('Job ID: ' + jobId);
            System.debug('Job Name: ' + jobName);
            System.debug('Next Run: ' + scheduledJob.NextFireTime);
            System.debug('Schedule: Daily at 12:00 PM');
            
        } catch (Exception e) {
            System.debug('❌ ERROR: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            
            result.put('success', false);
            result.put('error', e.getMessage());
            result.put('stackTrace', e.getStackTraceString());
        }
        
        return result;
    }
    
    /**
     * Method to check if reminder job is scheduled
     */
    @AuraEnabled
    public static Map<String, Object> checkJobStatus() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            List<CronTrigger> jobs = [
                SELECT Id, CronJobDetail.Name, NextFireTime, State, 
                       CronExpression, PreviousFireTime, StartTime
                FROM CronTrigger 
                WHERE CronJobDetail.Name = 'Daily Attendance Reminder - 12 PM'
            ];
            
            if (!jobs.isEmpty()) {
                CronTrigger job = jobs[0];
                
                result.put('isScheduled', true);
                result.put('jobId', job.Id);
                result.put('jobName', job.CronJobDetail.Name);
                result.put('nextRunTime', job.NextFireTime);
                result.put('previousRunTime', job.PreviousFireTime);
                result.put('state', job.State);
                result.put('cronExpression', job.CronExpression);
                result.put('startTime', job.StartTime);
                result.put('message', 'Job is scheduled and active');
                
            } else {
                result.put('isScheduled', false);
                result.put('message', 'Job is not scheduled. Please run setupDailyReminder() to schedule it.');
            }
            
            result.put('success', true);
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Method to remove/unschedule the job
     */
    @AuraEnabled
    public static Map<String, Object> removeScheduledJob() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            List<CronTrigger> jobs = [
                SELECT Id, CronJobDetail.Name
                FROM CronTrigger 
                WHERE CronJobDetail.Name = 'Daily Attendance Reminder - 12 PM'
            ];
            
            if (!jobs.isEmpty()) {
                Integer removedCount = 0;
                for (CronTrigger job : jobs) {
                    System.abortJob(job.Id);
                    removedCount++;
                }
                
                result.put('success', true);
                result.put('removed', true);
                result.put('jobsRemoved', removedCount);
                result.put('message', 'Successfully removed ' + removedCount + ' scheduled job(s)');
                
            } else {
                result.put('success', true);
                result.put('removed', false);
                result.put('jobsRemoved', 0);
                result.put('message', 'No scheduled jobs found to remove');
            }
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Test method to run the batch immediately (for testing)
     */
    @AuraEnabled
    public static Map<String, Object> runBatchNow() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            AttendanceReminderBatch batch = new AttendanceReminderBatch();
            Id batchJobId = Database.executeBatch(batch, 50);
            
            result.put('success', true);
            result.put('batchJobId', batchJobId);
            result.put('message', 'Batch job started successfully. Check email and debug logs.');
            
            System.debug('✅ Batch job started: ' + batchJobId);
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
}