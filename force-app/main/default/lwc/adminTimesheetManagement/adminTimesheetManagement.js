import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardStats from '@salesforce/apex/TimesheetAdminController.getDashboardStats';
import getTimesheetEntries from '@salesforce/apex/TimesheetAdminController.getTimesheetEntries';
import searchFilterOptions from '@salesforce/apex/TimesheetAdminController.searchFilterOptions';
import getFilterOptions from '@salesforce/apex/TimesheetAdminController.getFilterOptions';

export default class AdminTimesheetManagement extends LightningElement {
    
    @track stats = {
        totalHours: 0,
        pendingApprovals: 0,
        approvedHours: 0,
        rejectedEntries: 0,
        totalEmployees: 0,
        activeProjects: 0
    };
    
@track employeeSearch = '';
@track departmentSearch = '';
@track projectSearch = '';

@track filteredEmployeeResults = [];
@track filteredDepartmentResults = [];
@track filteredProjectResults = [];

@track showEmployeeDropdown = false;
@track showDepartmentDropdown = false;
@track showProjectDropdown = false;

    @track filteredEntries = [];
    @track allEntries = [];
    @track paginatedEntries = [];
    @track employeeOptions = [];
    @track departmentOptions = [];
    @track projectOptions = [];
    @track statusOptions = [];
    
     debounceTimeout;
    selectedEmployee = '';
    selectedDepartment = '';
    selectedProject = '';
    selectedStatus = '';
    searchTerm = '';
  // Pagination properties
    pageSize = 5;
    currentPage = 1;
    totalPages = 1;
    pageNumbers = [];

    currentMonth = new Date().getMonth();
    currentYear = new Date().getFullYear();
    currentWeekStart = null;
    viewMode = 'monthly'; // 'monthly' or 'weekly'

    isLoading = false;
    selectedEntryId = '';
   
    wiredStatsResult;
    wiredEntriesResult;

    connectedCallback() {
        const today = new Date();
        this.currentWeekStart = this.getWeekStartDate(today);
        this.loadFilterOptions();
        this.loadData();
    }
    
    // Get Monday of the current week
    getWeekStartDate(date) {
        const d = new Date(date);
        const day = d.getDay();
        const diff = d.getDate() - day + (day === 0 ? -6 : 1);
        return new Date(d.setDate(diff));
    }

    // Get date range label based on view mode
    get dateRangeLabel() {
        if (this.viewMode === 'weekly') {
            const weekEnd = new Date(this.currentWeekStart);
            weekEnd.setDate(weekEnd.getDate() + 6);
            
            const startStr = this.formatShortDate(this.currentWeekStart);
            const endStr = this.formatShortDate(weekEnd);
            
            return `${startStr} - ${endStr}`;
        } else {
            const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                               'July', 'August', 'September', 'October', 'November', 'December'];
            return `${monthNames[this.currentMonth]} ${this.currentYear}`;
        }
    }

    get viewModeLabel() {
        return this.viewMode === 'weekly' ? 'Switch to Monthly' : 'Switch to Weekly';
    }

    get hasEntries() {
        return this.filteredEntries && this.filteredEntries.length > 0;
    }
get hasActiveFilters() {
        return this.selectedEmployee || this.selectedDepartment || this.selectedProject || this.selectedStatus;
    }
    get paginationLabel() {
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.filteredEntries.length);
        return `Showing ${start} to ${end} of ${this.filteredEntries.length} entries`;
    }

    get canPreviousPage() {
        return this.currentPage > 1;
    }

    get canNextPage() {
        return this.currentPage < this.totalPages;
    }
    formatShortDate(date) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return `${months[date.getMonth()]} ${date.getDate()}`;
    }

    formatFullDate(date) {
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                       'July', 'August', 'September', 'October', 'November', 'December'];
        return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
    }

    // Calculate start date based on view mode
    get startDate() {
        if (this.viewMode === 'weekly') {
            return this.formatDateForAPI(this.currentWeekStart);
        } else {
            const firstDay = new Date(this.currentYear, this.currentMonth, 1);
            return this.formatDateForAPI(firstDay);
        }
    }

    // Calculate end date based on view mode
    get endDate() {
        if (this.viewMode === 'weekly') {
            const weekEnd = new Date(this.currentWeekStart);
            weekEnd.setDate(weekEnd.getDate() + 6);
            return this.formatDateForAPI(weekEnd);
        } else {
            const lastDay = new Date(this.currentYear, this.currentMonth + 1, 0);
            return this.formatDateForAPI(lastDay);
        }
    }

    // Format date to YYYY-MM-DD for API calls
    formatDateForAPI(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    // Load filter options from server
    async loadFilterOptions() {
        try {
            const results = await Promise.all([
                getFilterOptions({ filterType: 'employees' }),
                getFilterOptions({ filterType: 'departments' }),
                getFilterOptions({ filterType: 'projects' }),
                getFilterOptions({ filterType: 'status' })
            ]);

            this.employeeOptions = [
                { label: 'All Employees', value: '' },
                ...results[0].map(e => ({ label: e, value: e }))
            ];
            this.departmentOptions = [
                { label: 'All Departments', value: '' },
                ...results[1].map(d => ({ label: d, value: d }))
            ];
            this.projectOptions = [
                { label: 'All Projects', value: '' },
                ...results[2].map(p => ({ label: p, value: p }))
            ];
            this.statusOptions = [
                { label: 'All Status', value: '' },
                ...results[3].map(s => ({ label: s, value: s }))
            ];
           
        

        } catch (error) {
            console.error('Error loading filter options:', error);
            this.showToast('Error', 'Failed to load filter options', 'error');
        }
    }

    // Load timesheet data
    async loadData() {
        this.isLoading = true;
        try {
            const [statsData, entriesData] = await Promise.all([
                getDashboardStats({ 
                    startDate: this.startDate, 
                    endDate: this.endDate 
                }),
                getTimesheetEntries({
                    startDate: this.startDate,
                    endDate: this.endDate,
                    employeeFilter: this.selectedEmployee,
                    departmentFilter: this.selectedDepartment,
                    projectFilter: this.selectedProject,
                    statusFilter: this.selectedStatus
                })
                
            ]);
            console.log('Stats received:', statsData);
            console.log('Entries received:', entriesData.length, 'entries');
            console.log('Entries data:', entriesData);

            this.stats = statsData;
            this.allEntries = entriesData.map(entry => ({
                ...entry,
                statusClass: this.getStatusClass(entry.status)
            }));
            this.applyFilters();
            this.currentPage = 1;
            this.updatePagination();

            if (this.filteredEntries.length === 0) {
                console.warn('No entries found after filtering');
            }
        } catch (error) {
            console.error('Error loading data:', error);
            this.showToast('Error', error.body?.message || 'Failed to load data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Apply local filters to entries
    applyFilters() {
        let filtered = [...this.allEntries];

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            filtered = filtered.filter(entry => 
                entry.employeeName?.toLowerCase().includes(term) ||
                entry.description?.toLowerCase().includes(term) ||
                entry.projectName?.toLowerCase().includes(term)
            );
        }

       console.log('Applied filters - Before:', this.allEntries.length, 'After:', filtered.length);
        this.filteredEntries = filtered;
        
    }
 // Update pagination
    updatePagination() {
        this.totalPages = Math.ceil(this.filteredEntries.length / this.pageSize) || 1;
        this.currentPage = Math.min(this.currentPage, this.totalPages);
        
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedEntries = this.filteredEntries.slice(start, end);
        
        this.generatePageNumbers();
    }

    // Generate page number array for display
    generatePageNumbers() {
        this.pageNumbers = [];
        const maxPagesToShow = 5;
        let startPage = 1;
        let endPage = this.totalPages;

        if (this.totalPages > maxPagesToShow) {
            startPage = Math.max(1, this.currentPage - Math.floor(maxPagesToShow / 2));
            endPage = Math.min(this.totalPages, startPage + maxPagesToShow - 1);

            if (endPage - startPage + 1 < maxPagesToShow) {
                startPage = Math.max(1, endPage - maxPagesToShow + 1);
            }
        }

       for (let i = startPage; i <= endPage; i++) {
            this.pageNumbers.push({
                number: i,
                isActive: i === this.currentPage
            });
        }
    }

    // Get CSS class for status badge
    getStatusClass(status) {
        const classes = {
            'Pending': 'status-pending',
            'Approved': 'status-approved',
            'Rejected': 'status-rejected'
        };
        return classes[status] || 'status-pending';
    }

    // Navigation handlers
    handlePreviousMonth() {
        if (this.viewMode === 'weekly') {
            this.currentWeekStart = new Date(this.currentWeekStart);
            this.currentWeekStart.setDate(this.currentWeekStart.getDate() - 7);
        } else {
            if (this.currentMonth === 0) {
                this.currentMonth = 11;
                this.currentYear--;
            } else {
                this.currentMonth--;
            }
        }
        this.loadData();
    }

    handleNextMonth() {
        if (this.viewMode === 'weekly') {
            this.currentWeekStart = new Date(this.currentWeekStart);
            this.currentWeekStart.setDate(this.currentWeekStart.getDate() + 7);
        } else {
            if (this.currentMonth === 11) {
                this.currentMonth = 0;
                this.currentYear++;
            } else {
                this.currentMonth++;
            }
        }
        this.loadData();
    }

    // Toggle between weekly and monthly view
    handleMonthViewToggle() {
        if (this.viewMode === 'monthly') {
            this.viewMode = 'weekly';
            const today = new Date();
            this.currentWeekStart = this.getWeekStartDate(today);
        } else {
            this.viewMode = 'monthly';
            const today = new Date();
            this.currentMonth = today.getMonth();
            this.currentYear = today.getFullYear();
        }
        this.loadData();
    }

   // Filter handlers - these now trigger data load immediately
    handleEmployeeChange(event) {
        this.selectedEmployee = event.detail.value || '';
        console.log('Employee selected:', this.selectedEmployee);
        this.loadData();
    }

    handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value || '';
        console.log('Department selected:', this.selectedDepartment);
        this.loadData();
    }

    handleProjectChange(event) {
        this.selectedProject = event.detail.value || '';
                console.log('Project selected:', this.selectedProject);
                this.loadData();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value || '';
        console.log('Status selected:', this.selectedStatus);
        this.loadData();
    }

    /*handleApplyFilters() {
        this.loadData();
    }*/
handleApplyFilters() {
       // Convert 'All' values to empty string for proper filtering
       this.selectedEmployee = this.selectedEmployee === 'All Employees' ? '' : this.selectedEmployee;
       this.selectedDepartment = this.selectedDepartment === 'All Departments' ? '' : this.selectedDepartment;
       this.selectedProject = this.selectedProject === 'All Projects' ? '' : this.selectedProject;
       this.selectedStatus = this.selectedStatus === 'All Status' ? '' : this.selectedStatus;
       this.loadData();
   }
    handleClearFilters() {
        this.selectedEmployee = '';
        this.selectedDepartment = '';
        this.selectedProject = '';
        this.selectedStatus = '';
        this.searchTerm = '';
        this.loadData();
    }
// Individual pill clear handlers
    handleClearEmployee() {
        this.selectedEmployee = '';
        this.loadData();
    }

    handleClearDepartment() {
        this.selectedDepartment = '';
        this.loadData();
    }

    handleClearProject() {
        this.selectedProject = '';
        this.loadData();
    }

    handleClearStatus() {
        this.selectedStatus = '';
        this.loadData();
    }
    
// Pagination handlers
    handleFirstPage() {
        this.currentPage = 1;
        this.updatePagination();
    }

    handlePreviousPage() {
        if (this.canPreviousPage) {
            this.currentPage--;
            this.updatePagination();
        }
    }

    handlePageSelect(event) {
        this.currentPage = parseInt(event.currentTarget.dataset.page, 10);
        this.updatePagination();
    }

    handleNextPage() {
        if (this.canNextPage) {
            this.currentPage++;
            this.updatePagination();
        }
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updatePagination();
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
        this.updatePagination();
    }


    // Export CSV
    handleExportCSV() {
        try {
            if (!this.filteredEntries || this.filteredEntries.length === 0) {
                this.showToast('Warning', 'No data to export', 'warning');
                return;
            }

            let csv = 'Employee,Department,Project,Date,Description,Hours,Status\n';
            
            this.filteredEntries.forEach(entry => {
                const employee = entry.employeeName || '';
                const department = entry.department || '';
                const project = entry.projectName || '';
                const date = entry.entryDate || '';
                const description = (entry.description || '').replace(/"/g, '""');
                const hours = entry.hours || 0;               
                const status = entry.status || '';
                
                csv += `"${employee}","${department}","${project}","${date}","${description}","${hours}","${status}"\n`;
            });

            
 // Use data URI instead of blob for Lightning Web Security compatibility
            const encodedUri = encodeURI('data:text/csv;charset=utf-8,' + csv);
            const link = document.createElement('a');
            link.setAttribute('href', encodedUri);
            link.setAttribute('download', `timesheet_export_${this.startDate}_to_${this.endDate}.csv`);
            link.style.visibility = 'hidden';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            this.showToast('Success', 'CSV exported successfully', 'success');
        } catch (error) {
            console.error('Export error:', error);
            this.showToast('Error', 'Failed to export CSV: ' + error.message, 'error');
        }
    }

    // Toast notification
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    /* ---------------- EMPLOYEE AUTOCOMPLETE ---------------- */
handleEmployeeSearchChange(event) {
    const search = event.target.value;
    this.employeeSearch = search;
   clearTimeout(this.debounceTimeout);
    this.debounceTimeout = setTimeout(() => {
        if (search && search.length > 1) {
            this.fetchFilterResults('employees', search, 'employee');
        } else {
            this.filteredEmployeeResults = [];
            this.showEmployeeDropdown = false;
        }
    }, 300);
}

handleEmployeeSelect(event) {
    const value = event.currentTarget.dataset.value;
    this.selectedEmployee = value;
    this.employeeSearch = value;
    this.showEmployeeDropdown = false;
    this.loadData();
}

/* ---------------- DEPARTMENT AUTOCOMPLETE ---------------- */
handleDepartmentSearchChange(event) {
    const search = event.target.value;
    this.departmentSearch = search;
    clearTimeout(this.debounceTimeout);
    this.debounceTimeout = setTimeout(() => {
        if (search && search.length > 1) {
            this.fetchFilterResults('departments', search, 'department');
        } else {
            this.filteredDepartmentResults = [];
            this.showDepartmentDropdown = false;
        }
    }, 300);
}

handleDepartmentSelect(event) {
    const value = event.currentTarget.dataset.value;
    this.selectedDepartment = value;
    this.departmentSearch = value;
    this.showDepartmentDropdown = false;
    this.loadData();
}

/* ---------------- PROJECT AUTOCOMPLETE ---------------- */
handleProjectSearchChange(event) {
    const search = event.target.value;
    this.projectSearch = search;
    clearTimeout(this.debounceTimeout);
    this.debounceTimeout = setTimeout(() => {
        if (search && search.length > 1) {
            this.fetchFilterResults('projects', search, 'project');
        } else {
            this.filteredProjectResults = [];
            this.showProjectDropdown = false;
        }
    }, 300);
}

handleProjectSelect(event) {
    const value = event.currentTarget.dataset.value;
    this.selectedProject = value;
    this.projectSearch = value;
    this.showProjectDropdown = false;
    this.loadData();
}

/* ---------------- SHARED FETCH LOGIC ---------------- */
async fetchFilterResults(type, term, context) {
    try {
        const results = await searchFilterOptions({ filterType: type, searchTerm: term });
        const mapped = results.map(r => ({ label: r, value: r }));
        if (context === 'employee') {
            this.filteredEmployeeResults = mapped;
            this.showEmployeeDropdown = mapped.length > 0;
        } else if (context === 'department') {
            this.filteredDepartmentResults = mapped;
            this.showDepartmentDropdown = mapped.length > 0;
        } else if (context === 'project') {
            this.filteredProjectResults = mapped;
            this.showProjectDropdown = mapped.length > 0;
        }
    } catch (error) {
        console.error('Filter search error', error);
    }
}
}