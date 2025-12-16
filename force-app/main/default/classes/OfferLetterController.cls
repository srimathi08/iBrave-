/*public class OfferLetterController {

    public Id candidateId { get; set; }
    
    // Data structures to hold the fetched data
    public Candidate__c candidate { get; private set; }
    public Salary_Details__c salaryDetails { get; private set; }
    public Role_Responsibility__c rolesAndResponsibilities { get; private set; }

    public OfferLetterController() {
        // 1. Get the record ID from the URL
        candidateId = ApexPages.currentPage().getParameters().get('id');

        if (candidateId != null) {
            // 2. Fetch the Candidate and related child records via SOQL sub-query
            candidate = [
                SELECT 
                    Id, 
                    Name, 
                    Designation__c, 
                    Joining_Date__c, 
                    Date_of_Birth__c,
                    // Sub-query to get Salary Details
                    (SELECT Id, Annual_CTC__c, Basic_Pay_PF_Retirement_Benefits__c, 
                    Other_Basic_Pay__c, House_Rent_Allowance_HRA__c, Bucket_Allowance__c,
                    Gross_Salary_Annual__c, EPF_Employee_Contribution_12__c,
                    ESI_Employee_contribution_0_75__c, PT_Professional_Tax__c,
                    ESI_Employer_contribution_3_25__c, PF_Contribution_Employer__c,
                    Health_Policy_Insurance__c, Variable_Pay__c, 
                    Total_company_Contribution__c, Total_Deduction__c, Total_CTC__c
                    FROM Salary_Details__r LIMIT 1), 
                    // Sub-query to get Roles
                    (SELECT Id, Responsibility_Description__c, Category__c 
                    FROM Roles_Responsibility__r) 
                FROM Candidate__c 
                WHERE Id = :candidateId
                LIMIT 1
            ];

            // 3. Assign related list data to individual variables
            if (candidate.Salary_Details__r != null && !candidate.Salary_Details__r.isEmpty()) {
                salaryDetails = candidate.Salary_Details__r[0];
            }
            if (candidate.Roles_Responsibility__r != null && !candidate.Roles_Responsibility__r.isEmpty()) {
                rolesAndResponsibilities = candidate.Roles_Responsibility__r[0];
            }
        }
    }
    
    /**
     * @description Generates the full HTML table for the Compensation Annexure 1.
     * @return String: The HTML string with Monthly and Annual columns.
     */
    /*public String getCompensationTableHTML() {
        if (salaryDetails == null) {
            return '<p>Compensation details are not available for this candidate.</p>';
        }

        // Build the HTML Table String with styling for PDF
        String tableHtml = '<table style="width:100%; border-collapse: collapse; margin-top: 10px;">';
        
        // Header Row
        tableHtml += '<thead><tr>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left;">Particulars</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: right;">Monthly Salary Break-Up (Rs.)</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: right;">Annual Salary Break-Up (Rs.)</th>';
        tableHtml += '</tr></thead><tbody>';

        // Gross Salary Components
        Decimal basicAnnual = salaryDetails.Basic_Pay_PF_Retirement_Benefits__c != null ? salaryDetails.Basic_Pay_PF_Retirement_Benefits__c : 0;
        Decimal otherBasicAnnual = salaryDetails.Other_Basic_Pay__c != null ? salaryDetails.Other_Basic_Pay__c : 0;
        Decimal hraAnnual = salaryDetails.House_Rent_Allowance_HRA__c != null ? salaryDetails.House_Rent_Allowance_HRA__c : 0;
        Decimal bucketAnnual = salaryDetails.Bucket_Allowance__c != null ? salaryDetails.Bucket_Allowance__c : 0;
        Decimal grossAnnual = salaryDetails.Gross_Salary_Annual__c != null ? salaryDetails.Gross_Salary_Annual__c : 0;

        tableHtml += buildRow('Basic Pay PF & Retirement Benefits', basicAnnual);
        tableHtml += buildRow('Other Basic Pay', otherBasicAnnual);
        tableHtml += buildRow('House Rent Allowance', hraAnnual);
        tableHtml += buildRow('Bucket Allowance (Food, Telephone, Fuel, Car Driver Reimbursement, NPS & other Allowances)', bucketAnnual);
        
        // Gross Salary Total
        tableHtml += buildBoldRow('Gross Salary Per Annum / Month (A)', grossAnnual, '#f2f2f2');
        
        // Deductions Section Header
        tableHtml += '<tr><td colspan="3" style="border: 1px solid #000; padding: 8px; font-weight: bold; background-color: #e6e6e6;">Deductions from Gross Salary</td></tr>';
        
        Decimal epfEmployeeAnnual = salaryDetails.EPF_Employee_Contribution_12__c != null ? salaryDetails.EPF_Employee_Contribution_12__c : 0;
        Decimal esiEmployeeAnnual = salaryDetails.ESI_Employee_contribution_0_75__c != null ? salaryDetails.ESI_Employee_contribution_0_75__c : 0;
        Decimal ptAnnual = salaryDetails.PT_Professional_Tax__c != null ? salaryDetails.PT_Professional_Tax__c : 0;
        Decimal totalDeductionAnnual = salaryDetails.Total_Deduction__c != null ? salaryDetails.Total_Deduction__c : 0;
        
        tableHtml += buildRow('EPF - Employee Contribution @12%', epfEmployeeAnnual);
        tableHtml += buildRow('ESI - Employee contribution @0.75%', esiEmployeeAnnual);
        tableHtml += buildRow('PT', ptAnnual);
        
        // Total Deduction
        tableHtml += buildBoldRow('Total Deduction (B)', totalDeductionAnnual, '#f2f2f2');
        
        // Net Salary in Hand
        Decimal netSalaryAnnual = grossAnnual - totalDeductionAnnual;
        tableHtml += buildBoldRow('Net Salary In Hand (A) - (B)', netSalaryAnnual, '#ffffcc');
        
        // Company Contributions Section
        tableHtml += '<tr><td colspan="3" style="border: 1px solid #000; padding: 8px; font-weight: bold; background-color: #e6e6e6;">Company Contributions</td></tr>';
        
        Decimal pfEmployerAnnual = salaryDetails.PF_Contribution_Employer__c != null ? salaryDetails.PF_Contribution_Employer__c : 0;
        Decimal esiEmployerAnnual = salaryDetails.ESI_Employer_contribution_3_25__c != null ? salaryDetails.ESI_Employer_contribution_3_25__c : 0;
        Decimal healthPolicyAnnual = salaryDetails.Health_Policy_Insurance__c != null ? salaryDetails.Health_Policy_Insurance__c : 0;
        Decimal totalCompanyContributionAnnual = salaryDetails.Total_company_Contribution__c != null ? salaryDetails.Total_company_Contribution__c : 0;
        
        tableHtml += buildRow('PF Contribution Employer & admin Charges', pfEmployerAnnual);
        tableHtml += buildRow('ESI - Employer contribution @3.25%', esiEmployerAnnual);
        tableHtml += buildRow('Health Policy', healthPolicyAnnual);
        
        // Total Company Contribution
        tableHtml += buildBoldRow('Total company Contribution (C)', totalCompanyContributionAnnual, '#f2f2f2');
        
        // Variable Pay
        Decimal variablePayAnnual = salaryDetails.Variable_Pay__c != null ? salaryDetails.Variable_Pay__c : 0;
        tableHtml += buildRow('Variable Pay (D)', variablePayAnnual);
        
        // Cost to Company (CTC)
        Decimal ctcAnnual = salaryDetails.Total_CTC__c != null ? salaryDetails.Total_CTC__c : 0;
        tableHtml += buildBoldRow('Cost To Company (A+C+D)', ctcAnnual, '#ccffcc');
        
        tableHtml += '</tbody></table>';
        
        // Add Notes
        tableHtml += '<div style="margin-top: 15px; font-size: 9pt;">';
        tableHtml += '<p><strong>* Rounded-off to nearest rupee.</strong></p>';
        tableHtml += '<p><strong>Note:</strong></p>';
        tableHtml += '<ol style="margin-left: 20px;">';
        tableHtml += '<li>Employer contribution of PF is maximum to the extent of the Employee contribution or Rs.1800 whichever is less and company administration charges will be borne by the employer.</li>';
        tableHtml += '<li>Rs.1250/Rs.1025/Rs.690/Rs.315/Rs.135 per month will be deducted from the monthly gross salary if the six months gross is above Rs. 75001/Rs. 60001 to Rs.75000/Rs. 45001 to Rs.60000/ Rs.30001 to Rs.45000/Rs.21001 to Rs.30000 respectively.</li>';
        tableHtml += '<li>Labour welfare fund of Rs.20/- will be deducted once in every year.</li>';
        tableHtml += '<li>Medical insurance for Employee will be covered based on your salary.</li>';
        tableHtml += '<li>Company will pay the variable pay half-yearly basis, based on the performance. In-case of resignation/termination, an employee shall not be entitled to claim the variable pay.</li>';
        tableHtml += '<li>All retirement, superannuation and maternity benefits are calculated on the Basic when applicable.</li>';
        tableHtml += '</ol>';
        tableHtml += '</div>';

        return tableHtml;
    }
    
    /**
     * Helper method to build a standard table row with monthly and annual values
     */
    /*private String buildRow(String label, Decimal annualAmount) {
        Decimal monthlyAmount = annualAmount != null ? annualAmount / 12 : 0;
        String row = '<tr>';
        row += '<td style="border: 1px solid #000; padding: 8px;">' + label + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(monthlyAmount) + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(annualAmount) + '</td>';
        row += '</tr>';
        return row;
    }
    
    /**
     * Helper method to build a bold table row with background color
     */
    /*private String buildBoldRow(String label, Decimal annualAmount, String bgColor) {
        Decimal monthlyAmount = annualAmount != null ? annualAmount / 12 : 0;
        String row = '<tr style="font-weight: bold; background-color: ' + bgColor + ';">';
        row += '<td style="border: 1px solid #000; padding: 8px;">' + label + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(monthlyAmount) + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(annualAmount) + '</td>';
        row += '</tr>';
        return row;
    }
    
    /**
     * Helper method to format currency values
     */
    /*private String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return amount.setScale(2).format();
    }
    
    /**
     * @description Generates the Role & Responsibilities table with categories
     * @return String: The HTML string for roles table
     */
    /*public String getRolesTableHTML() {
        if (candidate.Roles_Responsibility__r == null || candidate.Roles_Responsibility__r.isEmpty()) {
            return '<p>Role and responsibility details are not available for this candidate.</p>';
        }
        
        String tableHtml = '<table style="width:100%; border-collapse: collapse; margin-top: 10px;">';
        tableHtml += '<thead><tr>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left; width: 30%;">Category</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left;">Actions</th>';
        tableHtml += '</tr></thead><tbody>';
        
        for (Role_Responsibility__c role : candidate.Roles_Responsibility__r) {
            tableHtml += '<tr>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px; vertical-align: top;">' + 
                        (role.Category__c != null ? role.Category__c : '') + '</td>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px;">' + 
                        (role.Responsibility_Description__c != null ? role.Responsibility_Description__c : '') + '</td>';
            tableHtml += '</tr>';
        }
        
        tableHtml += '</tbody></table>';
        return tableHtml;
    }
}*/
/**
 * OfferLetterController
 * Fetches data for the Candidate, Salary, and Roles for PDF generation.
 * Supports both On-Role and Intern offer types.
 */
public without sharing class OfferLetterController {

    public Id candidateId { get; set; }
    
    // Data structures to hold the fetched data
    public Candidate__c candidate { get; private set; }
    public Salary_Details__c salaryDetails { get; private set; }
    //public Role_Responsibility__c rolesAndResponsibilities { get; private set; }
    // List to hold all role responsibility records for the candidate via junction object
    public List<Role_Responsibility__c> candidateRoles { get; private set; }
    // Property to determine offer type
    public String offerType { get; private set; }

    public OfferLetterController() {
        // 1. Get the record ID from the URL
        candidateId = ApexPages.currentPage().getParameters().get('id');

        if (candidateId != null) {
            // 2. Fetch the Candidate and related child records via SOQL sub-query
            candidate = [
                SELECT 
                    Id, 
                    Name, First_Name__c,Last_Name__c,

                    Designation__c, 
                    Joining_Date__c, 
                    Date_of_Birth__c,
                    Offer_Type__c,
                    Father_Name__c,
                    Aadhar_Card_Number__c,
                    Internship_Start_Date__c,
                    Internship_End_Date__c,
                    Department__c,
					Offer_Accepted__c,Offer_Accepted_Date__c, Offer_Acceptance_IP__c,
                    // Sub-query to get Salary Details
                    (SELECT Id, Annual_CTC__c, Basic_Pay_PF_Retirement_Benefits__c, 
                    Other_Basic_Pay__c, House_Rent_Allowance_HRA__c, Bucket_Allowance__c,
                    Gross_Salary_Annual__c, EPF_Employee_Contribution_12__c,
                    ESI_Employee_contribution_0_75__c, PT_Professional_Tax__c,
                    ESI_Employer_contribution_3_25__c, PF_Contribution_Employer__c,
                    Health_Policy_Insurance__c, Variable_Pay__c, 
                    Total_company_Contribution__c, Total_Deduction__c, Total_CTC__c
                    FROM Salary_Details__r LIMIT 1)                   
                FROM Candidate__c 
                WHERE Id = :candidateId
                LIMIT 1
            ];

            // Determine offer type (default to 'On Role' if not specified)
            offerType = candidate.Offer_Type__c != null ? candidate.Offer_Type__c : 'On Role';

            // 3. Assign related list data to individual variables (only for On Role)
            if (offerType == 'On Role') {
                if (candidate.Salary_Details__r != null && !candidate.Salary_Details__r.isEmpty()) {
                    salaryDetails = candidate.Salary_Details__r[0];
                }
                // Fetch Role & Responsibility via junction object CandidateRoleResponsibility__c
                List<CandidateRoleResponsibility__c> junctionRecords = [
                    SELECT Role_Responsibility__r.Id, Role_Responsibility__r.Name, Role_Responsibility__r.Category__c,
                           Role_Responsibility__r.Responsibility_Description__c
                    FROM CandidateRoleResponsibility__c
                    WHERE Candidate__c = :candidateId
                ];

                candidateRoles = new List<Role_Responsibility__c>();
                for (CandidateRoleResponsibility__c junction : junctionRecords) {
                    if (junction.Role_Responsibility__r != null) {
                        candidateRoles.add(junction.Role_Responsibility__r);
                    }
                }
            }
        }
    }

    
    /**
     * @description Check if offer type is On-Role
     * @return Boolean
     */
    public Boolean getIsOnRoleOffer() {
        return offerType == 'On Role';
    }
    
    /**
     * @description Check if offer type is Intern
     * @return Boolean
     */
    public Boolean getIsInternOffer() {
        return offerType == 'Intern';
    }
    
    /**
     * @description Format Aadhar number to show last 4 digits
     * @return String: Masked Aadhar number
     */
    public String getFormattedAadhar() {
        if (candidate.Aadhar_Card_Number__c != null && candidate.Aadhar_Card_Number__c.length() >= 4) {
            String lastFour = candidate.Aadhar_Card_Number__c.right(4);
            return 'XXXX XXXX ' + lastFour;
        }
        return 'XXXX XXXX XXXX';
    }
    
    /**
     * @description Generates the full HTML table for the Compensation Annexure 1.
     * @return String: The HTML string with Monthly and Annual columns.
     */
    public String getCompensationTableHTML() {
        if (salaryDetails == null) {
            return '<p>Compensation details are not available for this candidate.</p>';
        }

        // Build the HTML Table String with styling for PDF
        String tableHtml = '<table style="width:100%; border-collapse: collapse; margin-top: 10px;">';
        
        // Header Row
        tableHtml += '<thead><tr>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left;">Particulars</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: right;">Monthly Salary Break-Up (Rs.)</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: right;">Annual Salary Break-Up (Rs.)</th>';
        tableHtml += '</tr></thead><tbody>';

        // Gross Salary Components
        Decimal basicAnnual = salaryDetails.Basic_Pay_PF_Retirement_Benefits__c != null ? salaryDetails.Basic_Pay_PF_Retirement_Benefits__c : 0;
        Decimal otherBasicAnnual = salaryDetails.Other_Basic_Pay__c != null ? salaryDetails.Other_Basic_Pay__c : 0;
        Decimal hraAnnual = salaryDetails.House_Rent_Allowance_HRA__c != null ? salaryDetails.House_Rent_Allowance_HRA__c : 0;
        Decimal bucketAnnual = salaryDetails.Bucket_Allowance__c != null ? salaryDetails.Bucket_Allowance__c : 0;
        Decimal grossAnnual = salaryDetails.Gross_Salary_Annual__c != null ? salaryDetails.Gross_Salary_Annual__c : 0;

        tableHtml += buildRow('Basic Pay PF & Retirement Benefits', basicAnnual);
        tableHtml += buildRow('Other Basic Pay', otherBasicAnnual);
        tableHtml += buildRow('House Rent Allowance', hraAnnual);
        tableHtml += buildRow('Bucket Allowance (Food, Telephone, Fuel, Car Driver Reimbursement, NPS & other Allowances)', bucketAnnual);
        
        // Gross Salary Total
        tableHtml += buildBoldRow('Gross Salary Per Annum / Month (A)', grossAnnual, '#f2f2f2');
        
        // Deductions Section Header
        tableHtml += '<tr><td colspan="3" style="border: 1px solid #000; padding: 8px; font-weight: bold; background-color: #e6e6e6;">Deductions from Gross Salary</td></tr>';
        
        Decimal epfEmployeeAnnual = salaryDetails.EPF_Employee_Contribution_12__c != null ? salaryDetails.EPF_Employee_Contribution_12__c : 0;
        Decimal esiEmployeeAnnual = salaryDetails.ESI_Employee_contribution_0_75__c != null ? salaryDetails.ESI_Employee_contribution_0_75__c : 0;
        Decimal ptAnnual = salaryDetails.PT_Professional_Tax__c != null ? salaryDetails.PT_Professional_Tax__c : 0;
        Decimal totalDeductionAnnual = salaryDetails.Total_Deduction__c != null ? salaryDetails.Total_Deduction__c : 0;
        
        tableHtml += buildRow('EPF - Employee Contribution @12%', epfEmployeeAnnual);
        tableHtml += buildRow('ESI - Employee contribution @0.75%', esiEmployeeAnnual);
        tableHtml += buildRow('PT', ptAnnual);
        
        // Total Deduction
        tableHtml += buildBoldRow('Total Deduction (B)', totalDeductionAnnual, '#f2f2f2');
        
        // Net Salary in Hand
        Decimal netSalaryAnnual = grossAnnual - totalDeductionAnnual;
        tableHtml += buildBoldRow('Net Salary In Hand (A) - (B)', netSalaryAnnual, '#ffffcc');
        
        // Company Contributions Section
        tableHtml += '<tr><td colspan="3" style="border: 1px solid #000; padding: 8px; font-weight: bold; background-color: #e6e6e6;">Company Contributions</td></tr>';
        
        Decimal pfEmployerAnnual = salaryDetails.PF_Contribution_Employer__c != null ? salaryDetails.PF_Contribution_Employer__c : 0;
        Decimal esiEmployerAnnual = salaryDetails.ESI_Employer_contribution_3_25__c != null ? salaryDetails.ESI_Employer_contribution_3_25__c : 0;
        Decimal healthPolicyAnnual = salaryDetails.Health_Policy_Insurance__c != null ? salaryDetails.Health_Policy_Insurance__c : 0;
        Decimal totalCompanyContributionAnnual = salaryDetails.Total_company_Contribution__c != null ? salaryDetails.Total_company_Contribution__c : 0;
        
        tableHtml += buildRow('PF Contribution Employer & admin Charges', pfEmployerAnnual);
        tableHtml += buildRow('ESI - Employer contribution @3.25%', esiEmployerAnnual);
        tableHtml += buildRow('Health Policy', healthPolicyAnnual);
        
        // Total Company Contribution
        tableHtml += buildBoldRow('Total company Contribution (C)', totalCompanyContributionAnnual, '#f2f2f2');
        
        // Variable Pay
        Decimal variablePayAnnual = salaryDetails.Variable_Pay__c != null ? salaryDetails.Variable_Pay__c : 0;
        tableHtml += buildRow('Variable Pay (D)', variablePayAnnual);
        
        // Cost to Company (CTC)
        Decimal ctcAnnual = salaryDetails.Total_CTC__c != null ? salaryDetails.Total_CTC__c : 0;
        tableHtml += buildBoldRow('Cost To Company (A+C+D)', ctcAnnual, '#ccffcc');
        
        tableHtml += '</tbody></table>';
        
        // Add Notes
        tableHtml += '<div style="margin-top: 15px; font-size: 9pt;">';
        tableHtml += '<p><strong>* Rounded-off to nearest rupee.</strong></p>';
        tableHtml += '<p><strong>Note:</strong></p>';
        tableHtml += '<ol style="margin-left: 20px;">';
        tableHtml += '<li>Employer contribution of PF is maximum to the extent of the Employee contribution or Rs.1800 whichever is less and company administration charges will be borne by the employer.</li>';
        tableHtml += '<li>Rs.1250/Rs.1025/Rs.690/Rs.315/Rs.135 per month will be deducted from the monthly gross salary if the six months gross is above Rs. 75001/Rs. 60001 to Rs.75000/Rs. 45001 to Rs.60000/ Rs.30001 to Rs.45000/Rs.21001 to Rs.30000 respectively.</li>';
        tableHtml += '<li>Labour welfare fund of Rs.20/- will be deducted once in every year.</li>';
        tableHtml += '<li>Medical insurance for Employee will be covered based on your salary.</li>';
        tableHtml += '<li>Company will pay the variable pay half-yearly basis, based on the performance. In-case of resignation/termination, an employee shall not be entitled to claim the variable pay.</li>';
        tableHtml += '<li>All retirement, superannuation and maternity benefits are calculated on the Basic when applicable.</li>';
        tableHtml += '</ol>';
        tableHtml += '</div>';

        return tableHtml;
    }
    
    /**
     * Helper method to build a standard table row with monthly and annual values
     */
    private String buildRow(String label, Decimal annualAmount) {
        Decimal monthlyAmount = annualAmount != null ? annualAmount / 12 : 0;
        String row = '<tr>';
        row += '<td style="border: 1px solid #000; padding: 8px;">' + label + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(monthlyAmount) + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(annualAmount) + '</td>';
        row += '</tr>';
        return row;
    }
    
    /**
     * Helper method to build a bold table row with background color
     */
    private String buildBoldRow(String label, Decimal annualAmount, String bgColor) {
        Decimal monthlyAmount = annualAmount != null ? annualAmount / 12 : 0;
        String row = '<tr style="font-weight: bold; background-color: ' + bgColor + ';">';
        row += '<td style="border: 1px solid #000; padding: 8px;">' + label + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(monthlyAmount) + '</td>';
        row += '<td style="border: 1px solid #000; padding: 8px; text-align: right;">' + formatCurrency(annualAmount) + '</td>';
        row += '</tr>';
        return row;
    }
    
    /**
     * Helper method to format currency values
     */
    private String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return amount.setScale(2).format();
    }
    
    /**
     * @description Generates the Role & Responsibilities table with categories
     * @return String: The HTML string for roles table
     */
    /*public String getRolesTableHTML() {
        if (candidate.Roles_Responsibility__r == null || candidate.Roles_Responsibility__r.isEmpty()) {
            return '<p>Role and responsibility details are not available for this candidate.</p>';
        }
        
        String tableHtml = '<table style="width:100%; border-collapse: collapse; margin-top: 10px;">';
        tableHtml += '<thead><tr>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left; width: 30%;">Category</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left;">Actions</th>';
        tableHtml += '</tr></thead><tbody>';
        
        for (Role_Responsibility__c role : candidate.Roles_Responsibility__r) {
            tableHtml += '<tr>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px; vertical-align: top;">' + 
                        (role.Category__c != null ? role.Category__c : '') + '</td>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px;">' + 
                        (role.Responsibility_Description__c != null ? role.Responsibility_Description__c : '') + '</td>';
            tableHtml += '</tr>';
        }
        
        tableHtml += '</tbody></table>';
        return tableHtml;
    }*/
public String getRolesTableHTML() {
        if (candidateRoles == null || candidateRoles.isEmpty()) {
            return '<p>Role and responsibility details are not available for this candidate.</p>';
        }
        
        String tableHtml = '<table style="width:100%; border-collapse: collapse; margin-top: 10px;">';
        tableHtml += '<thead><tr>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left; width: 30%;">Category</th>';
        tableHtml += '<th style="border: 1px solid #000; padding: 8px; background-color: #d9d9d9; font-weight: bold; text-align: left;">Actions</th>';
        tableHtml += '</tr></thead><tbody>';
        
        for (Role_Responsibility__c role : candidateRoles) {
            tableHtml += '<tr>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px; vertical-align: top;">' + 
                        (role.Category__c != null ? role.Category__c : '') + '</td>';
            tableHtml += '<td style="border: 1px solid #000; padding: 8px;">' + 
                        (role.Responsibility_Description__c != null ? role.Responsibility_Description__c : '') + '</td>';
            tableHtml += '</tr>';
        }
        
        tableHtml += '</tbody></table>';
        return tableHtml;
    }
}