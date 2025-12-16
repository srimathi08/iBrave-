import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex Imports
import getLeaveBalanceMatrix from '@salesforce/apex/LeaveBalanceMatrixController.getLeaveBalanceMatrix';
import getAllActiveLeaveTypes from '@salesforce/apex/LeaveBalanceMatrixController.getAllActiveLeaveTypes';

export default class LeaveBalanceMatrix extends LightningElement {
    
    // Filter Values
    @track selectedMonth = '';
    @track selectedYear = '';
    
    // Data
    @track matrixData = [];
    @track leaveTypeColumns = [];
    @track isLoading = false;
    @track hasGenerated = false;
    
    // Month Options
    monthOptions = [
        { label: 'January', value: '1' },
        { label: 'February', value: '2' },
        { label: 'March', value: '3' },
        { label: 'April', value: '4' },
        { label: 'May', value: '5' },
        { label: 'June', value: '6' },
        { label: 'July', value: '7' },
        { label: 'August', value: '8' },
        { label: 'September', value: '9' },
        { label: 'October', value: '10' },
        { label: 'November', value: '11' },
        { label: 'December', value: '12' }
    ];
    
    // Year Options (Last 2 years, current year, next 2 years)
    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let i = -2; i <= 2; i++) {
            const year = currentYear + i;
            years.push({ label: year.toString(), value: year.toString() });
        }
        return years;
    }
    
    connectedCallback() {
        // Set current month and year as default
        const today = new Date();
        this.selectedMonth = (today.getMonth() + 1).toString();
        this.selectedYear = today.getFullYear().toString();
    }
    
    // ==================== EVENT HANDLERS ====================
    
    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }
    
    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }
    
    handleGenerateReport() {
        if (!this.selectedMonth || !this.selectedYear) {
            this.showToast('Validation Error', 'Please select both Month and Year', 'error');
            return;
        }
        
        this.loadMatrixData();
    }
    
    handleReset() {
        const today = new Date();
        this.selectedMonth = (today.getMonth() + 1).toString();
        this.selectedYear = today.getFullYear().toString();
        this.matrixData = [];
        this.leaveTypeColumns = [];
        this.hasGenerated = false;
    }
    
    // ==================== DATA LOADING ====================
    
    loadMatrixData() {
        this.isLoading = true;
        
        Promise.all([
            this.loadLeaveTypes(),
            this.loadEmployeeBalances()
        ])
        .then(() => {
            this.hasGenerated = true;
            this.isLoading = false;
        })
        .catch(error => {
            this.isLoading = false;
            console.error('Error loading matrix data:', error);
            this.showToast('Error', 'Failed to load data: ' + this.getErrorMessage(error), 'error');
        });
    }
    
    /**
     * Load ALL active leave types (for matrix columns)
     * This ensures all leave type columns are shown
     */
    loadLeaveTypes() {
        return getAllActiveLeaveTypes()
            .then(result => {
                this.leaveTypeColumns = result.map(lt => ({
                    id: lt.Id,
                    name: lt.Leave_Type_Name__c,
                    code: lt.Leave_Code__c,
                    fullName: lt.Leave_Type_Name__c + ' (' + lt.Leave_Code__c + ')',
                    sortOrder: lt.Sort_Order__c || 999
                })).sort((a, b) => a.sortOrder - b.sortOrder);
                
                console.log('✅ Leave Types loaded for columns:', this.leaveTypeColumns.length);
            });
    }
    
    /**
     * Load ONLY ELIGIBLE employee balances
     * Non-eligible leave types will automatically show as N/A
     */
    loadEmployeeBalances() {
        return getLeaveBalanceMatrix({
            month: this.selectedMonth,
            year: this.selectedYear
        })
        .then(result => {
            console.log('✅ Eligible balances loaded:', result.length);
            
            // Process the matrix data
            this.matrixData = this.processMatrixData(result);
            console.log('✅ Matrix Data processed:', this.matrixData.length, 'employees');
        });
    }
    
    /**
     * ✅ UPDATED: Process matrix data with N/A for non-eligible leave types
     */
    processMatrixData(data) {
        const processedData = [];
        
        // Group balances by employee
        const employeeMap = new Map();
        
        // Build employee map with ONLY ELIGIBLE balances
        data.forEach(balance => {
            const empId = balance.Employee__c;
            const empName = balance.Employee__r.Name;
            const empEmployeeId = balance.Employee__r.Employee_Id__c;
            const empDepartment = balance.Employee__r.Department;
            const empGender = balance.Employee__r.Gender__c;
            const empMaritalStatus = balance.Employee__r.Marital_Status__c;
            
            if (!employeeMap.has(empId)) {
                employeeMap.set(empId, {
                    employeeId: empId,
                    employeeName: empName,
                    employeeIdDisplay: this.formatEmployeeId(empEmployeeId),
                    department: empDepartment,
                    gender: empGender,
                    maritalStatus: empMaritalStatus,
                    balanceMap: new Map()  // Only ELIGIBLE leave types will be here
                });
            }
            
            // Store balance ONLY for ELIGIBLE leave types
            employeeMap.get(empId).balanceMap.set(balance.Leave_Type__c, {
                available: balance.Available__c,
                allocated: balance.Total_Allocated__c,
                used: balance.Used__c,
                isEligible: balance.Is_Eligible__c
            });
        });
        
        // Build matrix rows with ALL leave type columns
        employeeMap.forEach((empData) => {
            const balances = [];
            
            // ✅ CRITICAL: For each leave type column, check if employee has this balance
            this.leaveTypeColumns.forEach(leaveType => {
                const balanceData = empData.balanceMap.get(leaveType.id);
                
                if (balanceData && balanceData.isEligible) {
                    // ✅ Employee IS ELIGIBLE for this leave type
                    balances.push({
                        leaveTypeId: leaveType.id,
                        value: balanceData.available,
                        displayValue: balanceData.available !== null && balanceData.available !== undefined 
                            ? balanceData.available.toString() 
                            : '0',
                        balanceClass: this.getBalanceClass(balanceData.available),
                        isEligible: true
                    });
                } else {
                    // ✅ Employee is NOT ELIGIBLE for this leave type
                    // Show N/A (e.g., Maternity for males, Paternity for females)
                    balances.push({
                        leaveTypeId: leaveType.id,
                        value: null,
                        displayValue: 'N/A',
                        balanceClass: 'balance-not-applicable',
                        isEligible: false
                    });
                }
            });
            
            processedData.push({
                employeeId: empData.employeeId,
                employeeName: empData.employeeName,
                employeeIdDisplay: empData.employeeIdDisplay,
                department: empData.department,
                gender: empData.gender,
                maritalStatus: empData.maritalStatus,
                balances: balances
            });
        });
        
        // Sort by employee name
        return processedData.sort((a, b) => a.employeeName.localeCompare(b.employeeName));
    }
    
    /**
     * Format Employee ID for display
     */
    formatEmployeeId(employeeId) {
        if (employeeId === null || employeeId === undefined) {
            return 'N/A';
        }
        return String(employeeId);
    }
    
    /**
     * ✅ Get CSS class based on balance value
     * Returns appropriate color class for the balance cell
     */
    getBalanceClass(value) {
        if (value === null || value === undefined) {
            return 'balance-not-applicable';  // Gray for N/A
        } else if (value === 0) {
            return 'balance-zero';  // Red for exhausted
        } else if (value > 0 && value <= 3) {
            return 'balance-low';  // Orange for low
        } else if (value > 3 && value <= 7) {
            return 'balance-medium';  // Blue for medium
        } else {
            return 'balance-high';  // Green for high
        }
    }
    
    // ==================== COMPUTED PROPERTIES ====================
    
    get hasData() {
        return this.matrixData && this.matrixData.length > 0;
    }
    
    get totalEmployees() {
        return this.matrixData ? this.matrixData.length : 0;
    }
    
    get totalLeaveTypes() {
        return this.leaveTypeColumns ? this.leaveTypeColumns.length : 0;
    }
    
    get reportPeriod() {
        if (!this.selectedMonth || !this.selectedYear) return '-';
        
        const monthName = this.monthOptions.find(m => m.value === this.selectedMonth)?.label || '';
        return `${monthName} ${this.selectedYear}`;
    }
    
    get showScrollIndicator() {
        return this.leaveTypeColumns && this.leaveTypeColumns.length > 5;
    }
    
    // ==================== EXPORT TO CSV ====================
    
    /**
     * ✅ UPDATED: Export to CSV with N/A for non-eligible leaves
     */
    exportToCSV() {
        if (!this.hasData) {
            this.showToast('No Data', 'Please generate a report first', 'warning');
            return;
        }
        
        try {
            // Build CSV content
            let csv = 'Employee ID,Employee Name,Department,';
            
            // Header row - Leave Type Codes
            csv += this.leaveTypeColumns.map(lt => `${lt.code}`).join(',');
            csv += '\n';
            
            // Data rows
            this.matrixData.forEach(employee => {
                csv += `${employee.employeeIdDisplay},`;
                csv += `"${employee.employeeName}",`;
                csv += `${employee.department || 'N/A'},`;
                
                // ✅ Balance columns - keep N/A as is, convert others to numbers
                csv += employee.balances.map(b => {
                    if (b.displayValue === 'N/A') {
                        return 'N/A';
                    }
                    return b.displayValue === '-' ? '0' : b.displayValue;
                }).join(',');
                
                csv += '\n';
            });
            
            // Create download link
            const fileName = `Leave_Balance_Matrix_${this.selectedMonth}_${this.selectedYear}.csv`;
            
            const element = document.createElement('a');
            element.setAttribute('href', 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv));
            element.setAttribute('download', fileName);
            element.style.display = 'none';
            
            document.body.appendChild(element);
            element.click();
            document.body.removeChild(element);
            
            this.showToast('Success', 'CSV file downloaded successfully', 'success');
            
        } catch (error) {
            console.error('Error exporting CSV:', error);
            this.showToast('Error', 'Failed to export CSV: ' + error.message, 'error');
        }
    }
    
    // ==================== UTILITY METHODS ====================
    
    getErrorMessage(error) {
        if (!error) return 'Unknown error occurred';
        
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        }
        
        if (typeof error === 'string') {
            return error;
        }
        
        return error.message || 'Unknown error occurred';
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}