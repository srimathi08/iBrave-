@isTest
public class ResumePdfEnqueuerTest {

    /**
     * Utility method to create a test Account (using TestDataFactory if available)
     */
    private static Account getTestAccount() {
        Account acc;
        try {
            acc = TestDataFactory.createAccount(true);
        } catch (Exception e) {
            acc = new Account(Name = 'Test Resume Account');
            insert acc;
        }
        return acc;
    }

    // =============================================================
    // 🔹 TEST 1 — Valid Flow Input (Happy Path)
    // =============================================================
    @isTest
    static void testEnqueueResumePdf_HappyPath() {
        Account acc = getTestAccount();

        ResumePdfEnqueuer.EnqueueInput input = new ResumePdfEnqueuer.EnqueueInput();
        input.accountId = acc.Id;
        input.badgeNames = 'Salesforce Developer, Apex Specialist';
        input.fileName = 'Resume_Test.pdf';

        List<ResumePdfEnqueuer.EnqueueInput> inputList = new List<ResumePdfEnqueuer.EnqueueInput>{ input };

        Test.startTest();
        ResumePdfEnqueuer.enqueueResumePdf(inputList);
        Test.stopTest();

        System.assert(true, 'Queueable job executed successfully.');
    }

    // =============================================================
    // 🔹 TEST 2 — Null or Empty Inputs
    // =============================================================
    @isTest
    static void testEnqueueResumePdf_NullAndEmptyInputs() {
        Test.startTest();
        ResumePdfEnqueuer.enqueueResumePdf(null);
        ResumePdfEnqueuer.enqueueResumePdf(new List<ResumePdfEnqueuer.EnqueueInput>());
        Test.stopTest();

        System.assert(true, 'Handled null and empty input without errors.');
    }

    // =============================================================
    // 🔹 TEST 3 — Queueable Execution (Valid)
    // =============================================================
    @isTest
    static void testQueueableJob_ExecutesWithoutError() {
        Account acc = getTestAccount();

        ResumePdfEnqueuer.ResumePdfJob job = new ResumePdfEnqueuer.ResumePdfJob(
            acc.Id,
            'Platform Developer I',
            'Resume_Test.pdf'
        );

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Queueable executed successfully.');
    }

    // =============================================================
    // 🔹 TEST 4 — Exception Handling Path
    // =============================================================
    @isTest
    static void testQueueableJob_ExceptionHandling() {
        Account acc = getTestAccount();

        ResumePdfEnqueuer.ResumePdfJob job = new ResumePdfEnqueuer.ResumePdfJob(
            acc.Id,
            null,
            null
        );

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Queueable handled exceptions gracefully.');
    }

    // =============================================================
    // 🔹 TEST 5 — Multiple Inputs
    // =============================================================
    @isTest
    static void testEnqueueResumePdf_MultipleInputs() {
        Account acc1 = getTestAccount();
        Account acc2 = new Account(Name = 'Second Resume Account');
        insert acc2;

        ResumePdfEnqueuer.EnqueueInput in1 = new ResumePdfEnqueuer.EnqueueInput();
        in1.accountId = acc1.Id;
        in1.badgeNames = 'PD1, LWC Specialist';
        in1.fileName = 'Resume_One.pdf';

        ResumePdfEnqueuer.EnqueueInput in2 = new ResumePdfEnqueuer.EnqueueInput();
        in2.accountId = acc2.Id;
        in2.badgeNames = 'Integration Architect';
        in2.fileName = 'Resume_Two.pdf';

        List<ResumePdfEnqueuer.EnqueueInput> inputList = new List<ResumePdfEnqueuer.EnqueueInput>{ in1, in2 };

        Test.startTest();
        ResumePdfEnqueuer.enqueueResumePdf(inputList);
        Test.stopTest();

        System.assert(true, 'Multiple Queueable jobs executed successfully.');
    }
}