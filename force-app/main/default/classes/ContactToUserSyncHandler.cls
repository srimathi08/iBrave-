public with sharing class ContactToUserSyncHandler {

    private static final Set<String> ALLOWED_CATEGORIES = new Set<String>{
        'Management',
        'HR Manager',
        'HR Team',
        'On-Role(Manager)',
        'On-Role(Team Member)',
        'Intern-Stipend',
        'Unpaid Intern'
    };

    // ─────────────────────────────────────────────────────────────
    // Main entry point — called from trigger for after insert/update
    // ─────────────────────────────────────────────────────────────
    public static void syncContactsToUsers(List<Contact> newContacts) {

        // Step 1: Collect eligible Contact Ids
        Set<Id> contactIds = getEligibleContactIds(newContacts);
        if (contactIds.isEmpty()) return;

        // Step 2: Build Contact → User map
        Map<Id, User> contactToUserMap = getContactUserMap(contactIds);
        if (contactToUserMap.isEmpty()) return;

        // Step 3: Build list of Users to update
        List<User> usersToUpdate = buildUsersToUpdate(newContacts, contactToUserMap);

        // Step 4: Perform update
        if (!usersToUpdate.isEmpty()) {
            update usersToUpdate;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Step 1: Filter contacts by allowed Employee_Category__c
    // ─────────────────────────────────────────────────────────────
    @TestVisible
    private static Set<Id> getEligibleContactIds(List<Contact> contacts) {
        Set<Id> ids = new Set<Id>();
        for (Contact con : contacts) {
            if (con.Employee_Category__c != null &&
                ALLOWED_CATEGORIES.contains(con.Employee_Category__c)) {
                ids.add(con.Id);
            }
        }
        return ids;
    }

    // ─────────────────────────────────────────────────────────────
    // Step 2: Query Users linked to given Contact Ids
    // ─────────────────────────────────────────────────────────────
    @TestVisible
    private static Map<Id, User> getContactUserMap(Set<Id> contactIds) {
        Map<Id, User> contactToUserMap = new Map<Id, User>();
        for (User usr : [
            SELECT Id, ContactId,
                   FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department,
                   Marital_Status__c, Date_of_Joining__c, Designation__c,
                   Employment_Type__c, Probation_End_Date__c,
                   Is_Probation__c, Mode_of_Work__c, Gender__c, ManagerId,
                   Number_of_Children__c, Employee_IDs__c, Employee_Category__c,
                   Date_Of_Birth__c
            FROM User
            WHERE ContactId IN :contactIds
        ]) {
            contactToUserMap.put(usr.ContactId, usr);
        }
        return contactToUserMap;
    }

    // ─────────────────────────────────────────────────────────────
    // Step 3: Map Contact fields → User fields
    // ─────────────────────────────────────────────────────────────
    @TestVisible
    private static List<User> buildUsersToUpdate(
        List<Contact> contacts,
        Map<Id, User> contactToUserMap
    ) {
        List<User> usersToUpdate = new List<User>();
        for (Contact con : contacts) {
            if (!contactToUserMap.containsKey(con.Id)) continue;

            User usr = contactToUserMap.get(con.Id);

            // Standard fields
            usr.FirstName         = con.FirstName;
            usr.LastName          = con.LastName;
            usr.Email             = con.Email;
            usr.Phone             = con.Phone;
            usr.MobilePhone       = con.MobilePhone;
            usr.Title             = con.Title;
            usr.Department        = con.User_Department__c;
            usr.ManagerId         = con.Manager__c;

            // Custom fields
            usr.Marital_Status__c     = con.Marital_Status__c;
            usr.Date_of_Joining__c    = con.Date_of_Joining__c;
            usr.Designation__c        = con.User_Designation__c;
            usr.Probation_End_Date__c = con.Probations_End_Date__c;
            usr.Is_Probation__c       = con.Is_Probation__c;
            usr.Mode_of_Work__c       = con.Mode_of_Work__c;
            usr.Gender__c             = con.GenderIdentity;
            usr.Number_of_Children__c = con.Number_of_Children__c;
            usr.Employee_IDs__c       = con.Employee_Id__c;
            usr.Employee_Category__c  = con.Employee_Category__c;
            usr.Employment_Type__c    = con.Employment_Status__c;
            usr.Date_Of_Birth__c      = con.Birthdate;

            usersToUpdate.add(usr);
        }
        return usersToUpdate;
    }
}