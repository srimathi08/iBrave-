/*public class OfferLetterPDFGenerator {
    @InvocableMethod(label='Generate Offer Letter PDF')
    public static void generateOfferLetter(List<Id> candidateIds) {
        for (Id candId : candidateIds) {
            // Generate PDF using VF page
            PageReference pdfPage = Page.OfferLetterPDF;
            pdfPage.getParameters().put('id', candId);
            Blob pdfBlob = pdfPage.getContentAsPDF();

            String fileName = 'Offer_Letter_' + candId + '_' + Date.today().format() + '.pdf';
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = candId; // link to candidate
            cv.IsMajorVersion = true;
            insert cv;

            ContentVersion resultCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            Candidate__c cand = [SELECT Id FROM Candidate__c WHERE Id = :candId LIMIT 1];
            cand.Offer_Letter_Document_Id__c = resultCV.ContentDocumentId;
			cand.Offer_Letter_Status__c = 'Generated'; // Set status value as per picklist
            cand.Offer_Letter_Generated_Date__c = Date.today(); 
            update cand;
           
        }
    }
}*/
/*public class OfferLetterPDFGenerator {
    @InvocableMethod(label='Generate Offer Letter PDF')
    public static void generateOfferLetter(List<Id> candidateIds) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        
        for (Id candId : candidateIds) {
            // Generate PDF
            PageReference pdfPage = Page.OfferLetterPDF;
            pdfPage.getParameters().put('id', candId);
            Blob pdfBlob = pdfPage.getContentAsPDF();
            String fileName = 'Offer_Letter_' + candId + '_' + Date.today().format() + '.pdf';
            
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = candId;
            cv.IsMajorVersion = true;
            insert cv;
            
            // Get ContentDocumentId
            ContentVersion resultCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // Create Public Link via ContentDistribution
            ContentDistribution cd = new ContentDistribution();
            cd.ContentVersionId = cv.Id;
            cd.Name = fileName;
            cd.PreferencesAllowViewInBrowser = true; // IMPORTANT: Allows viewing before download
            cd.PreferencesAllowOriginalDownload = true; // Allows download
            cd.PreferencesExpires = false; // Link doesn't expire
            insert cd;
            
            // Get the public URL
            ContentDistribution resultCD = [SELECT DistributionPublicUrl, ContentDownloadUrl 
                                           FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
            
            // Update Candidate record
            Candidate__c cand = new Candidate__c();
            cand.Id = candId;
            cand.Offer_Letter_Document_Id__c = resultCV.ContentDocumentId;
            cand.Offer_Letter_Doc_Link__c = resultCD.DistributionPublicUrl; // View link
            cand.Offer_Letter_Status__c = 'Generated';
            cand.Offer_Letter_Generated_Date__c = Date.today();
            candidatesToUpdate.add(cand);
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }
}*/
public class OfferLetterPDFGenerator {
    @InvocableMethod(label='Generate Offer Letter PDF')
    public static void generateOfferLetter(List<Id> candidateIds) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
 
	String siteUrl = 'https://innovation-dream-9744--hrmproject.sandbox.my.site.com/CandidatePortal';  
        
        for (Id candId : candidateIds) {
            // Generate unique acceptance token
            String acceptanceToken = generateUniqueToken();
            
            // Generate PDF
            PageReference pdfPage = Page.OfferLetterPDF;
            pdfPage.getParameters().put('id', candId);
            //Blob pdfBlob = pdfPage.getContentAsPDF();
Blob pdfBlob;

if (Test.isRunningTest()) {
    pdfBlob = Blob.valueOf('FAKE PDF');     // Test-safe PDF blob
} else {
    pdfBlob = pdfPage.getContentAsPDF();
}


            String fileName = 'Offer_Letter_' + candId + '_' + Date.today().format() + '.pdf';
            
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = candId;
            cv.IsMajorVersion = true;
            insert cv;
            
            // Query to get ContentDocumentId
            ContentVersion resultCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // Create PUBLIC ContentDistribution
            ContentDistribution cd = new ContentDistribution();
            cd.ContentVersionId = resultCV.Id;
            cd.Name = fileName;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesAllowOriginalDownload = true;
            cd.PreferencesExpires = false;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;  // No password required
            cd.PreferencesAllowPDFDownload = true;
            insert cd;
            
            // Get the PUBLIC download URL
            ContentDistribution resultCD = [SELECT ContentDownloadUrl, DistributionPublicUrl 
                                           FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
            
            // Use ContentDownloadUrl for direct PDF access without login
            String publicPdfUrl = resultCD.ContentDownloadUrl;
            
            // Generate acceptance page URL
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String acceptanceUrl = siteUrl + '/apex/OfferLeterAcceptancePage?token=' + acceptanceToken;
            
            // Update Candidate record
            Candidate__c cand = new Candidate__c();
            cand.Id = candId;
            cand.Offer_Letter_Document_Id__c = resultCV.ContentDocumentId;
            cand.Offer_Letter_Doc_Link__c = publicPdfUrl;  // Public download link
            cand.Offer_Acceptance_Token__c = acceptanceToken;
            cand.Offer_Acceptance_URL__c = acceptanceUrl;  // Store acceptance URL
            cand.Offer_Letter_Status__c = 'Generated';
            cand.Offer_Letter_Generated_Date__c = Date.today();
            cand.Offer_Accepted__c = false;
            cand.Onboarding_Status__c = 'Not Started';
            candidatesToUpdate.add(cand);
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }
    
    /*private static String generateUniqueToken() {
        Blob b = Crypto.GenerateAESKey(128);
        String h = EncodingUtil.ConvertTohex(b);
        return h.substring(0,32);
    }*/
@TestVisible
private static String generateUniqueToken() {
    Blob b = Crypto.GenerateAESKey(128);
    String h = EncodingUtil.ConvertTohex(b);
    return h.substring(0,32);
}

}