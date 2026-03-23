@isTest
public class EmailTemplateTest {
    
    @isTest
    static void testEmailBody_withCandidateAndOpportunity() {
        // Arrange
        List<String> responses = new List<String>();
        responses.add('001XXXXXXXXXXX:Test Candidate'); // Candidate (Account Id starts with 001)
        responses.add('006YYYYYYYYYYY:Test Opportunity'); // Opportunity (Id starts with 006)

        Boolean checkCandidate = true;
        Boolean checkJD = true;

        // Act
        String emailBody = EmailTemplate.HtmlBody(responses, checkCandidate, checkJD);

        // Assert
        System.assertNotEquals(null, emailBody, 'Email body should not be null');
        System.assert(emailBody.contains('Candidates Created Successfully'), 'Should include candidates section');
        System.assert(emailBody.contains('Opportunities Created Successfully'), 'Should include opportunities section');
        System.assert(emailBody.contains('Test Candidate'), 'Should include candidate name');
        System.assert(emailBody.contains('001XXXXXXXXXXX'), 'Should include Account Id link');
        System.assert(emailBody.contains('006YYYYYYYYYYY'), 'Should include Opportunity Id link');
        System.assert(emailBody.contains('This is an automated message from Salesforce.'), 'Should include footer');
    }

    @isTest
    static void testEmailBody_onlyCandidate() {
        // Arrange
        List<String> responses = new List<String>{ '001ABCDEF12345:Candidate One' };

        // Act
        String emailBody = EmailTemplate.HtmlBody(responses, true, false);

        // Assert
        System.assert(emailBody.contains('Candidates Created Successfully'), 'Candidate section should appear');
        System.assert(emailBody.contains('Candidate One'), 'Candidate name should appear');
        System.assert(!emailBody.contains('Opportunities Created Successfully'), 'Opportunities section should not appear');
    }

    @isTest
    static void testEmailBody_onlyOpportunity() {
        // Arrange
        List<String> responses = new List<String>{ '006OPP12345678:Opp One' };

        // Act
        String emailBody = EmailTemplate.HtmlBody(responses, false, true);

        // Assert
        System.assert(emailBody.contains('Opportunities Created Successfully'), 'Opportunities section should appear');
        System.assert(emailBody.contains('006OPP12345678'), 'Opportunity Id should appear');
        System.assert(!emailBody.contains('Candidates Created Successfully'), 'Candidates section should not appear');
    }
    
    @isTest
    static void testEmailBody_emptyResponse() {
        // Arrange
        List<String> responses = new List<String>();

        // Act
        String emailBody = EmailTemplate.HtmlBody(responses, true, true);

        // Assert
        System.assert(emailBody.contains('Candidates Created Successfully'), 'Candidate section should still appear');
        System.assert(emailBody.contains('Opportunities Created Successfully'), 'Opportunities section should still appear');
    }
}