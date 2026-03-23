import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id'; // NEW: For cancellation tab

// Leave Types & Holidays
import getLeaveTypes from '@salesforce/apex/LeaveAdminController.getLeaveTypes';
import getHolidays from '@salesforce/apex/LeaveAdminController.getHolidays';
import saveLeaveTypeRecord from '@salesforce/apex/LeaveAdminController.saveLeaveType';
import deleteLeaveTypeRecord from '@salesforce/apex/LeaveAdminController.deleteLeaveType';
import saveHolidayRecord from '@salesforce/apex/LeaveAdminController.saveHoliday';
import deleteHolidayRecord from '@salesforce/apex/LeaveAdminController.deleteHoliday';
import syncAllBalances from '@salesforce/apex/LeaveAdminController.syncAllBalances';

// Employee Allocations WITH PAGINATION
import getEmployeesWithBalancesPaginated from '@salesforce/apex/EmployeeAllocationController.getEmployeesWithBalancesPaginated';
import updateEmployeeBalances from '@salesforce/apex/EmployeeAllocationController.updateEmployeeBalances';

// Leave Reports Apex Imports
import searchLeaveRequests from '@salesforce/apex/LeaveAdminController.searchLeaveRequests';
import exportLeaveRequestsToCSV from '@salesforce/apex/LeaveAdminController.exportLeaveRequestsToCSV';

// NEW: Leave Balance Matrix Apex Imports
import getLeaveBalanceMatrix from '@salesforce/apex/LeaveBalanceMatrixController.getLeaveBalanceMatrix';
import getAllActiveLeaveTypes from '@salesforce/apex/LeaveBalanceMatrixController.getAllActiveLeaveTypes';

// NEW: Admin Leave Cancellation Apex Imports
import getCancellableLeaveRequests from '@salesforce/apex/LeaveRequestController.getCancellableLeaveRequests';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';

// Add this import at the top
import searchEmployees from '@salesforce/apex/LeaveAdminController.searchEmployees';

export default class LeaveAdminConfig extends LightningElement {
    @track activeTab = 'leavetypes';
    @track isLoading = false;
    
    // Leave Types
    @track leaveTypes = [];
    @track showLeaveTypeModal = false;
    @track isEditMode = false;
    @track currentLeaveType = {};
    
    // Holidays
    @track holidays = [];
    @track showHolidayModal = false;
    @track isHolidayEditMode = false;
    @track currentHoliday = {};

    // Employee Allocations WITH PAGINATION
    @track employees = [];
    @track filteredEmployees = [];
    @track searchKey = '';
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track showEditModal = false;
    @track selectedEmployee = {};
    @track editBalances = [];

    // Leave Reports Tab Properties
    @track filteredLeaveRequests = [];
    @track filterEmployeeId = '';
    @track filterEmployeeName = '';
    @track filterDepartment = '';
    @track filterLeaveType = '';
    @track filterStatus = '';
    @track filterStartDateFrom = '';
    @track filterStartDateTo = '';

    // Employee Search Suggestions
@track employeeIdSuggestions = [];
@track employeeNameSuggestions = [];
@track showEmployeeIdSuggestions = false;
@track showEmployeeNameSuggestions = false;
@track selectedEmployeeFromId = null;
@track selectedEmployeeFromName = null;
    
    // ============================================
    // NEW: LEAVE BALANCE MATRIX TAB PROPERTIES
    // ============================================
    @track matrixData = [];
    @track leaveTypeColumns = [];
    @track isMatrixLoading = false;
    @track hasMatrixGenerated = false;
    @track matrixSelectedMonth = '';
    @track matrixSelectedYear = '';
    
    // ============================================
    // NEW: ADMIN LEAVE CANCELLATION TAB PROPERTIES
    // ============================================
    currentUserId = Id;
    @track cancellationEmployeeId = '';
    @track cancellableLeaves = [];
    @track isCancellationLoading = false;
    @track cancellationSearchPerformed = false;
    
    // Filter to show only active users (for cancellation tab)
    userFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };
    
    // Picklist Options
    accrualTypeOptions = [
        { label: 'Yearly', value: 'Yearly' },
        { label: 'Monthly', value: 'Monthly' },
        { label: 'None', value: 'None' }
    ];

    holidayTypeOptions = [
        { label: 'Public Holiday', value: 'Public Holiday' },
        { label: 'Optional Holiday', value: 'Optional Holiday' },
        { label: 'Festival', value: 'Festival' },
        { label: 'Regional Holiday', value: 'Regional Holiday' }
    ];
    
    statusOptions = [
        { label: 'All Status', value: '' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' },
        { label: 'Completed', value: 'Completed' }
    ];
    
    // NEW: Month Options for Matrix Tab
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

    connectedCallback() {
        this.loadData();
        // NEW: Set default month and year for matrix tab
        const today = new Date();
        this.matrixSelectedMonth = (today.getMonth() + 1).toString();
        this.matrixSelectedYear = today.getFullYear().toString();
    }

    loadData() {
        this.isLoading = true;
        Promise.all([
            this.loadLeaveTypes(),
            this.loadHolidays(),
            this.loadEmployees()
        ])
        .then(() => {
            this.isLoading = false;
        })
        .catch(error => {
            this.isLoading = false;
            this.showToast('Error', 'Failed to load data: ' + (error.body?.message || error.message), 'error');
        });
    }

    loadLeaveTypes() {
        return getLeaveTypes()
            .then(result => {
                this.leaveTypes = result.map(leave => ({
                    ...leave,
                    iconClass: this.getIconClass(leave.Leave_Code__c),
                    carryForwardText: leave.Carry_Forward_Allowed__c 
                        ? `${leave.Max_Carry_Forward_Days__c} days` 
                        : 'Not allowed',
                    statusClass: leave.Is_Active__c ? 'status-badge active' : 'status-badge inactive',
                    statusText: leave.Is_Active__c ? 'Active' : 'Inactive'
                }));
                console.log('Leave Types loaded:', this.leaveTypes.length);
            });
    }

    loadHolidays() {
        return getHolidays()
            .then(result => {
                this.holidays = result.map(holiday => ({
                    ...holiday,
                    formattedDate: this.formatDate(holiday.Holiday_Date__c),
                    departmentText: holiday.Applicable_Departments__c || 'All Departments',
                    statusClass: holiday.Is_Active__c ? 'status-badge active' : 'status-badge inactive',
                    statusText: holiday.Is_Active__c ? 'Active' : 'Inactive',
                    typeClass: this.getHolidayTypeClass(holiday.Holiday_Type__c)
                }));
                console.log('Holidays loaded:', this.holidays.length);
            });
    }

    // UPDATED WITH PAGINATION
    loadEmployees() {
        return getEmployeesWithBalancesPaginated({ 
            pageNumber: this.currentPage,
            searchKey: this.searchKey || ''
        })
        .then(result => {
            this.employees = result.employees.map(emp => ({
                ...emp,
                Employee_IDs__c: emp.EmployeeId,
                balances: emp.balances.map(bal => ({
                    Id: bal.Id,
                    leaveTypeName: bal.Leave_Type__r.Leave_Type_Name__c,
                    leaveCode: bal.Leave_Type__r.Leave_Code__c,
                    allocated: bal.Total_Allocated__c,
                    available: bal.Available__c,
                    used: bal.Used__c,
                    booked: bal.Booked__c
                }))
            }));
            
            this.filteredEmployees = [...this.employees];
            this.totalRecords = result.totalRecords;
            this.totalPages = result.totalPages;
            this.pageSize = result.pageSize;
            this.currentPage = result.pageNumber;
            
            console.log('Employees loaded:', this.employees.length, 'Total:', this.totalRecords);
        });
    }

    // ============================================
    // TAB NAVIGATION
    // ============================================
    
    get isLeaveTypesTab() {
        return this.activeTab === 'leavetypes';
    }

    get isHolidaysTab() {
        return this.activeTab === 'holidays';
    }

    get isAllocationsTab() {
        return this.activeTab === 'allocations';
    }

    get isReportsTab() {
        return this.activeTab === 'reports';
    }
    
    // NEW: Balance Matrix Tab Visibility
    get isBalanceMatrixTab() {
        return this.activeTab === 'balancematrix';
    }
    
    // NEW: Cancellation Tab Visibility
    get isCancellationTab() {
        return this.activeTab === 'cancellation';
    }

    get leaveTypesTabClass() {
        return this.activeTab === 'leavetypes' ? 'tab-button active' : 'tab-button';
    }

    get holidaysTabClass() {
        return this.activeTab === 'holidays' ? 'tab-button active' : 'tab-button';
    }

    get allocationsTabClass() {
        return this.activeTab === 'allocations' ? 'tab-button active' : 'tab-button';
    }

    get reportsTabClass() {
        return this.activeTab === 'reports' ? 'tab-button active' : 'tab-button';
    }
    
    // NEW: Balance Matrix Tab Class
    get balanceMatrixTabClass() {
        return this.activeTab === 'balancematrix' ? 'tab-button active' : 'tab-button';
    }
    
    // NEW: Cancellation Tab Class
    get cancellationTabClass() {
        return this.activeTab === 'cancellation' ? 'tab-button active' : 'tab-button';
    }

    handleLeaveTypesTab() {
        this.activeTab = 'leavetypes';
    }

    handleHolidaysTab() {
        this.activeTab = 'holidays';
    }

    handleAllocationsTab() {
        this.activeTab = 'allocations';
    }

    handleReportsTab() {
        this.activeTab = 'reports';
    }
    
    // NEW: Balance Matrix Tab Handler
    handleBalanceMatrixTab() {
        this.activeTab = 'balancematrix';
    }
    
    // NEW: Cancellation Tab Handler
    handleCancellationTab() {
        this.activeTab = 'cancellation';
    }

    // ============================================
    // COMPUTED PROPERTIES
    // ============================================
    
    get hasLeaveTypes() {
        return this.leaveTypes && this.leaveTypes.length > 0;
    }

    get hasHolidays() {
        return this.holidays && this.holidays.length > 0;
    }

    get hasEmployees() {
        return this.filteredEmployees && this.filteredEmployees.length > 0;
    }

    get leaveTypeCount() {
        return this.leaveTypes ? this.leaveTypes.length : 0;
    }

    get holidayCount() {
        return this.holidays ? this.holidays.length : 0;
    }

    get employeeCount() {
        return this.totalRecords || 0;
    }

    get leaveTypeModalTitle() {
        return this.isEditMode ? 'Edit Leave Type' : 'New Leave Type';
    }

    get holidayModalTitle() {
        return this.isHolidayEditMode ? 'Edit Holiday' : 'New Holiday';
    }

    // PAGINATION COMPUTED PROPERTIES
    get hasPreviousPage() {
        return this.currentPage > 1;
    }

    get hasNextPage() {
        return this.currentPage < this.totalPages;
    }

    get pageInfo() {
        if (this.totalRecords === 0) {
            return 'No employees found';
        }
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `Showing ${start}-${end} of ${this.totalRecords} employees`;
    }

    // Reports Tab Computed Properties
    get hasFilteredResults() {
        return this.filteredLeaveRequests && this.filteredLeaveRequests.length > 0;
    }

    get noFilteredResults() {
        return !this.hasFilteredResults;
    }

    get filteredLeaveRequestsCount() {
        return this.filteredLeaveRequests ? this.filteredLeaveRequests.length : 0;
    }

    get leaveTypeFilterOptions() {
        const allOption = [{ label: 'All Leave Types', value: '' }];
        const typeOptions = this.leaveTypes.map(type => ({
            label: type.Leave_Type_Name__c,
            value: type.Id
        }));
        return [...allOption, ...typeOptions];
    }
    
    // ============================================
    // NEW: BALANCE MATRIX COMPUTED PROPERTIES
    // ============================================
    
    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let i = -2; i <= 2; i++) {
            const year = currentYear + i;
            years.push({ label: year.toString(), value: year.toString() });
        }
        return years;
    }
    
    get hasMatrixData() {
        return this.matrixData && this.matrixData.length > 0;
    }
    
    get totalMatrixEmployees() {
        return this.matrixData ? this.matrixData.length : 0;
    }
    
    get totalMatrixLeaveTypes() {
        return this.leaveTypeColumns ? this.leaveTypeColumns.length : 0;
    }
    
    get matrixReportPeriod() {
        if (!this.matrixSelectedMonth || !this.matrixSelectedYear) return '-';
        
        const monthName = this.monthOptions.find(m => m.value === this.matrixSelectedMonth)?.label || '';
        return `${monthName} ${this.matrixSelectedYear}`;
    }
    
    get showMatrixScrollIndicator() {
        return this.leaveTypeColumns && this.leaveTypeColumns.length > 5;
    }
    
    // ============================================
    // NEW: CANCELLATION TAB COMPUTED PROPERTIES
    // ============================================
    
    get hasCancellableLeaves() {
        return this.cancellableLeaves && this.cancellableLeaves.length > 0;
    }

    // ============================================
    // LEAVE TYPE HANDLERS
    // ============================================
    
    handleAddLeaveType() {
        this.isEditMode = false;
        this.currentLeaveType = {
            Leave_Type_Name__c: '',
            Leave_Code__c: '',
            Default_Allocation__c: 0,
            Icon_Name__c: 'utility:layers',
            Color_Code__c: '#5B9BD5',
            Is_Active__c: true,
            Requires_Approval__c: true,
            Carry_Forward_Allowed__c: false,
            Max_Carry_Forward_Days__c: 0,
            Minimum_Notice_Days__c: 0,
            Sort_Order__c: 0,
            Accrual_Type__c: 'Yearly',
            Description__c: ''
        };
        this.showLeaveTypeModal = true;
    }

    handleEditLeaveType(event) {
        const id = event.currentTarget.dataset.id;
        const lt = this.leaveTypes.find(l => l.Id === id);
        if (lt) {
            this.isEditMode = true;
            this.currentLeaveType = { ...lt };
            this.showLeaveTypeModal = true;
        }
    }

    handleDeleteLeaveType(event) {
        const id = event.currentTarget.dataset.id;
        if (confirm('Delete this leave type?')) {
            this.isLoading = true;
            deleteLeaveTypeRecord({ leaveTypeId: id })
                .then(() => {
                    this.showToast('Success', 'Leave type deleted', 'success');
                    return this.loadLeaveTypes();
                })
                .then(() => {
                    this.isLoading = false;
                })
                .catch(err => {
                    this.isLoading = false;
                    this.showToast('Error', err.body?.message, 'error');
                });
        }
    }

    closeLeaveTypeModal() {
        this.showLeaveTypeModal = false;
        this.currentLeaveType = {};
    }

    saveLeaveType() {
        if (!this.validateLeaveType()) {
            return;
        }

        this.isLoading = true;
        saveLeaveTypeRecord({ leaveType: this.currentLeaveType })
            .then(() => {
                const message = this.isEditMode ? 'Leave Type updated successfully' : 'Leave Type created successfully';
                this.showToast('Success', message, 'success');
                this.closeLeaveTypeModal();
                return this.loadLeaveTypes();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to save: ' + error.body?.message, 'error');
            });
    }

    validateLeaveType() {
        if (!this.currentLeaveType.Leave_Type_Name__c) {
            this.showToast('Validation Error', 'Please enter Leave Type Name', 'error');
            return false;
        }
        if (!this.currentLeaveType.Leave_Code__c) {
            this.showToast('Validation Error', 'Please enter Leave Code', 'error');
            return false;
        }
        return true;
    }

    // Leave Type Field Change Handlers
    handleLeaveTypeNameChange(e) { this.currentLeaveType.Leave_Type_Name__c = e.target.value; }
    handleLeaveCodeChange(e) { this.currentLeaveType.Leave_Code__c = e.target.value.toUpperCase(); }
    handleDefaultAllocationChange(e) { this.currentLeaveType.Default_Allocation__c = e.target.value; }
    handleSortOrderChange(e) { this.currentLeaveType.Sort_Order__c = e.target.value; }
    handleIconNameChange(e) { this.currentLeaveType.Icon_Name__c = e.target.value; }
    handleColorCodeChange(e) { this.currentLeaveType.Color_Code__c = e.target.value; }
    handleAccrualTypeChange(e) { this.currentLeaveType.Accrual_Type__c = e.detail.value; }
    handleMinNoticeDaysChange(e) { this.currentLeaveType.Minimum_Notice_Days__c = e.target.value; }
    handleRequiresApprovalChange(e) { this.currentLeaveType.Requires_Approval__c = e.target.checked; }
    handleIsActiveChange(e) { this.currentLeaveType.Is_Active__c = e.target.checked; }
    handleCarryForwardChange(e) { this.currentLeaveType.Carry_Forward_Allowed__c = e.target.checked; }
    handleMaxCarryForwardChange(e) { this.currentLeaveType.Max_Carry_Forward_Days__c = e.target.value; }
    handleDescriptionChange(e) { this.currentLeaveType.Description__c = e.target.value; }

    // ============================================
    // HOLIDAY HANDLERS
    // ============================================
    
    handleAddHoliday() {
        this.isHolidayEditMode = false;
        this.currentHoliday = {
            Name: '',
            Holiday_Date__c: '',
            Holiday_Type__c: 'Public Holiday',
            Applicable_Departments__c: [],
            Icon_Name__c: 'utility:event',
            Is_Active__c: true,
            Description__c: ''
        };
        this.showHolidayModal = true;
    }

    handleEditHoliday(event) {
        const id = event.currentTarget.dataset.id;
        const hol = this.holidays.find(h => h.Id === id);
        if (hol) {
            this.isHolidayEditMode = true;
            this.currentHoliday = { 
                ...hol,
                Applicable_Departments__c: hol.Applicable_Departments__c ? hol.Applicable_Departments__c.split(';') : []
            };
            this.showHolidayModal = true;
        }
    }

    handleDeleteHoliday(event) {
        const id = event.currentTarget.dataset.id;
        if (confirm('Delete this holiday?')) {
            this.isLoading = true;
            deleteHolidayRecord({ holidayId: id })
                .then(() => {
                    this.showToast('Success', 'Holiday deleted', 'success');
                    return this.loadHolidays();
                })
                .then(() => {
                    this.isLoading = false;
                })
                .catch(err => {
                    this.isLoading = false;
                    this.showToast('Error', err.body?.message, 'error');
                });
        }
    }

    closeHolidayModal() {
        this.showHolidayModal = false;
        this.currentHoliday = {};
    }

    saveHoliday() {
        if (!this.currentHoliday.Name || !this.currentHoliday.Holiday_Date__c) {
            this.showToast('Validation Error', 'Please fill required fields', 'error');
            return;
        }

        this.isLoading = true;
        const holidayToSave = {
            ...this.currentHoliday,
            Applicable_Departments__c: Array.isArray(this.currentHoliday.Applicable_Departments__c) 
                ? this.currentHoliday.Applicable_Departments__c.join(';') 
                : this.currentHoliday.Applicable_Departments__c
        };

        saveHolidayRecord({ holiday: holidayToSave })
            .then(() => {
                const message = this.isHolidayEditMode ? 'Holiday updated successfully' : 'Holiday created successfully';
                this.showToast('Success', message, 'success');
                this.closeHolidayModal();
                return this.loadHolidays();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to save: ' + error.body?.message, 'error');
            });
    }

    // Holiday Field Change Handlers
    handleHolidayNameChange(e) { this.currentHoliday.Name = e.target.value; }
    handleHolidayDateChange(e) { this.currentHoliday.Holiday_Date__c = e.target.value; }
    handleHolidayTypeChange(e) { this.currentHoliday.Holiday_Type__c = e.detail.value; }
    handleDepartmentsChange(e) { this.currentHoliday.Applicable_Departments__c = e.detail.value; }
    handleHolidayIconChange(e) { this.currentHoliday.Icon_Name__c = e.target.value; }
    handleHolidayActiveChange(e) { this.currentHoliday.Is_Active__c = e.target.checked; }
    handleHolidayDescriptionChange(e) { this.currentHoliday.Description__c = e.target.value; }

    // ============================================
    // EMPLOYEE ALLOCATIONS HANDLERS WITH PAGINATION
    // ============================================
    
    handleSearch(event) {
        this.searchKey = event.target.value;
        this.currentPage = 1; // Reset to first page when searching
        this.loadEmployees();
    }

    handleEditAllocations(event) {
        const employeeId = event.currentTarget.dataset.employeeId;
        const employee = this.employees.find(e => e.Id === employeeId);
        
        if (employee) {
            this.selectedEmployee = employee;
            this.editBalances = employee.balances.map(bal => ({ ...bal }));
            this.showEditModal = true;
        }
    }

    handleAllocationChange(event) {
        const balanceId = event.currentTarget.dataset.balanceId;
        const newValue = parseFloat(event.target.value);
        
        const balance = this.editBalances.find(b => b.Id === balanceId);
        if (balance) {
            balance.allocated = newValue;
            balance.available = newValue - (balance.used + balance.booked);
        }
    }

    closeEditModal() {
        this.showEditModal = false;
        this.selectedEmployee = {};
        this.editBalances = [];
    }

    saveAllocations() {
        this.isLoading = true;
        
        const balancesToUpdate = this.editBalances.map(bal => ({
            Id: bal.Id,
            Total_Allocated__c: bal.allocated
        }));
        
        updateEmployeeBalances({ balances: balancesToUpdate })
            .then(() => {
                this.showToast('Success', 'Leave allocations updated successfully', 'success');
                this.closeEditModal();
                return this.loadEmployees();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to save: ' + error.body?.message, 'error');
            });
    }

    // PAGINATION HANDLERS
    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadEmployees();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.loadEmployees();
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.loadEmployees();
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.loadEmployees();
    }

    // ============================================
    // LEAVE REPORTS TAB HANDLERS
    // ============================================
    
    // 
    
    // ============================================
// LEAVE REPORTS TAB HANDLERS
// ============================================

handleEmployeeIdFilter(event) {
    this.filterEmployeeId = event.target.value;
    
    if (this.filterEmployeeId && this.filterEmployeeId.length >= 1) {
        this.searchEmployeesByField('employeeId', this.filterEmployeeId);
    } else {
        this.showEmployeeIdSuggestions = false;
        this.employeeIdSuggestions = [];
    }
}

handleEmployeeNameFilter(event) {
    this.filterEmployeeName = event.target.value;
    
    if (this.filterEmployeeName && this.filterEmployeeName.length >= 2) {
        this.searchEmployeesByField('name', this.filterEmployeeName);
    } else {
        this.showEmployeeNameSuggestions = false;
        this.employeeNameSuggestions = [];
    }
}

searchEmployeesByField(fieldType, searchTerm) {
    searchEmployees({ 
        searchType: fieldType,
        searchTerm: searchTerm
    })
    .then(result => {
        if (fieldType === 'employeeId') {
            this.employeeIdSuggestions = result;
            this.showEmployeeIdSuggestions = result.length > 0;
        } else if (fieldType === 'name') {
            this.employeeNameSuggestions = result;
            this.showEmployeeNameSuggestions = result.length > 0;
        }
    })
    //.catch(error => {
        //console.error('Error searching employees:', error);
        //this.showToast('Error', 'Failed to search employees', 'error');
   // });
}

handleEmployeeIdSuggestionClick(event) {
    const selectedId = event.currentTarget.dataset.id;
    const selectedName = event.currentTarget.dataset.name;
    const selectedEmpId = event.currentTarget.dataset.empid;
    
    this.filterEmployeeId = selectedEmpId;
    this.filterEmployeeName = selectedName;
    this.selectedEmployeeFromId = selectedId;
    this.showEmployeeIdSuggestions = false;
    this.employeeIdSuggestions = [];
}

handleEmployeeNameSuggestionClick(event) {
    const selectedId = event.currentTarget.dataset.id;
    const selectedName = event.currentTarget.dataset.name;
    const selectedEmpId = event.currentTarget.dataset.empid;
    
    this.filterEmployeeName = selectedName;
    this.filterEmployeeId = selectedEmpId;
    this.selectedEmployeeFromName = selectedId;
    this.showEmployeeNameSuggestions = false;
    this.employeeNameSuggestions = [];
}

handleDepartmentFilter(event) {
    this.filterDepartment = event.target.value;
}

handleLeaveTypeFilter(event) {
    this.filterLeaveType = event.detail.value;
}

handleStatusFilter(event) {
    this.filterStatus = event.detail.value;
}

handleStartDateFromFilter(event) {
    this.filterStartDateFrom = event.target.value;
}

handleStartDateToFilter(event) {
    this.filterStartDateTo = event.target.value;
}

handleClearFilters() {
    this.filterEmployeeId = '';
    this.filterEmployeeName = '';
    this.filterDepartment = '';
    this.filterLeaveType = '';
    this.filterStatus = '';
    this.filterStartDateFrom = '';
    this.filterStartDateTo = '';
    this.filteredLeaveRequests = [];
    this.showEmployeeIdSuggestions = false;
    this.showEmployeeNameSuggestions = false;
    this.employeeIdSuggestions = [];
    this.employeeNameSuggestions = [];
    this.selectedEmployeeFromId = null;
    this.selectedEmployeeFromName = null;
}

    handleSearchLeaveRequests() {
        this.isLoading = true;
        
        const filters = {
            employeeId: this.filterEmployeeId,
            employeeName: this.filterEmployeeName,
            department: this.filterDepartment,
            leaveTypeId: this.filterLeaveType,
            status: this.filterStatus,
            startDateFrom: this.filterStartDateFrom,
            startDateTo: this.filterStartDateTo
        };

        searchLeaveRequests({ filters: filters })
            .then(result => {
                this.filteredLeaveRequests = result.map(req => ({
                    ...req,
                    employeeId: req.Employee__r.Employee_IDs__c,
                    employeeName: req.Employee__r.Name,
                    department: req.Employee__r.Department || 'N/A',
                    leaveTypeName: req.Leave_Type__r ? req.Leave_Type__r.Leave_Type_Name__c : 'N/A',
                    leaveTypeCode: req.Leave_Type__r ? req.Leave_Type__r.Leave_Code__c : 'N/A',
                    managerName: req.Manager__r ? req.Manager__r.Name : 'N/A',
                    approvedByName: req.Approved_By__r ? req.Approved_By__r.Name : 'N/A',
                    formattedStartDate: this.formatDate(req.Start_Date__c),
                    formattedEndDate: this.formatDate(req.End_Date__c),
                    formattedAppliedDate: this.formatDateTime(req.Applied_Date__c),
                    formattedActionDate: this.getActionDate(req),
                    statusClass: this.getStatusClass(req.Status__c)
                }));
                this.isLoading = false;
                
                if (this.filteredLeaveRequests.length === 0) {
                    this.showToast('No Results', 'No leave requests found matching the filters', 'info');
                } else {
                    this.showToast('Success', `Found ${this.filteredLeaveRequests.length} leave request(s)`, 'success');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to search: ' + (error.body?.message || error.message), 'error');
            });
    }

    handleExportToExcel() {
        this.isLoading = true;
        
        const filters = {
            employeeId: this.filterEmployeeId,
            employeeName: this.filterEmployeeName,
            department: this.filterDepartment,
            leaveTypeId: this.filterLeaveType,
            status: this.filterStatus,
            startDateFrom: this.filterStartDateFrom,
            startDateTo: this.filterStartDateTo
        };

        exportLeaveRequestsToCSV({ filters: filters })
            .then(csvData => {
                this.downloadCSV(csvData);
                this.isLoading = false;
                this.showToast('Success', 'Leave requests exported successfully', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to export: ' + (error.body?.message || error.message), 'error');
            });
    }

    downloadCSV(csvData) {
        try {
            const universalBOM = '\uFEFF';
            const csvContent = universalBOM + csvData;
            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            const link = document.createElement('a');
            const today = new Date();
            const dateStr = today.toISOString().split('T')[0];
            
            link.setAttribute('href', encodedUri);
            link.setAttribute('download', `Leave_Requests_${dateStr}.csv`);
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            console.error('Download error:', error);
            this.showToast('Error', 'Failed to download file', 'error');
        }
    }

    getActionDate(request) {
        if (request.Approved_Date__c) {
            return this.formatDateTime(request.Approved_Date__c);
        } else if (request.Rejected_Date__c) {
            return this.formatDateTime(request.Rejected_Date__c);
        } else if (request.Cancelled_Date__c) {
            return this.formatDateTime(request.Cancelled_Date__c);
        }
        return 'N/A';
    }

    getStatusClass(status) {
        switch(status) {
            case 'Approved': return 'status-badge approved';
            case 'Rejected': return 'status-badge rejected';
            case 'Pending': return 'status-badge pending';
            case 'Cancelled': return 'status-badge cancelled';
            case 'Completed': return 'status-badge completed';
            default: return 'status-badge';
        }
    }

    // ============================================
    // NEW: LEAVE BALANCE MATRIX TAB HANDLERS
    // ============================================
    
    handleMatrixMonthChange(event) {
        this.matrixSelectedMonth = event.detail.value;
    }
    
    handleMatrixYearChange(event) {
        this.matrixSelectedYear = event.detail.value;
    }
    
    handleGenerateMatrixReport() {
        if (!this.matrixSelectedMonth || !this.matrixSelectedYear) {
            this.showToast('Validation Error', 'Please select both Month and Year', 'error');
            return;
        }
        
        this.loadMatrixData();
    }
    
    handleMatrixReset() {
        const today = new Date();
        this.matrixSelectedMonth = (today.getMonth() + 1).toString();
        this.matrixSelectedYear = today.getFullYear().toString();
        this.matrixData = [];
        this.leaveTypeColumns = [];
        this.hasMatrixGenerated = false;
    }
    
    loadMatrixData() {
        this.isMatrixLoading = true;
        
        Promise.all([
            this.loadMatrixLeaveTypes(),
            this.loadMatrixEmployeeBalances()
        ])
        .then(() => {
            this.hasMatrixGenerated = true;
            this.isMatrixLoading = false;
        })
        .catch(error => {
            this.isMatrixLoading = false;
            console.error('Error loading matrix data:', error);
            this.showToast('Error', 'Failed to load matrix data: ' + this.getErrorMessage(error), 'error');
        });
    }
    
    loadMatrixLeaveTypes() {
        return getAllActiveLeaveTypes()
            .then(result => {
                this.leaveTypeColumns = result.map(lt => ({
                    id: lt.Id,
                    name: lt.Leave_Type_Name__c,
                    code: lt.Leave_Code__c,
                    fullName: lt.Leave_Type_Name__c + ' (' + lt.Leave_Code__c + ')',
                    sortOrder: lt.Sort_Order__c || 999
                })).sort((a, b) => a.sortOrder - b.sortOrder);
                
                console.log('✅ Matrix Leave Types loaded:', this.leaveTypeColumns.length);
            });
    }
    
    loadMatrixEmployeeBalances() {
        return getLeaveBalanceMatrix({
            month: this.matrixSelectedMonth,
            year: this.matrixSelectedYear
        })
        .then(result => {
            console.log('✅ Matrix balances loaded:', result.length);
            this.matrixData = this.processMatrixData(result);
            console.log('✅ Matrix Data processed:', this.matrixData.length, 'employees');
        });
    }
    
    processMatrixData(data) {
        const processedData = [];
        const employeeMap = new Map();
        
        // Build employee map with ONLY ELIGIBLE balances
        data.forEach(balance => {
            const empId = balance.Employee__c;
            const empName = balance.Employee__r.Name;
            const empEmployeeId = balance.Employee__r.Employee_IDs__c;
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
                    balanceMap: new Map()
                });
            }
            
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
            
            this.leaveTypeColumns.forEach(leaveType => {
                const balanceData = empData.balanceMap.get(leaveType.id);
                
                if (balanceData && balanceData.isEligible) {
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
        
        return processedData.sort((a, b) => a.employeeName.localeCompare(b.employeeName));
    }
    
    formatEmployeeId(employeeId) {
        if (employeeId === null || employeeId === undefined) {
            return 'N/A';
        }
        return String(employeeId);
    }
    
    getBalanceClass(value) {
        if (value === null || value === undefined) {
            return 'balance-not-applicable';
        } else if (value === 0) {
            return 'balance-zero';
        } else if (value > 0 && value <= 3) {
            return 'balance-low';
        } else if (value > 3 && value <= 7) {
            return 'balance-medium';
        } else {
            return 'balance-high';
        }
    }
    
    exportMatrixToCSV() {
        if (!this.hasMatrixData) {
            this.showToast('No Data', 'Please generate a report first', 'warning');
            return;
        }
        
        try {
            let csv = 'Employee ID,Employee Name,Department,';
            csv += this.leaveTypeColumns.map(lt => `${lt.code}`).join(',');
            csv += '\n';
            
            this.matrixData.forEach(employee => {
                csv += `${employee.employeeIdDisplay},`;
                csv += `"${employee.employeeName}",`;
                csv += `${employee.department || 'N/A'},`;
                
                csv += employee.balances.map(b => {
                    if (b.displayValue === 'N/A') {
                        return 'N/A';
                    }
                    return b.displayValue === '-' ? '0' : b.displayValue;
                }).join(',');
                
                csv += '\n';
            });
            
            const fileName = `Leave_Balance_Matrix_${this.matrixSelectedMonth}_${this.matrixSelectedYear}.csv`;
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

    // ============================================
    // NEW: ADMIN LEAVE CANCELLATION TAB HANDLERS
    // ============================================
    
    handleCancellationEmployeeSelect(event) {
        this.cancellationEmployeeId = event.detail.recordId;
        
        if (this.cancellationEmployeeId) {
            this.loadCancellableLeaves();
        }
    }
    
    loadCancellableLeaves() {
        this.isCancellationLoading = true;
        this.cancellationSearchPerformed = true;
        
        getCancellableLeaveRequests({ employeeId: this.cancellationEmployeeId })
            .then(result => {
                console.log('Cancellable leave requests found:', result.length);
                this.cancellableLeaves = result.map(leave => ({
                    ...leave,
                    formattedStartDate: this.formatDate(leave.Start_Date__c),
                    formattedEndDate: this.formatDate(leave.End_Date__c)
                }));
                
                if (this.cancellableLeaves.length === 0) {
                    this.showToast('Info', 'No active leave requests found for this employee', 'info');
                }
            })
            .catch(error => {
                console.error('Error loading leave requests:', error);
                this.showToast('Error', 'Failed to load leave requests: ' + this.getErrorMessage(error), 'error');
                this.cancellableLeaves = [];
            })
            .finally(() => {
                this.isCancellationLoading = false;
            });
    }
    
    handleCancelLeaveClick(event) {
        const leaveId = event.target.dataset.id;
        const leaveName = event.target.dataset.name;
        const employeeName = event.target.dataset.employee;
        
        const confirmMessage = `Are you sure you want to cancel leave request "${leaveName}" for ${employeeName}?\n\nThis will:\n✅ Restore the leave balance\n✅ Enable attendance check-in\n✅ Send notification email to employee`;
        
        if (confirm(confirmMessage)) {
            this.cancelLeave(leaveId);
        }
    }
    
    cancelLeave(leaveId) {
        this.isCancellationLoading = true;
        const cancellationReason = 'Cancelled by Admin to enable attendance check-in';
        
        cancelLeaveRequest({
            leaveRequestId: leaveId,
            cancelledBy: this.currentUserId,
            cancellationReason: cancellationReason
        })
            .then(result => {
                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                    this.loadCancellableLeaves();
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error cancelling leave:', error);
                this.showToast('Error', 'Failed to cancel leave request: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isCancellationLoading = false;
            });
    }

    // ============================================
    // SYNC BALANCES
    // ============================================
    
    handleSyncAllBalances() {
        if (!confirm('This will create employee leave balance records for all active users. Continue?')) {
            return;
        }
        
        this.isLoading = true;
        const timeoutId = setTimeout(() => {
            this.isLoading = false;
            this.showToast('Error', 'Sync operation timed out.', 'error');
        }, 30000);
        
        syncAllBalances()
            .then(result => {
                clearTimeout(timeoutId);
                this.isLoading = false;
                this.showToast('Success', result, 'success');
                return this.loadData();
            })
            .catch(error => {
                clearTimeout(timeoutId);
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Sync failed', 'error');
            });
    }

    // ============================================
    // REFRESH
    // ============================================
    
    handleRefresh() {
        this.loadData();
    }

    // ============================================
    // HELPER METHODS
    // ============================================
    
    getIconClass(leaveCode) {
        const code = (leaveCode || '').toUpperCase();
        switch(code) {
            case 'CL': return 'card-icon-wrapper casual-bg';
            case 'EL': return 'card-icon-wrapper earned-bg';
            case 'SL': return 'card-icon-wrapper sick-bg';
            case 'LWP': return 'card-icon-wrapper lwp-bg';
            case 'SAB': return 'card-icon-wrapper sabbatical-bg';
            default: return 'card-icon-wrapper default-bg';
        }
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        const day = String(date.getDate()).padStart(2, '0');
        const month = date.toLocaleString('default', { month: 'short' });
        const year = date.getFullYear();
        return `${day}-${month}-${year}`;
    }

    formatDateTime(dateTimeString) {
        if (!dateTimeString) return '';
        const date = new Date(dateTimeString);
        const day = String(date.getDate()).padStart(2, '0');
        const month = date.toLocaleString('default', { month: 'short' });
        const year = date.getFullYear();
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${day}-${month}-${year} ${hours}:${minutes}`;
    }

    getHolidayTypeClass(type) {
        switch(type) {
            case 'Public Holiday': return 'type-badge public';
            case 'Optional Holiday': return 'type-badge optional';
            case 'Festival': return 'type-badge festival';
            case 'Regional Holiday': return 'type-badge regional';
            default: return 'type-badge';
        }
    }
    
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