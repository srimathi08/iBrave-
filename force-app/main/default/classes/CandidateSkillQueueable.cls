public class CandidateSkillQueueable implements Queueable {

    private List<Account> accounts;
    private List<List<Map<String, Object>>> skillsByResume;

    public CandidateSkillQueueable(
        List<Account> accounts,
        List<List<Map<String, Object>>> skillsByResume
    ) {
        this.accounts = accounts;
        this.skillsByResume = skillsByResume;
    }

    public void execute(QueueableContext qc) {

        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        /* ---------- Load Existing Skill Master ---------- */
        Map<String, Skill__c> skillMaster = new Map<String, Skill__c>();
        for (Skill__c sk : [
            SELECT Id, Skill_Name__c, Category__c
            FROM Skill__c
        ]) {
            skillMaster.put(clean(sk.Skill_Name__c), sk);
        }

        /* ---------- Existing Employee Skills ---------- */
        Map<String, Employee_Skill__c> existingMap = new Map<String, Employee_Skill__c>();
        for (Employee_Skill__c es : [
            SELECT Id, Employee_Name__c, Full_Skill_Name__c, Proficiency__c
            FROM Employee_Skill__c
            WHERE Employee_Name__c IN :accounts
        ]) {
            existingMap.put(
                es.Employee_Name__c + '::' + clean(es.Full_Skill_Name__c),
                es
            );
        }

        List<Skill__c> skillsToInsert = new List<Skill__c>();
        List<Employee_Skill__c> empSkillsToInsert = new List<Employee_Skill__c>();
        List<Employee_Skill__c> empSkillsToUpdate = new List<Employee_Skill__c>();

        /* ==================================================
           PHASE 1: COLLECT & INSERT SKILLS
           ================================================== */
        for (Integer i = 0; i < accounts.size(); i++) {
            for (Map<String, Object> s : skillsByResume[i]) {

                String rawSkill = (String) s.get('name');
                if (String.isBlank(rawSkill)) continue;

                String normSkill = clean(rawSkill);
                String category  = (String) s.get('Category');

                if (!skillMaster.containsKey(normSkill)) {
                    Skill__c sk = new Skill__c(
                        Skill_Name__c = rawSkill,
                        Active__c = true,
                        Category__c = category
                    );
                    skillsToInsert.add(sk);
                    skillMaster.put(normSkill, sk);
                }
            }
        }

        if (!skillsToInsert.isEmpty()) {
            insert skillsToInsert;
        }

        /* ==================================================
           PHASE 2: EMPLOYEE SKILLS (LINK TO ACCOUNT + SKILL)
           ================================================== */
        for (Integer i = 0; i < accounts.size(); i++) {
            Account acc = accounts[i];

            for (Map<String, Object> s : skillsByResume[i]) {

                String rawSkill = (String) s.get('name');
                if (String.isBlank(rawSkill)) continue;

                String normSkill   = clean(rawSkill);
                String proficiency = (String) s.get('proficiency');

                Skill__c skillRef = skillMaster.get(normSkill);
                if (skillRef == null) continue; // safety guard

                String key = acc.Id + '::' + normSkill;

                if (existingMap.containsKey(key)) {
                    Employee_Skill__c existing = existingMap.get(key);
                    if (existing.Proficiency__c != proficiency) {
                        existing.Proficiency__c = proficiency;
                        empSkillsToUpdate.add(existing);
                    }
                } else {
                    empSkillsToInsert.add(new Employee_Skill__c(
                        Name = rawSkill.left(80),
                        Full_Skill_Name__c = rawSkill,
                        Skill__c = skillRef.Id,
                        Employee_Name__c = acc.Id,
                        Proficiency__c = proficiency
                    ));
                }
            }
        }

        /* ---------- DML ---------- */
        if (!empSkillsToInsert.isEmpty()) insert empSkillsToInsert;
        if (!empSkillsToUpdate.isEmpty()) update empSkillsToUpdate;
    }

    /* ---------- Utility ---------- */
    private static String clean(String s) {
        return s == null ? '' : s.toLowerCase().replaceAll('[^a-z0-9]', '');
    }
}