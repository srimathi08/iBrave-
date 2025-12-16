/**
 * @description Admin Attendance View LWC Controller - Enhanced with Dropdown Filters
 * @author Salesforce Consultant
 * @date 2025-10-17
 * @version 2.1 - Fixed CSV export and initial load behavior
 */

import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Apex Methods
import getAdminAttendanceRecords from '@salesforce/apex/AdminAttendanceViewController.getAdminAttendanceRecords';
import getEmployeeIds from '@salesforce/apex/AdminAttendanceViewController.getEmployeeIds';
import getEmployeeNames from '@salesforce/apex/AdminAttendanceViewController.getEmployeeNames';
import getDepartments from '@salesforce/apex/AdminAttendanceViewController.getDepartments';
import exportAttendanceToCSV from '@salesforce/apex/AdminAttendanceViewController.exportAttendanceToCSV';

export default class AdminAttendanceView extends LightningElement {
    
    // ============================================
    // STATE PROPERTIES
    // ============================================
    
    @track isLoading = false;
    @track filtersExpanded = true;
    @track hasError = false;
    @track errorMessage = '';
    
    // Filter Values
    @track employeeIdFilter = '';
    @track employeeNameFilter = '';
    @track departmentFilter = '';
    @track startDate = '';
    @track endDate = '';
    
    // Table Data
    @track displayedRecords = [];
    @track allRecords = [];
    
    // Sorting
    @track sortedBy = '';
    @track sortDirection = 'asc';
    
    // Pagination
    @track pageSize = 20;
    @track currentPage = 1;
    @track totalRecords = 0;
    @track totalPages = 0;
    
    // Dropdown Options
    @track employeeIdOptions = [];
    @track employeeNameOptions = [];
    @track departmentOptions = [];
    
    // ✅ NEW: Track if filters have been applied
    @track filtersHaveBeenApplied = false;
    
    // ============================================
    // LIFECYCLE HOOKS
    // ============================================
    
    connectedCallback() {
        console.log('=== Admin Attendance View Initialized ===');
        this.initializeComponent();
    }
    
    /**
     * ✅ UPDATED: Initialize component - Load dropdown options ONLY (no data initially)
     */
    initializeComponent() {
        // Set default date range (last 7 days)
        const today = new Date();
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(today.getDate() - 7);
        
        this.startDate = this.formatDateForInput(sevenDaysAgo);
        this.endDate = this.formatDateForInput(today);
        
        console.log('Default date range:', this.startDate, 'to', this.endDate);
        
        // Load dropdown options only
        this.loadEmployeeIds();
        this.loadEmployeeNames();
        this.loadDepartments();
        
        // ✅ CHANGED: DO NOT load initial data - wait for user to apply filters
        console.log('✅ Waiting for user to apply filters before loading data');
    }
    
    /**
     * Load Employee IDs for dropdown
     */
    loadEmployeeIds() {
        getEmployeeIds()
            .then(result => {
                console.log('Employee IDs loaded:', result.length);
                
                const idOptions = [{ label: 'All Employee IDs', value: '' }];
                
                if (result && result.length > 0) {
                    result.forEach(option => {
                        idOptions.push({
                            label: option.label,
                            value: option.value
                        });
                    });
                }
                
                this.employeeIdOptions = idOptions;
                console.log('Employee ID options:', this.employeeIdOptions.length);
                
            })
            .catch(error => {
                console.error('Error loading Employee IDs:', error);
                this.employeeIdOptions = [{ label: 'All Employee IDs', value: '' }];
            });
    }
    
    /**
     * Load Employee Names for dropdown
     */
    loadEmployeeNames() {
        getEmployeeNames()
            .then(result => {
                console.log('Employee Names loaded:', result.length);
                
                const nameOptions = [{ label: 'All Employees', value: '' }];
                
                if (result && result.length > 0) {
                    result.forEach(option => {
                        nameOptions.push({
                            label: option.label,
                            value: option.value
                        });
                    });
                }
                
                this.employeeNameOptions = nameOptions;
                console.log('Employee Name options:', this.employeeNameOptions.length);
                
            })
            .catch(error => {
                console.error('Error loading Employee Names:', error);
                this.employeeNameOptions = [{ label: 'All Employees', value: '' }];
            });
    }
    
    /**
     * Load departments for filter dropdown
     */
    loadDepartments() {
        getDepartments()
            .then(result => {
                console.log('Departments loaded:', result);
                
                const deptOptions = [{ label: 'All Departments', value: '' }];
                
                if (result && result.length > 0) {
                    result.forEach(dept => {
                        deptOptions.push({
                            label: dept,
                            value: dept
                        });
                    });
                }
                
                this.departmentOptions = deptOptions;
                console.log('Department options:', this.departmentOptions);
                
            })
            .catch(error => {
                console.error('Error loading departments:', error);
                this.departmentOptions = [{ label: 'All Departments', value: '' }];
            });
    }
    
    // ============================================
    // DATA LOADING
    // ============================================
    
    /**
     * Load attendance data from Apex
     */
    loadAttendanceData() {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';
        
        console.log('=== Loading Attendance Data ===');
        console.log('Filters:', {
            employeeId: this.employeeIdFilter,
            employeeName: this.employeeNameFilter,
            department: this.departmentFilter,
            startDate: this.startDate,
            endDate: this.endDate,
            pageSize: this.pageSize,
            pageNumber: this.currentPage,
            sortField: this.sortedBy || 'Date__c',
            sortDirection: this.sortDirection
        });
        
        // Build filter parameters
        const filterParams = {
            employeeId: this.employeeIdFilter,
            employeeName: this.employeeNameFilter,
            department: this.departmentFilter,
            startDate: this.startDate,
            endDate: this.endDate,
            pageSize: parseInt(this.pageSize),
            pageNumber: this.currentPage,
            sortField: this.sortedBy || 'Date__c',
            sortDirection: this.sortDirection.toUpperCase()
        };
        
        // Call Apex method
        getAdminAttendanceRecords({ filterParams: filterParams })
            .then(result => {
                console.log('✅ Attendance data loaded successfully');
                console.log('Result:', result);
                
                if (result.success) {
                    this.displayedRecords = result.records || [];
                    this.totalRecords = result.totalRecords || 0;
                    this.totalPages = result.totalPages || 0;
                    
                    console.log('Records displayed:', this.displayedRecords.length);
                    console.log('Total records:', this.totalRecords);
                } else {
                    this.handleError(result.error || 'Failed to load attendance data');
                }
                
                this.isLoading = false;
                
            })
            .catch(error => {
                console.error('❌ Error loading attendance data:', error);
                this.handleError(this.parseError(error));
                this.isLoading = false;
            });
    }
    
    // ============================================
    // FILTER HANDLERS
    // ============================================
    
    handleEmployeeIdChange(event) {
        this.employeeIdFilter = event.detail.value;
        console.log('Employee ID filter:', this.employeeIdFilter);
    }
    
    handleEmployeeNameChange(event) {
        this.employeeNameFilter = event.detail.value;
        console.log('Employee Name filter:', this.employeeNameFilter);
    }
    
    handleDepartmentChange(event) {
        this.departmentFilter = event.detail.value;
        console.log('Department filter:', this.departmentFilter);
    }
    
    handleStartDateChange(event) {
        this.startDate = event.target.value;
        console.log('Start date:', this.startDate);
    }
    
    handleEndDateChange(event) {
        this.endDate = event.target.value;
        console.log('End date:', this.endDate);
    }
    
    handleToggleFilters() {
        this.filtersExpanded = !this.filtersExpanded;
        console.log('Filters expanded:', this.filtersExpanded);
    }
    
    /**
     * ✅ UPDATED: Clear filters and reset to initial state
     */
    handleClearFilters() {
        console.log('Clearing all filters...');
        
        // Reset all filter values
        this.employeeIdFilter = '';
        this.employeeNameFilter = '';
        this.departmentFilter = '';
        
        // Reset to default date range (last 7 days)
        const today = new Date();
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(today.getDate() - 7);
        
        this.startDate = this.formatDateForInput(sevenDaysAgo);
        this.endDate = this.formatDateForInput(today);
        
        // Reset pagination
        this.currentPage = 1;
        
        // ✅ CHANGED: Reset filters applied flag and clear records
        this.filtersHaveBeenApplied = false;
        this.displayedRecords = [];
        this.totalRecords = 0;
        this.totalPages = 0;
        
        this.showToast('Filters Cleared', 'All filters have been reset. Apply filters to view records.', 'info');
    }
    
    /**
     * ✅ UPDATED: Apply filters and load data
     */
    handleApplyFilters() {
        console.log('Applying filters...');
        
        // Reset to first page
        this.currentPage = 1;
        
        // ✅ NEW: Mark that filters have been applied
        this.filtersHaveBeenApplied = true;
        
        // Show toast
        this.showToast('Filters Applied', 'Loading filtered attendance data...', 'info');
        
        // Load data with filters
        this.loadAttendanceData();
    }
    
    // ============================================
    // SORTING HANDLERS
    // ============================================
    
    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        console.log('Sorting by field:', field);
        
        // Toggle sort direction if same field
        if (this.sortedBy === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortedBy = field;
            this.sortDirection = 'asc';
        }
        
        console.log('Sort direction:', this.sortDirection);
        
        // Map frontend field names to backend field names
        const fieldMapping = {
            'employeeId': 'Employee_Name__r.Employee_Id__c',
            'employeeName': 'Employee_Name__r.Name',
            'managerName': 'Employee_Name__r.Manager.Name',
            'department': 'Employee_Name__r.Department',
            'date': 'Date__c',
            'checkInTime': 'Check_In_Time__c',
            'checkOutTime': 'Check_Out_Time__c',
            'hoursWorked': 'Hours_Worked__c',
            'location': 'Check_In_Location_Name__c',
            'wfhApprovalStatusText': 'WFH_Approval_Status__c'
        };
        
        this.sortedBy = fieldMapping[field] || field;
        
        // Reload data with new sort
        this.loadAttendanceData();
    }
    
    // ============================================
    // PAGINATION HANDLERS
    // ============================================
    
    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            console.log('Previous page:', this.currentPage);
            this.loadAttendanceData();
        }
    }
    
    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            console.log('Next page:', this.currentPage);
            this.loadAttendanceData();
        }
    }
    
    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value);
        this.currentPage = 1; // Reset to first page
        console.log('Page size changed to:', this.pageSize);
        this.loadAttendanceData();
    }
    
    // ============================================
    // ACTION HANDLERS
    // ============================================
    
    /**
     * ✅ FIXED: Export CSV with proper file download (LWS compatible)
     */
    handleExportCSV() {
        console.log('Exporting to CSV...');
        
        if (!this.filtersHaveBeenApplied) {
            this.showToast('No Data', 'Please apply filters first to export data', 'warning');
            return;
        }
        
        this.isLoading = true;
        
        // Build filter parameters
        const filterParams = {
            employeeId: this.employeeIdFilter,
            employeeName: this.employeeNameFilter,
            department: this.departmentFilter,
            startDate: this.startDate,
            endDate: this.endDate,
            pageSize: 10000, // Export all records
            pageNumber: 1,
            sortField: this.sortedBy || 'Date__c',
            sortDirection: this.sortDirection.toUpperCase()
        };
        
        exportAttendanceToCSV({ filterParams: filterParams })
            .then(csvContent => {
                console.log('✅ CSV export successful');
                
                // ✅ FIXED: Use proper file download method compatible with Lightning Web Security
                this.downloadCSVFile(csvContent);
                
                this.showToast('Success', 'CSV file downloaded successfully', 'success');
                this.isLoading = false;
                
            })
            .catch(error => {
                console.error('❌ CSV export error:', error);
                this.showToast('Error', 'Failed to export CSV: ' + this.parseError(error), 'error');
                this.isLoading = false;
            });
    }
    
    /**
     * ✅ NEW: Download CSV file using Lightning Web Security compatible method
     */
    downloadCSVFile(csvContent) {
        // Create a hidden link element
        const hiddenElement = document.createElement('a');
        hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
        hiddenElement.target = '_blank';
        hiddenElement.download = `Attendance_Report_${this.getCurrentDateTimeString()}.csv`;
        
        // Append to body, click, and remove
        document.body.appendChild(hiddenElement);
        hiddenElement.click();
        document.body.removeChild(hiddenElement);
    }
    
    handleFullscreen() {
        this.showToast('Fullscreen', 'Fullscreen mode coming soon', 'info');
    }
    
    handleRefresh() {
        console.log('Refreshing data...');
        this.showToast('Refreshing', 'Reloading dropdown options...', 'info');
        
        // Reload dropdown options
        this.loadEmployeeIds();
        this.loadEmployeeNames();
        this.loadDepartments();
        
        // Only reload table data if filters have been applied
        if (this.filtersHaveBeenApplied) {
            this.loadAttendanceData();
        }
    }
    
    handleRetry() {
        console.log('Retrying to load data...');
        this.loadAttendanceData();
    }
    
    handleViewDetails(event) {
        const recordId = event.target.dataset.id;
        console.log('View details for record:', recordId);
        this.showToast('View Details', `Opening details for record ${recordId}`, 'info');
    }
    
    handleEditRecord(event) {
        const recordId = event.target.dataset.id;
        console.log('Edit record:', recordId);
        this.showToast('Edit Record', `Editing record ${recordId}`, 'info');
    }
    
    handleExportIndividual(event) {
        const recordId = event.target.dataset.id;
        console.log('Export individual record:', recordId);
        this.showToast('Export Individual', `Exporting record ${recordId}`, 'info');
    }
    
    // ============================================
    // COMPUTED PROPERTIES
    // ============================================
    
    get filterToggleIcon() {
        return this.filtersExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    get filtersPanelClass() {
        return this.filtersExpanded ? 'filters-panel expanded' : 'filters-panel collapsed';
    }
    
    get hasRecords() {
        return this.displayedRecords && this.displayedRecords.length > 0;
    }
    
    get showPagination() {
        return this.hasRecords && !this.isLoading && !this.hasError;
    }
    
    get paginationStart() {
        return this.totalRecords === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }
    
    get paginationEnd() {
        const end = this.currentPage * this.pageSize;
        return end > this.totalRecords ? this.totalRecords : end;
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }
    
    get currentPageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }
    
    get filtersApplied() {
        return this.employeeIdFilter || 
               this.employeeNameFilter || 
               this.departmentFilter;
    }
    
    get activeFiltersLabel() {
        let count = 0;
        if (this.employeeIdFilter) count++;
        if (this.employeeNameFilter) count++;
        if (this.departmentFilter) count++;
        
        return `${count} Active Filter${count !== 1 ? 's' : ''}`;
    }
    
    /**
     * ✅ NEW: Show initial message if filters haven't been applied yet
     */
    get showInitialMessage() {
        return !this.filtersHaveBeenApplied;
    }
    
    get pageSizeOptions() {
        return [
            { label: '10', value: '10' },
            { label: '20', value: '20' },
            { label: '50', value: '50' },
            { label: '100', value: '100' }
        ];
    }
    
    // ============================================
    // UTILITY METHODS
    // ============================================
    
    /**
     * Format date for input field (YYYY-MM-DD)
     */
    formatDateForInput(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }
    
    /**
     * Get current date time string for file names
     */
    getCurrentDateTimeString() {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        
        return `${year}${month}${day}_${hours}${minutes}${seconds}`;
    }
    
    /**
     * Parse error object to readable message
     */
    parseError(error) {
        if (!error) {
            return 'Unknown error occurred';
        }
        
        // Handle AuraHandledException
        if (error.body && error.body.message) {
            return error.body.message;
        }
        
        // Handle standard Error object
        if (error.message) {
            return error.message;
        }
        
        // Handle string errors
        if (typeof error === 'string') {
            return error;
        }
        
        // Fallback
        return JSON.stringify(error);
    }
    
    /**
     * Handle error state
     */
    handleError(errorMsg) {
        this.hasError = true;
        this.errorMessage = errorMsg;
        this.displayedRecords = [];
        this.totalRecords = 0;
        
        console.error('Error state:', errorMsg);
        this.showToast('Error', errorMsg, 'error');
    }
    
    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable',
            duration: variant === 'error' ? 8000 : 4000
        });
        this.dispatchEvent(event);
    }
}