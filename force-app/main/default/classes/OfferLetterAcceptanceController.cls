/*public without sharing class OfferLetterAcceptanceController {
    public Boolean isSuccess {get; set;}
    public String errorMessage {get; set;}
    public String candidateName {get; set;}
    public String designation {get; set;}
    public String acceptanceDate {get; set;}
    public String onboardingFormUrl {get; set;}

    // Constructor ONLY checks token and sets up state
    public OfferLetterAcceptanceController() {
        isSuccess = false;
    }

    // This method does everything except page setup
    public PageReference processAcceptance() {
        String token = ApexPages.currentPage().getParameters().get('token');
        if (String.isBlank(token)) {
            errorMessage = 'Invalid or missing acceptance token. Please use the link provided in your email.';
            return null;
        }
        try {
            List<Candidate__c> candidates = [
                SELECT Id, First_Name__c, Last_Name__c, Designation__c, 
                       Offer_Accepted__c, Offer_Accepted_Date__c, Personal_Email__c, 
                       onboarding_Form_URL__c, Onboarding_Status__c,
                       Offer_Letter_Status__c
                FROM Candidate__c 
                WHERE Offer_Acceptance_Token__c = :token 
                LIMIT 1
            ];
            if (candidates.isEmpty()) {
                errorMessage = 'Invalid or expired acceptance link. Please contact HR for assistance.';
                return null;
            }
            Candidate__c candidate = candidates[0];
            candidateName = candidate.First_Name__c + ' ' + candidate.Last_Name__c;
            designation = candidate.Designation__c;
            onboardingFormUrl = candidate.onboarding_Form_URL__c;

            if (candidate.Offer_Accepted__c) {
                isSuccess = true;
                acceptanceDate = candidate.Offer_Accepted_Date__c != null ? 
                    candidate.Offer_Accepted_Date__c.format() : Date.today().format();
                return null;
            }

            // Safe to run DML here
            candidate.Offer_Accepted__c = true;
            candidate.Offer_Accepted_Date__c = Date.today();
            candidate.Offer_Letter_Status__c = 'Accepted';
            candidate.Onboarding_Status__c = 'In Progress';
            update candidate;

            isSuccess = true;
            acceptanceDate = Date.today().format();
        } catch (Exception e) {
            errorMessage = 'An unexpected error occurred. Please try again or contact HR at hr@quadrobay.com';
            System.debug('Error in OfferLetterAcceptanceController: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        return null;
    }
}*/
public without sharing class OfferLetterAcceptanceController {
    public Boolean isSuccess { get; set; }
    public String errorMessage { get; set; }
    public String candidateName { get; set; }
    public String designation { get; set; }
    public String acceptanceDate { get; set; }
    public String onboardingFormUrl { get; set; }
    public String onboardingStatus { get; set;}

    public OfferLetterAcceptanceController() {
        isSuccess = false;
    }

    public PageReference processAcceptance() {
        String token = ApexPages.currentPage().getParameters().get('token');
        if (String.isBlank(token)) {
            errorMessage = 'Invalid or missing acceptance token. Please use the link provided in your email.';
            return null;
        }

        try {
            Candidate__c candidate = [
                SELECT Id, First_Name__c, Last_Name__c, Designation__c,
                       Offer_Accepted__c, Offer_Accepted_Date__c,
                       Offer_Letter_Status__c, Offer_Letter_Signed_Document_Id__c,Onboarding_Status__c,
                       Personal_Email__c, onboarding_Form_URL__c,Date_of_Birth__c,Phone_No__c
                FROM Candidate__c
                WHERE Offer_Acceptance_Token__c = :token
                LIMIT 1
            ];

            if (candidate == null) {
                errorMessage = 'Invalid or expired acceptance link. Please contact HR for assistance.';
                return null;
            }

            candidateName = candidate.First_Name__c + ' ' + candidate.Last_Name__c;
            designation = candidate.Designation__c;
            onboardingFormUrl = candidate.onboarding_Form_URL__c;
			onboardingStatus = candidate.Onboarding_Status__c;

            // Already accepted
            if (candidate.Offer_Accepted__c) {
                isSuccess = true;
                acceptanceDate = candidate.Offer_Accepted_Date__c != null ? 
                    String.valueOf(candidate.Offer_Accepted_Date__c) : Date.today().format();
                return null;
            }

            // Capture IP
            String ipAddress = ApexPages.currentPage().getHeaders().get('True-Client-IP');
            if (String.isBlank(ipAddress)) ipAddress = ApexPages.currentPage().getHeaders().get('X-Forwarded-For');
            if (String.isBlank(ipAddress)) ipAddress = 'Unknown';

            // 1️⃣ Update candidate acceptance
            candidate.Offer_Accepted__c = true;
            candidate.Offer_Accepted_Date__c = Date.today();
            candidate.Offer_Letter_Status__c = 'Accepted';
            candidate.Onboarding_Status__c = 'In Progress';
            candidate.Offer_Acceptance_IP__c = ipAddress;
            update candidate;
		// Step 2: Requery updated data for PDF rendering
		Candidate__c candRecord = [
    SELECT Id, First_Name__c, Last_Name__c, Offer_Accepted__c, 
           Offer_Accepted_Date__c, Offer_Acceptance_IP__c
    FROM Candidate__c
    WHERE Id = :candidate.Id
		];
            // 2️⃣ Generate signed PDF
            PageReference pdfPage = Page.OfferLetterPDF;
            //pdfPage.getParameters().put('id', String.valueOf(candidate.Id));
			pdfPage.getParameters().put('id', candRecord.Id);
            //Blob signedPdf = pdfPage.getContentAsPDF();
		Blob signedPdf;
		if (Test.isRunningTest()) {
    	signedPdf = Blob.valueOf('UNIT.TEST.PDF.CONTENT');
		} else {
    	signedPdf = pdfPage.getContentAsPDF();
		}
            // 3️⃣ Save signed PDF as new file
            String fileName = 'Offer_Letter_Signed_' + candidate.Last_Name__c + '_' + Date.today().format();
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName + '.pdf';
            cv.VersionData = signedPdf;
            cv.FirstPublishLocationId = candRecord.Id;
            insert cv;

            // Save the doc id for reference
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            candidate.Offer_Letter_Signed_Document_Id__c = insertedCv.ContentDocumentId;
            update candidate;

            isSuccess = true;
            acceptanceDate = String.valueOf(System.now());

           // --- Send HR notification email (no attachment) ---
try {
    // ✅ Get org base URL safely for API v58+
    String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
    String candidateLink = baseUrl + '/lightning/r/Candidate__c/' + candidate.Id + '/view';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

    // HR email address
    mail.setToAddresses(new String[] { 'hr@quadrobay.com' });

    mail.setSubject('Candidate Accepted Offer - ' + candidate.First_Name__c + ' ' + candidate.Last_Name__c);

    String body =
        'Hello HR Team,\n\n' +
        'The following candidate has accepted the offer:\n\n' +
        'Name: ' + candidate.First_Name__c + ' ' + candidate.Last_Name__c + '\n' +
        'Designation: ' + candidate.Designation__c + '\n' +
        'Acceptance Date: ' + String.valueOf(candidate.Offer_Accepted_Date__c) + '\n' +
        'IP Address: ' + candidate.Offer_Acceptance_IP__c + '\n\n' +
        'You can view the candidate record here:\n' + candidateLink + '\n\n' +
        'Regards,\nHR Automation System\nQuadrobay Technologies Pvt. Ltd.';

    mail.setPlainTextBody(body);

    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

} catch (Exception exEmail) {
    System.debug('⚠️ Failed to send HR notification email: ' + exEmail.getMessage());
}

            
        } catch (Exception e) {
            errorMessage = 'An unexpected error occurred. Please try again or contact HR at hr@quadrobay.com';
            System.debug('Error in OfferLetterAcceptanceController: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        return null;
    }
}