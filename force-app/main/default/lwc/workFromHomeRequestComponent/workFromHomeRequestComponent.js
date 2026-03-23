import { LightningElement, track, wire } from 'lwc';
import Id from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningAlert from 'lightning/alert';

// Apex
import getManagerInfo from '@salesforce/apex/WFH_Request.getManagerInfoforWFH';
import submitWorkFromHomeRequest from '@salesforce/apex/WFH_Request.submitWorkFromHomeRequest';
import getMyWFHRequests from '@salesforce/apex/WFH_Request.getMyWFHRequests';
import getPublicHolidaysForDateRange from '@salesforce/apex/WFH_Request.getPublicHolidaysForDateRange';
import checkOverlappingRequests from '@salesforce/apex/WFH_Request.checkOverlappingRequests';
import { refreshApex } from '@salesforce/apex';


export default class WorkFromHomeRequest extends LightningElement {

    // ================= UI STATE =================
    @track showForm = false;
    @track showCalculation = false;
    @track hasOverlap = false;
    @track overlapMessage = '';

    // ================= FORM DATA =================
    @track startDate;
    @track endDate;
    @track reason;
    // ================= CALCULATION DATA =================
    @track totalDays = 0;
    @track workingDays = 0;
    @track weekendDays = 0;
    @track holidayDays = 0;
    @track excludedDates = [];
    // ================= USER INFO =================
    employeeId = Id;
    @track employeeName = '';
    @track employmentType = '';
    @track managerId = '';
    @track managerName = '';
@track showManagementWarning = false;  // ✅ ADD — for 6+ days banner
    // ================= TABLE DATA =================
    @track requests = [];
    wiredResult;

    columns = [
        { 
            label: 'Start Date', 
            fieldName: 'Start_Date__c', 
            type: 'date',
            cellAttributes: { alignment: 'left' }
        },
        { 
            label: 'End Date', 
            fieldName: 'End_Date__c', 
            type: 'date',
            cellAttributes: { alignment: 'left' }
        },
        { 
            label: 'Working Days', 
            fieldName: 'Number_of_Days__c', 
            type: 'number',
            cellAttributes: { alignment: 'center' }
        },
        { 
            label: 'Reason', 
            fieldName: 'Reason__c',
            wrapText: true,
            cellAttributes: { alignment: 'left' }
        },
        { 
            label: 'Status', 
            fieldName: 'Status__c',
            type: 'text',
            cellAttributes: { 
                alignment: 'center',
                class: { fieldName: 'statusClass' }
            }
        }
    ];

    // ================= LOAD TABLE =================
    @wire(getMyWFHRequests)
    wiredRequests(result) {
        this.wiredResult = result;
        if (result.data) {
            // Add status class for styling
            this.requests = result.data.map(record => {
                return {
                    ...record,
                    statusClass: this.getStatusClass(record.Status__c)
                };
            });
        } else if (result.error) {
            console.error('Error loading requests:', result.error);
            this.showToast('Error', 'Unable to load requests', 'error');
        }
    }

    // ================= LIFECYCLE =================
    connectedCallback() {
        this.loadManagerInfo();
    }

    // ================= LOAD MANAGER INFO =================
    loadManagerInfo() {
        getManagerInfo({ employeeId: this.employeeId })
            .then(result => {
                this.managerId = result.managerId;
                this.managerName = result.managerName;
                this.employeeName = result.employeeName;
                this.employmentType = result.employmentType;
            })
            .catch(error => {
                console.error('Error loading manager info:', error);
                this.managerName = 'No manager assigned';
                this.showToast('Warning', 'Unable to load manager information', 'warning');
            });
    }

    // ================= FORM HANDLERS =================
   async handleChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value;
        this[fieldName] = value;

        // Validate end date is after start date
        if (fieldName === 'endDate' && this.startDate && value < this.startDate) {
            event.target.setCustomValidity('End date must be after start date');
            event.target.reportValidity();
        } else if (fieldName === 'startDate' && this.endDate && value > this.endDate) {
            event.target.setCustomValidity('Start date must be before end date');
            event.target.reportValidity();
        } else {

            event.target.setCustomValidity('');
        }
    


        // Calculate working days when both dates are selected
        if (this.startDate && this.endDate && this.endDate >= this.startDate) {
            //this.calculateWorkingDays();
             await this.calculateWorkingDays();
            await this.checkForOverlaps();
        } else {
            this.showCalculation = false;
            this.hasOverlap = false;
        }
    }


    // ================= CHECK FOR OVERLAPPING REQUESTS =================
    async checkForOverlaps() {
        try {
            const result = await checkOverlappingRequests({
                startDate: this.startDate,
                endDate: this.endDate,
                employeeId: this.employeeId
            });

            this.hasOverlap = result.hasOverlap;
            this.overlapMessage = result.message || '';

        } catch (error) {
            console.error('Error checking overlaps:', error);
            this.hasOverlap = false;
            this.overlapMessage = '';
        }
    }



    // ================= CALCULATE WORKING DAYS =================
    async calculateWorkingDays() {
        try {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            
            // Get public holidays from server
            const holidays = await getPublicHolidaysForDateRange({
                startDate: this.startDate,
                endDate: this.endDate
            });

            const holidaySet = new Set(holidays.map(h => h.Holiday_Date__c));
            
            let totalDays = 0;
            let workingDays = 0;
            let weekendDays = 0;
            let holidayDays = 0;
            const excludedDates = [];

            let currentDate = new Date(start);
            
            while (currentDate <= end) {
                totalDays++;
                const dateString = this.formatDate(currentDate);
                const dayOfWeek = currentDate.getDay(); // 0=Sunday, 6=Saturday
                
                const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
                const isHoliday = holidaySet.has(dateString);
                
                if (isWeekend) {
                    weekendDays++;
                    excludedDates.push({
                        date: this.formatDateDisplay(currentDate),
                        reason: 'Weekend',
                        class: 'weekend-tag'
                    });
                } else if (isHoliday) {
                    holidayDays++;
                    excludedDates.push({
                        date: this.formatDateDisplay(currentDate),
                        reason: 'Holiday',
                        class: 'holiday-tag'
                    });
                } else {
                    workingDays++;
                }
                
                currentDate.setDate(currentDate.getDate() + 1);
            }

            this.totalDays = totalDays;
            this.workingDays = workingDays;
            this.weekendDays = weekendDays;
            this.holidayDays = holidayDays;
            this.excludedDates = excludedDates;
            this.showCalculation = true;
            this.showManagementWarning = (workingDays >= 6);

        } catch (error) {
            console.error('Error calculating working days:', error);
            this.showCalculation = false;
            // ✅ ADD: Show Management warning banner for 6+ days
this.showManagementWarning = (workingDays >= 6);
        }
    }



    handleNewRequest() {
        if (!this.managerName || this.managerName === 'No manager assigned') {
            this.showToast(
                'Error', 
                'You must have a manager assigned to submit a WFH request', 
                'error'
            );
            return;
        }
        this.resetForm();
        this.showForm = true;
    }

    handleCancel() {
        this.showForm = false;
        this.resetForm();
    }

    // ================= SUBMIT (REAL SAVE) =================
    handleSubmit() {
        console.log('🔵 Submit clicked');
        // Validate all required fields
        if (!this.startDate || !this.endDate || !this.reason) {
           // this.showToast('Error', 'Please fill all required fields', 'error');
            LightningAlert.open({
    message: 'Please fill all required fields',
    theme: 'error',   // error | warning | success | info
    label: 'Error'
});
            return;
        }

        // Additional date validation
        if (this.endDate < this.startDate) {
            //this.showToast('Error', 'End date must be after start date', 'error');
            LightningAlert.open({
    message: 'End date must be after start date',
    theme: 'error',   // error | warning | success | info
    label: 'Error'
});
            return;
        }

        // ✅ Check for overlapping requests
        if (this.hasOverlap) {
            LightningAlert.open({
                message: this.overlapMessage,
                theme: 'warning',
                label: 'Overlapping Request Found'
            });
            return;
        }

        if (this.workingDays === 0) {
            LightningAlert.open({
                message: 'No working days found in selected date range. Please select dates that include at least one working day.',
                theme: 'error',
                label: 'Error'
            });
            return;
        }
        // ✅ Block 6+ days
if (this.workingDays >= 6) {
    LightningAlert.open({
        message: 'WFH requests above 5 days require Management approval. ' +
                 'Please contact your Manager and HR directly to get approval.',
        theme: 'warning',
        label: 'Management Approval Required'
    });
    return;
}

console.log('✅ All validations passed');
    console.log('📅 Start Date:', this.startDate);
    console.log('📅 End Date:', this.endDate);
    console.log('📝 Reason:', this.reason);
    console.log('📊 Working Days:', this.workingDays);



        const requestRec = {
            Start_Date__c: this.startDate,
            End_Date__c: this.endDate,
            Reason__c: this.reason
        };

          console.log('🚀 Calling Apex with:', JSON.stringify(requestRec));


        submitWorkFromHomeRequest({ wfhRequest: requestRec })
            .then(() => {
                // this.showToast(
                //     'Success',
                //     'Work From Home request submitted successfully. Your manager will be notified.',
                //     'success'
                // );
 LightningAlert.open({
    message: 'Work From Home request submitted successfully. Your manager will be notified.',
    theme: 'success', // success | error | warning | info
    label: 'Success'
});


                this.showForm = false;
                this.resetForm();
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                console.error('Error submitting request:', error);
                console.error('Full error object:', JSON.stringify(error, null, 2));
            console.error('Error body:', error.body);
            console.error('Error message:', error.body?.message);
            console.error('Error output:', error.body?.output);
            console.error('Error stackTrace:', error.body?.stackTrace);
                //const errorMessage = error.body?.message || 'An error occurred while submitting your request';
                //this.showToast('Error', errorMessage, 'error');
                // Extract the actual error message
            let errorMessage = 'An error occurred while submitting your request';
            
            if (error.body?.message) {
                errorMessage = error.body.message;
            } else if (error.body?.output?.errors && error.body.output.errors.length > 0) {
                errorMessage = error.body.output.errors[0].message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            console.log('📢 Displaying error to user:', errorMessage);
            console.log('📢 Full error details:', {
                status: error.status,
                statusText: error.statusText,
                message: errorMessage
            });
            
            // Show detailed error to user
            LightningAlert.open({
                message: errorMessage + ' (Check browser console for details)',
                theme: 'error',
                label: 'Submission Failed'
            });
        
            });
    }

    // ================= HELPER METHODS =================
    resetForm() {
        this.startDate = null;
        this.endDate = null;
        this.reason = '';
        this.showCalculation = false;
        this.hasOverlap = false;
        this.overlapMessage = '';
        this.workingDays = 0;
        this.totalDays = 0;
        this.weekendDays = 0;
        this.holidayDays = 0;
        this.excludedDates = [];
         this.showManagementWarning = false; // ✅ ADD THIS
        
        // Clear any validation errors
        const inputs = this.template.querySelectorAll('lightning-input, lightning-textarea');
        inputs.forEach(input => {
            if (input.setCustomValidity) {
                input.setCustomValidity('');
                input.reportValidity();
            }
        });
    }

    formatDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    formatDateDisplay(date) {
        const options = { weekday: 'short', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    getStatusClass(status) {
        if (!status) return '';
        
        const statusLower = status.toLowerCase();
        if (statusLower.includes('approved')) {
            return 'status-approved';
        } else if (statusLower.includes('rejected')) {
            return 'status-rejected';
        } else if (statusLower.includes('pending')) {
            return 'status-pending';
        } else if (statusLower.includes('cancelled')) {
            return 'status-cancelled';
        }
        return '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ 
                title, 
                message, 
                variant,
                mode: 'dismissable'
            })
        );
    }

    // Inside your WorkFromHomeRequest class
handleRefresh() {
    this.showToast('Loading', 'Refreshing requests...', 'info');
    return refreshApex(this.wiredResult);
}

    // ================= GETTERS =================
    get today() {
        return new Date().toISOString().split('T')[0];
    }

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }

    // ✅ FIXED: Added missing getter for excluded dates
    get hasExcludedDates() {
        return this.excludedDates && this.excludedDates.length > 0;
    }
}