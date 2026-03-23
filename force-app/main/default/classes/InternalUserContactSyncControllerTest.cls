@isTest
private class InternalUserContactSyncControllerTest {

    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        String uniqueVal = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        User u = new User(
            FirstName = 'Initial',
            LastName = 'User',
            Alias = 'iuser',
            Email = 'internaluser' + uniqueVal + '@example.com',
            Username = 'internaluser' + uniqueVal + '@example.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    private static Contact createTestContact() {
        Contact c = new Contact(
            FirstName = 'Priya',
            LastName = 'Dharshini',
            Email = 'priya.contact@example.com',
            Phone = '1234567890',
            MobilePhone = '9876543210',
            Title = 'Consultant',
            Employee_Id__c = 'EMP001',
            User_Designation__c = 'Senior Consultant',
            User_Department__c = 'Salesforce',
            Date_of_Joining__c = Date.today().addYears(-2),
            Employment_Status__c = 'Full Time',
            Marital_Status__c = 'Single',
            
            Is_Probation__c = true,
            Mode_of_Work__c = 'Full time work',
            GenderIdentity = 'Female',
            Number_of_Children__c = 1,
            Employee_Category__c = 'Management',
            Birthdate = Date.newInstance(1998, 5, 10)
        );
        insert c;
        return c;
    }

    @isTest
    static void testLinkAndSyncInternalUser_Success() {
        User testUser = createTestUser();
        Contact testContact = createTestContact();

        Test.startTest();
        InternalUserContactSyncController.SyncResponse response =
            InternalUserContactSyncController.linkAndSyncInternalUser(testContact.Id, testUser.Id);
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertEquals('Internal User linked and synced successfully.', response.message);
        System.assertEquals(testContact.Id, response.contactId);
        System.assertEquals(testUser.Id, response.userId);

        Contact updatedContact = [
            SELECT Id, Internal_User__c
            FROM Contact
            WHERE Id = :testContact.Id
        ];

        User updatedUser = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department, ManagerId,
                   Employee_IDs__c, Designation__c, Marital_Status__c,
                   Date_of_Joining__c, Probation_End_Date__c, Is_Probation__c,
                   Mode_of_Work__c, Gender__c, Number_of_Children__c,
                   Employee_Category__c, Employment_Type__c, Date_Of_Birth__c
            FROM User
            WHERE Id = :testUser.Id
        ];

        System.assertEquals(testUser.Id, updatedContact.Internal_User__c);

        System.assertEquals(testContact.FirstName, updatedUser.FirstName);
        System.assertEquals(testContact.LastName, updatedUser.LastName);
        System.assertEquals(testContact.Email, updatedUser.Email);
        System.assertEquals(testContact.Phone, updatedUser.Phone);
        System.assertEquals(testContact.MobilePhone, updatedUser.MobilePhone);
        System.assertEquals(testContact.Title, updatedUser.Title);
        System.assertEquals(testContact.User_Department__c, updatedUser.Department);
        System.assertEquals(testContact.Employee_Id__c, updatedUser.Employee_IDs__c);
        System.assertEquals(testContact.User_Designation__c, updatedUser.Designation__c);
        System.assertEquals(testContact.Marital_Status__c, updatedUser.Marital_Status__c);
        System.assertEquals(testContact.Date_of_Joining__c, updatedUser.Date_of_Joining__c);
        
        System.assertEquals(testContact.Is_Probation__c, updatedUser.Is_Probation__c);
        System.assertEquals(testContact.Mode_of_Work__c, updatedUser.Mode_of_Work__c);
        System.assertEquals(testContact.GenderIdentity, updatedUser.Gender__c);
        System.assertEquals(testContact.Number_of_Children__c, updatedUser.Number_of_Children__c);
        System.assertEquals(testContact.Employee_Category__c, updatedUser.Employee_Category__c);
        System.assertEquals(testContact.Employment_Status__c, updatedUser.Employment_Type__c);
        System.assertEquals(testContact.Birthdate, updatedUser.Date_Of_Birth__c);
    }

    @isTest
    static void testLinkAndSyncInternalUser_NullInputs() {
        Test.startTest();
        InternalUserContactSyncController.SyncResponse response =
            InternalUserContactSyncController.linkAndSyncInternalUser(null, null);
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('Contact Id and User Id are required.', response.message);
    }

    @isTest
    static void testSyncContactsToUsers_Bulk() {
        User user1 = createTestUser();
        User user2 = createTestUser();

        Contact con1 = new Contact(
            FirstName = 'Emp',
            LastName = 'One',
            Email = 'emp1@example.com',
            Phone = '1111111111',
            MobilePhone = '9999991111',
            Title = 'QA Engineer',
            Employee_Id__c = 'EMP101',
            User_Designation__c = 'Senior Software Testing Engineer',
            User_Department__c = 'QA-Quality Assurance',
            Date_of_Joining__c = Date.today().addYears(-1),
            Employment_Status__c = 'Full Time',
            Marital_Status__c = 'Married',
            
            Is_Probation__c = false,
            Mode_of_Work__c = 'Full time work',
            GenderIdentity = 'Female',
            Number_of_Children__c = 2,
            Employee_Category__c = 'HR Team',
            Birthdate = Date.newInstance(1995, 8, 20),
            Internal_User__c = user1.Id
        );

        Contact con2 = new Contact(
            FirstName = 'Emp',
            LastName = 'Two',
            Email = 'emp2@example.com',
            Phone = '2222222222',
            MobilePhone = '9999992222',
            Title = 'Manager',
            Employee_Id__c = 'EMP102',
            User_Designation__c = 'Operations Manager',
            User_Department__c = 'Salesforce',
            Date_of_Joining__c = Date.today().addYears(-3),
            Employment_Status__c = 'Full Time',
            Marital_Status__c = 'Single',
            
            Is_Probation__c = true,
            Mode_of_Work__c = 'Full time work',
            GenderIdentity = 'Male',
            Number_of_Children__c = 0,
            Employee_Category__c = 'Management',
            Birthdate = Date.newInstance(1992, 3, 14),
            Internal_User__c = user2.Id
        );

        insert new List<Contact>{ con1, con2 };

        List<Contact> contactsToSync = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Manager__c, Birthdate,
                   Employee_Id__c, User_Designation__c, User_Department__c,
                   Date_of_Joining__c, Employment_Status__c, Internal_User__c,
                   Marital_Status__c, Probations_End_Date__c, Is_Probation__c,
                   Mode_of_Work__c, GenderIdentity, Number_of_Children__c,
                   Employee_Category__c
            FROM Contact
            WHERE Id IN :new List<Id>{con1.Id, con2.Id}
        ];

        Test.startTest();
        InternalUserContactSyncController.syncContactsToUsers(contactsToSync);
        Test.stopTest();

        Map<Id, User> updatedUsers = new Map<Id, User>([
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department,
                   Employee_IDs__c, Designation__c, Marital_Status__c,
                   Date_of_Joining__c, Probation_End_Date__c, Is_Probation__c,
                   Mode_of_Work__c, Gender__c, Number_of_Children__c,
                   Employee_Category__c, Employment_Type__c, Date_Of_Birth__c
            FROM User
            WHERE Id IN :new List<Id>{user1.Id, user2.Id}
        ]);

        User updatedUser1 = updatedUsers.get(user1.Id);
        User updatedUser2 = updatedUsers.get(user2.Id);

        System.assertEquals(con1.FirstName, updatedUser1.FirstName);
        System.assertEquals(con1.LastName, updatedUser1.LastName);
        System.assertEquals(con1.Email, updatedUser1.Email);
        System.assertEquals(con1.Phone, updatedUser1.Phone);
        System.assertEquals(con1.MobilePhone, updatedUser1.MobilePhone);
        System.assertEquals(con1.Title, updatedUser1.Title);
        System.assertEquals(con1.User_Department__c, updatedUser1.Department);
        System.assertEquals(con1.Employee_Id__c, updatedUser1.Employee_IDs__c);
        System.assertEquals(con1.User_Designation__c, updatedUser1.Designation__c);
        System.assertEquals(con1.Marital_Status__c, updatedUser1.Marital_Status__c);
        System.assertEquals(con1.Date_of_Joining__c, updatedUser1.Date_of_Joining__c);
        System.assertEquals(con1.Probations_End_Date__c, updatedUser1.Probation_End_Date__c);
        System.assertEquals(con1.Is_Probation__c, updatedUser1.Is_Probation__c);
        System.assertEquals(con1.Mode_of_Work__c, updatedUser1.Mode_of_Work__c);
        System.assertEquals(con1.GenderIdentity, updatedUser1.Gender__c);
        System.assertEquals(con1.Number_of_Children__c, updatedUser1.Number_of_Children__c);
        System.assertEquals(con1.Employee_Category__c, updatedUser1.Employee_Category__c);
        System.assertEquals(con1.Employment_Status__c, updatedUser1.Employment_Type__c);
        System.assertEquals(con1.Birthdate, updatedUser1.Date_Of_Birth__c);

        System.assertEquals(con2.FirstName, updatedUser2.FirstName);
        System.assertEquals(con2.LastName, updatedUser2.LastName);
        System.assertEquals(con2.Email, updatedUser2.Email);
        System.assertEquals(con2.Phone, updatedUser2.Phone);
        System.assertEquals(con2.MobilePhone, updatedUser2.MobilePhone);
        System.assertEquals(con2.Title, updatedUser2.Title);
        System.assertEquals(con2.User_Department__c, updatedUser2.Department);
        System.assertEquals(con2.Employee_Id__c, updatedUser2.Employee_IDs__c);
        System.assertEquals(con2.User_Designation__c, updatedUser2.Designation__c);
        System.assertEquals(con2.Marital_Status__c, updatedUser2.Marital_Status__c);
        System.assertEquals(con2.Date_of_Joining__c, updatedUser2.Date_of_Joining__c);
        
        System.assertEquals(con2.Is_Probation__c, updatedUser2.Is_Probation__c);
        System.assertEquals(con2.Mode_of_Work__c, updatedUser2.Mode_of_Work__c);
        System.assertEquals(con2.GenderIdentity, updatedUser2.Gender__c);
        System.assertEquals(con2.Number_of_Children__c, updatedUser2.Number_of_Children__c);
        System.assertEquals(con2.Employee_Category__c, updatedUser2.Employee_Category__c);
        System.assertEquals(con2.Employment_Status__c, updatedUser2.Employment_Type__c);
        System.assertEquals(con2.Birthdate, updatedUser2.Date_Of_Birth__c);
    }

    @isTest
    static void testSyncContactsToUsers_EmptyAndNull() {
        Test.startTest();
        InternalUserContactSyncController.syncContactsToUsers(new List<Contact>());
        InternalUserContactSyncController.syncContactsToUsers(null);
        Test.stopTest();

        System.assert(true);
    }
}