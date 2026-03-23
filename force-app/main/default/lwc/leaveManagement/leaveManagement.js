import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';
import LightningAlert from 'lightning/alert';


// Apex Imports
import getEmployeeLeaveBalances from '@salesforce/apex/EmployeeLeaveController.getEmployeeLeaveBalances';
import getUpcomingHolidays from '@salesforce/apex/EmployeeLeaveController.getUpcomingHolidays';
import getManagerInfo from '@salesforce/apex/LeaveRequestController.getManagerInfo';
import submitLeaveRequestApex from '@salesforce/apex/LeaveRequestController.submitLeaveRequest';
import getPastLeaveRequests from '@salesforce/apex/LeaveRequestController.getPastLeaveRequests';
import validateLeaveEligibility from '@salesforce/apex/LeaveRequestController.validateLeaveEligibility';
import canApplyForLeave from '@salesforce/apex/EmployeeLeaveController.canApplyForLeave';
import getLeaveBalanceSummary1 from '@salesforce/apex/EmployeeLeaveController.getLeaveBalanceSummary1';
import checkHolidayConflict from '@salesforce/apex/LeaveRequestController.checkHolidayConflict';
import checkOverlappingLeave from '@salesforce/apex/LeaveRequestController.checkOverlappingLeave';
import revokeLeaveRequest from '@salesforce/apex/LeaveRequestController.revokeLeaveRequest';


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
    @track totalAvailableLeave = 0;

    //checkingfor Holiday
    @track showHolidayWarning = false;
@track holidayWarningMessage = '';
@track conflictingHolidays = [];

@track publicHolidaysMap = new Map(); // Store holidays for quick lookup

// Overlapping leave validation
@track showOverlapWarning = false;
@track overlapWarningMessage = '';
@track conflictingLeaves = [];

@track showRevokeModal = false;
@track revokeReason = '';
@track revokingRequestId = '';
@track revokingRequestName = '';
@track isRevoking = false;
    

    
    // Half Day Type Options
    halfDayTypeOptions = [
        { label: 'First Half', value: 'First Half' },
        { label: 'Second Half', value: 'Second Half' }
    ];
//getting total available leaves --sri--
    connectedCallback() {
           this.loadAllData();
    this.loadTotalAvailableLeave();
     this.loadPublicHolidays(); // ADD THIS LINE
    }

    loadTotalAvailableLeave() {
    getLeaveBalanceSummary1({employeeId: this.employeeId,year: this.currentYear })
    .then(result => {
        console.log('Total Available Leave:', result.totalAvailable);
        this.totalAvailableLeave = result.totalAvailable || 0;
    })
    .catch(error => {
        console.error('Error loading total available leave', error);
        this.totalAvailableLeave = 0;
    });
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
                // Inside the result.map() in loadAllLeaveRequests, add this field:
                this.canRevokeRequest(request)
                console.log('All Leave Requests loaded:', this.allLeaveRequests.length);
            })
            .catch(error => {
                console.error('Error in loadAllLeaveRequests:', error);
                throw error;
            });
    } */

loadAllLeaveRequests() {
    return getPastLeaveRequests({ employeeId: this.employeeId })
        .then(result => {
            this.allLeaveRequests = result.map(request => {
                const leaveType = request.Leave_Type__r || {};
                const manager = request.Manager__r || {};
                const approvedBy = request.Approved_By__r || {};

                // ===== REVOKE ELIGIBILITY - computed inline =====
                let canRevoke = false;
                if (request.Status__c === 'Pending') {
                    const today = new Date();
                    today.setHours(0, 0, 0, 0);

                    const startDate = new Date(request.Start_Date__c);
                    startDate.setHours(0, 0, 0, 0);

                    if (today < startDate) {
                        // Future leave — always revocable
                        canRevoke = true;
                    } else if (today.getTime() === startDate.getTime()) {
                        // Today is the start date — only before 9 AM
                        const now = new Date();
                        const deadline = new Date();
                        deadline.setHours(9, 0, 0, 0);
                        canRevoke = now < deadline;
                    }
                    // today > startDate → canRevoke stays false
                }

                return {
                    ...request,
                    leaveTypeName: leaveType.Leave_Type_Name__c || 'Unknown',
                    leaveCode: leaveType.Leave_Code__c || 'N/A',
                    formattedStartDate: this.formatDate(request.Start_Date__c),
                    formattedEndDate: this.formatDate(request.End_Date__c),
                    formattedAppliedDate: this.formatDateTime(request.Applied_Date__c),
                    statusClass: this.getStatusClass(request.Status__c),
                    daysText: (request.Total_Days__c === 1) ? 'day' : 'days',
                    managerName: manager.Name || 'N/A',
                    managerComments: request.Manager_Comments__c || 'N/A',
                    actionedByName: this.getActionedByName(request),
                    canRevoke: canRevoke,  // ✅ correctly inside return object
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

    // Add this method in the connectedCallback or loadAllData section
/**
 * Load Public Holidays for the current year
 */
loadPublicHolidays() {
    getUpcomingHolidays()
        .then(result => {
            // Create a Map for quick holiday lookup by date
            this.publicHolidaysMap = new Map();
            result.forEach(holiday => {
                const dateKey = this.formatDateKey(holiday.Holiday_Date__c);
                this.publicHolidaysMap.set(dateKey, holiday.Name);
            });
            console.log('Public holidays loaded:', this.publicHolidaysMap.size);
        })
        .catch(error => {
            console.error('Error loading public holidays:', error);
        });
}

/**
 * Format date to YYYY-MM-DD for map key
 */
formatDateKey(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

/**
 * Check if a date is a public holiday
 */
isPublicHoliday(date) {
    const dateKey = this.formatDateKey(date.toISOString());
    return this.publicHolidaysMap.has(dateKey);
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

    // Add getter for displaying holiday list
    get hasConflictingHolidays() {
    return this.conflictingHolidays && this.conflictingHolidays.length > 0;
    }

        get hasConflictingLeaves() {
    return this.conflictingLeaves && this.conflictingLeaves.length > 0;
}
    // ==================== APPLY LEAVE MODAL METHODS ====================

    /**
 * NEW METHOD: Check for overlapping leave requests
 */
/* checkForOverlappingLeave() {
    // Only check if both dates are selected
    if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
        this.showOverlapWarning = false;
        this.conflictingLeaves = [];
        return;
    }
    
    // Call Apex to check for overlapping leaves
   checkOverlappingLeave({
        employeeId: this.employeeId,
        startDate: this.leaveRequest.Start_Date__c,
        endDate: this.leaveRequest.End_Date__c
    })
    .then(result => {
        if (result.hasOverlap) {
            this.showOverlapWarning = true;
            this.conflictingLeaves = result.conflictingLeaves;
            
            // Build warning message
            if (result.conflictCount === 1) {
                const leave = result.conflictingLeaves[0];
                this.overlapWarningMessage = 
                    `⚠️ You already have a ${leave.status} leave request (${leave.leaveRequestName}) for ${leave.startDate} to ${leave.endDate}. Please cancel it first or choose different dates.`;
            } else {
                this.overlapWarningMessage = 
                    `⚠️ You have ${result.conflictCount} existing leave requests that overlap with these dates. Please review and choose different dates.`;
            }
        } else {
            this.showOverlapWarning = false;
            this.conflictingLeaves = [];
            this.overlapWarningMessage = '';
        }
    })
    .catch(error => {
        console.error('Error checking overlapping leave:', error);
        this.showOverlapWarning = false;
        this.conflictingLeaves = [];
    });
}*/


/**
 * Check for ANY overlapping leave requests (blocks all overlaps regardless of leave type)
 */
async checkForOverlappingLeave() {
    // Only check if both dates are selected
    if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
        this.showOverlapWarning = false;
        this.conflictingLeaves = [];
        return;
    }
    
    try {
        const result = await checkOverlappingLeave({
            employeeId: this.employeeId,
            startDate: this.leaveRequest.Start_Date__c,
            endDate: this.leaveRequest.End_Date__c
        });
        
        if (result.hasOverlap) {
            this.showOverlapWarning = true;
            this.conflictingLeaves = result.conflictingLeaves;
            
            // Build detailed warning message
            if (result.conflictCount === 1) {
                const leave = result.conflictingLeaves[0];
                this.overlapWarningMessage = 
                    `⚠️ OVERLAP DETECTED: You already have a ${leave.status} ${leave.leaveType} (${leave.leaveCode}) request (${leave.leaveRequestName}) from ${leave.startDate} to ${leave.endDate} (${leave.totalDays} days). You cannot apply for any leave on dates that already have existing leave requests.`;
            } else {
                this.overlapWarningMessage = 
                    `⚠️ OVERLAP DETECTED: You have ${result.conflictCount} existing leave requests that overlap with these dates. You cannot apply for leave on dates that already have pending or approved leave requests.`;
            }
            
            console.log('⚠️ Overlap detected:', this.conflictingLeaves);
        } else {
            this.showOverlapWarning = false;
            this.conflictingLeaves = [];
            this.overlapWarningMessage = '';
        }
    } catch (error) {
        console.error('❌ Error checking overlapping leave:', error);
        this.showOverlapWarning = false;
        this.conflictingLeaves = [];
    }
}

    
    /**
     * Handle Apply Leave Button
     */
    handleApplyLeave() {
        if (!this.hasLeaveBalances) {
            //this.showToast('No Leave Types', 'You do not have any eligible leave types. Please contact HR.', 'warning');
            LightningAlert.open({
    message: 'You do not have any eligible leave types. Please contact HR.',
    theme: 'warning', // warning | error | success | info
    label: 'No Leave Types'
});

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
        this.checkForHolidayConflicts();
    this.checkForOverlappingLeave(); // ADD THIS LINE
    }

    /**
     * Handle End Date Change
     */
    handleEndDateChange(event) {
        this.leaveRequest.End_Date__c = event.target.value;
        this.calculateTotalDays();

        // Check for holiday conflicts
    this.checkForHolidayConflicts();
     this.checkForOverlappingLeave(); // ADD THIS LINE
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

    // Also update handleStartDateChange to check holidays
handleStartDateChange(event) {
    this.leaveRequest.Start_Date__c = event.target.value;
    
    // Ensure end date is not before start date
    if (this.leaveRequest.End_Date__c < this.leaveRequest.Start_Date__c) {
        this.leaveRequest.End_Date__c = this.leaveRequest.Start_Date__c;
    }
    
    this.calculateTotalDays();
    
    // Check for holiday conflicts
    this.checkForHolidayConflicts();
}

// NEW METHOD: Check for holiday conflicts
checkForHolidayConflicts() {
    // Only check if both dates are selected
    if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
        this.showHolidayWarning = false;
        this.conflictingHolidays = [];
        return;
    }
    
    // Call Apex to check for holidays
    checkHolidayConflict({
        startDate: this.leaveRequest.Start_Date__c,
        endDate: this.leaveRequest.End_Date__c
    })
    .then(result => {
        if (result.hasConflict) {
            this.showHolidayWarning = true;
            this.conflictingHolidays = result.conflictingHolidays;
            
            // Build warning message
            if (result.holidayCount === 1) {
                const holiday = result.conflictingHolidays[0];
                this.holidayWarningMessage = 
                    `⚠️ Your selected dates include a public holiday: ${holiday.name} on ${holiday.dayOfWeek}, ${holiday.date}. Please choose different dates.`;
            } else {
                this.holidayWarningMessage = 
                    `⚠️ Your selected dates include ${result.holidayCount} public holidays. Please review and choose different dates.`;
            }
        } else {
            this.showHolidayWarning = false;
            this.conflictingHolidays = [];
            this.holidayWarningMessage = '';
        }
    })
    .catch(error => {
        console.error('Error checking holidays:', error);
        this.showHolidayWarning = false;
        this.conflictingHolidays = [];
    });
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
        //if (this.leaveRequest.Is_Half_Day__c) {
            //this.calculatedDays = 0.5;
            //return;
        //}

        // Handle half-day leave
    if (this.leaveRequest.Is_Half_Day__c) {
        // Check if the half-day falls on weekend or holiday
        const dayOfWeek = startDate.getDay();
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        const isHoliday = this.isPublicHoliday(startDate);
        
        if (isWeekend || isHoliday) {
            this.calculatedDays = 0;
            this.showEligibilityMessage = true;
            this.eligibilityMessage = isWeekend 
                ? 'Half-day leave cannot be applied on weekends.'
                : 'Half-day leave cannot be applied on public holidays.';
            return;
        }
        
        this.calculatedDays = 0.5;
        this.showEligibilityMessage = false;
        return;
    }
        
        // Calculate working days excluding weekends
        this.calculatedDays = this.calculateWorkingDays(startDate, endDate);


         // Show message if no working days
    if (this.calculatedDays <= 0) {
        this.showEligibilityMessage = true;
        this.eligibilityMessage = 'Selected dates only contain weekends and/or public holidays. Please select working days.';
    } else {
        this.showEligibilityMessage = false;
        this.eligibilityMessage = '';
    }
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
        let excludedDays = [];
        
        // Loop through each day from start to end (inclusive)
        while (currentDate <= endDate) {
            const dayOfWeek = currentDate.getDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday

            // Check if it's a weekend
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        
        // Check if it's a public holiday
        const isHoliday = this.isPublicHoliday(currentDate);
            
            // Exclude Saturday (6) and Sunday (0)
           // if (dayOfWeek !== 0 && dayOfWeek !== 6) {
             //   workingDays++;
            //}

            // Only count if it's NOT a weekend AND NOT a public holiday
        if (!isWeekend && !isHoliday) {
            workingDays++;
        } else {
            // Track excluded days for logging
            if (isWeekend) {
                excludedDays.push(`${currentDate.toISOString().split('T')[0]} (Weekend)`);
            }
            if (isHoliday) {
                const holidayName = this.publicHolidaysMap.get(this.formatDateKey(currentDate.toISOString()));
                excludedDays.push(`${currentDate.toISOString().split('T')[0]} (${holidayName})`);
            }
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
    async submitLeaveRequest() {
        console.log(this.employeeId);
                console.log(this.leaveRequest.Leave_Type__c);
                console.log(this.calculatedDays); 
        // Validate
        if (!this.validateLeaveRequest()) {
            console.log('Inside If');
            return;
        }


    if (this.calculatedDays <= 0) {
    this.showEligibilityMessage = true;
    this.eligibilityMessage =
        'Saturday and Sunday are non-working days. Please select working days.';
    return;
}


        this.isSubmitting = true;
        
        // Server-side validation first
         try {
        // Server-side validation
        const validationResult = await validateLeaveEligibility({
            employeeId: this.employeeId,
            leaveTypeId: this.leaveRequest.Leave_Type__c,
            requestedDays: this.calculatedDays
        });
        
        if (!validationResult.isEligible) {
            await LightningAlert.open({
                message: validationResult.message,
                theme: 'error',
                label: 'Validation Error'
            });
            this.isSubmitting = false;
            return;
        }
        
        // Prepare request data
        const requestData = {
            ...this.leaveRequest,
            Employee__c: this.employeeId,
            Total_Days__c: this.calculatedDays
        };

        // Submit to server
        const result = await submitLeaveRequestApex({ leaveRequest: requestData });
        
        if (result) {
            await LightningAlert.open({
                message: 'Leave request submitted successfully! Your manager will be notified via email.',
                theme: 'success',
                label: '✅ Success'
            });
            
            this.closeApplyLeaveModal();
            this.loadAllData();
        }
        
    } catch (error) {
        console.error('❌ Error submitting leave request:', error);
        await LightningAlert.open({
            message: 'Failed to submit: ' + this.getErrorMessage(error),
            theme: 'error',
            label: 'Submission Error'
        });
    } finally {
        this.isSubmitting = false;
    }
    }

    /**
 * Validate Leave Request
 * UPDATED: Enhanced validation for working days
 */
validateLeaveRequest() {
    if (!this.leaveRequest.Leave_Type__c) {
        LightningAlert.open({
            message: 'Please select a leave type',
            theme: 'error',
            label: 'Validation Error'
        });
        return false;
    }

    if (!this.leaveRequest.Start_Date__c || !this.leaveRequest.End_Date__c) {
        LightningAlert.open({
            message: 'Please select start and end dates',
            theme: 'error',
            label: 'Validation Error'
        });
        return false;
    }

     // NEW: Check for overlapping leave requests
    if (this.showOverlapWarning) {
        LightningAlert.open({
            message: 'You already have leave request(s) for the selected dates. Please cancel existing requests first or choose different dates.',
            theme: 'Warning',
            label: 'Overlapping Leave Detected'
        });
        return false;
    }

    // NEW: Check if calculated days is 0 or negative
    if (this.calculatedDays <= 0) {
        LightningAlert.open({
            message: 'Selected dates only contain weekends and/or public holidays. Please select working days.',
            theme: 'error',
            label: 'Invalid Dates'
        });
        return false;
    }

    // Check for holiday conflicts (warning, not blocking anymore since we calculate working days)
    // This is just for information now
    if (this.showHolidayWarning) {
        console.log('Note: Selected period includes public holidays, but working days calculated accordingly');
    }

    if (this.leaveRequest.Is_Half_Day__c && !this.leaveRequest.Half_Day_Type__c) {
        LightningAlert.open({
            message: 'Please select half day type (First Half or Second Half)',
            theme: 'error',
            label: 'Validation Error'
        });
        return false;
    }

    if (!this.leaveRequest.Reason__c || this.leaveRequest.Reason__c.trim() === '') {
        LightningAlert.open({
            message: 'Please provide a reason for leave',
            theme: 'error',
            label: 'Validation Error'
        });
        return false;
    }

    if (!this.managerId) {
        LightningAlert.open({
            message: 'No manager assigned. Please contact HR.',
            theme: 'error',
            label: 'Validation Error'
        });
        return false;
    }

    return true;
}


// ==================== REVOKE LEAVE METHODS ====================

/**
 * Check if a leave request can be revoked (client-side fast check)
 */
canRevokeRequest(request) {
    if (request.Status__c !== 'Pending') {
        return false;
    }
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const startDate = new Date(request.Start_Date__c);
    startDate.setHours(0, 0, 0, 0);
    
    // Past start date — cannot revoke
    if (today > startDate) return false;
    
    // Today is the start date — check if before 9 AM
    if (today.getTime() === startDate.getTime()) {
        const now = new Date();
        const deadline = new Date();
        deadline.setHours(9, 0, 0, 0);
        if (now >= deadline) return false;
    }
    
    return true;
}

/**
 * Open revoke modal
 */
handleRevokeLeave(event) {
    const requestId = event.currentTarget.dataset.id;
    const requestName = event.currentTarget.dataset.name;
    this.revokingRequestId = requestId;
    this.revokingRequestName = requestName;
    this.revokeReason = '';
    this.showRevokeModal = true;
}

/**
 * Handle revoke reason input
 */
handleRevokeReasonChange(event) {
    this.revokeReason = event.target.value;
}

/**
 * Close revoke modal
 */
closeRevokeModal() {
    this.showRevokeModal = false;
    this.revokingRequestId = '';
    this.revokingRequestName = '';
    this.revokeReason = '';
}

/**
 * Confirm and submit revoke
 */
async confirmRevokeLeave() {
    if (!this.revokeReason || this.revokeReason.trim() === '') {
        await LightningAlert.open({
            message: 'Please provide a reason for revoking this leave.',
            theme: 'error',
            label: 'Reason Required'
        });
        return;
    }
    
    this.isRevoking = true;
    
    try {
        const result = await revokeLeaveRequest({
            leaveRequestId: this.revokingRequestId,
            revokeReason: this.revokeReason
        });
        
        if (result.success) {
            await LightningAlert.open({
                message: result.message,
                theme: 'success',
                label: '✅ Leave Revoked'
            });
            this.closeRevokeModal();
            this.loadAllData(); // Refresh balances and table
        } else {
            await LightningAlert.open({
                message: result.message,
                theme: 'error',
                label: 'Cannot Revoke'
            });
        }
    } catch (error) {
        await LightningAlert.open({
            message: 'Error: ' + this.getErrorMessage(error),
            theme: 'error',
            label: 'Revoke Failed'
        });
    } finally {
        this.isRevoking = false;
    }
}

    // ==================== UTILITY METHODS ====================
    
    /**
     * Handle Refresh
     */
    handleRefresh() {
        this.loadAllData();
        this.loadPublicHolidays(); // ADD THIS LINE
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