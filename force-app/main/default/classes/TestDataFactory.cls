@isTest
public class TestDataFactory {

    // ------------------ Utility ------------------
    private static String randomString(String prefix) {
        String raw = prefix + '_' + String.valueOf(Crypto.getRandomInteger()) + '_' + DateTime.now().getTime();
        return raw.length() > 70 ? raw.substring(0, 70) : raw;
    }

    private static String safeName(String value) {
        return value.length() > 80 ? value.substring(0, 80) : value;
    }

    private static Date todayPlus(Integer months) {
        return Date.today().addMonths(months);
    }

    // ------------------ ACCOUNT ------------------
    public static Account createAccount(Boolean doInsert) {
        Account managerAcc = new Account(
            Name = safeName(randomString('ManagerAccount')),
            Phone = '9998887777',
            Industry = 'Management'
        );
        insert managerAcc;

        Account acc = new Account(
            Name = safeName(randomString('TestAccount')),
            BillingStreet = '123 Billing Street',
            BillingCity = 'Chennai', 
            BillingState = 'Tamil Nadu',
            BillingPostalCode = '600001', 
            BillingCountry = 'India', 
            ShippingStreet = '456 Shipping Street', 
            ShippingCity = 'Chennai',
            ShippingState = 'Tamil Nadu',
            ShippingPostalCode = '600002',
            ShippingCountry = 'India', 
            Phone = '9876543210', 
            Website = 'https://example.com', 
            Industry = 'IT Services', 
            NumberOfEmployees = 200, 
            Description = 'Full test data account',
            AccountSource = 'LinkedIn',
            Current_Location__c = 'Chennai', 
            Date_of_Birth__c = Date.newInstance(1990, 1, 1), 
            Degree__c = 'B.Tech Computer Science', 
            FileName__c = 'resume.pdf', 
            Languages_Known__c = 'English, Hindi', 
            Service__c = 'Salesforce Consulting',
            Years_of_Experience__c = '5 Years', // Text field 
            Availability_for_New_Project__c = 'Immediately Available',
            Billing_Frequency__c = 'Monthly', 
            Blood_group__c = 'B+', 
            Contractor_Type__c = 'Freelancer', 
            Date_of_Joining__c = Date.today().addYears(-2),
            Designation__c = 'Salesforce Developer', 
            Employee_Email__c = 'test.employee@example.com',
            Employee_ID__c = 'EMP001',
            Manager__c = managerAcc.Id, // ✅ Lookup(Account) 
            MRR__c = 12000.0, 
            Notice_Period__c = '30 Days', 
            Payment_Type__c = 'Commission Based',
            Payment_Value__c = 5000.0,
            Personal_Email__c = 'personal@example.com', 
            Product__c = 'CRM', 
            Qualification__c = 'B.Tech', 
            Referred_By__c = 'LinkedIn', 
            //Region__c = 'South', 
            Service_Location_Of_Customer__c = 'Chennai',
            Start_Date__c = Date.today(),
              Status__c = 'Active',
              UAN_Number__c = 1234, // Number field
               Work_Experience__c = '5 Years', 
                Current_Organization__c = 'TechCorp',
                Past_Companies__c = 'Infosys, TCS',
                  LinkedIn__c = 'https://linkedin.com/in/test',
                   College_Name__c = 'Anna University',
                    Ext_Id__c = 'EXT1234', Active__c = true
        );
        if (doInsert) insert acc;
        return acc;
    }

    // ------------------ CONTACT ------------------
    public static Contact createContact(Boolean doInsert, Id accountId) {
        Contact c = new Contact(
            AccountId = accountId,
            FirstName = 'John',
            LastName = safeName(randomString('Doe')),
            Phone = '9876543210',
            Email = 'john.doe_' + randomString('mail') + '@example.com',
            Title = 'Salesforce Developer', 
            Department = 'IT', 
            MobilePhone = '9876500000',
            MailingStreet = '123 Main Street',
            MailingCity = 'Chennai', 
            MailingState = 'Tamil Nadu', 
            MailingPostalCode = '600001', 
            MailingCountry = 'India'
        );
        if (doInsert) insert c;
        return c;
    }

    // ------------------ SKILL ------------------
    public static Skill__c createSkill(Boolean doInsert) {
        Skill__c skill = new Skill__c(
            Skill_Name__c = 'Apex Development',
            Category__c = 'Technical',
            Role__c = 'Developer',
            Active__c = true
        );
        if (doInsert) insert skill;
        return skill;
    }

    // ------------------ EMPLOYEE SKILL ------------------
    public static Employee_Skill__c createEmployeeSkill(Boolean doInsert, Id accountId, Id skillId) {
        Employee_Skill__c empSkill = new Employee_Skill__c(
            Name = safeName(randomString('EmpSkill')),
            Employee_Name__c = accountId,
            Skill__c = skillId,
            Is_Skill_Certified__c = true,
            Primary_Secondary_Skill__c = 'Primary Skill',
            Proficiency__c = 'Beginner'
        );
        if (doInsert) insert empSkill;
        return empSkill;
    }

    // ------------------ JOB DESCRIPTION ------------------
    public static Job_Description__c createJobDescription(Boolean doInsert, Id opportunityId, Id accountId) {
        Job_Description__c jd = new Job_Description__c(
            Name = safeName(randomString('JobDescription')),
            Company_Name__c = 'TechCorp Pvt Ltd',
            Opportunity__c = opportunityId,
            Source__c = accountId,
            Skills__c = 'Apex, LWC, Integration',
            Experience__c = 3.0, 
            Other_Location__c = 'Remote, Bangalore',
            Key_Responsibilities__c = 'Develop, test and deploy Salesforce applications.', 
            Preferred_Location__c = 'Chennai', 
            Required_Qualifications__c = 'B.Tech in Computer Science',
            Time_Zone__c = 'IST',
            Job_Tagline__c = 'Join our growing Salesforce team!', 
            Seniority__c = 'Mid Level',
            FileName__c = 'JobDesc.pdf', 
            Status__c = 'Draft',
            Service__c = 'Salesforce Implementation',
            Amount__c = 80000.0
        );
        if (doInsert) insert jd;
        return jd;
    }

    // ------------------ OPPORTUNITY ------------------
    public static Opportunity createOpportunity(Boolean doInsert, Id accountId, Id jdId) {
        Opportunity opp = new Opportunity(
            Name = safeName(randomString('Opportunity')),
            AccountId = accountId,
            JD_Lookup__c = jdId,
            StageName = 'Prospecting',
            CloseDate = todayPlus(1),
            Amount = 100000.0,
            Date_Received__c = Date.today(), 
            Experience_Required__c = '3-5 Years', 
           Job_Description__c = 'Developer role with Apex/LWC skills.', 
           Job_Location__c = 'Hyderabad', 
           Job_Type__c = 'Onsite', 
           Role_Required__c = 'Salesforce Developer', 
          Skills_Required__c = 'Apex, LWC, SOQL', 
           Source_Of_Requirement__c = 'Whatsapp', 
           Start_Date__c = todayPlus(1),
	       Budget_Confirmed__c = true, 	
           Budget_In_JD__c = '400 USD', 
           Currency_Mentioned_In_JD__c = 'USD',
           Generate_Match__c='Generate Match',
           Identified_Budget__c= 400,
           Job_Duration__c	='5 Month onsite',
           Original_Budget_Amount__c=7000,
           Original_Currency__c='USD'
        );
        if (doInsert) insert opp;
        return opp;
    }

    // ------------------ CERTIFICATION ------------------
    public static Certification__c createCertification(Boolean doInsert, Id accountId, Id empSkillId) {
        Certification__c cert = new Certification__c(
            Name = safeName(randomString('Certification')),
            Candidate_Name__c = accountId,
            SubSkill__c = empSkillId,
            Issuing_Organization__c = 'Salesforce',
            Full_Certification_Name__c = 'Salesforce Certified Platform Developer I',
            Expiration_Date__c = Date.today().addYears(1), 
            Issue_Date__c = Date.today().addMonths(-6),
            Status__c = 'Verified',
            Badge_Resource_Name__c = 'DevBadge.png'
        );
        if (doInsert) insert cert;
        return cert;
    }

    // ------------------ PROJECT EXPERIENCE ------------------
    public static Project_Experience__c createProjectExperience(Boolean doInsert, Id accountId) {
        Project_Experience__c proj = new Project_Experience__c(
            Name = safeName(randomString('ProjectExp')),
            Employee_Name__c = accountId,
            Project_Name__c = 'CRM Migration',
            Project_Role__c = 'Developer',
            Action__c = 'Development', 
            End_Date__c = Date.today(), 
            Learning_Outcome__c = 'Improved problem solving',
            Project_Phase__c = 'Phase 1',  
            Result__c = 'Delivered Successfully', 
            Situtation__c = 'Agile project', 
            Skills_Applied__c = 'Apex, LWC', 
            Start_Date__c = Date.today().addMonths(-3), 
            Task__c = 'Custom feature development', 
            Tools_Used__c = 'VS Code, Git', 
            Achievements__c = 'Ahead of schedule', 
            Client_Name__c = 'GlobalCorp', 
            Responsibilities__c = 'Coding, Testing, Deployment',
            Designation_Job_Title__c = 'Software Engineer', 
            Project_Location__c = 'Remote', 
            Environment__c = 'Agile'
        );
        if (doInsert) insert proj;
        return proj;
    }

    // ------------------ INTERVIEW ------------------
public static Interview__c createInterview(Boolean doInsert, Id accountId, Id oppId) {
    // ✅ Always generate a short, unique, and safe name
    String nameVal = 'INT_' + Math.abs(Crypto.getRandomInteger());

    Interview__c interview = new Interview__c(
        Name = safeName(nameVal),               // stays under 80 chars
        Candidate_Name__c = accountId,
        Opportunity__c = oppId,
        Interview_Mode__c = 'Online',
        Interview_Round__c = 'Technical Round 1',
        Client_Name__c = accountId,
        Interviewer_Name__c = accountId,
        Interview_Stage__c = 'Shortlisted',
        Job_Description__c = 'Apex & Integration',
        Scheduled_Date_Time__c = DateTime.now().addDays(1)
    );

    // ✅ Double-check before insert to prevent any concatenation issues
    interview.Name = safeName(interview.Name);

    if (doInsert) insert interview;
    return interview;
}

    // ------------------ FEEDBACK ------------------
    public static Feedback__c createFeedback(Boolean doInsert, Id accountId, Id interviewId, Id oppId) {
        Feedback__c fb = new Feedback__c(
            Name = safeName(randomString('Feedback')),
            Candidate_Name__c = accountId,
            Interview__c = interviewId,
            Opportunity__c = oppId,
            Interviewer_Name__c = accountId, 
            Area_Of_Improvement__c = 'Apex Optimization',
            Interview_Status__c = 'Shortlisted', 
            Communication_Skills_Aptitude__c = '1',
            Recommendations__c = 'Recommended', 
            Recommended_for_Role__c = 'Yes', 
            Strength__c = 'Good communication',
            Weakness__c = 'Needs code optimization', 
            Job_Knowledge__c = '1',
            Technical_Skills__c = '1',
            Reason__c = 'Strong technical and problem-solving ability' 

        );
        if (doInsert) insert fb;
        return fb;
    }

    // ------------------ SERVICE ------------------
    public static Service__c createService(Boolean doInsert) {
        Service__c serv = new Service__c(
            Name = safeName(randomString('TestService')),
            Email_Body__c = 'Sample email body for Service testing',
            EmailFrom__c = 'service_' + randomString('mail') + '@example.com',
            WhatsappFrom__c = '+919876543210'
        );
        if (doInsert) insert serv;
        return serv;
    }

    // ------------------ CONTENT DOCUMENT ------------------
    public static Map<String, SObject> createContentDocumentFor(Id linkedEntityId) {
        Map<String, SObject> result = new Map<String, SObject>();

        ContentVersion cv = new ContentVersion(
            Title = 'resume.pdf',
            PathOnClient = 'resume.pdf',
            VersionData = Blob.valueOf('dummy content')
        );
        insert cv;

        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = linkedEntityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        result.put('ContentVersion', cv);
        result.put('ContentDocumentLink', cdl);
        return result;
    }

    // ------------------ FULL HIERARCHY ------------------
    public static Map<String, SObject> createAccountHierarchy(Boolean doInsert) {
        Map<String, SObject> result = new Map<String, SObject>();

        Account acc = createAccount(doInsert);
        Contact con = createContact(doInsert, acc.Id);
        Skill__c skill = createSkill(doInsert);
        Employee_Skill__c empSkill = createEmployeeSkill(doInsert, acc.Id, skill.Id);
        Job_Description__c jd = createJobDescription(doInsert, null, acc.Id);
        Opportunity opp = createOpportunity(doInsert, acc.Id, jd.Id);
        jd.Opportunity__c = opp.Id; update jd;
        Certification__c cert = createCertification(doInsert, acc.Id, empSkill.Id);
        Project_Experience__c proj = createProjectExperience(doInsert, acc.Id);
        Interview__c interview = createInterview(doInsert, acc.Id, opp.Id);
        Feedback__c fb = createFeedback(doInsert, acc.Id, interview.Id, opp.Id);
        Service__c serv = createService(doInsert);

        // ✅ Attach a sample ContentDocument to Service__c
        Map<String, SObject> contentMap = createContentDocumentFor(serv.Id);

        result.put('Account', acc);
        result.put('Contact', con);
        result.put('Skill', skill);
        result.put('EmployeeSkill', empSkill);
        result.put('JobDescription', jd);
        result.put('Opportunity', opp);
        result.put('Certification', cert);
        result.put('ProjectExperience', proj);
        result.put('Interview', interview);
        result.put('Feedback', fb);
        result.put('Service', serv);
        result.putAll(contentMap);

        return result;
    }

// ------------------ LIGHTWEIGHT TEST DATA FOR PROMPT BUILDER TESTS ------------------
public static Map<String, SObject> createMinimalHierarchy(Boolean doInsert) {
    Map<String, SObject> result = new Map<String, SObject>();

    // Step 1: Create an Account (basic fields only)
    Account acc = new Account(
        Name = 'QbayTestAccount_' + String.valueOf(Crypto.getRandomInteger()),
        Phone = '9876543210',
        Industry = 'IT Services',
        BillingCity = 'Chennai'
    );
    if (doInsert) insert acc;
    result.put('Account', acc);

    // Step 2: Create a minimal ContentDocument and link to Account
    ContentVersion cv = new ContentVersion(
        Title = 'Resume.pdf',
        PathOnClient = 'Resume.pdf',
        VersionData = Blob.valueOf('Dummy resume content')
    );
    insert cv;

    Id contentDocId = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
    ].ContentDocumentId;

    ContentDocumentLink cdl = new ContentDocumentLink(
        ContentDocumentId = contentDocId,
        LinkedEntityId = acc.Id,
        ShareType = 'V',
        Visibility = 'AllUsers'
    );
    insert cdl;

    result.put('ContentVersion', cv);
    result.put('ContentDocumentLink', cdl);

    return result;
}

}