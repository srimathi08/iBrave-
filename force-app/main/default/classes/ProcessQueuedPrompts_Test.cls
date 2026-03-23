@IsTest(SeeAllData=true)
public class ProcessQueuedPrompts_Test {

    // ✅ Test #1 — Normal scenario where WhatsApp = true
    @IsTest
    static void test_execute_schedulable_with_records() {
        // Step 1: Create test Service__c records
        List<Id> serviceIds = ProcessQueuedPrompts_DataSetup.createTestServices(3);

        // Step 2: Verify setup
        Integer beforeCount = [SELECT COUNT() FROM Service__c WHERE Whatsapp__c = true];
        System.assertEquals(3, beforeCount, 'Expected 3 WhatsApp=true records before execution.');

        // Step 3: Run the schedulable job
        Test.startTest();
            System.schedule('Test_ProcessQueuedPrompts', '0 0 0 ? * * *', new ProcessQueuedPrompts());
        Test.stopTest(); // 🚀 Schedulable + Queueable both execute here

        // Step 4: Verify results
        List<Service__c> updated = [SELECT Whatsapp__c FROM Service__c WHERE Id IN :serviceIds];
        for (Service__c svc : updated) {
            System.assertEquals(false, svc.Whatsapp__c, 'Whatsapp__c should be set to false after execution.');
        }
    }

    // ✅ Test #2 — No records found (edge case)
    @IsTest
    static void test_execute_schedulable_with_no_records() {
        // Step 1: Ensure no WhatsApp=true records exist
        delete [SELECT Id FROM Service__c];

        // Step 2: Run the schedulable job
        Test.startTest();
            System.schedule('Test_ProcessQueuedPrompts_Empty', '0 0 0 ? * * *', new ProcessQueuedPrompts());
        Test.stopTest();

        // Step 3: Validate nothing blew up
        System.assertEquals(0, [SELECT COUNT() FROM Service__c WHERE Whatsapp__c = true],
            'There should be no WhatsApp=true records after execution.');
    }

    // ✅ (Optional) Test #3 — Verify Queueable jobs enqueued
    @IsTest
    static void test_jobs_enqueued() {
        List<Id> serviceIds = ProcessQueuedPrompts_DataSetup.createTestServices(2);

        Test.startTest();
            System.schedule('Test_ProcessQueuedPrompts_QueueCheck', '0 0 0 ? * * *', new ProcessQueuedPrompts());
        Test.stopTest();

        // Check AsyncApexJob table to ensure at least one queueable job was submitted
        Integer queuedJobs = [
            SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'
        ];
        System.assert(queuedJobs > 0, 'Expected at least one queueable job to be enqueued.');
    }
}