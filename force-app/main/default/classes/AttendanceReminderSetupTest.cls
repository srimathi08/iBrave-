@isTest
private class AttendanceReminderSetupTest {
    
    @TestSetup
    static void makeData(){
        // No setup data needed for scheduler tests
    }
    
    @isTest
    static void testSetupDailyReminder_NoExistingJobs() {
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.setupDailyReminder();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertNotEquals(null, result.get('jobId'));
        System.assertEquals('Daily Attendance Reminder - 12 PM', result.get('jobName'));
        System.assertEquals('0 0 12 * * ? *', result.get('cronExpression'));
        System.assertEquals(0, (Integer)result.get('existingJobsRemoved'));
    }
    
    @isTest
    static void testSetupDailyReminder_WithExistingJob() {
        // Clean any existing jobs first
        AttendanceReminderSetup.removeScheduledJob();
        
        // Create one existing job
        String cronExp = '0 0 12 * * ? *';
        System.schedule('Daily Attendance Reminder - 12 PM', cronExp, new AttendanceReminderScheduler());
        
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.setupDailyReminder();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertEquals(1, (Integer)result.get('existingJobsRemoved'));
        System.assertNotEquals(null, result.get('jobId'));
    }
    
    @isTest
    static void testCheckJobStatus_JobNotScheduled() {
        // Ensure no job exists
        AttendanceReminderSetup.removeScheduledJob();
        
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.checkJobStatus();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertEquals(false, (Boolean)result.get('isScheduled'));
        System.assertEquals('Job is not scheduled. Please run setupDailyReminder() to schedule it.', 
                           (String)result.get('message'));
    }
    
    @isTest
    static void testCheckJobStatus_JobScheduled() {
        // Schedule job first
        AttendanceReminderSetup.setupDailyReminder();
        
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.checkJobStatus();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertEquals(true, (Boolean)result.get('isScheduled'));
        System.assertNotEquals(null, result.get('jobId'));
    }
    
    @isTest
    static void testRemoveScheduledJob_NoJobs() {
        // Ensure no jobs exist
        AttendanceReminderSetup.removeScheduledJob();
        
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.removeScheduledJob();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertEquals(false, (Boolean)result.get('removed'));
        System.assertEquals(0, (Integer)result.get('jobsRemoved'));
    }
    
    @isTest
    static void testRemoveScheduledJob_WithJobs() {
        // Create job first
        AttendanceReminderSetup.setupDailyReminder();
        
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.removeScheduledJob();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertEquals(true, (Boolean)result.get('removed'));
        System.assertEquals(1, (Integer)result.get('jobsRemoved'));
    }
    
    @isTest
    static void testRunBatchNow() {
        Test.startTest();
        Map<String,Object> result = AttendanceReminderSetup.runBatchNow();
        Test.stopTest();
        
        System.assertEquals(true, (Boolean)result.get('success'));
        System.assertNotEquals(null, result.get('batchJobId'));
        System.assertEquals('Batch job started successfully. Check email and debug logs.', 
                           (String)result.get('message'));
    }
}