import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateMonthlyReport from '@salesforce/apex/MonthlyAttendanceReportController.generateMonthlyReport';
import exportReportToExcel from '@salesforce/apex/MonthlyAttendanceReportController.exportReportToExcel';
import getDepartments from '@salesforce/apex/MonthlyAttendanceReportController.getDepartments';
import getManagers from '@salesforce/apex/MonthlyAttendanceReportController.getManagers';


export default class MonthlyAttendanceReport extends LightningElement {
    
    // Filter values
    @track selectedMonth = String(new Date().getMonth() + 1);
    @track selectedYear = String(new Date().getFullYear());
    @track selectedDepartment = '';
    @track selectedManager = '';
    
    // Report data
    @track reportData = null;
    @track dateHeaders = [];
    @track allEmployees = [];
    @track displayedEmployees = [];
    
    // Summary data
    @track totalEmployees = 0;
    @track totalWorkingDays = 0;
    @track totalHolidays = 0;
    @track totalWeekends = 0;
    
    // Loading states
    @track isLoading = false;
    @track isLoadingMore = false;
    @track isExporting = false;
    
    // Pagination
    recordsPerPage = 50;
    currentPage = 1;
    
    // Options for dropdowns
    @track monthOptions = [
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
    
    @track yearOptions = [];
    @track departmentOptions = [{ label: 'All Departments', value: '' }];
    @track managerOptions = [{ label: 'All Managers', value: '' }];
    
    // Computed properties
    get hasReportData() {
        return this.displayedEmployees && this.displayedEmployees.length > 0;
    }
    
    get hasMoreRecords() {
        return this.displayedEmployees.length < this.allEmployees.length;
    }
    
    // Initialize component
    connectedCallback() {
        this.initializeYearOptions();
        this.loadDepartments();
        this.loadManagers();
    }
    
    /**
     * Initialize year options (current year ± 5 years)
     */
    initializeYearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        
        for (let i = currentYear - 5; i <= currentYear + 5; i++) {
            years.push({ label: String(i), value: String(i) });
        }
        
        this.yearOptions = years;
    }
    
    /**
     * Load departments
     */
    loadDepartments() {
        getDepartments()
            .then(result => {
                const depts = [{ label: 'All Departments', value: '' }];
                result.forEach(dept => {
                    depts.push({ label: dept, value: dept });
                });
                this.departmentOptions = depts;
            })
            .catch(error => {
                console.error('Error loading departments:', error);
            });
    }
    
    /**
     * Load managers
     */
    loadManagers() {
        getManagers()
            .then(result => {
                const mgrs = [{ label: 'All Managers', value: '' }];
                result.forEach(mgr => {
                    mgrs.push({ label: mgr.Name, value: mgr.Id });
                });
                this.managerOptions = mgrs;
            })
            .catch(error => {
                console.error('Error loading managers:', error);
            });
    }
    
    /**
     * Handle filter changes
     */
    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }
    
    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }
    
    handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;
    }
    
    handleManagerChange(event) {
        this.selectedManager = event.detail.value;
    }
    
    /**
     * Generate report
     */
    handleGenerateReport() {
        if (!this.selectedMonth || !this.selectedYear) {
            this.showToast('Error', 'Please select both month and year', 'error');
            return;
        }
        
        this.isLoading = true;
        this.reportData = null;
        this.allEmployees = [];
        this.displayedEmployees = [];
        this.currentPage = 1;
        
        generateMonthlyReport({
            month: parseInt(this.selectedMonth),
            year: parseInt(this.selectedYear),
            departmentFilter: this.selectedDepartment,
            managerFilter: this.selectedManager
        })
        .then(result => {
            if (result.success) {
                this.processReportData(result);
                this.showToast('Success', result.message, 'success');
            } else {
                this.showToast('Error', result.error || 'Failed to generate report', 'error');
            }
        })
        .catch(error => {
            console.error('Error generating report:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
    
    /**
     * Process report data and format for display
     * ✅ UPDATED v3.2: Added Days Payable processing
     */
    processReportData(result) {
        // Store summary data
        this.totalEmployees = result.totalEmployees || 0;
        this.totalWorkingDays = result.totalWorkingDays || 0;
        this.totalHolidays = result.totalHolidays || 0;
        this.totalWeekends = result.totalWeekends || 0;
        
        // Process date headers
        this.dateHeaders = (result.dateHeaders || []).map(header => {
            return {
                ...header,
                headerClass: this.getHeaderClass(header)
            };
        });
        
        // Process employee data
        this.allEmployees = (result.employees || []).map(emp => {
            return {
                Id: emp.Id,
                employeeId: emp.employeeId || 'N/A',
                employeeName: emp.employeeName || 'N/A',
                dateOfJoining: emp.dateOfJoining || 'N/A',
                workLocationDetails: emp.workLocationDetails || 'N/A',
                managerName: emp.managerName || 'N/A',
                totalDays: emp.totalDays || 0,
                workingDays: emp.workingDays || 0,
                presentDays: emp.presentDays || 0,
                absentDays: emp.absentDays || 0,
                totalLeaves: emp.totalLeaves || 0,
                holidayCount: emp.holidayCount || 0,
                weekendCount: emp.weekendCount || 0,      // ✅ NEW v3.2
                daysPayable: emp.daysPayable || 0,        // ✅ NEW v3.2
                lopDays: emp.lopDays || 0,                // ✅ NEW v3.2
                dailyAttendance: (emp.dailyAttendance || []).map(day => {
                    return {
                        ...day,
                        cellClass: this.getCellClass(day),
                        statusBadgeClass: this.getStatusBadgeClass(day.statusCode)
                    };
                })
            };
        });
        
        // Load first page
        this.loadMoreEmployees();
        
        console.log('Report processed (v3.2 - Days Payable):', {
            totalEmployees: this.totalEmployees,
            dateHeaders: this.dateHeaders.length,
            allEmployees: this.allEmployees.length,
            sampleEmployee: this.allEmployees.length > 0 ? {
                name: this.allEmployees[0].employeeName,
                daysPayable: this.allEmployees[0].daysPayable,
                lopDays: this.allEmployees[0].lopDays
            } : null
        });
    }
    
    /**
     * Get header CSS class based on day type
     */
    getHeaderClass(header) {
        let classes = 'date-col';
        
        if (header.isHoliday) {
            classes += ' holiday-header';
        } else if (header.isWeekend) {
            classes += ' weekend-header';
        }
        
        return classes;
    }
    
    /**
     * Get cell CSS class based on attendance status
     */
    getCellClass(day) {
        let classes = 'attendance-cell';
        
        if (day.isWeekend) {
            classes += ' weekend-cell';
        } else if (day.isHoliday) {
            classes += ' holiday-cell';
        } else {
            const status = day.statusCode;
            if (status === 'P' || status === 'P*') {
                classes += ' present-cell';
            } else if (status === 'A') {
                classes += ' absent-cell';
            } else if (status && status !== 'W' && status !== 'H') {
                classes += ' leave-cell';
            }
        }
        
        return classes;
    }
    
    /**
     * Get status badge CSS class
     */
    getStatusBadgeClass(statusCode) {
        let classes = 'status-badge';
        
        if (!statusCode) {
            return classes;
        }
        
        if (statusCode === 'P') {
            classes += ' present-badge';
        } else if (statusCode === 'P*') {
            classes += ' late-badge';
        } else if (statusCode === 'A') {
            classes += ' absent-badge';
        } else if (statusCode === 'H') {
            classes += ' holiday-badge';
        } else if (statusCode === 'W') {
            classes += ' weekend-badge';
        } else if (statusCode.includes('-H')) {
            classes += ' half-badge';
        } else {
            classes += ' leave-badge';
        }
        
        return classes;
    }
    
    /**
     * Load more employees (pagination)
     */
    loadMoreEmployees() {
        const start = (this.currentPage - 1) * this.recordsPerPage;
        const end = start + this.recordsPerPage;
        
        const newEmployees = this.allEmployees.slice(start, end);
        this.displayedEmployees = [...this.displayedEmployees, ...newEmployees];
        this.currentPage++;
    }
    
    /**
     * Handle scroll event for infinite loading
     */
    handleScroll(event) {
        const target = event.target;
        const scrollThreshold = 100;
        
        if (target.scrollHeight - target.scrollTop - target.clientHeight < scrollThreshold) {
            if (this.hasMoreRecords && !this.isLoadingMore) {
                this.isLoadingMore = true;
                
                // Simulate loading delay
                setTimeout(() => {
                    this.loadMoreEmployees();
                    this.isLoadingMore = false;
                }, 500);
            }
        }
    }
    
    /**
     * Export report to Excel
     */
    handleExportToExcel() {
        if (!this.hasReportData) {
            this.showToast('Warning', 'No report data to export', 'warning');
            return;
        }
        
        this.isExporting = true;
        
        exportReportToExcel({
            month: parseInt(this.selectedMonth),
            year: parseInt(this.selectedYear),
            departmentFilter: this.selectedDepartment,
            managerFilter: this.selectedManager
        })
        .then(result => {
            if (result.success) {
                this.downloadExcelFile(result.fileData, result.fileName);
                this.showToast('Success', 'Excel file exported successfully', 'success');
            } else {
                this.showToast('Error', result.error || 'Failed to export', 'error');
            }
        })
        .catch(error => {
            console.error('Error exporting to Excel:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        })
        .finally(() => {
            this.isExporting = false;
        });
    }
    
    /**
     * Download Excel file
     */
    downloadExcelFile(base64Data, fileName) {
        const link = document.createElement('a');
        link.href = 'data:application/vnd.ms-excel;base64,' + base64Data;
        link.download = fileName;
        link.click();
    }
    
    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    /**
     * Get error message from error object
     */
    getErrorMessage(error) {
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        } else if (error.message) {
            return error.message;
        }
        return 'An unknown error occurred';
    }
}