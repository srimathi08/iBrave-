import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';

// Apex Imports
import getEmployeeLeaveBalances from '@salesforce/apex/EmployeeLeaveController.getEmployeeLeaveBalances';
import getUpcomingHolidays from '@salesforce/apex/EmployeeLeaveController.getUpcomingHolidays';
import getManagerInfo from '@salesforce/apex/LeaveRequestController.getManagerInfo';
import submitLeaveRequestApex from '@salesforce/apex/LeaveRequestController.submitLeaveRequest';
import getPastLeaveRequests from '@salesforce/apex/LeaveRequestController.getPastLeaveRequests';
import validateLeaveEligibility from '@salesforce/apex/LeaveRequestController.validateLeaveEligibility';
import canApplyForLeave from '@salesforce/apex/EmployeeLeaveController.canApplyForLeave';

export default class LeaveManagement extends LightningElement {
    // User Info
    employeeId = Id;
    currentYear = new Date().getFullYear().toString();
    
    // Data
    @track employeeLeaveBalances = [];
    @track upcomingHolidays = [];
    @track allLeaveRequests = [];
    @track filteredRequests = [];
    @track isLoading = false;

    // Filtering
    @track currentFilter = 'all';
    
    // Apply Leave Modal
    @track showApplyLeaveModal = false;
    @track leaveRequest = {};
    @track selectedLeaveBalance = null;
    @track calculatedDays = 0;
    @track isSubmitting = false;
    @track managerName = '';
    @track managerId = '';
    
    // Eligibility message
    @track showEligibilityMessage = false;
    @track eligibilityMessage = '';
    
    // Half Day Type Options
    halfDayTypeOptions = [
        { label: 'First Half', value: 'First Half' },
        { label: 'Second Half', value: 'Second Half' }
    ];

    connectedCallback() {
        this.loadAllData();
    }

    // ==================== DATA LOADING METHODS ====================
    
    /**
     * Load all data on component initialization
     */
    loadAllData() {
        this.isLoading = true;
        Promise.all([
            this.loadLeaveBalances(),
            this.loadUpcomingHolidays(),
            this.loadAllLeaveRequests()
        ])
        .then(() => {
            this.isLoading = false;
        })
        .catch(error => {
            this.isLoading = false;
            console.error('Error in loadAllData:', error);
            this.showToast('Error', 'Failed to load data: ' + this.getErrorMessage(error), 'error');
        });
    }

    /**
     * Load Leave Balances - Only eligible ones
     */
    loadLeaveBalances() {
        return getEmployeeLeaveBalances({ 
            employeeId: this.employeeId, 
            year: this.currentYear 
        })
        .then(result => {
            this.employeeLeaveBalances = result.map(balance => {
                // Null safety checks
                const leaveType = balance.Leave_Type__r || {};
                
                return {
                    ...balance,
                    leaveTypeName: leaveType.Leave_Type_Name__c || 'Unknown',
                    leaveCode: leaveType.Leave_Code__c || 'N/A',
                    iconName: leaveType.Icon_Name__c || 'utility:event',
                    hasCarryForward: (balance.Carried_Forward__c || 0) > 0,
                    Total_Allocated__c: balance.Total_Allocated__c || 0,
                    Available__c: balance.Available__c || 0,
                    Used__c: balance.Used__c || 0,
                    Booked__c: balance.Booked__c || 0,
                    Pending_Approval__c: balance.Pending_Approval__c || 0,
                    Carried_Forward__c: balance.Carried_Forward__c || 0
                };
            });
            console.log('Leave Balances loaded:', this.employeeLeaveBalances.length);
        })
        .catch(error => {
            console.error('Error in loadLeaveBalances:', error);
            throw error;
        });
    }

    /**
     * Load Upcoming Holidays
     */
    loadUpcomingHolidays() {
        return getUpcomingHolidays()
            .then(result => {
                this.upcomingHolidays = result.map(holiday => ({
                    ...holiday,
                    formattedDate: this.formatDate(holiday.Holiday_Date__c),
                    Icon_Name__c: holiday.Icon_Name__c || 'utility:event'
                }));
                console.log('Holidays loaded:', this.upcomingHolidays.length);
            })
            .catch(error => {
                console.error('Error in loadUpcomingHolidays:', error);
                throw error;
            });
    }

    /**
     * Load All Leave Requests
     */
    loadAllLeaveRequests() {
        return getPastLeaveRequests({ employeeId: this.employeeId })
            .then(result => {
                this.allLeaveRequests = result.map(request => {
                    // Null safety for all fields
                    const leaveType = request.Leave_Type__r || {};
                    const manager = request.Manager__r || {};
                    const approvedBy = request.Approved_By__r || {};
                    
                    return {
                        ...request,
                        // Leave Type fields with null checks
                        leaveTypeName: leaveType.Leave_Type_Name__c || 'Unknown',
                        leaveCode: leaveType.Leave_Code__c || 'N/A',
                        
                        // Dates with null checks
                        formattedStartDate: this.formatDate(request.Start_Date__c),
                        formattedEndDate: this.formatDate(request.End_Date__c),
                        formattedAppliedDate: this.formatDateTime(request.Applied_Date__c),
                        
                        // Status and styling
                        statusClass: this.getStatusClass(request.Status__c),
                        daysText: (request.Total_Days__c === 1) ? 'day' : 'days',
                        
                        // Manager fields
                        managerName: manager.Name || 'N/A',
                        managerComments: request.Manager_Comments__c || 'N/A',
                        
                        // Actioned by
                        actionedByName: this.getActionedByName(request),
                        
                        // For table display - create nested object for compatibility
                        Leave_Type__r: {
                            Leave_Type_Name__c: leaveType.Leave_Type_Name__c || 'Unknown',
                            Leave_Code__c: leaveType.Leave_Code__c || 'N/A'
                        },
                        Manager__r: {
                            Name: manager.Name || 'N/A'
                        }
                    };
                });
                this.applyFilter();
                console.log('All Leave Requests loaded:', this.allLeaveRequests.length);
            })
            .catch(error => {
                console.error('Error in loadAllLeaveRequests:', error);
                throw error;
            });
    }

    // ==================== FILTER METHODS ====================
    
    /**
     * Apply filter based on current selection
     */
    applyFilter() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        
        switch(this.currentFilter) {
            case 'pending':
                this.filteredRequests = this.allLeaveRequests.filter(req => req.Status__c === 'Pending');
                break;
            case 'approved':
                this.filteredRequests = this.allLeaveRequests.filter(req => req.Status__c === 'Approved');
                break;
            case 'past':
                this.filteredRequests = this.allLeaveRequests.filter(req => {
                    if (!req.End_Date__c) return false;
                    const endDate = new Date(req.End_Date__c);
                    return endDate < today;
                });
                break;
            case 'all':
            default:
                this.filteredRequests = [...this.allLeaveRequests];
                break;
        }
    }

    /**
     * Filter handlers
     */
    handleFilterAll() {
        this.currentFilter = 'all';
        this.applyFilter();
    }

    handleFilterPending() {
        this.currentFilter = 'pending';
        this.applyFilter();
    }

    handleFilterApproved() {
        this.currentFilter = 'approved';
        this.applyFilter();
    }

    handleFilterPast() {
        this.currentFilter = 'past';
        this.applyFilter();
    }

    // ==================== HELPER METHODS ====================
    
    /**
     * Get Actioned By Name
     */
    getActionedByName(request) {
        if (request.Status__c === 'Approved' || request.Status__c === 'Rejected') {
            if (request.Approved_By__r && request.Approved_By__r.Name) {
                return request.Approved_By__r.Name;
            }
        }
        return 'N/A';
    }

    /**
     * Get Status Class for Badge
     */
    getStatusClass(status) {
        if (!status) return 'status-badge';
        
        switch(status) {
            case 'Approved': return 'status-badge approved';
            case 'Rejected': return 'status-badge rejected';
            case 'Pending': return 'status-badge pending';
            case 'Cancelled': return 'status-badge cancelled';
            case 'Completed': return 'status-badge completed';
            default: return 'status-badge';
        }
    }

    // ==================== COMPUTED PROPERTIES ====================
    
    get hasLeaveBalances() {
        return this.employeeLeaveBalances && this.employeeLeaveBalances.length > 0;
    }

    get hasUpcomingHolidays() {
        return this.upcomingHolidays && this.upcomingHolidays.length > 0;
    }

    get hasFilteredRequests() {
        return this.filteredRequests && this.filteredRequests.length > 0;
    }

    get leaveTypeOptions() {
        if (!this.employeeLeaveBalances || this.employeeLeaveBalances.length === 0) {
            return [];
        }
        
        return this.employeeLeaveBalances.map(balance => ({
            label: `${balance.leaveTypeName} (Available: ${balance.Available__c} days)`,
            value: balance.Leave_Type__c
        }));
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    get upcomingHolidaysCount() {
        return this.upcomingHolidays ? this.upcomingHolidays.length : 0;
    }

    get filteredRequestsCount() {
        return this.filteredRequests ? this.filteredRequests.length : 0;
    }

    get showHolidayScrollIndicator() {
        return this.upcomingHolidays && this.upcomingHolidays.length > 5;
    }

    get showRequestScrollIndicator() {
        return this.filteredRequests && this.filteredRequests.length > 10;
    }

    // Computed properties for button variants
    get allFilterVariant() {
        return this.currentFilter === 'all' ? 'brand' : 'neutral';
    }

    get pendingFilterVariant() {
        return this.currentFilter === 'pending' ? 'brand' : 'neutral';
    }

    get approvedFilterVariant() {
        return this.currentFilter === 'approved' ? 'brand' : 'neutral';
    }

    get pastFilterVariant() {
        return this.currentFilter === 'past' ? 'brand' : 'neutral';
    }

    // ==================== APPLY LEAVE MODAL METHODS ====================
    
    /**
     * Handle Apply Leave Button
     */
    handleApplyLeave() {
        if (!this.hasLeaveBalances) {
            this.showToast('No Leave Types', 'You do not have any eligible leave types. Please contact HR.', 'warning');
            return;
        }
        
        this.loadManagerInfo();
        this.initializeLeaveRequest();
        this.showApplyLeaveModal = true;
    }

    /**
     * Load Manager Information
     */
    loadManagerInfo() {
        getManagerInfo({ employeeId: this.employeeId })
            .then(result => {
                this.managerId = result.managerId || '';
                this.managerName = result.managerName || 'No manager assigned';
            })
            .catch(error => {
                console.error('Error loading manager:', error);
                this.managerName = 'No manager assigned';
            });
    }

    /**
     * Initialize Leave Request
     */
    initializeLeaveRequest() {
        const today = new Date().toISOString().split('T')[0];
        this.leaveRequest = {
            Leave_Type__c: '',
            Start_Date__c: today,
            End_Date__c: today,
            Is_Half_Day__c: false,
            Half_Day_Type__c: '',
            Reason__c: ''
        };
        this.selectedLeaveBalance = null;
        this.calculatedDays = 0;
        this.showEligibilityMessage = false;
        this.eligibilityMessage = '';
    }

    /**
     * Close Apply Leave Modal
     */
    closeApplyLeaveModal() {
        this.showApplyLeaveModal = false;
        this.leaveRequest = {};
        this.selectedLeaveBalance = null;
        this.calculatedDays = 0;
        this.managerName = '';
        this.managerId = '';
        this.showEligibilityMessage = false;
        this.eligibilityMessage = '';
    }

    // ==================== FORM FIELD HANDLERS ====================
    
    /**
     * Handle Leave Type Change
     */
    handleLeaveTypeChange(event) {
        this.leaveRequest.Leave_Type__c = event.detail.value;
        
        // Find and display available balance
        this.selectedLeaveBalance = this.employeeLeaveBalances.find(
            bal => bal.Leave_Type__c === event.detail.value
        );
        
        // Check eligibility using Apex
        if (this.selectedLeaveBalance) {
            this.checkLeaveEligibility();
        }
        
        this.calculateTotalDays();
    }

    /**
     * Check eligibility for selected leave type
     */
    checkLeaveEligibility() {
        canApplyForLeave({
            employeeId: this.employeeId,
            leaveTypeId: this.leaveRequest.Leave_Type__c,
            year: this.currentYear
        })
        .then(result => {
            if (!result.canApply) {
                this.showEligibilityMessage = true;
                this.eligibilityMessage = result.message;
            } else {
                this.showEligibilityMessage = false;
                this.eligibilityMessage = '';
            }
        })
        .catch(error => {
            console.error('Error checking eligibility:', error);
            this.showEligibilityMessage = true;
            this.eligibilityMessage = 'Unable to verify eligibility. Please try again.';
        });
    }

    /**
     * Handle Start Date Change
     */
    handleStartDateChange(event) {
        this.leaveRequest.Start_Date__c = event.target.value;
        
        // Ensure end date is not before start date
        if (this.leaveRequest.End_Date__c < this.leaveRequest.Start_Date__c) {
            this.leaveRequest.End_Date__c = this.leaveRequest.Start_Date__c;
        }
        
        this.calculateTotalDays();
    }

    /**
     * Handle End Date Change
     */
    handleEndDateChange(event) {
        this.leaveRequest.End_Date__c = event.target.value;
        this.calculateTotalDays();
    }

    /**
     * Handle Half Day Change
     */
    handleHalfDayChange(event) {
        this.leaveRequest.Is_Half_Day__c = event.target.checked;
        
        // Reset half day type if unchecked
        if (!event.target.checked) {
            this.leaveRequest.Half_Day_Type__c = '';
        }
        
        this.calculateTotalDays();
    }

    /**
     * Handle Half Day Type Change
     */
    handleHalfDayTypeChange(event) {
        this.leaveRequest.Half_Day_Type__c = event.detail.value;
    }

    /**
     * Handle Reason Change
     */
    handleReasonChange(event) {
        this.leaveRequest.Reason__c = event.target.value;
    }

    /**
     * Calculate Total Days - EXCLUDING WEEKENDS (Saturday & Sunday)
     * MODIFIED: Now excludes weekends from calculation
     */
    calculateTotalDays() {
        if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
            this.calculatedDays = 0;
            return;
        }

        const startDate = new Date(this.leaveRequest.Start_Date__c);
        const endDate = new Date(this.leaveRequest.End_Date__c);
        
        // Handle half-day leave
        if (this.leaveRequest.Is_Half_Day__c) {
            this.calculatedDays = 0.5;
            return;
        }
        
        // Calculate working days excluding weekends
        this.calculatedDays = this.calculateWorkingDays(startDate, endDate);
    }

    /**
     * Calculate Working Days excluding weekends (Saturday & Sunday)
     * NEW METHOD: Excludes Saturday (6) and Sunday (0)
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @returns {Number} - Number of working days
     */
    calculateWorkingDays(startDate, endDate) {
        let workingDays = 0;
        let currentDate = new Date(startDate);
        
        // Loop through each day from start to end (inclusive)
        while (currentDate <= endDate) {
            const dayOfWeek = currentDate.getDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
            
            // Exclude Saturday (6) and Sunday (0)
            if (dayOfWeek !== 0 && dayOfWeek !== 6) {
                workingDays++;
            }
            
            // Move to next day
            currentDate.setDate(currentDate.getDate() + 1);
        }
        
        console.log(`Working days between ${startDate.toISOString().split('T')[0]} and ${endDate.toISOString().split('T')[0]}: ${workingDays} days`);
        return workingDays;
    }

    // ==================== SUBMIT LEAVE REQUEST ====================
    
    /**
     * Submit Leave Request
     */
    submitLeaveRequest() {
        console.log(this.employeeId);
                console.log(this.leaveRequest.Leave_Type__c);
                console.log(this.calculatedDays); 
        // Validate
        if (!this.validateLeaveRequest()) {
            console.log('Inside If');
            return;
        }

        

        this.isSubmitting = true;
        
        // Server-side validation first
        validateLeaveEligibility({
            employeeId: this.employeeId,
            leaveTypeId: this.leaveRequest.Leave_Type__c,
            requestedDays: this.calculatedDays
            
        })
        .then(validationResult => {
            if (!validationResult.isEligible) {
                this.showToast('Validation Error', validationResult.message, 'error');
                this.isSubmitting = false;
                return Promise.reject('Validation failed');
                  
            }
            
            // Prepare data
            const requestData = {
                ...this.leaveRequest,
                Employee__c: this.employeeId,
                Total_Days__c: this.calculatedDays
            };

            return submitLeaveRequestApex({ leaveRequest: requestData });
        })
        .then(result => {
            if (result) {
                this.showToast('Success', 'Leave request submitted successfully! Your manager will be notified via email.', 'success');
                this.closeApplyLeaveModal();
                this.loadAllData();
            }
        })
        .catch(error => {
            if (error !== 'Validation failed') {
                console.error('Error in submitLeaveRequest:', error);
                this.showToast('Error', 'Failed to submit: ' + this.getErrorMessage(error), 'error');
            }
        })
        .finally(() => {
            this.isSubmitting = false;
        });
    }

    /**
     * Validate Leave Request
     */
    validateLeaveRequest() {
        if (!this.leaveRequest.Leave_Type__c) {
            this.showToast('Validation Error', 'Please select a leave type', 'error');
            return false;
        }

        if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
            this.showToast('Validation Error', 'Please select start and end dates', 'error');
            return false;
        }

        if (this.leaveRequest.Is_Half_Day__c && !this.leaveRequest.Half_Day_Type__c) {
            this.showToast('Validation Error', 'Please select half day type (First Half or Second Half)', 'error');
            return false;
        }

        if (!this.leaveRequest.Reason__c || this.leaveRequest.Reason__c.trim() === '') {
            this.showToast('Validation Error', 'Please provide a reason for leave', 'error');
            return false;
        }

        if (!this.managerId) {
            this.showToast('Validation Error', 'No manager assigned. Please contact HR.', 'error');
            return false;
        }

        return true;
    }

    // ==================== UTILITY METHODS ====================
    
    /**
     * Handle Refresh
     */
    handleRefresh() {
        this.loadAllData();
    }

    /**
     * Format Date (DD-MMM-YYYY)
     */
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        try {
            const date = new Date(dateString);
            if (isNaN(date.getTime())) return 'Invalid Date';
            
            const day = String(date.getDate()).padStart(2, '0');
            const month = date.toLocaleString('default', { month: 'short' });
            const year = date.getFullYear();
            return `${day}-${month}-${year}`;
        } catch (e) {
            return 'N/A';
        }
    }

    /**
     * Format DateTime
     */
    formatDateTime(dateTimeString) {
        if (!dateTimeString) return 'N/A';
        try {
            const date = new Date(dateTimeString);
            if (isNaN(date.getTime())) return 'Invalid Date';
            
            const day = String(date.getDate()).padStart(2, '0');
            const month = date.toLocaleString('default', { month: 'short' });
            const year = date.getFullYear();
            return `${day}-${month}-${year}`;
        } catch (e) {
            return 'N/A';
        }
    }

    /**
     * Get Error Message
     */
    getErrorMessage(error) {
        if (!error) return 'Unknown error occurred';
        
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
            if (error.body.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors);
                if (fieldErrors.length > 0 && fieldErrors[0].length > 0) {
                    return fieldErrors[0][0].message;
                }
            }
        }
        
        if (typeof error === 'string') {
            return error;
        }
        
        return error.message || 'Unknown error occurred';
    }

    /**
     * Show Toast
     */
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