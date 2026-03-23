@isTest
private class ContactTriggerHandlerTest {

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

    @isTest
    static void testAfterInsert_SyncsUser() {
        User testUser = createTestUser();

        Contact con = new Contact(
            FirstName = 'Priya',
            LastName = 'Dharshini',
            Email = 'priya.insert@example.com',
            Phone = '1111111111',
            MobilePhone = '9999999999',
            Title = 'Consultant',
            User_Department__c = 'Salesforce',
            Marital_Status__c = 'Single',
            Date_of_Joining__c = Date.today().addYears(-2),
            User_Designation__c = 'Senior Consultant',
            
            Is_Probation__c = true,
            Mode_of_Work__c = 'Full time work',
            GenderIdentity = 'Female',
            Number_of_Children__c = 1,
            Employee_Id__c = 'EMP1001',
            Employee_Category__c = 'Management',
            Employment_Status__c = 'Full Time',
            Birthdate = Date.newInstance(1998, 5, 10),
            Internal_User__c = testUser.Id
        );

        Test.startTest();
        insert con;
        Test.stopTest();

        User updatedUser = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department, ManagerId,
                   Marital_Status__c, Date_of_Joining__c, Designation__c,
                   Probation_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                   Gender__c, Number_of_Children__c, Employee_IDs__c,
                   Employee_Category__c, Employment_Type__c, Date_Of_Birth__c
            FROM User
            WHERE Id = :testUser.Id
        ];

        System.assertEquals(con.FirstName, updatedUser.FirstName);
        System.assertEquals(con.LastName, updatedUser.LastName);
        System.assertEquals(con.Email, updatedUser.Email);
        System.assertEquals(con.Phone, updatedUser.Phone);
        System.assertEquals(con.MobilePhone, updatedUser.MobilePhone);
        System.assertEquals(con.Title, updatedUser.Title);
        System.assertEquals(con.User_Department__c, updatedUser.Department);
        System.assertEquals(con.Marital_Status__c, updatedUser.Marital_Status__c);
        System.assertEquals(con.Date_of_Joining__c, updatedUser.Date_of_Joining__c);
        System.assertEquals(con.User_Designation__c, updatedUser.Designation__c);
        
        System.assertEquals(con.Is_Probation__c, updatedUser.Is_Probation__c);
        System.assertEquals(con.Mode_of_Work__c, updatedUser.Mode_of_Work__c);
        System.assertEquals(con.GenderIdentity, updatedUser.Gender__c);
        System.assertEquals(con.Number_of_Children__c, updatedUser.Number_of_Children__c);
        System.assertEquals(con.Employee_Id__c, updatedUser.Employee_IDs__c);
        System.assertEquals(con.Employee_Category__c, updatedUser.Employee_Category__c);
        System.assertEquals(con.Employment_Status__c, updatedUser.Employment_Type__c);
        System.assertEquals(con.Birthdate, updatedUser.Date_Of_Birth__c);
    }

    @isTest
    static void testAfterUpdate_SyncsChangedFields() {
        User testUser = createTestUser();

        Contact con = new Contact(
            FirstName = 'Old',
            LastName = 'Name',
            Email = 'old@example.com',
            Phone = '2222222222',
            MobilePhone = '8888888888',
            Title = 'Junior Consultant',
            User_Department__c = 'Salesforce',
            Marital_Status__c = 'Single',
            Date_of_Joining__c = Date.today().addYears(-1),
            User_Designation__c = 'Consultant',
            
            Is_Probation__c = true,
            Mode_of_Work__c = 'Hybrid',
            GenderIdentity = 'Female',
            Number_of_Children__c = 0,
            Employee_Id__c = 'EMP2001',
            Employee_Category__c = 'HR Team',
            Employment_Status__c = 'Full Time',
            Birthdate = Date.newInstance(1997, 3, 12),
            Internal_User__c = testUser.Id
        );
        insert con;

        Test.startTest();
        con.FirstName = 'New';
        con.LastName = 'Employee';
        con.Email = 'new@example.com';
        con.Phone = '3333333333';
        con.MobilePhone = '7777777777';
        con.Title = 'Manager';
        con.User_Department__c = 'HR & Finance';
        con.Marital_Status__c = 'Married';
        con.User_Designation__c = 'HR Manager';
        con.Is_Probation__c = false;
        con.Mode_of_Work__c = 'Hybrid';
        con.Number_of_Children__c = 2;
        con.Employee_Id__c = 'EMP2002';
        con.Employee_Category__c = 'Management';
        con.Employment_Status__c = 'Full Time';
        update con;
        Test.stopTest();

        User updatedUser = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department,
                   Marital_Status__c, Designation__c, Is_Probation__c,
                   Mode_of_Work__c, Number_of_Children__c, Employee_IDs__c,
                   Employee_Category__c, Employment_Type__c
            FROM User
            WHERE Id = :testUser.Id
        ];

        System.assertEquals('New', updatedUser.FirstName);
        System.assertEquals('Employee', updatedUser.LastName);
        System.assertEquals('new@example.com', updatedUser.Email);
        System.assertEquals('3333333333', updatedUser.Phone);
        System.assertEquals('7777777777', updatedUser.MobilePhone);
        System.assertEquals('Manager', updatedUser.Title);
        System.assertEquals('HR & Finance', updatedUser.Department);
        System.assertEquals('Married', updatedUser.Marital_Status__c);
        System.assertEquals('HR Manager', updatedUser.Designation__c);
        System.assertEquals(false, updatedUser.Is_Probation__c);
        System.assertEquals('Hybrid', updatedUser.Mode_of_Work__c);
        System.assertEquals(2, updatedUser.Number_of_Children__c);
        System.assertEquals('EMP2002', updatedUser.Employee_IDs__c);
        System.assertEquals('Management', updatedUser.Employee_Category__c);
        System.assertEquals('Full Time', updatedUser.Employment_Type__c);
    }

    @isTest
    static void testNoSyncWhenInternalUserBlank() {
        Contact con = new Contact(
            FirstName = 'No',
            LastName = 'Link',
            Email = 'nolink@example.com'
        );

        Test.startTest();
        insert con;
        con.Phone = '4444444444';
        update con;
        Test.stopTest();

        Contact saved = [SELECT Id, Internal_User__c, Phone FROM Contact WHERE Id = :con.Id];
        System.assertEquals(null, saved.Internal_User__c);
        System.assertEquals('4444444444', saved.Phone);
    }

    @isTest
    static void testIrrelevantFieldChange() {
        User testUser = createTestUser();

        Contact con = new Contact(
            FirstName = 'Same',
            LastName = 'User',
            Email = 'same@example.com',
            Phone = '5555555555',
            MobilePhone = '6666666666',
            Title = 'Consultant',
            User_Department__c = 'HR & Finance',
            User_Designation__c = 'HR Executive',
            Employee_Id__c = 'EMP3001',
            Internal_User__c = testUser.Id
        );
        insert con;

        User beforeUser = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department, Designation__c, Employee_IDs__c
            FROM User
            WHERE Id = :testUser.Id
        ];

        Test.startTest();
        con.Description = 'Only non-sync field changed';
        update con;
        Test.stopTest();

        User afterUser = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department, Designation__c, Employee_IDs__c
            FROM User
            WHERE Id = :testUser.Id
        ];

        System.assertEquals(beforeUser.FirstName, afterUser.FirstName);
        System.assertEquals(beforeUser.LastName, afterUser.LastName);
        System.assertEquals(beforeUser.Email, afterUser.Email);
        System.assertEquals(beforeUser.Phone, afterUser.Phone);
        System.assertEquals(beforeUser.MobilePhone, afterUser.MobilePhone);
        System.assertEquals(beforeUser.Title, afterUser.Title);
        System.assertEquals(beforeUser.Department, afterUser.Department);
        System.assertEquals(beforeUser.Designation__c, afterUser.Designation__c);
        System.assertEquals(beforeUser.Employee_IDs__c, afterUser.Employee_IDs__c);
    }
}