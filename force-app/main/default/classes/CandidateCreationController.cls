/**
 * @method createCandidates(String pdfText) [public static]
 * @desc 
 *   Parses AI-extracted resume data (in JSON format) from a PDF string, creates new Candidate 
 *   Accounts, and inserts related Skills, Certifications, and Employee-Skill junction records.
 *   It skips duplicate candidates based on email to avoid creating existing records.
 * 
 * @param {String} pdfText - A JSON-formatted string extracted from resumes via AI, containing 
 *   Account details, Skills, and Certifications for one or more candidates.
 * 
 * @return {List<Account>} - Returns a list of newly created Account (Candidate) records.
 * 
 * @throws {Exception} - Throws any exception encountered during JSON parsing or database operations.
 * 
 * @notes 
 *   - Skips any resumes that match existing Account records based on PersonEmail.
 *   - Supports candidate attributes like DOB, Degree, Experience, and Language Known.
 *   - Creates related Skill__c and Certification__c records.
 *   - Creates Employee_Skill__c to link Skills to Candidates.
 *   - Expects JSON to follow structure: 
 *     {
 "resumes": [
 {
  "account": {
  "firstName": "",
  "lastName": "",
  "dateofBirth":"",
  "currentLocation":"",
  "languagesKnown":"",
  "email": "",
  "phone": "",
  "summary": "",
  "experience": "", ex 4 years
  "linkedin": ""
  "filename":""
  "degree"":""
"designation"":""
  },
  "skills": [
  {
   "name": "",
   "proficiency": "Beginner | Intermediate | Advanced",
   "lastUsed": "",
   "Category": "Technical | Tools & Platforms | Soft Skills | Project & Process Skills | Domain Knowledge"
  }
  ],
  "certifications": [
  {
   "name": "",
   "issuedBy": "",
   "issueDate": "",
   "expiryDate": ""
  }
  ]
 }
 ]
}
 * 
 * @author Afrose Ahamed
 * @since v1.0
 */

public class CandidateCreationController {

    // ============================================================
    // ENTRY METHOD
    // ============================================================
    public static List<Account> createCandidates(String pdfText, String contentDocumentId) {

        /* ---------- 0. Clean & Parse JSON ---------- */
        String cleanedJson = pdfText
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);

        if (parsed == null) return new List<Account>();

        List<Object> rawResumes;
        if (parsed.containsKey('resumes')) {
            rawResumes = (List<Object>) parsed.get('resumes');
        } else if (parsed.containsKey('account')) {
            rawResumes = new List<Object>{ parsed };
        } else {
            return new List<Account>();
        }

        /* ---------- 1. Existing Accounts by Email ---------- */
        Set<String> emailKeys = new Set<String>();
        for (Object o : rawResumes) {
            Map<String, Object> acc =
                (Map<String, Object>) ((Map<String, Object>) o).get('account');
            if (String.isNotBlank((String) acc.get('email'))) {
                emailKeys.add(((String) acc.get('email')).toLowerCase());
            }
        }

        Map<String, Account> existingByEmail = new Map<String, Account>();
        if (!emailKeys.isEmpty()) {
            for (Account a : [
                SELECT Id, Name, Phone, Personal_Email__c, Description,
                       Designation__c, Years_of_Experience__c,
                       Languages_Known__c, Current_Location__c,
                       Current_Organization__c, Past_Companies__c,
                       College_Name__c, Filename__c, Degree__c,
                       Date_of_Birth__c, LinkedIn__c
                FROM Account
                WHERE Personal_Email__c IN :emailKeys
            ]) {
                existingByEmail.put(a.Personal_Email__c.toLowerCase(), a);
            }
        }

        List<Account> accToInsert = new List<Account>();
        List<Account> accToUpdate = new List<Account>();
        List<Account> allAccounts = new List<Account>();

        List<List<Map<String, Object>>> skillsByResume = new List<List<Map<String, Object>>>();
        List<List<Map<String, Object>>> certsByResume  = new List<List<Map<String, Object>>>();
        List<List<Map<String, Object>>> projsByResume  = new List<List<Map<String, Object>>>();

        Id candidateRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'Candidates'
            LIMIT 1
        ].Id;

        /* ---------- 2. Build Accounts ---------- */
        for (Object o : rawResumes) {

            Map<String, Object> resume  = (Map<String, Object>) o;
            Map<String, Object> accJson = (Map<String, Object>) resume.get('account');

            String email = (String) accJson.get('email');
            String emailKey = String.isNotBlank(email) ? email.toLowerCase() : null;

            Account acc;

            if (emailKey != null && existingByEmail.containsKey(emailKey)) {

                acc = existingByEmail.get(emailKey);
                if (compareAndUpdateAccount(acc, accJson)) {
                    accToUpdate.add(acc);
                }

            } else {

                String pastCompanies;
                if (accJson.get('pastCompanies') != null) {
                    List<String> pcs = new List<String>();
                    for (Object pc : (List<Object>) accJson.get('pastCompanies')) {
                        if (pc != null) pcs.add((String) pc);
                    }
                    pastCompanies = pcs.isEmpty() ? null : String.join(pcs, ', ');
                }

                acc = new Account(
                    RecordTypeId           = candidateRT,
                    Name                   = buildCandidateName(accJson), // ✅ FIXED
                    Phone                  = (String) accJson.get('phone'),
                    Personal_Email__c      = email,
                    Description            = (String) accJson.get('summary'),
                    Designation__c         = (String) accJson.get('designation'),
                    LinkedIn__c            = (String) accJson.get('linkedin'),
                    Years_of_Experience__c = (String) accJson.get('experience'),
                    Languages_Known__c     = (String) accJson.get('languagesKnown'),
                    Current_Organization__c= (String) accJson.get('currentCompany'),
                    Current_Location__c    = (String) accJson.get('currentLocation'),
                    Past_Companies__c      = pastCompanies,
                    Filename__c            = (String) accJson.get('filename'),
                    Degree__c              = (String) accJson.get('degree'),
                    College_Name__c        = (String) accJson.get('college'),
                    Status__c              = 'Active',
                    Account_Type__c        = 'Candidate',
                    Date_of_Birth__c       =
                        accJson.get('dateofBirth') != null &&
                        String.valueOf(accJson.get('dateofBirth')).trim() != ''
                        ? Date.valueOf((String) accJson.get('dateofBirth'))
                        : null
                );

                accToInsert.add(acc);
            }

            skillsByResume.add(safeList(resume.get('skills')));
            certsByResume.add(safeList(resume.get('certifications')));
            projsByResume.add(safeList(resume.get('projects')));
            allAccounts.add(acc);
        }

        if (!accToInsert.isEmpty()) insert accToInsert;
        if (!accToUpdate.isEmpty()) update accToUpdate;


/* ---------- 3. Attach Resume File (ADDED BACK) ---------- */
        if (!accToInsert.isEmpty() && String.isNotBlank(contentDocumentId)) {

            List<ContentDocumentLink> links = new List<ContentDocumentLink>();

            for (Account acc : accToInsert) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId    = acc.Id,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
            insert links;
        }

        /* ---------- 4. Create Contact (ADDED BACK) ---------- */
        List<Contact> contacts = new List<Contact>();

        for (Account acc : accToInsert) {
            contacts.add(new Contact(
                LastName            = acc.Name,
                Email               = acc.Personal_Email__c,
                Phone               = acc.Phone,
                AccountId           = acc.Id,
                Candidate_Contact__c = true
            ));
        }

        if (!contacts.isEmpty()) {
            insert contacts;
        }



        /* ---------- 3. Skills ---------- */
        System.enqueueJob(
            new CandidateSkillQueueable(allAccounts, skillsByResume)
        );

        /* ---------- 4. Certifications ---------- */
        handleCertifications(allAccounts, certsByResume);

        /* ---------- 5. Projects ---------- */
        handleProjects(allAccounts, projsByResume);

        return allAccounts;
    }

    // ============================================================
    // HELPERS
    // ============================================================

    // ✅ SINGLE SOURCE OF TRUTH FOR ACCOUNT NAME
    private static String buildCandidateName(Map<String, Object> accJson) {

        String name = (String) accJson.get('name');
        if (String.isNotBlank(name)) {
            return name.trim();
        }

        // Absolute fallback – never allow null
        return 'Candidate - ' + DateTime.now().getTime();
    }

    private static List<Map<String, Object>> safeList(Object obj) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (obj != null) {
            for (Object o : (List<Object>) obj) {
                if (o != null) out.add((Map<String, Object>) o);
            }
        }
        return out;
    }

    private static Boolean compareAndUpdateAccount(Account acc, Map<String, Object> j) {
        Boolean changed = false;

        String newName = buildCandidateName(j);
        if (String.isNotBlank(newName) && acc.Name != newName) {
            acc.Name = newName;
            changed = true;
        }

        if (acc.Phone != (String) j.get('phone')) { acc.Phone = (String) j.get('phone'); changed = true; }
        if (acc.Description != (String) j.get('summary')) { acc.Description = (String) j.get('summary'); changed = true; }
        if (acc.Designation__c != (String) j.get('designation')) { acc.Designation__c = (String) j.get('designation'); changed = true; }

        return changed;
    }

    private static String clean(String s) {
        return s == null ? '' : s.toLowerCase().replaceAll('[^a-z0-9]', '');
    }

    private static Date safeDate(Object raw) {
        if (raw == null) return null;
        try {
            return Date.valueOf(String.valueOf(raw));
        } catch (Exception e) {
            return null;
        }
    }

    /* ================= CERTIFICATIONS ================= */

    private static void handleCertifications(
        List<Account> accounts,
        List<List<Map<String,Object>>> certsByResume
    ) {

        Map<String, Certification__c> existingMap = new Map<String, Certification__c>();

        for (Certification__c cert : [
            SELECT Id, Candidate_Name__c,
                   Full_Certification_Name__c,
                   Issuing_Organization__c,
                   Issue_Date__c,
                   Expiration_Date__c
            FROM Certification__c
            WHERE Candidate_Name__c IN :accounts
        ]) {
            String key = cert.Candidate_Name__c + '::' +
                         clean(cert.Full_Certification_Name__c) + '::' +
                         clean(cert.Issuing_Organization__c) + '::' +
                         (cert.Issue_Date__c != null ? String.valueOf(cert.Issue_Date__c) : '');
            existingMap.put(key, cert);
        }

        List<Certification__c> toInsert = new List<Certification__c>();
        List<Certification__c> toUpdate = new List<Certification__c>();

        for (Integer i = 0; i < accounts.size(); i++) {
            for (Map<String, Object> c : certsByResume[i]) {

                String name = (String) c.get('name');
                if (String.isBlank(name)) continue;

                String org = (String) c.get('issuedBy');
                Date issueDate = safeDate(c.get('issueDate'));
                Date expiryDate = safeDate(c.get('expiryDate'));

                String key = accounts[i].Id + '::' +
                             clean(name) + '::' +
                             clean(org) + '::' +
                             (issueDate != null ? String.valueOf(issueDate) : '');

                if (existingMap.containsKey(key)) {
                    Certification__c ex = existingMap.get(key);
                    if (ex.Expiration_Date__c != expiryDate) {
                        ex.Expiration_Date__c = expiryDate;
                        toUpdate.add(ex);
                    }
                } else {
                    toInsert.add(new Certification__c(
                        Name = name.left(80),
                        Full_Certification_Name__c = name,
                        Issuing_Organization__c = org,
                        Issue_Date__c = issueDate,
                        Expiration_Date__c = expiryDate,
                        Candidate_Name__c = accounts[i].Id
                    ));
                }
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /* ================= PROJECTS ================= */

   private static void handleProjects(
    List<Account> accounts,
    List<List<Map<String,Object>>> projsByResume
) {

    // Existing projects keyed by Account + Project Name + Client
    Map<String, Project_Experience__c> existingMap =
        new Map<String, Project_Experience__c>();

    for (Project_Experience__c pe : [
        SELECT Id, Employee_Name__c,
               Full_Project_Name__c, Client_Name__c,
               Project_Role__c, Situtation__c, Task__c,
               Action__c, Result__c, Learning_Outcome__c,
               Skills_Applied__c, Tools_Used__c,
               Start_Date__c, End_Date__c,
               Achievements__c, Responsibilities__c,
               Designation_Job_Title__c,
               Project_Location__c, Environment__c
        FROM Project_Experience__c
        WHERE Employee_Name__c IN :accounts
    ]) {
        String key = pe.Employee_Name__c + '::' +
                     clean(pe.Full_Project_Name__c) + '::' +
                     clean(pe.Client_Name__c);
        existingMap.put(key, pe);
    }

    List<Project_Experience__c> toInsert = new List<Project_Experience__c>();
    List<Project_Experience__c> toUpdate = new List<Project_Experience__c>();

    for (Integer i = 0; i < accounts.size(); i++) {

        Account acc = accounts[i];

        for (Map<String, Object> p : projsByResume[i]) {

            String projName = (String) p.get('projectName');
            if (String.isBlank(projName)) continue;

            String client = (String) p.get('clientName');

            String key = acc.Id + '::' +
                         clean(projName) + '::' +
                         clean(client);

            Date startDate = safeDate(p.get('startDate'));
            Date endDate   = safeDate(p.get('endDate'));

            if (existingMap.containsKey(key)) {

                // 🔄 UPDATE EXISTING PROJECT
                Project_Experience__c existing = existingMap.get(key);
                Boolean changed = false;

                if (existing.Project_Role__c != (String)p.get('projectRole')) { existing.Project_Role__c = (String)p.get('projectRole'); changed = true; }
                if (existing.Situtation__c != (String)p.get('situation')) { existing.Situtation__c = (String)p.get('situation'); changed = true; }
                if (existing.Task__c != (String)p.get('task')) { existing.Task__c = (String)p.get('task'); changed = true; }
                if (existing.Action__c != (String)p.get('action')) { existing.Action__c = (String)p.get('action'); changed = true; }
                if (existing.Result__c != (String)p.get('result')) { existing.Result__c = (String)p.get('result'); changed = true; }
                if (existing.Learning_Outcome__c != (String)p.get('learningOutcome')) { existing.Learning_Outcome__c = (String)p.get('learningOutcome'); changed = true; }
                if (existing.Skills_Applied__c != (String)p.get('skillsApplied')) { existing.Skills_Applied__c = (String)p.get('skillsApplied'); changed = true; }
                if (existing.Tools_Used__c != (String)p.get('toolsUsed')) { existing.Tools_Used__c = (String)p.get('toolsUsed'); changed = true; }
                if (existing.Start_Date__c != startDate) { existing.Start_Date__c = startDate; changed = true; }
                if (existing.End_Date__c != endDate) { existing.End_Date__c = endDate; changed = true; }
                if (existing.Achievements__c != (String)p.get('achievements')) { existing.Achievements__c = (String)p.get('achievements'); changed = true; }
                if (existing.Responsibilities__c != (String)p.get('responsibilities')) { existing.Responsibilities__c = (String)p.get('responsibilities'); changed = true; }
                if (existing.Designation_Job_Title__c != (String)p.get('designationJobTitle')) { existing.Designation_Job_Title__c = (String)p.get('designationJobTitle'); changed = true; }
                if (existing.Project_Location__c != (String)p.get('projectLocation')) { existing.Project_Location__c = (String)p.get('projectLocation'); changed = true; }
                if (existing.Environment__c != (String)p.get('environment')) { existing.Environment__c = (String)p.get('environment'); changed = true; }

                if (changed) toUpdate.add(existing);

            } else {

                // ➕ INSERT NEW PROJECT
                toInsert.add(new Project_Experience__c(
                    Name = projName.left(80),
                    Full_Project_Name__c = projName,
                    Project_Name__c = projName,
                    Client_Name__c = client,
                    Employee_Name__c = acc.Id,
                    Project_Role__c = (String)p.get('projectRole'),
                    Situtation__c = (String)p.get('situation'),
                    Task__c = (String)p.get('task'),
                    Action__c = (String)p.get('action'),
                    Result__c = (String)p.get('result'),
                    Learning_Outcome__c = (String)p.get('learningOutcome'),
                    Skills_Applied__c = (String)p.get('skillsApplied'),
                    Tools_Used__c = (String)p.get('toolsUsed'),
                    Start_Date__c = startDate,
                    End_Date__c = endDate,
                    Achievements__c = (String)p.get('achievements'),
                    Responsibilities__c = (String)p.get('responsibilities'),
                    Designation_Job_Title__c = (String)p.get('designationJobTitle'),
                    Project_Location__c = (String)p.get('projectLocation'),
                    Environment__c = (String)p.get('environment')
                ));
            }
        }
    }

    if (!toInsert.isEmpty()) insert toInsert;
    if (!toUpdate.isEmpty()) update toUpdate;
}

}