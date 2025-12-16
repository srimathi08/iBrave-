@IsTest
private class CandidateConversionServiceTest {

    // Utility method to create a full Candidate record
    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Middle_Name__c = 'A',
            Date_Of_Birth__c = Date.newInstance(1995, 5, 12),
            Gender__c = 'Male',
            Department__c = 'SFDC',
            Personal_Email__c = 'john.doe@example.com',
            Phone_No__c = '9876543210',
            Aadhar_Card_Number__c = '123412341234',
            Blood_Group__c = 'A+',
            Campus_City__c = 'Chennai',
            Campus_Name__c = 'ABC',
            Consultancy_Name__c = 'XYZ',
            Joining_Date__c = Date.today(),
            Designation__c = 'Developer',
            Driving_License_Number__c = 'TN12345',
            Emergency_Contact_Name__c = 'Parent',
            Emergency_Contact_Phone__c = '9876543211',
            Marital_Status__c = 'Single',
            Number_of_Children__c = 0,
            PAN_Number__c = 'ABCDE1234F',
            Place_of_Posting_Base_Location__c = 'Chennai',
            Referred_Person_Name__c = 'Someone',
            Salutation__c = 'Mr.',
            Source_Of_Applicant__c = 'Advertisement',
            UAN_Number__c = 'UAN1234567',
            Work_Location__c = 'Chennai',
            Communication_Address__Street__s = '123 Anna St',
            Communication_Address__City__s = 'Chennai',
            Communication_Address__StateCode__s = 'TN',
            Communication_Address__PostalCode__s = '600001',
            Communication_Address__CountryCode__s = 'IN',
            Permanent_Address__Street__s = '456 MG Road',
            Permanent_Address__City__s = 'Chennai',
            Permanent_Address__StateCode__s = 'TN',
            Permanent_Address__PostalCode__s = '600002',
            Permanent_Address__CountryCode__s = 'IN'
        );
        insert c;
        return c;
    }

    // Utility to create all child records
    private static void createChildRecords(Id candidateId) {

        insert new Education_Detail__c(Candidate__c = candidateId);
        insert new Family_Members__c(Candidate__c = candidateId);
        insert new Work_Experience__c(Candidate__c = candidateId);
        insert new Bank_Details__c(Candidate__c = candidateId);

        Role_Responsibility__c role = new Role_Responsibility__c(
            Name = 'Role1',
            Responsibility_Description__c = 'Test Role',
            Category__c = 'Category A'
        );
        insert role;

        insert new CandidateRoleResponsibility__c(
            Candidate__c = candidateId,
            Role_Responsibility__c = role.Id
        );

        insert new Salary_Details__c(
            Candidate__c = candidateId
        );
    }

    // MAIN TEST METHOD
    @IsTest
    static void testCandidateConversion() {

        Candidate__c cand = createCandidate();
        createChildRecords(cand.Id);

        CandidateConversionService.CandidateInput input = 
            new CandidateConversionService.CandidateInput();
        input.candidateId = cand.Id;

        Test.startTest();
        List<CandidateConversionService.CandidateOutput> result =
            CandidateConversionService.convertCandidateToContact(
                new List<CandidateConversionService.CandidateInput>{ input }
            );
        Test.stopTest();

        // Assertions
        System.assertEquals(1, result.size(), 'One output expected');
        System.assert(result[0].message.contains('Contact created successfully'));

        Contact con = [
            SELECT Id, Employee_ID__c, Candidate__c
            FROM Contact
            WHERE Candidate__c = :cand.Id
            LIMIT 1
        ];

        System.assertNotEquals(null, con.Id, 'Contact should be created');
        System.assert(con.Employee_ID__c.startsWith('Qbay '), 'Employee ID must start with Qbay');

        // Assert Child records updated with Contact__c
        System.assertEquals(1, [
            SELECT COUNT() FROM Education_Detail__c WHERE Contact__c = :con.Id
        ]);

        System.assertEquals(1, [
            SELECT COUNT() FROM Family_Members__c WHERE Contact__c = :con.Id
        ]);

        System.assertEquals(1, [
            SELECT COUNT() FROM Work_Experience__c WHERE Contact__c = :con.Id
        ]);

        System.assertEquals(1, [
            SELECT COUNT() FROM Bank_Details__c WHERE Contact__c = :con.Id
        ]);

        System.assertEquals(1, [
            SELECT COUNT() FROM CandidateRoleResponsibility__c WHERE Contact__c = :con.Id
        ]);

        System.assertEquals(1, [
            SELECT COUNT() FROM Salary_Details__c WHERE Contact__c = :con.Id
        ]);
    }

    // NEGATIVE TEST — NULL Candidate ID
    @IsTest
    static void testNullCandidateId() {
        CandidateConversionService.CandidateInput input = 
            new CandidateConversionService.CandidateInput();

        input.candidateId = null;

        Test.startTest();
        List<CandidateConversionService.CandidateOutput> result =
            CandidateConversionService.convertCandidateToContact(
                new List<CandidateConversionService.CandidateInput>{ input }
            );
        Test.stopTest();

        System.assertEquals('Candidate Id is null', result[0].message);
    }
}