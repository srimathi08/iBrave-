import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';

// Import Apex methods
import submitHybridScheduleRequest from '@salesforce/apex/HybridWorkScheduleController.submitHybridScheduleRequest';
import getEmployeeSchedules from '@salesforce/apex/HybridWorkScheduleController.getEmployeeSchedules';

export default class HybridScheduleRequest extends LightningElement {
    // User data
    employeeId = USER_ID;
    
    // Form data
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
    
    // UI state
    @track isLoading = false;
    @track hasValidationError = false;
    @track validationErrorMessage = '';
    @track existingSchedules = [];
    
    // Computed properties
    get minMonth() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        return `${year}-${month}`;
    }
    
    get scheduleTypeOptions() {
        return [
            { label: 'Fixed Days (Same pattern every week)', value: 'Fixed Days' },
            { label: 'Flexible (May vary)', value: 'Flexible' },
            { label: 'Custom Pattern', value: 'Custom Pattern' }
        ];
    }
    
    get selectedWFHDaysText() {
        const selected = this.daysOfWeek.filter(day => day.isWFH).map(day => day.label);
        return selected.length > 0 ? selected.join(', ') : 'None';
    }
    
    get selectedOfficeDaysText() {
        const selected = this.daysOfWeek.filter(day => day.isOffice).map(day => day.label);
        return selected.length > 0 ? selected.join(', ') : 'None';
    }
    
    get reasonCharCount() {
        return this.reason ? this.reason.length : 0;
    }
    
    get isReasonTooShort() {
        return this.reasonCharCount > 0 && this.reasonCharCount < 20;
    }
    
    get showSummary() {
        return this.selectedMonth && (this.getSelectedWFHDays().length > 0 || this.getSelectedOfficeDays().length > 0);
    }
    
    get selectedMonthDisplay() {
        if (!this.selectedMonth) return '';
        const date = new Date(this.selectedMonth + '-01');
        return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    }
    
    get totalWFHDays() {
        return this.getSelectedWFHDays().length;
    }
    
    get totalOfficeDays() {
        return this.getSelectedOfficeDays().length;
    }
    
    get isSubmitDisabled() {
        return !this.selectedMonth || 
               (this.getSelectedWFHDays().length === 0 && this.getSelectedOfficeDays().length === 0) ||
               !this.reason || 
               this.reason.length < 20 ||
               this.isLoading;
    }
    
    get hasExistingSchedules() {
        return this.existingSchedules && this.existingSchedules.length > 0;
    }
    
    // Lifecycle
    connectedCallback() {
        console.log('Hybrid Schedule Request component initialized');
        this.loadExistingSchedules();
    }
    
    // Event handlers
    handleMonthChange(event) {
        this.selectedMonth = event.target.value;
        console.log('Selected month:', this.selectedMonth);
        this.validateForm();
    }
    
    handleScheduleTypeChange(event) {
        this.scheduleType = event.detail.value;
        console.log('Schedule type:', this.scheduleType);
    }
    
    handleWFHDayChange(event) {
        const dayValue = event.target.dataset.day;
        const isChecked = event.target.checked;
        
        this.daysOfWeek = this.daysOfWeek.map(day => {
            if (day.value === dayValue) {
                return { ...day, isWFH: isChecked };
            }
            return day;
        });
        
        console.log('WFH days updated:', this.getSelectedWFHDays());
        this.validateForm();
    }
    
    handleOfficeDayChange(event) {
        const dayValue = event.target.dataset.day;
        const isChecked = event.target.checked;
        
        this.daysOfWeek = this.daysOfWeek.map(day => {
            if (day.value === dayValue) {
                return { ...day, isOffice: isChecked };
            }
            return day;
        });
        
        console.log('Office days updated:', this.getSelectedOfficeDays());
        this.validateForm();
    }
    
    handleReasonChange(event) {
        this.reason = event.target.value;
        this.validateForm();
    }
    
    handleReset() {
        this.selectedMonth = '';
        this.scheduleType = 'Fixed Days';
        this.reason = '';
        this.daysOfWeek = this.daysOfWeek.map(day => ({
            ...day,
            isWFH: false,
            isOffice: false
        }));
        this.hasValidationError = false;
        this.validationErrorMessage = '';
        
        this.showToast('Reset', 'Form has been reset', 'info');
    }
    
    handleRefresh() {
        this.loadExistingSchedules();
    }
    
    async handleSubmit() {
        // Final validation
        if (!this.validateForm()) {
            return;
        }
        
        this.isLoading = true;
        
        try {
            const wfhDays = this.getSelectedWFHDays().join(';');
            const officeDays = this.getSelectedOfficeDays().join(';');
            const scheduleMonth = this.selectedMonth + '-01'; // Format: YYYY-MM-01
            
            console.log('Submitting schedule request...');
            console.log('Employee ID:', this.employeeId);
            console.log('Month:', scheduleMonth);
            console.log('WFH Days:', wfhDays);
            console.log('Office Days:', officeDays);
            
            const result = await submitHybridScheduleRequest({
                employeeId: this.employeeId,
                scheduleMonth: scheduleMonth,
                wfhDays: wfhDays,
                officeDays: officeDays,
                scheduleType: this.scheduleType,
                reason: this.reason
            });
            
            console.log('Submission result:', JSON.stringify(result, null, 2));
            
            if (result.success) {
                this.showToast(
                    'Success!',
                    result.message || 'Your hybrid work schedule request has been submitted for approval',
                    'success'
                );
                
                // Reset form
                this.handleReset();
                
                // Refresh existing schedules
                this.loadExistingSchedules();
            } else {
                this.showToast(
                    'Error',
                    result.error || 'Failed to submit schedule request',
                    'error'
                );
            }
            
        } catch (error) {
            console.error('Error submitting schedule:', error);
            this.showToast(
                'Error',
                error.body?.message || 'An error occurred while submitting your request',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    
    // Helper methods
    getSelectedWFHDays() {
        return this.daysOfWeek.filter(day => day.isWFH).map(day => day.value);
    }
    
    getSelectedOfficeDays() {
        return this.daysOfWeek.filter(day => day.isOffice).map(day => day.value);
    }
    
    validateForm() {
        this.hasValidationError = false;
        this.validationErrorMessage = '';
        
        // Check if at least one day is selected
        if (this.getSelectedWFHDays().length === 0 && this.getSelectedOfficeDays().length === 0) {
            this.hasValidationError = true;
            this.validationErrorMessage = 'Please select at least one WFH day or Office day';
            return false;
        }
        
        // Check for overlapping days
        const wfhDays = this.getSelectedWFHDays();
        const officeDays = this.getSelectedOfficeDays();
        const overlap = wfhDays.filter(day => officeDays.includes(day));
        
        if (overlap.length > 0) {
            this.hasValidationError = true;
            this.validationErrorMessage = `Cannot select same day for both WFH and Office: ${overlap.join(', ')}`;
            return false;
        }
        
        return true;
    }
    
    async loadExistingSchedules() {
        this.isLoading = true;
        
        try {
            console.log('Loading existing schedules for employee:', this.employeeId);
            
            const schedules = await getEmployeeSchedules({
                employeeId: this.employeeId
            });
            
            console.log('Existing schedules:', JSON.stringify(schedules, null, 2));
            
            // Format schedules for display
            this.existingSchedules = schedules.map(schedule => {
                const monthDate = new Date(schedule.Schedule_Month__c);
                const monthDisplay = monthDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
                
                let statusClass = 'status-pending';
                if (schedule.Approval_Status__c === 'Approved') {
                    statusClass = 'status-approved';
                } else if (schedule.Approval_Status__c === 'Rejected') {
                    statusClass = 'status-rejected';
                }
                
                return {
                    ...schedule,
                    monthDisplay: monthDisplay,
                    wfhDaysDisplay: schedule.WFH_days__c ? schedule.WFH_days__c.replace(/;/g, ', ') : 'None',
                    officeDaysDisplay: schedule.Office_Days__c ? schedule.Office_Days__c.replace(/;/g, ', ') : 'None',
                    statusClass: statusClass,
                    showApprovalDate: schedule.Approval_Date__c && schedule.Approval_Status__c === 'Approved',
                    approvalDateDisplay: schedule.Approval_Date__c ? new Date(schedule.Approval_Date__c).toLocaleDateString() : '',
                    showRejectionReason: schedule.Approval_Status__c === 'Rejected' && schedule.Rejection_Reason__c
                };
            });
            
        } catch (error) {
            console.error('Error loading existing schedules:', error);
            this.showToast(
                'Error',
                'Failed to load existing schedules',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}