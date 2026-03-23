public class OfferLetterValidation {

    public class ValidationResult {
        @InvocableVariable
        public Boolean isValid;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Validate Offer Letter Data')
    public static List<ValidationResult> validate(List<Id> candidateIds) {

        ValidationResult result = new ValidationResult();
        result.isValid = true; // default allow

        Candidate__c c = [
            SELECT Id, Offer_Type__c,
                   (SELECT Id FROM Salary_Details__r LIMIT 1)
            FROM Candidate__c
            WHERE Id = :candidateIds[0]
        ];

        // 🔐 Validate ONLY if Offer Type is EXACTLY 'On Role'
        if (String.valueOf(c.Offer_Type__c) == 'On Role') {

            Boolean hasSalary =
                c.Salary_Details__r != null &&
                !c.Salary_Details__r.isEmpty();

            Integer roleCount = [
                SELECT COUNT()
                FROM Person_Responsibility__c
                WHERE Candidate__c = :c.Id
            ];

            if (!hasSalary || roleCount == 0) {
                result.isValid = false;
                result.message =
                    'Salary Details and Role & Responsibilities are mandatory for On-Role candidates.';
            }
        }

        return new List<ValidationResult>{ result };
    }
}