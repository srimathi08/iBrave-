public with sharing class OpportunityMatchHelper {
    
    public class MatchResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String explanation;
    }

    // ----------------------------
    // Generate Matches for Subset (main logic)
    // ----------------------------
    public static void generateMatchesForSubset(Id opportunityId, List<Id> accountIds) {
        List<Job_Match__c> insertedMatches = new List<Job_Match__c>();

        // Step 1: Get Opportunity details
        Opportunity opp = [
            SELECT Id, Job_Description__c, Skills_Required__c, Experience_Required__c,Role_Required__c,Required_Qualifications__c,Must_Have_Skills__c , Secondary_Skills__c, Good_to_Have_Skills__c 
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        String jobDescription   = String.isNotBlank(opp.Job_Description__c) ? opp.Job_Description__c : '';
      //  String skillsRequired   = String.isNotBlank(opp.Skills_Required__c) ? opp.Skills_Required__c : '';
        String expRequired      = String.isNotBlank(opp.Experience_Required__c) ? opp.Experience_Required__c : '';


        // Step 2: Fetch given Accounts only
        List<Account> accounts = [
            SELECT Id, Name, Years_of_Experience__c,Designation__c,Description, 
                   (SELECT Skill_Name__c, Employee_Name__r.Name FROM Employee_Skills__r),
                   (SELECT Name, Candidate_Name__r.Name FROM Certifications__r),
                   (SELECT Project_Name__c, Skills_Applied__c, Tools_Used__c,Achievements__c ,Action__c,Learning_Outcome__c,
                    Responsibilities__c,Result__c, Employee_Name__r.Name FROM Project_Experiences__r)
            FROM Account
            WHERE Id IN :accountIds
AND Status__c != 'Blacklist'
AND Active__c  = True
AND (Availability_for_New_Project__c IN ('Immediately Available', 'Available in 1 Week', 'Available in 2 Weeks')
           OR Availability_for_New_Project__c = NULL)
        ];

        // Step 3: Loop through accounts
        for (Account acc : accounts) {
            try {

               // ----------------------------
// EXPERIENCE FILTER (🔥 ADD HERE)
// ----------------------------
Decimal candidateExp = 0.0;

if (String.isNotBlank(acc.Years_of_Experience__c)) {
    try {
        // Removes words like "years", "+", etc.
        String cleanedExp = acc.Years_of_Experience__c.replaceAll('[^0-9.]', '');
        
        if (String.isNotBlank(cleanedExp)) {
            candidateExp = Decimal.valueOf(cleanedExp);
        }
    } catch (Exception e) {
        candidateExp = 0.0;
    }
}
Decimal requiredExp = 0;

// Convert required experience safely
if (String.isNotBlank(expRequired)) {
    try {
        requiredExp = Decimal.valueOf(expRequired.replaceAll('[^0-9.]', ''));
    } catch (Exception e) {
        requiredExp = 0;
    }
}

// Define range
Decimal minAllowedExp = requiredExp;
Decimal maxAllowedExp = requiredExp;

if (requiredExp < 5) {
    // Exact match only
    minAllowedExp = requiredExp;
    maxAllowedExp = requiredExp;
} 
else if (requiredExp >= 5 && requiredExp <= 10) {
    minAllowedExp = requiredExp - 2;
} 
else if (requiredExp > 10 && requiredExp < 15) {
    minAllowedExp = requiredExp - 3;
} 
else if (requiredExp >= 15) {
    minAllowedExp = requiredExp - 4;
}

// 🚫 SKIP candidates outside range
if (candidateExp < minAllowedExp || candidateExp > maxAllowedExp) {
    System.debug('⛔ Skipping candidate due to experience mismatch: ' + acc.Name);
    continue;
}                  

                String candidateName = acc.Name;
                String candidateExperience = acc.Years_of_Experience__c != null ? String.valueOf(acc.Years_of_Experience__c) : '0';

                String skills = '';
                for (Employee_Skill__c skill : acc.Employee_Skills__r) {
                    if (skill.Skill_Name__c != null) {
                        skills += (skill.Employee_Name__r != null ? skill.Employee_Name__r.Name + ' - ' : '') + skill.Skill_Name__c + ', ';
                    }
                }

                String certifications = '';
                for (Certification__c cert : acc.Certifications__r) {
                    certifications += (cert.Candidate_Name__r != null ? cert.Candidate_Name__r.Name + ' - ' : '') + cert.Name + ', ';
                }

              /*  String projectExperience = '';
                for (Project_Experience__c proj : acc.Project_Experiences__r) {
                    projectExperience += 
                        (proj.Employee_Name__r != null ? proj.Employee_Name__r.Name + ': ' : '') +
                        'Skills Applied=' + (proj.Skills_Applied__c != null ? proj.Skills_Applied__c : '') +
                        ', Tools Used=' + (proj.Tools_Used__c != null ? proj.Tools_Used__c : '') + '\n';
                }*/

                  // Project Experience (✅ Includes your new fields)
String projectExperience = '';
if (acc.Project_Experiences__r != null) {
    for (Project_Experience__c proj : acc.Project_Experiences__r) {
        projectExperience += 
            (proj.Employee_Name__r != null ? proj.Employee_Name__r.Name + ': ' : '') +
            (proj.Project_Name__c != null ? 'Project=' + proj.Project_Name__c + ', ' : '') +
            (proj.Skills_Applied__c != null ? 'Skills Applied=' + proj.Skills_Applied__c + ', ' : '') +
            (proj.Tools_Used__c != null ? 'Tools Used=' + proj.Tools_Used__c + ', ' : '') +
            (proj.Achievements__c != null ? 'Achievements=' + proj.Achievements__c + ', ' : '') +
            (proj.Action__c != null ? 'Action=' + proj.Action__c + ', ' : '') +
            (proj.Learning_Outcome__c != null ? 'Learning Outcome=' + proj.Learning_Outcome__c + ', ' : '') +
            (proj.Responsibilities__c != null ? 'Responsibilities=' + proj.Responsibilities__c + ', ' : '') +
            (proj.Result__c != null ? 'Result=' + proj.Result__c : '') + '\n';
    }
}
                // ----------------------------
                // Group fields into 5 inputs
                // ----------------------------
              /* String opportunityDetails = 
              'Job Description: ' + jobDescription + '\n' +
              'Skills Required: ' + skillsRequired + '\n' +
             'Experience Required: ' + expRequired + ' years\n' +
             'Role Required: ' + (opp.Role_Required__c != null ? opp.Role_Required__c : '') + '\n' +
'Qualifications Required: ' + (opp.Required_Qualifications__c != null ? opp.Required_Qualifications__c : '')+ '\n';  */ 


/*String opportunityDetails =
    (String.isNotBlank(jobDescription) ? jobDescription + ' ' : '') +
    (String.isNotBlank(skillsRequired) ? skillsRequired + ' ' : '') +
    (String.isNotBlank(opp.Role_Required__c) ? opp.Role_Required__c + ' ' : '') +
    (String.isNotBlank(opp.Required_Qualifications__c) ? opp.Required_Qualifications__c : '');  */

String opportunityDetails =
    '\n--- JOB DESCRIPTION ---\n' +
    (String.isNotBlank(jobDescription) ? jobDescription + '\n' : '') +

    '\n--- MUST HAVE SKILLS ---\n' +
    (String.isNotBlank(opp.Must_Have_Skills__c) ? opp.Must_Have_Skills__c + '\n' : '') +

    '\n--- SECONDARY SKILLS ---\n' +
    (String.isNotBlank(opp.Secondary_Skills__c) ? opp.Secondary_Skills__c + '\n' : '') +

    '\n--- GOOD TO HAVE SKILLS ---\n' +
    (String.isNotBlank(opp.Good_to_Have_Skills__c) ? opp.Good_to_Have_Skills__c + '\n' : '') +
    /*'\n--- SKILLS REQUIRED ---\n' +
    (String.isNotBlank(skillsRequired) ? skillsRequired + '\n' : '') + */
    '\n--- ROLE REQUIRED ---\n' +
    (String.isNotBlank(opp.Role_Required__c) ? opp.Role_Required__c + '\n' : '') +
    '\n--- QUALIFICATIONS ---\n' +
    (String.isNotBlank(opp.Required_Qualifications__c) ? opp.Required_Qualifications__c : '');


                String candidateProfile =
    '--- CANDIDATE PROFILE ---\n' +
    'Name: ' + acc.Name + '\n' +
    'Years of Experience: ' +
        (acc.Years_of_Experience__c != null ? acc.Years_of_Experience__c : '') + '\n' +
    'Designation: ' + (acc.Designation__c != null ? acc.Designation__c : '') + '\n\n' +
    '--- DESCRIPTION ---\n' +
    (acc.Description != null ? acc.Description : '') + '\n';

                // Step 4: Call Einstein LLM with grouped inputs
                String jsonResult = getCandidateJobMatch(
                    opportunityDetails,
                    candidateProfile,
                    skills,
                    certifications,
                    projectExperience
                );

                String cleanedJson = cleanJson(jsonResult);

                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
                Integer score = parsed.containsKey('score') ? Integer.valueOf(parsed.get('score')) : 0;
                String explanation = parsed.containsKey('explanation') ? (String)parsed.get('explanation') : 'No explanation provided.';

                Job_Match__c match = new Job_Match__c(
                    Candidate_Name__c = acc.Id,
                    Opportunity_Name__c = opportunityId,
                    Match_Score__c = score,
                    Explanation__c = explanation
                );

                insertedMatches.add(match);

            } catch (Exception e) {
                System.debug('❌ Error processing Account ' + acc.Id + ': ' + e.getMessage());
            }
        }

        // Step 5: Insert Job_Match__c
        if (!insertedMatches.isEmpty()) {
            try {
                insert insertedMatches;
                System.debug('✅ Inserted ' + insertedMatches.size() + ' Job_Match__c records');
            } catch (Exception e) {
                System.debug('❌ Insert failed: ' + e.getMessage());
            }
        }
    }

    // ----------------------------
    // Einstein API Call
    // ----------------------------
    @AuraEnabled
    public static String getCandidateJobMatch(
        String opportunityDetails,
        String candidateProfile,
        String skills,
        String certifications,
        String projectExperience
    ) {
        System.debug('Entered getCandidateJobMatch');
        try {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue oppDetailsVal = new ConnectApi.WrappedValue();
oppDetailsVal.value = opportunityDetails;
inputParams.put('Input:Opportunity_Details', oppDetailsVal);

ConnectApi.WrappedValue candidateProfileVal = new ConnectApi.WrappedValue();
candidateProfileVal.value = candidateProfile;
inputParams.put('Input:Candidate_Profile', candidateProfileVal);

ConnectApi.WrappedValue skillsVal = new ConnectApi.WrappedValue();
skillsVal.value = skills;
inputParams.put('Input:Candidate_Skills', skillsVal);

ConnectApi.WrappedValue certsVal = new ConnectApi.WrappedValue();
certsVal.value = certifications;
inputParams.put('Input:Candidate_Certifications', certsVal);

ConnectApi.WrappedValue projectsVal = new ConnectApi.WrappedValue();
projectsVal.value = projectExperience;
inputParams.put('Input:Candidate_Projects', projectsVal);


            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.inputParams = inputParams;
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.numGenerations = 1;
            input.additionalConfig.enablePiiMasking = true;
            input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
            input.isPreview = false;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Profile_Match', input);

            return output.generations[0].text;

        } catch (Exception e) {
            return '{"score":0, "explanation":"Error: ' + e.getMessage().replace('"','') + '"}';
        }
    }

    // ----------------------------
    // Utility: Clean JSON
    // ----------------------------
    public static String cleanJson(String response) {
        response = response.replaceAll('```json', '');
        response = response.replaceAll('```', '');
        response = response.replaceAll('\u00A0', ' ');
        return response.trim();
    }

    // ----------------------------
    // Get All Matches
    // ----------------------------
    @AuraEnabled(cacheable=true)
    public static List<Job_Match__c> getAllMatches(Id opportunityId) {
        return [
            SELECT Id, Match_Score__c, Explanation__c, Candidate_Name__r.Name
            FROM Job_Match__c
            WHERE Opportunity_Name__c = :opportunityId
            AND Match_Score__c >= 6
            ORDER BY CreatedDate DESC
 //ORDER BY Match_Score__c DESC NULLS LAST
        ];
    }

    // ----------------------------
    // Get Interview by Candidate
    // ----------------------------
    @AuraEnabled
    public static Interview__c getInterviewByCandidate(Id candidateId) {
        return [
            SELECT Id, Candidate_Name__r.Name, Interviewer_Name__c,
                   Scheduled_Date_Time__c, Opportunity__r.Name, Job_Description__c
            FROM Interview__c
            WHERE Candidate_Name__c = :candidateId
            LIMIT 1
        ];
    }

    // ----------------------------
    // Get Opportunity Details
    // ----------------------------
    @AuraEnabled(cacheable=true)
    public static Opportunity getOpportunityDetails(Id opportunityId) {
        return [
            SELECT Id, Job_Description__c, Skills_Required__c, Experience_Required__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
    }

    // ----------------------------
    // Create Interview (Map-based)
    // ----------------------------
    @AuraEnabled
    public static void createInterviewRecord(Map<String, Object> interviewData) {
        Interview__c interview = new Interview__c();
        interview.Candidate_Name__c = (Id)interviewData.get('Candidate_Name__c');
        interview.Interviewer_Name__c = (String)interviewData.get('Interviewer_Name__c');
        interview.Scheduled_Date_Time__c = (Datetime)interviewData.get('Scheduled_Date_Time__c');
        interview.Opportunity__c = (Id)interviewData.get('Opportunity__c');
        interview.Job_Description__c = (String)interviewData.get('Job_Description__c');
        insert interview;
    }

    // ----------------------------
    // Save Interview (field-based)
    // ----------------------------
    @AuraEnabled
    public static void saveInterview(String email, Id interviewerId, Datetime scheduledDateTime,
                                     Id candidateId, Id opportunityId, String jobDescription) {
        System.debug('✅ Entered saveInterview');
        try {
            if (String.isBlank(email)) throw new AuraHandledException('Email is required.');
            if (interviewerId == null) throw new AuraHandledException('Interviewer ID is required.');
            if (scheduledDateTime == null) throw new AuraHandledException('Scheduled date and time is required.');
            if (candidateId == null) throw new AuraHandledException('Candidate ID is required.');
            if (opportunityId == null) throw new AuraHandledException('Opportunity ID is required.');

            Interview__c interview = new Interview__c();
            interview.Interviewer_Name__c = interviewerId;
            interview.Scheduled_Date_Time__c = scheduledDateTime;
            interview.Candidate_Name__c = candidateId;
            interview.Opportunity__c = opportunityId;
            interview.Job_Description__c = jobDescription;

            insert interview;
            System.debug('✅ Interview inserted successfully: ' + interview.Id);

        } catch (Exception e) {
            System.debug('❌ Error in saveInterview: ' + e.getMessage());
            throw new AuraHandledException('Failed to save interview: ' + e.getMessage());
        }
    }
}







/*public with sharing class OpportunityMatchHelper {

    public class MatchResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String explanation;
    }

    // ----------------------------
    // Helper: Check if JD is empty
    // ----------------------------
    private static Boolean isJDEmpty(Opportunity opp) {
        return String.isBlank(opp.Job_Description__c)
            && String.isBlank(opp.Skills_Required__c)
            && String.isBlank(opp.Role_Required__c)
            && String.isBlank(opp.Required_Qualifications__c);
    }

    // ----------------------------
    // Generate Matches for Subset
    // ----------------------------
    public static void generateMatchesForSubset(Id opportunityId, List<Id> accountIds) {

        List<Job_Match__c> insertedMatches = new List<Job_Match__c>();

        // Step 1: Get Opportunity details
        Opportunity opp = [
            SELECT Id,
                   Job_Description__c,
                   Skills_Required__c,
                   Experience_Required__c,
                   Role_Required__c,
                   Required_Qualifications__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        String jobDescription = String.isNotBlank(opp.Job_Description__c)
            ? opp.Job_Description__c
            : '';

        String skillsRequired = String.isNotBlank(opp.Skills_Required__c)
            ? opp.Skills_Required__c
            : '';

        // Step 2: Fetch Accounts
        List<Account> accounts = [
            SELECT Id, Name, Years_of_Experience__c, Designation__c, Description,
                   (SELECT Skill_Name__c, Employee_Name__r.Name FROM Employee_Skills__r),
                   (SELECT Name, Candidate_Name__r.Name FROM Certifications__r),
                   (SELECT Project_Name__c, Skills_Applied__c, Tools_Used__c,
                           Achievements__c, Action__c, Learning_Outcome__c,
                           Responsibilities__c, Result__c, Employee_Name__r.Name
                    FROM Project_Experiences__r)
            FROM Account
            WHERE Id IN :accountIds
              AND Status__c != 'Blacklist'
              AND (
                    Availability_for_New_Project__c IN
                    ('Immediately Available', 'Available in 1 Week', 'Available in 2 Weeks')
                    OR Availability_for_New_Project__c = NULL
                  )
        ];

        // Step 3: Loop through Accounts
        for (Account acc : accounts) {
            try {

                // ----------------------------
                // 🔴 HARD STOP: Empty JD
                // ----------------------------
                if (isJDEmpty(opp)) {
                    insertedMatches.add(new Job_Match__c(
                        Candidate_Name__c   = acc.Id,
                        Opportunity_Name__c = opportunityId,
                        Match_Score__c      = 0,
                        Explanation__c      =
                            'Job description is empty; match scoring was skipped.'
                    ));
                    continue; // ⛔ Skip Einstein call
                }

                // ----------------------------
                // Build Candidate Inputs
                // ----------------------------
                String skills = '';
                for (Employee_Skill__c sk : acc.Employee_Skills__r) {
                    if (sk.Skill_Name__c != null) {
                        skills += sk.Skill_Name__c + ', ';
                    }
                }

                String certifications = '';
                for (Certification__c cert : acc.Certifications__r) {
                    certifications += cert.Name + ', ';
                }

                String projectExperience = '';
                if (acc.Project_Experiences__r != null) {
                    for (Project_Experience__c proj : acc.Project_Experiences__r) {
                        projectExperience +=
                            (proj.Project_Name__c != null ? 'Project=' + proj.Project_Name__c + ', ' : '') +
                            (proj.Skills_Applied__c != null ? 'Skills=' + proj.Skills_Applied__c + ', ' : '') +
                            (proj.Tools_Used__c != null ? 'Tools=' + proj.Tools_Used__c : '') + '\n';
                    }
                }

                // ----------------------------
                // Build Opportunity Details
                // ----------------------------
                String opportunityDetails =
                    '--- JOB DESCRIPTION ---\n' +
                    (String.isNotBlank(jobDescription) ? jobDescription + '\n' : '') +
                    '\n--- SKILLS REQUIRED ---\n' +
                    (String.isNotBlank(skillsRequired) ? skillsRequired + '\n' : '') +
                    '\n--- ROLE REQUIRED ---\n' +
                    (String.isNotBlank(opp.Role_Required__c)
                        ? opp.Role_Required__c + '\n'
                        : '') +
                    '\n--- QUALIFICATIONS ---\n' +
                    (String.isNotBlank(opp.Required_Qualifications__c)
                        ? opp.Required_Qualifications__c
                        : '');

                String candidateProfile =
                    'Name: ' + acc.Name + '\n' +
                    'Experience: ' +
                    (acc.Years_of_Experience__c != null
                        ? acc.Years_of_Experience__c
                        : '') + '\n' +
                    'Designation: ' +
                    (acc.Designation__c != null
                        ? acc.Designation__c
                        : '') + '\n' +
                    (acc.Description != null ? acc.Description : '');

                // ----------------------------
                // Call Einstein
                // ----------------------------
                String jsonResult = getCandidateJobMatch(
                    opportunityDetails,
                    candidateProfile,
                    skills,
                    certifications,
                    projectExperience
                );

                String cleanedJson = cleanJson(jsonResult);
                Map<String, Object> parsed =
                    (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

                Integer score = parsed.containsKey('score')
                    ? Integer.valueOf(parsed.get('score'))
                    : 0;

                String explanation = parsed.containsKey('explanation')
                    ? (String) parsed.get('explanation')
                    : 'No explanation provided.';

                insertedMatches.add(new Job_Match__c(
                    Candidate_Name__c   = acc.Id,
                    Opportunity_Name__c = opportunityId,
                    Match_Score__c      = score,
                    Explanation__c      = explanation
                ));

            } catch (Exception e) {
                System.debug('❌ Error processing account ' + acc.Id + ': ' + e.getMessage());
            }
        }

        // Step 4: Insert results
        if (!insertedMatches.isEmpty()) {
            insert insertedMatches;
        }
    }

    // ----------------------------
    // Einstein Call
    // ----------------------------
    @AuraEnabled
    public static String getCandidateJobMatch(
        String opportunityDetails,
        String candidateProfile,
        String skills,
        String certifications,
        String projectExperience
    ) {
        try {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue v;

            v = new ConnectApi.WrappedValue(); v.value = opportunityDetails;
            inputParams.put('Input:Opportunity_Details', v);

            v = new ConnectApi.WrappedValue(); v.value = candidateProfile;
            inputParams.put('Input:Candidate_Profile', v);

            v = new ConnectApi.WrappedValue(); v.value = skills;
            inputParams.put('Input:Candidate_Skills', v);

            v = new ConnectApi.WrappedValue(); v.value = certifications;
            inputParams.put('Input:Candidate_Certifications', v);

            v = new ConnectApi.WrappedValue(); v.value = projectExperience;
            inputParams.put('Input:Candidate_Projects', v);

            ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            input.inputParams = inputParams;
            input.additionalConfig =
                new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.numGenerations = 1;
            input.isPreview = false;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Profile_Match',
                    input
                );

            return output.generations[0].text;

        } catch (Exception e) {
            return '{"domain":"General","score":0,"explanation":"Error during match generation"}';
        }
    }

    // ----------------------------
    // Utility
    // ----------------------------
    public static String cleanJson(String response) {
        response = response.replaceAll('```json', '');
        response = response.replaceAll('```', '');
        return response.trim();
    }
} */