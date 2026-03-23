import { LightningElement, track } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import LightningAlert from 'lightning/alert';

import submitHybridScheduleRequest from
    '@salesforce/apex/HybridWorkScheduleController.submitHybridScheduleRequest';
import getEmployeeSchedules from
    '@salesforce/apex/HybridWorkScheduleController.getEmployeeSchedules';

export default class HybridScheduleRequest extends LightningElement {

    employeeId = USER_ID;

    @track showForm = false;
    @track isLoading = false;

    @track selectedMonth = '';
    @track scheduleType = 'Fixed Days';
    @track reason = '';

    @track daysOfWeek = [
        { label: 'Monday', value: 'Monday', isWFH: false, isOffice: false },
        { label: 'Tuesday', value: 'Tuesday', isWFH: false, isOffice: false },
        { label: 'Wednesday', value: 'Wednesday', isWFH: false, isOffice: false },
        { label: 'Thursday', value: 'Thursday', isWFH: false, isOffice: false },
        { label: 'Friday', value: 'Friday', isWFH: false, isOffice: false }
    ];

    @track hasValidationError = false;
    @track validationErrorMessage = '';
    @track existingSchedules = [];

    @track selectedMonth = '';
@track scheduleType = 'Fixed Days';
@track reason = '';

@track selectedMonth = '';
@track selectedWeek = '';
@track weekStartDate = '';
@track scheduleType = 'Fixed Days';
@track reason = '';

    connectedCallback() {
        this.loadExistingSchedules();
    }

    /* ======================
        GETTERS
    ======================= */

    get minMonth() {
        const d = new Date();
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    }

    get scheduleTypeOptions() {
        return [
            { label: 'Fixed Days', value: 'Fixed Days' },
            { label: 'Flexible', value: 'Flexible' },
            { label: 'Custom Pattern', value: 'Custom Pattern' }
        ];
    }

    get selectedWFHDaysText() {
        return this.getSelectedWFHDays().join(', ') || 'None';
    }

    get selectedOfficeDaysText() {
        return this.getSelectedOfficeDays().join(', ') || 'None';
    }

    get reasonCharCount() {
        return this.reason.length;
    }

    get isSubmitDisabled() {
        const totalSelectedDays = this.getSelectedWFHDays().length + this.getSelectedOfficeDays().length;
        
       return !this.selectedWeek ||        // ← was !this.selectedMonth
           !this.weekStartDate ||       // ← extra safety check
               !this.reason ||
               this.reason.length < 20 ||
               totalSelectedDays !== 5 || // ✅ Must select exactly 5 days
               this.isLoading;
    }

    get hasExistingSchedules() {
        return this.existingSchedules.length > 0;
    }

    /* ======================
        HANDLERS
    ======================= */

    handleNewRequest() {
        this.resetForm();
        this.showForm = true;
    }

    handleCancel() {
        this.showForm = false;
        this.resetForm();
    }

    handleMonthChange(e) {
        this.selectedMonth = e.target.value;
    }

    handleScheduleTypeChange(e) {
        this.scheduleType = e.detail.value;
    }

    handleWFHDayChange(e) {
        const day = e.target.dataset.day;
        const checked = e.target.checked;
        
        console.log('WFH Day Change:', day, 'Checked:', checked);
        
        // Find the current state of this day
        const dayConfig = this.daysOfWeek.find(d => d.value === day);
        console.log('Current Day Config:', dayConfig);
        
        // If trying to check and it's already in Office, prevent it
        if (checked && dayConfig.isOffice) {
            console.log('⚠️ Conflict detected - Day already in Office');
            this.hasValidationError = true;
            this.validationErrorMessage = `⚠️ CONFLICT: ${day} is already selected as an Office day. Please deselect it from Office Days first.`;
            
            // Show alert
            LightningAlert.open({
                message: `${day} is already selected for Office Days. A day cannot be both Work From Home and Office day simultaneously. Please deselect it from Office Days first.`,
                theme: 'error',
                label: '⚠️ Conflict Detected'
            });
            
            return; // Don't update state
        }
        
        // Update WFH selection
        this.daysOfWeek = this.daysOfWeek.map(d =>
            d.value === day ? { ...d, isWFH: checked } : d
        );
        
        console.log('Updated daysOfWeek:', JSON.parse(JSON.stringify(this.daysOfWeek)));
        
        this.validateDaySelection();
    }

    handleOfficeDayChange(e) {
        const day = e.target.dataset.day;
        const checked = e.target.checked;
        
        console.log('Office Day Change:', day, 'Checked:', checked);
        
        // Find the current state of this day
        const dayConfig = this.daysOfWeek.find(d => d.value === day);
        console.log('Current Day Config:', dayConfig);
        
        // If trying to check and it's already in WFH, prevent it
        if (checked && dayConfig.isWFH) {
            console.log('⚠️ Conflict detected - Day already in WFH');
            this.hasValidationError = true;
            this.validationErrorMessage = `⚠️ CONFLICT: ${day} is already selected as a Work From Home day. Please deselect it from WFH Days first.`;
            
            // Show alert
            LightningAlert.open({
                message: `${day} is already selected for Work From Home Days. A day cannot be both Work From Home and Office day simultaneously. Please deselect it from WFH Days first.`,
                theme: 'error',
                label: '⚠️ Conflict Detected'
            });
            
            return; // Don't update state
        }
        
        // Update Office selection
        this.daysOfWeek = this.daysOfWeek.map(d =>
            d.value === day ? { ...d, isOffice: checked } : d
        );
        
        console.log('Updated daysOfWeek:', JSON.parse(JSON.stringify(this.daysOfWeek)));
        
        this.validateDaySelection();
    }

    handleReasonChange(e) {
        this.reason = e.target.value;
    }

    async handleSubmit() {
        console.log('=== SUBMITTING HYBRID SCHEDULE REQUEST ===');

          // ✅ Guard: ensure weekStartDate is valid
    if (!this.weekStartDate || this.weekStartDate.startsWith('-')) {
        await LightningAlert.open({
            message: 'Please re-select the schedule week and try again.',
            theme: 'error',
            label: 'Invalid Week'
        });
        return;
    }
        
        // ✅ Final validation before submit
        const totalSelectedDays = this.getSelectedWFHDays().length + this.getSelectedOfficeDays().length;
        
        if (totalSelectedDays !== 5) {
            await LightningAlert.open({
                message: `You must select all 5 weekdays. Currently selected: ${totalSelectedDays} days. Please select ${5 - totalSelectedDays} more day(s).`,
                theme: 'warning',
                label: '⚠️ Incomplete Selection'
            });
            return;
            
        }
        
        
        this.isLoading = true;

        try {
            const result = await submitHybridScheduleRequest({
                employeeId: this.employeeId,
                scheduleMonth: this.weekStartDate,
                wfhDays: this.getSelectedWFHDays().join(';'),
                officeDays: this.getSelectedOfficeDays().join(';'),
                scheduleType: this.scheduleType,
                reason: this.reason
            });
            console.log('Submit Result:', result);

            if (result.success) {

                this.isLoading = false; // ← stop spinner BEFORE showing alert
                await LightningAlert.open({
                    message: result.message || 'Request submitted successfully',
                    theme: 'success',
                    label: 'Success'
                });

                this.showForm = false;
                this.resetForm();
                await this.loadExistingSchedules();

            } else {
                await LightningAlert.open({
                    message: result.message || result.alert || 'You already have a hybrid schedule request for this month',
                    theme: 'info',
                    label: 'Alert'
                });
            }
        } catch (error) {
            console.error('❌ Submit Error:', error);
            
            let errorMessage = 'An unexpected error occurred';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            await LightningAlert.open({
                message: errorMessage,
                theme: 'error',
                label: 'Error'
            });
            
        } finally {
            this.isLoading = false;
        }
    }

    /* ======================
        HELPERS
    ======================= */

    getSelectedWFHDays() {
        return this.daysOfWeek.filter(d => d.isWFH).map(d => d.value);
    }

    getSelectedOfficeDays() {
        return this.daysOfWeek.filter(d => d.isOffice).map(d => d.value);
    }

    get minWeek() {
    const d = new Date();
    const year = d.getFullYear();
    
    // Get ISO week number safely
    const tempDate = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const dayNum = tempDate.getUTCDay() || 7;
    tempDate.setUTCDate(tempDate.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(tempDate.getUTCFullYear(), 0, 1));
    const weekNum = Math.ceil((((tempDate - yearStart) / 86400000) + 1) / 7);
    
    return `${year}-W${String(weekNum).padStart(2, '0')}`;
}


// Update getWeekDates to use the same method
getWeekDates(weekStr) {
    try {
        if (!weekStr || !weekStr.includes('-W')) {
            return { start: new Date(), end: new Date() };
        }
        const parts = weekStr.split('-W');
        const year = parseInt(parts[0], 10);
        const week = parseInt(parts[1], 10);

        if (isNaN(year) || isNaN(week)) {
            return { start: new Date(), end: new Date() };
        }

        const start = this.getMondayOfISOWeek(week, year);
        const end = new Date(start);
        end.setDate(start.getDate() + 6);

        return { start, end };
    } catch(e) {
        console.error('getWeekDates error:', e);
        return { start: new Date(), end: new Date() };
    }
}

handleWeekChange(e) {
    const raw = e.target.value;
    console.log('Raw week input value:', raw);
    this.selectedWeek = raw;
    this.weekStartDate = '';

    if (!raw) return;

    try {
        // LWC type="week" returns "2026-W11" format
        // But sometimes returns just the week number differently
        let year, week;

        if (raw.includes('-W')) {
            const parts = raw.split('-W');
            year = parseInt(parts[0], 10);
            week = parseInt(parts[1], 10);
        } else {
            console.error('Unexpected week format:', raw);
            return;
        }

        console.log('Parsed year:', year, 'week:', week);

        if (!year || !week || isNaN(year) || isNaN(week)) {
            console.error('Invalid year/week values');
            return;
        }

        const startDate = this.getMondayOfISOWeek(week, year);
        console.log('Calculated startDate:', startDate);

        if (!startDate || isNaN(startDate.getTime())) {
            console.error('Invalid start date calculated');
            return;
        }

        const y = startDate.getFullYear();
        const m = String(startDate.getMonth() + 1).padStart(2, '0');
        const d = String(startDate.getDate()).padStart(2, '0');
        this.weekStartDate = `${y}-${m}-${d}`;

        console.log('weekStartDate final:', this.weekStartDate);

    } catch(err) {
        console.error('handleWeekChange error:', err);
        this.weekStartDate = '';
    }
}

// Separate clean method - ISO 8601 week to Monday date
getMondayOfISOWeek(week, year) {
    // Jan 4th is always in week 1 of ISO calendar
    const jan4 = new Date(year, 0, 4);
    
    // Get day of week for Jan 4 (0=Sun, make it 1=Mon...7=Sun)
    const jan4DayOfWeek = jan4.getDay() === 0 ? 7 : jan4.getDay();
    
    // Monday of week 1
    const mondayWeek1 = new Date(jan4);
    mondayWeek1.setDate(jan4.getDate() - (jan4DayOfWeek - 1));
    
    // Monday of target week
    const targetMonday = new Date(mondayWeek1);
    targetMonday.setDate(mondayWeek1.getDate() + (week - 1) * 7);
    
    return targetMonday;
}
    validateDaySelection() {
        const totalSelected = this.getSelectedWFHDays().length + this.getSelectedOfficeDays().length;
        
        if (totalSelected < 5) {
            this.hasValidationError = true;
            this.validationErrorMessage = `⚠️ You must select all 5 weekdays. Currently selected: ${totalSelected}/5 days. Please select ${5 - totalSelected} more day(s).`;
        } else if (totalSelected === 5) {
            this.hasValidationError = false;
            this.validationErrorMessage = '';
        } else if (totalSelected > 5) {
            this.hasValidationError = true;
            this.validationErrorMessage = `⚠️ You can only select 5 weekdays total. Currently selected: ${totalSelected}/5 days. Please deselect ${totalSelected - 5} day(s).`;
        }
    }

    resetForm() {
    this.selectedMonth = '';
    this.selectedWeek = '';
    this.weekStartDate = '';
    this.scheduleType = 'Fixed Days';
    this.reason = '';
    this.hasValidationError = false;
    this.validationErrorMessage = '';

    this.daysOfWeek = this.daysOfWeek.map(d => ({
        ...d,
        isWFH: false,
        isOffice: false
    }));
}
    async loadExistingSchedules() {
        this.isLoading = true;
        
        try {
            const schedules = await getEmployeeSchedules({ employeeId: this.employeeId });
            
            console.log('📋 Loaded Schedules:', schedules);
            
            this.existingSchedules = schedules.map(s => {
              /*  const monthDate = new Date(s.Schedule_Month__c);
                const monthDisplay = monthDate.toLocaleDateString('en-US', { 
                    month: 'long', 
                    year: 'numeric' 
                });*/

                const monthDate = new Date(s.Schedule_Month__c);

// Calculate week number within the month
const getWeekOfMonth = (date) => {
    const firstDay = new Date(date.getFullYear(), date.getMonth(), 1);
    return Math.ceil((date.getDate() + firstDay.getDay()) / 7);
};

// Calculate week start (Monday) and end (Sunday)
const dayOfWeek = monthDate.getDay(); // 0=Sun, 1=Mon...
const diffToMonday = (dayOfWeek === 0) ? -6 : 1 - dayOfWeek;
const weekStart = new Date(monthDate);
weekStart.setDate(monthDate.getDate() + diffToMonday);
const weekEnd = new Date(weekStart);
weekEnd.setDate(weekStart.getDate() + 6);

const formatDate = (d) => d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
});

const weekNumber = getWeekOfMonth(weekStart);
const monthName = weekStart.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
const monthDisplay = `Week ${weekNumber} — ${formatDate(weekStart)} to ${formatDate(weekEnd)}`;
                
                const wfhDaysDisplay = s.WFH_days__c 
                    ? s.WFH_days__c.replace(/;/g, ', ') 
                    : 'None';
                
                const officeDaysDisplay = s.Office_Days__c 
                    ? s.Office_Days__c.replace(/;/g, ', ') 
                    : 'None';
                
                const managerName = s.managerName || 'N/A';
                
                let statusClass = 'status-pending';
                if (s.Approval_Status__c === 'Approved') {
                    statusClass = 'status-approved';
                } else if (s.Approval_Status__c === 'Rejected') {
                    statusClass = 'status-rejected';
                }
                
                let approvalDateDisplay = null;
                let showApprovalDate = false;
                if (s.Approval_Date__c) {
                    const approvalDate = new Date(s.Approval_Date__c);
                    approvalDateDisplay = approvalDate.toLocaleDateString('en-US', {
                        month: 'short',
                        day: 'numeric',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                    showApprovalDate = true;
                }
                
                const showRejectionReason = s.Approval_Status__c === 'Rejected' && 
                                           s.Rejection_Reason__c != null;
                
                return {
                    Id: s.Id,
                    Name: s.Name,
                    Schedule_Month__c: s.Schedule_Month__c,
                    monthDisplay: monthDisplay,
                    wfhDaysDisplay: wfhDaysDisplay,
                    officeDaysDisplay: officeDaysDisplay,
                    managerName: managerName,
                    Approval_Status__c: s.Approval_Status__c,
                    statusClass: statusClass,
                    Rejection_Reason__c: s.Rejection_Reason__c,
                    showRejectionReason: showRejectionReason,
                    approvalDateDisplay: approvalDateDisplay,
                    showApprovalDate: showApprovalDate,
                    Total_WFH_Days__c: s.Total_WFH_Days__c,
                    Total_Office_Days__c: s.Total_Office_Days__c,
                    Schedule_Type__c: s.Schedule_Type__c,
                    Reason__c: s.Reason__c,
                    monthDisplay: monthDisplay,
weekLabel: monthName  // e.g. "March 2026"
                };
            });
            
            console.log('✅ Processed Schedules:', this.existingSchedules);
            
        } catch (error) {
            console.error('❌ Error loading schedules:', error);
            this.existingSchedules = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadExistingSchedules();
    }
}