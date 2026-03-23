@isTest(SeeAllData=true)
private class parseEmailTest {

    /* =========================================================
     * Utility: Generate large blob (> 50 KB)
     * ========================================================= */
    private static Blob generateLargeBlob() {
        String s = '';
        for (Integer i = 0; i < 60000; i++) {
            s += 'A';
        }
        return Blob.valueOf(s);
    }

    /* --------------------------------------------------
     * TEST 1: Valid Resume Attachment Accepted
     * -------------------------------------------------- */
    @isTest
    static void testValidResumeAttachmentAccepted() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'resume@test.com';
        email.subject = 'Resume Upload';
        email.plainTextBody = 'Resume attached';

        Messaging.InboundEmail.BinaryAttachment att =
            new Messaging.InboundEmail.BinaryAttachment();
        att.fileName = 'resume.pdf';
        att.body = generateLargeBlob(); // > 50 KB

        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>{ att };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Id
            FROM Service__c
            WHERE EmailFrom__c = 'resume@test.com'
            LIMIT 1
        ];

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :s.Id
        ];

        System.assertEquals(1, links.size());
    }

    /* --------------------------------------------------
     * TEST 2: Signature Image Skipped
     * -------------------------------------------------- */
    @isTest
    static void testSignatureImageSkipped() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'logo@test.com';
        email.subject = 'Logo Only';
        email.plainTextBody = 'Signature image';

        Messaging.InboundEmail.BinaryAttachment att =
            new Messaging.InboundEmail.BinaryAttachment();
        att.fileName = 'logo.png';
        att.body = generateLargeBlob();

        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>{ att };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Id
            FROM Service__c
            WHERE EmailFrom__c = 'logo@test.com'
            LIMIT 1
        ];

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :s.Id
        ];

        System.assertEquals(0, links.size());
    }

    /* --------------------------------------------------
     * TEST 3: Small Resume File Skipped
     * -------------------------------------------------- */
    @isTest
    static void testSmallResumeSkipped() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'small@test.com';
        email.subject = 'Small Resume';
        email.plainTextBody = 'Tiny file';

        Messaging.InboundEmail.BinaryAttachment att =
            new Messaging.InboundEmail.BinaryAttachment();
        att.fileName = 'resume.pdf';
        att.body = Blob.valueOf('tiny'); // < 50 KB

        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>{ att };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Id
            FROM Service__c
            WHERE EmailFrom__c = 'small@test.com'
            LIMIT 1
        ];

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :s.Id
        ];

        System.assertEquals(0, links.size());
    }

    /* --------------------------------------------------
     * TEST 4: Job Description Email (No Attachment)
     * -------------------------------------------------- */
    @isTest
    static void testJobDescriptionEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'jd@test.com';
        email.subject = 'Salesforce Developer JD';
        email.plainTextBody = 'Job description content';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'jd@test.com'
            LIMIT 1
        ];

        System.assertEquals('Salesforce Developer JD', s.Name);
    }

    /* --------------------------------------------------
     * TEST 5: No Subject, No Attachment
     * -------------------------------------------------- */
    @isTest
    static void testNoSubjectEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'nosubject@test.com';
        email.plainTextBody = 'Email body only';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'nosubject@test.com'
            LIMIT 1
        ];

        System.assertEquals('Email Resume', s.Name);
    }

    /* --------------------------------------------------
     * TEST 6: Safe Execution Flow (No Failure)
     * -------------------------------------------------- */
    @isTest
    static void testSafeExecutionFlow() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'safe@test.com';
        email.subject = 'Safe Subject';
        email.plainTextBody = 'Safe body';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Email processed successfully', result.message);
    }
}



/*@isTest(SeeAllData=true)
private class parseEmailTest {

    
    @isTest
    static void testCandidateResumeEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'candidate@test.com';
        email.subject = 'Candidate Resume';
        email.plainTextBody = 'Please find attached resume';

        Messaging.InboundEmail.BinaryAttachment att =
            new Messaging.InboundEmail.BinaryAttachment();
        att.fileName = 'resume.pdf';
        att.body = Blob.valueOf('PDF DATA'); // ✅ FIXED

        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>{ att };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;
        env.toAddress = 'resume@company.com';

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Id, Name, EmailFrom__c, Email_Subject__c, Email_Body__c
            FROM Service__c
            WHERE EmailFrom__c = 'candidate@test.com'
            LIMIT 1
        ];

        System.assertEquals('Candidate Resume', s.Name);
        System.assertEquals('candidate@test.com', s.EmailFrom__c);

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :s.Id
        ];
        //System.assertEquals(1, links.size());
    }

   
    @isTest
    static void testJobDescriptionEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'jd@test.com';
        email.subject = 'Salesforce Developer JD';
        email.plainTextBody = 'This is a job description';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;
        env.toAddress = 'jd@company.com';

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'jd@test.com'
            LIMIT 1
        ];

        System.assertEquals('Salesforce Developer JD', s.Name);
    }

  
    @isTest
    static void testNoSubjectEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'nosubject@test.com';
        email.plainTextBody = 'Email body only';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'nosubject@test.com'
            LIMIT 1
        ];

        System.assertEquals('Email Resume', s.Name);
    }

    
    @isTest
    static void testSafeExecutionFlow() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'test123@gmail.com';
        email.subject = 'Test Subject';
        email.plainTextBody = 'Test Body';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('Email processed successfully', result.message);
    }
}  */




/*@isTest(SeeAllData=true)
private class parseEmailTest {

    
    @isTest
    static void testCandidateResumeEmail() {

        // -------------------------
        // Inbound Email
        // -------------------------
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'candidate@test.com';
        email.subject = 'Candidate Resume';
        email.plainTextBody = 'Please find attached resume';

        Messaging.InboundEmail.BinaryAttachment att =
            new Messaging.InboundEmail.BinaryAttachment();
        att.fileName = 'resume.pdf';
        att.body = Blob.valueOf('PDF DATA');

        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>{ att };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;
        env.toAddress = 'resume@company.com';

        // -------------------------
        // Execute
        // -------------------------
        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

        // -------------------------
        // Assertions
        // -------------------------
       // System.assertEquals(true, result.success);
       // System.assertEquals('Email processed successfully', result.message);

        Service__c s = [
            SELECT Id, Name, EmailFrom__c, Email_Subject__c, Email_Body__c
            FROM Service__c
            LIMIT 1
        ];

        System.assertEquals('candidate@test.com', s.EmailFrom__c);
        System.assertEquals('Candidate Resume', s.Email_Subject__c);

        // Attachment linked
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :s.Id
        ];
        System.assertEquals(1, links.size());
    }

  
    @isTest
    static void testJobDescriptionEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'jd@test.com';
        email.subject = 'Salesforce Developer JD';
        email.plainTextBody = 'This is a job description';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;
        env.toAddress = 'jd@company.com';

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

       // System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'jd@test.com'
            LIMIT 1
        ];

        System.assertEquals('Salesforce Developer JD', s.Name);
    }

    
    @isTest
    static void testNoSubjectEmail() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'nosubject@test.com';
        email.plainTextBody = 'Email body only';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = email.fromAddress;

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(email, env);
        Test.stopTest();

       // System.assertEquals(true, result.success);

        Service__c s = [
            SELECT Name
            FROM Service__c
            WHERE EmailFrom__c = 'nosubject@test.com'
            LIMIT 1
        ];

        System.assertEquals('Email Resume', s.Name);
    }

   
    @isTest
    static void testExceptionFlow() {

        Test.startTest();
        Messaging.InboundEmailResult result =
            new parseEmail().handleInboundEmail(null, null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(
            result.message.contains('Error processing email')
        );
    }
} */