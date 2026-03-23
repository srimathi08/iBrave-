/*public with sharing class ResumePdfService {

    public class ResumeInput {
        @InvocableVariable public String resumeText;
        @InvocableVariable public String fileName;
        @InvocableVariable public Id accountId;

  // ✅ NEW: Add badge names input too!
        @InvocableVariable public String badgeNames;

    }

    @InvocableMethod(label='Generate Resume PDF')
    public static List<Id> generatePdf(List<ResumeInput> inputs) {
        List<Id> fileIds = new List<Id>();
        system.debug('Input >>'+ inputs);

        for (ResumeInput input : inputs) {
            PageReference pdfPage = Page.ResumePdfPage;
            system.debug('pdfPage >>'+ pdfPage);
            pdfPage.getParameters().put('resumeHtml', input.resumeText);
            pdfPage.getParameters().put('badgeNames', input.badgeNames); //Added for Badge

            Blob pdfBlob = pdfPage.getContentAsPDF();

            ContentVersion cv = new ContentVersion();
            cv.Title = input.fileName;
            cv.PathOnClient = input.fileName + '.pdf';
            cv.VersionData = pdfBlob;
            insert cv;

            ContentDocumentLink link = new ContentDocumentLink();
            link.ContentDocumentId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
            ].ContentDocumentId;
            link.LinkedEntityId = input.accountId;
            link.ShareType = 'V';
            insert link;

            fileIds.add(cv.Id);
        }
         system.debug('fileIds >>'+ fileIds);  
        return fileIds;
    }
}*/


//working code for AKSHAYA record id
/*
public with sharing class ResumePdfService {

    public class ResumeInput {
        @InvocableVariable public String fileName;
        @InvocableVariable public Id accountId;
        @InvocableVariable public String badgeNames;
    }

    @InvocableMethod(label='Generate Resume PDF')
    public static List<Id> generatePdf(List<ResumeInput> inputs) {
        List<Id> fileIds = new List<Id>();
        try {
            System.debug('⚡ Input >> ' + inputs);

            for (ResumeInput input : inputs) {
                PageReference pdfPage = Page.ResumePdfPage;
                 system.debug('pdfPage'+ pdfPage);
                // Pass safe params
                system.debug('recordId'+String.valueOf(input.accountId));
                system.debug('badgeNames'+input.badgeNames);
                pdfPage.getParameters().put('recordId', String.valueOf(input.accountId));
                pdfPage.getParameters().put('badgeNames', input.badgeNames);

                // Try to generate PDF
                Blob pdfBlob = pdfPage.getContentAsPDF();
                system.debug('pdfBlob'+ pdfBlob);

                // Create ContentVersion
                ContentVersion cv = new ContentVersion();
                cv.Title = input.fileName;
                system.debug(' cv.Title '+ cv.Title );
                cv.PathOnClient = input.fileName + '.pdf';
                cv.VersionData = pdfBlob;
                insert cv;

                // Link file to Account
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = [
                    SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
                ].ContentDocumentId;
                link.LinkedEntityId = input.accountId;
                link.ShareType = 'V';
                insert link;

                fileIds.add(cv.Id);
            }

            System.debug('✅ fileIds >> ' + fileIds);
            return fileIds;

        } catch (Exception e) {
            // Log full details
            System.debug('❌ Error Message >>> ' + e.getMessage());
            System.debug('❌ Error Cause   >>> ' + e.getCause());
            System.debug('❌ Error Trace   >>> ' + e.getStackTraceString());

            // Option 1: rethrow so Flow sees the failure
            throw new AuraHandledException('ResumePdfService failed: ' + e.getMessage());

            // Option 2: (if you don’t want Flow to fail) just return empty list
            // return new List<Id>();
        }
    }
}*/



public with sharing class ResumePdfService {

    // Input structure used by Flow
    public class ResumeInput {
        @InvocableVariable public String fileName;
        @InvocableVariable public Id accountId;
        @InvocableVariable public String badgeNames;
    }

    @InvocableMethod(label='Generate Resume PDF')
    public static List<Id> generatePdf(List<ResumeInput> inputs) {
        List<Id> fileIds = new List<Id>();
        if (inputs == null || inputs.isEmpty()) return fileIds;

        try {
            System.debug('⚡ Input >> ' + inputs);

            for (ResumeInput input : inputs) {
                PageReference pdfPage = Page.ResumePdfPage;
                System.debug('pdfPage: ' + pdfPage);

                // Pass safe params
                System.debug('recordId: ' + String.valueOf(input.accountId));
                System.debug('badgeNames: ' + input.badgeNames);
                if (input.accountId != null) pdfPage.getParameters().put('recordId', String.valueOf(input.accountId));
                if (!String.isBlank(input.badgeNames)) pdfPage.getParameters().put('badgeNames', input.badgeNames);

                // Try to generate PDF
                Blob pdfBlob;
                try {
                    pdfBlob = pdfPage.getContentAsPDF();
                    System.debug('pdfBlob size: ' + (pdfBlob == null ? 0 : pdfBlob.size()));
                } catch (Exception renderEx) {
                    System.debug('⚠️ PDF render failed for account ' + input.accountId + ': ' + renderEx.getMessage());
                    System.debug(renderEx.getStackTraceString());

                    // Try fallback by forcing controller fallback param (if controller supports it)
                    try {
                        pdfPage.getParameters().put('forceFallback', '1');
                        pdfBlob = pdfPage.getContentAsPDF();
                        System.debug('pdfBlob size (fallback): ' + (pdfBlob == null ? 0 : pdfBlob.size()));
                    } catch (Exception renderEx2) {
                        System.debug('❌ Fallback render also failed for account ' + input.accountId + ': ' + renderEx2.getMessage());
                        System.debug(renderEx2.getStackTraceString());
                        pdfBlob = null;
                    }
                }

                if (pdfBlob == null) {
                    System.debug('⏭ Skipping file creation because pdfBlob is null for account ' + input.accountId);
                    continue;
                }

                // Create ContentVersion
                ContentVersion cv = new ContentVersion();
                String title = String.isBlank(input.fileName) ? ('Resume_' + Datetime.now().getTime()) : input.fileName;
                cv.Title = title;
                cv.PathOnClient = title + '.pdf';
                cv.VersionData = pdfBlob;
                insert cv;

                // Link file to Account
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = [
                    SELECT ContentDocumentId 
                    FROM ContentVersion 
                    WHERE Id = :cv.Id
                ].ContentDocumentId;
                link.LinkedEntityId = input.accountId;
                link.ShareType = 'V';
                insert link;

                fileIds.add(cv.Id);
            }

            System.debug('✅ fileIds >> ' + fileIds);
            return fileIds;

        } catch (Exception e) {
            // Log full details for troubleshooting, but do not throw AuraHandledException from a non-Aura context
            System.debug('❌ Error Message >>> ' + e.getMessage());
            System.debug('❌ Error Cause   >>> ' + e.getCause());
            System.debug('❌ Error Trace   >>> ' + e.getStackTraceString());

            // Return partial results or empty list so caller can continue
            return fileIds;
        }
    }
}