@isTest
private class ContactToUserSyncHandlerTest {

    // ─────────────────────────────────────────────────────────────────────
    // NOTE: This org does not have Digital Experiences / Communities enabled,
    // so Users cannot be linked to Contacts (FIELD_INTEGRITY_EXCEPTION).
    // All handler logic is tested directly via @TestVisible methods.
    // Trigger flow tests use System.runAs + existing internal users only.
    // ─────────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────

    private static Contact buildContact(String lastName, String category) {
        Contact con = new Contact(
            LastName             = lastName,
            Employee_Category__c = category
        );
        return con;
    }

    private static Contact buildContactNoCategory(String lastName) {
        return new Contact(LastName = lastName);
    }

    // ─────────────────────────────────────────────
    // getEligibleContactIds — all 7 allowed categories
    // ─────────────────────────────────────────────

    @isTest
    static void testGetEligibleContactIds_AllAllowed() {
        List<String> allowed = new List<String>{
            'Management', 'HR Manager', 'HR Team',
            'On-Role(Manager)', 'On-Role(Team Member)',
            'Intern-Stipend', 'Unpaid Intern'
        };
        List<Contact> contacts = new List<Contact>();
        for (String cat : allowed) {
            contacts.add(buildContact('Cat_' + cat.left(8).replace('(','').replace(')',''), cat));
        }
        insert contacts;

        Test.startTest();
        Set<Id> result = ContactToUserSyncHandler.getEligibleContactIds(contacts);
        Test.stopTest();

        System.assertEquals(7, result.size(), 'All 7 allowed categories should be eligible');
    }

    // ─────────────────────────────────────────────
    // getEligibleContactIds — null category excluded
    // ─────────────────────────────────────────────

    @isTest
    static void testGetEligibleContactIds_NullCategory() {
        Contact con = buildContactNoCategory('NullCat');
        insert con;

        Test.startTest();
        Set<Id> result = ContactToUserSyncHandler.getEligibleContactIds(new List<Contact>{ con });
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Null category should be excluded');
    }

    // ─────────────────────────────────────────────
    // getEligibleContactIds — mixed eligible + ineligible (null)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetEligibleContactIds_Mixed() {
        Contact eligible   = buildContact('EligMixed', 'Management');
        Contact ineligible = buildContactNoCategory('IneligMixed');
        insert new List<Contact>{ eligible, ineligible };

        Test.startTest();
        Set<Id> result = ContactToUserSyncHandler.getEligibleContactIds(
            new List<Contact>{ eligible, ineligible }
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Only 1 eligible contact should be returned');
        System.assert(result.contains(eligible.Id), 'Eligible contact Id should be present');
    }

    // ─────────────────────────────────────────────
    // getEligibleContactIds — empty list
    // ─────────────────────────────────────────────

    @isTest
    static void testGetEligibleContactIds_EmptyList() {
        Test.startTest();
        Set<Id> result = ContactToUserSyncHandler.getEligibleContactIds(new List<Contact>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty input should return empty set');
    }

    // ─────────────────────────────────────────────
    // getContactUserMap — empty set returns empty map
    // ─────────────────────────────────────────────

    @isTest
    static void testGetContactUserMap_EmptySet() {
        Test.startTest();
        Map<Id, User> result = ContactToUserSyncHandler.getContactUserMap(new Set<Id>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty input should return empty map');
    }

    // ─────────────────────────────────────────────
    // getContactUserMap — contact with no linked user → empty map
    // ─────────────────────────────────────────────

    @isTest
    static void testGetContactUserMap_NoLinkedUser() {
        Contact con = buildContact('NoUser', 'HR Team');
        insert con;

        Test.startTest();
        Map<Id, User> result = ContactToUserSyncHandler.getContactUserMap(new Set<Id>{ con.Id });
        Test.stopTest();

        System.assertEquals(0, result.size(), 'No user linked → empty map');
    }

    // ─────────────────────────────────────────────
    // getContactUserMap — multiple contacts, none linked → empty map
    // ─────────────────────────────────────────────

    @isTest
    static void testGetContactUserMap_MultipleContactsNoUsers() {
        Contact c1 = buildContact('Multi1', 'Management');
        Contact c2 = buildContact('Multi2', 'HR Manager');
        insert new List<Contact>{ c1, c2 };

        Test.startTest();
        Map<Id, User> result = ContactToUserSyncHandler.getContactUserMap(
            new Set<Id>{ c1.Id, c2.Id }
        );
        Test.stopTest();

        System.assertEquals(0, result.size(), 'No users linked to any contact');
    }

    // ─────────────────────────────────────────────
    // buildUsersToUpdate — empty contactToUserMap → empty list
    // ─────────────────────────────────────────────

    @isTest
    static void testBuildUsersToUpdate_EmptyMap() {
        Contact con = buildContact('EmptyMap', 'Intern-Stipend');
        insert con;

        Test.startTest();
        List<User> result = ContactToUserSyncHandler.buildUsersToUpdate(
            new List<Contact>{ con },
            new Map<Id, User>()
        );
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Empty map → empty result');
    }

    // ─────────────────────────────────────────────
    // buildUsersToUpdate — contact NOT in map → skipped
    // ─────────────────────────────────────────────

    @isTest
    static void testBuildUsersToUpdate_ContactNotInMap() {
        Contact c1 = buildContact('InMap',    'Management');
        Contact c2 = buildContact('NotInMap', 'HR Team');
        insert new List<Contact>{ c1, c2 };

        // Map only contains c1's Id → c2 should be skipped
        User dummyUser = [SELECT Id, ContactId, FirstName, LastName, Email, Phone,
                                 MobilePhone, Title, Department, Marital_Status__c,
                                 Date_of_Joining__c, Designation__c, Employment_Type__c,
                                 Probation_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                                 Gender__c, ManagerId, Number_of_Children__c,
                                 Employee_IDs__c, Employee_Category__c, Date_Of_Birth__c
                          FROM User WHERE IsActive = true LIMIT 1];

        Map<Id, User> contactToUserMap = new Map<Id, User>{ c1.Id => dummyUser };

        Test.startTest();
        List<User> result = ContactToUserSyncHandler.buildUsersToUpdate(
            new List<Contact>{ c2 }, // only c2 passed, not in map
            contactToUserMap
        );
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Contact not in map should be skipped');
    }

    // ─────────────────────────────────────────────
    // buildUsersToUpdate — contact IS in map → all fields populated
    // ─────────────────────────────────────────────

    @isTest
    static void testBuildUsersToUpdate_FieldsPopulated() {
        Contact con = new Contact(
            FirstName            = 'Field',
            LastName             = 'Populate',
            Email                = 'fieldpop@example.invalid',
            Phone                = '1112223333',
            MobilePhone          = '4445556666',
            Title                = 'Analyst',
            Employee_Category__c = 'Management',
            Is_Probation__c      = true,
            Birthdate            = Date.newInstance(1992, 7, 4)
        );
        insert con;

        // Re-query with all required fields
        con = [SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title,
                      User_Department__c, Manager__c, Marital_Status__c,
                      Date_of_Joining__c, User_Designation__c, Probations_End_Date__c,
                      Is_Probation__c, Mode_of_Work__c, GenderIdentity,
                      Number_of_Children__c, Employee_Id__c, Employee_Category__c,
                      Employment_Status__c, Birthdate
               FROM Contact WHERE Id = :con.Id];

        // Use any active internal user as the "User to update" stub
        User stubUser = [SELECT Id, ContactId, FirstName, LastName, Email, Phone,
                                MobilePhone, Title, Department, Marital_Status__c,
                                Date_of_Joining__c, Designation__c, Employment_Type__c,
                                Probation_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                                Gender__c, ManagerId, Number_of_Children__c,
                                Employee_IDs__c, Employee_Category__c, Date_Of_Birth__c
                         FROM User WHERE IsActive = true LIMIT 1];

        Map<Id, User> contactToUserMap = new Map<Id, User>{ con.Id => stubUser };

        Test.startTest();
        List<User> result = ContactToUserSyncHandler.buildUsersToUpdate(
            new List<Contact>{ con }, contactToUserMap
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should produce 1 user to update');
        User u = result[0];
        System.assertEquals('Field',                    u.FirstName,          'FirstName synced');
        System.assertEquals('Populate',                 u.LastName,           'LastName synced');
        System.assertEquals('fieldpop@example.invalid', u.Email,              'Email synced');
        System.assertEquals('1112223333',               u.Phone,              'Phone synced');
        System.assertEquals('4445556666',               u.MobilePhone,        'MobilePhone synced');
        System.assertEquals('Analyst',                  u.Title,              'Title synced');
        System.assertEquals(true,                       u.Is_Probation__c,    'Is_Probation synced');
        System.assertEquals(Date.newInstance(1992,7,4), u.Date_Of_Birth__c,   'Birthdate synced');
        System.assertEquals('Management',               u.Employee_Category__c,'Category synced');
    }

    // ─────────────────────────────────────────────
    // buildUsersToUpdate — multiple contacts, only matching ones returned
    // ─────────────────────────────────────────────

    @isTest
    static void testBuildUsersToUpdate_MultipleContacts_OnlyMatched() {
        Contact c1 = buildContact('Matched1',   'Management');
        Contact c2 = buildContact('Matched2',   'HR Team');
        Contact c3 = buildContactNoCategory('Unmatched3');
        insert new List<Contact>{ c1, c2, c3 };

        c1 = [SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title,
                     User_Department__c, Manager__c, Marital_Status__c,
                     Date_of_Joining__c, User_Designation__c, Probations_End_Date__c,
                     Is_Probation__c, Mode_of_Work__c, GenderIdentity,
                     Number_of_Children__c, Employee_Id__c, Employee_Category__c,
                     Employment_Status__c, Birthdate FROM Contact WHERE Id = :c1.Id];
        c2 = [SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title,
                     User_Department__c, Manager__c, Marital_Status__c,
                     Date_of_Joining__c, User_Designation__c, Probations_End_Date__c,
                     Is_Probation__c, Mode_of_Work__c, GenderIdentity,
                     Number_of_Children__c, Employee_Id__c, Employee_Category__c,
                     Employment_Status__c, Birthdate FROM Contact WHERE Id = :c2.Id];

        List<User> stubUsers = [SELECT Id, ContactId, FirstName, LastName, Email, Phone,
                                       MobilePhone, Title, Department, Marital_Status__c,
                                       Date_of_Joining__c, Designation__c, Employment_Type__c,
                                       Probation_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                                       Gender__c, ManagerId, Number_of_Children__c,
                                       Employee_IDs__c, Employee_Category__c, Date_Of_Birth__c
                                FROM User WHERE IsActive = true LIMIT 2];

        Map<Id, User> contactToUserMap = new Map<Id, User>{
            c1.Id => stubUsers[0],
            c2.Id => stubUsers.size() > 1 ? stubUsers[1] : stubUsers[0]
        };
        // c3 deliberately NOT in map

        Test.startTest();
        List<User> result = ContactToUserSyncHandler.buildUsersToUpdate(
            new List<Contact>{ c1, c2, c3 }, contactToUserMap
        );
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Only 2 matched contacts should produce users');
    }

    // ─────────────────────────────────────────────
    // syncContactsToUsers — no eligible contacts → early return
    // ─────────────────────────────────────────────

    @isTest
    static void testSyncContactsToUsers_NoEligible_EarlyReturn() {
        Contact con = buildContactNoCategory('EarlyReturn');
        insert con;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ContactToUserSyncHandler.syncContactsToUsers(new List<Contact>{ con });
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Should return early without exception');
    }

    // ─────────────────────────────────────────────
    // syncContactsToUsers — eligible but no linked users → early return
    // ─────────────────────────────────────────────

    @isTest
    static void testSyncContactsToUsers_EligibleNoLinkedUsers() {
        Contact con = buildContact('EligNoUser', 'HR Manager');
        insert con;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ContactToUserSyncHandler.syncContactsToUsers(new List<Contact>{ con });
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Should return early without exception when no users linked');
    }

    // ─────────────────────────────────────────────
    // syncContactsToUsers — empty list → no-op
    // ─────────────────────────────────────────────

    @isTest
    static void testSyncContactsToUsers_EmptyList() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ContactToUserSyncHandler.syncContactsToUsers(new List<Contact>());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Empty list should not throw');
    }

    // ─────────────────────────────────────────────
    // Trigger — after insert fires, no error for ineligible contact
    // ─────────────────────────────────────────────

    @isTest
    static void testTrigger_AfterInsert_IneligibleContact() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            Contact con = buildContactNoCategory('TrigInsertNoSync');
            insert con;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Trigger should not throw for ineligible contact on insert');
    }

    // ─────────────────────────────────────────────
    // Trigger — after update fires, no error for eligible contact without linked user
    // ─────────────────────────────────────────────

    @isTest
    static void testTrigger_AfterUpdate_EligibleNoLinkedUser() {
        Contact con = buildContact('TrigUpdateNoLink', 'Unpaid Intern');
        insert con;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            con.Title = 'Intern Level 2';
            update con;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Trigger should not throw when no user is linked');
    }

    // ─────────────────────────────────────────────
    // Trigger — bulk insert of mixed eligible/ineligible contacts
    // ─────────────────────────────────────────────

    @isTest
    static void testTrigger_BulkInsert_MixedContacts() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(buildContact('BulkElig_' + i, 'Management'));
        }
        for (Integer i = 0; i < 10; i++) {
            contacts.add(buildContactNoCategory('BulkInelig_' + i));
        }

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            insert contacts;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Bulk insert of mixed contacts should not throw');
    }

    // ─────────────────────────────────────────────
    // Trigger — bulk update of eligible contacts
    // ─────────────────────────────────────────────

    @isTest
    static void testTrigger_BulkUpdate_EligibleContacts() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(buildContact('BulkUpd_' + i, 'On-Role(Team Member)'));
        }
        insert contacts;

        for (Contact c : contacts) {
            c.Title = 'Updated Title';
        }

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            update contacts;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Bulk update of eligible contacts should not throw');
    }
}