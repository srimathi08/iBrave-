public with sharing class ResumePdfEnqueuer {

    // Input structure for Flow (Invocable)
    public class EnqueueInput {
        @InvocableVariable(label='Account Id') public Id accountId;
        @InvocableVariable(label='Badge Names (comma separated)') public String badgeNames;
        @InvocableVariable(label='File name') public String fileName;
    }

    /**
     * Invocable called from Flow. It enqueues a Queueable job for each input row.
     * The Queueable runs AFTER the current transaction commits, so it will see committed field values.
     */
    @InvocableMethod(label='Enqueue Resume PDF Generation (Queueable)')
    public static void enqueueResumePdf(List<EnqueueInput> inputs) {
        if (inputs == null || inputs.isEmpty()) return;
        for (EnqueueInput inRec : inputs) {
            try {
                System.enqueueJob(new ResumePdfJob(inRec.accountId, inRec.badgeNames, inRec.fileName));
            } catch (Exception ex) {
                System.debug('❌ Failed to enqueue ResumePdfJob for account=' + inRec.accountId + ' => ' + ex.getMessage());
            }
        }
    }

    // Queueable job that performs the actual PDF generation by calling the existing ResumePdfService
   // public class ResumePdfJob implements Queueable {
public class ResumePdfJob implements Queueable, Database.AllowsCallouts {
        private Id accountId;
        private String badgeNames;
        private String fileName;

        public ResumePdfJob(Id acctId, String badges, String fname) {
            this.accountId = acctId;
            this.badgeNames = badges;
            this.fileName = fname;
        }

        public void execute(QueueableContext ctx) {
            try {
                ResumePdfService.ResumeInput ri = new ResumePdfService.ResumeInput();
                ri.accountId = this.accountId;
                ri.badgeNames = this.badgeNames;
                ri.fileName = this.fileName;

                // Call your existing service method
                ResumePdfService.generatePdf(new List<ResumePdfService.ResumeInput>{ ri });

            } catch (Exception ex) {
                System.debug('❌ ResumePdfJob failed for Account ' + accountId + ' : ' + ex.getMessage());
                System.debug(ex.getStackTraceString());
            }
        }
    }
}