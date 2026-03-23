public without sharing class OfferLetterController {

    public Id candidateId { get; set; }
    
    // Data structures to hold the fetched data
    public Candidate__c candidate { get; private set; }
    public Salary_Details__c salaryDetails { get; private set; }
    public Map<Id, List<Person_Responsibility__c>> groupedResponsibilities { get; private set; }
	public Map<Id, String> roleNames { get; private set; }
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
                    Designations__c, 
                    Joining_Date__c, 
                    Date_of_Birth__c,
                    Offer_Type__c,
                    Father_Name__c,
                    Aadhar_Card_Number__c,
                    Internship_Start_Date__c,
                    Internship_End_Date__c,
                    Department__c,Offer_Letter_Reference__c,
					Offer_Accepted__c,Offer_Accepted_Date__c, Offer_Acceptance_IP__c,Place_of_Posting_Base_Location__c,
Company_Address__Street__s,
Company_Address__City__s,
Company_Address__StateCode__s,
Company_Address__PostalCode__s,
Company_Address__CountryCode__s,
                    // Sub-query to get Salary Details
                    (SELECT Id, Basic_Pay_PF_Retirement_Benefits__c, 
                   Other_Allowances_Total__c, House_Rent_Allowance_HRA__c, Bucket_Allowances__c,
                    Gross_Salary__c, EPF_Employee_Contribution_12__c,
                    ESI_Employee_contribution_0_75__c, PT_Annual__c,
                    ESI_Employer_contribution_3_25__c, PF_Contribution_Employer__c,
                    Health_Policy_Insurance__c, Variable_Pay__c, 
                    Total_company_Contribution__c, Total_Deduction__c, Total_CTC__c
                    FROM Salary_Details__r LIMIT 1)                   
                FROM Candidate__c 
                WHERE Id = :candidateId
                LIMIT 1
            ];
         

offerType = candidate.Offer_Type__c;
            
if (offerType == 'On Role') {

    // ✅ 1. Load Salary Details from sub‑query
    if (candidate.Salary_Details__r != null && !candidate.Salary_Details__r.isEmpty()) {
        salaryDetails = candidate.Salary_Details__r[0];
    }

    // ✅ 2. Load Role & Responsibility via junction object
List<Person_Responsibility__c> responsibilityRecords = [
    SELECT Role_Category__c,
           Role_Category__r.Name,
           Responsibility_Text__c,
           Sequence__c
    FROM Person_Responsibility__c
    WHERE Candidate__c = :candidateId
    AND Is_Selected__c = TRUE
    ORDER BY Role_Category__c, Sequence__c
];

    groupedResponsibilities = new Map<Id, List<Person_Responsibility__c>>();
roleNames = new Map<Id, String>();

for(Person_Responsibility__c pr : responsibilityRecords) {

    Id roleId = pr.Role_Category__c;

    roleNames.put(roleId, pr.Role_Category__r.Name);

    if(!groupedResponsibilities.containsKey(roleId)) {
        groupedResponsibilities.put(roleId, new List<Person_Responsibility__c>());
    }

    groupedResponsibilities.get(roleId).add(pr);
}

    
}
        }
    }

    
    /**
     * @description Check if offer type is On-Role
     * @return Boolean
     */
    public Boolean getIsOnRoleOffer() {
        //return offerType == 'On Role';
return offerType != null && offerType.equalsIgnoreCase('On Role');
    }  

    /**
     * @description Check if offer type is Intern
     * @return Boolean
     */
    public Boolean getIsInternOffer() {
        //return offerType == 'Intern';
 return offerType != null && offerType.equalsIgnoreCase('Intern');
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
        Decimal otherBasicAnnual = salaryDetails.Other_Allowances_Total__c != null ? salaryDetails.Other_Allowances_Total__c : 0;
        Decimal hraAnnual = salaryDetails.House_Rent_Allowance_HRA__c != null ? salaryDetails.House_Rent_Allowance_HRA__c : 0;
        Decimal bucketAnnual = salaryDetails.Bucket_Allowances__c != null ? salaryDetails.Bucket_Allowances__c : 0;
        Decimal grossAnnual = salaryDetails.Gross_Salary__c != null ? salaryDetails.Gross_Salary__c : 0;

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
        Decimal ptAnnual = salaryDetails.PT_Annual__c != null ? salaryDetails.PT_Annual__c : 0;
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
    
public String getRolesTableHTML() {

    if(groupedResponsibilities == null || groupedResponsibilities.isEmpty()) {
        return '<p>Role and responsibility details are not available for this candidate.</p>';
    }

    String html = '';

    html += '<table style="width:100%; border-collapse: collapse; margin-top: 15px;">';

    html += '<tr>';
    html += '<th style="border: 1px solid #000; padding: 8px; width:30%;">Category</th>';
    html += '<th style="border: 1px solid #000; padding: 8px;">Responsibilities</th>';
    html += '</tr>';

    for(Id roleId : groupedResponsibilities.keySet()) {

        html += '<tr>';

        // ✅ Role Category Column
        html += '<td style="border: 1px solid #000; padding: 8px; vertical-align: top;">'
              + '<b>' + roleNames.get(roleId) + '</b>'
              + '</td>';

        // ✅ Responsibilities Column
        html += '<td style="border: 1px solid #000; padding: 8px;">';

        Integer counter = 1;  // RESET PER ROLE

        for(Person_Responsibility__c pr : groupedResponsibilities.get(roleId)) {

            html += '<p style="margin:3px 0;">';
            html += counter + '. ' + pr.Responsibility_Text__c;
            html += '</p>';

            counter++; 
        }

        html += '</td>';
        html += '</tr>';
    }

    html += '</table>';

    return html;
}


}