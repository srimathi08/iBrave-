import { LightningElement, track, wire } from 'lwc';
import getEntries from '@salesforce/apex/TimesheetController.getEntries';
import deleteTimesheetEntry from '@salesforce/apex/TimesheetController.deleteTimesheetEntry';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TimesheetManager extends LightningElement {
    @track timesheetEntries = [];
    wiredEntriesResult; // Hold the wired response

    @track isModalOpen = false;
    @track activeTab = 'myEntries';
    @track modalEntry = null;

    @track weekDetailEntries = [];
    @track selectedWeekId = null;
    @track isWeekModalOpen = false;
@track selectedMonth = (new Date()).getMonth();
@track selectedYear = (new Date()).getFullYear();

   formatTime(sfTime) {
    // sfTime: Likely in milliseconds from midnight, or a Time object, or string "HH:mm:ss" format
    // If milliseconds:
    if (typeof sfTime === "number") {
        // Convert ms to Date
        let date = new Date(0, 0, 0, 0, 0, 0, sfTime);
        let hours = date.getHours();
        let minutes = date.getMinutes();
        let ampm = hours >= 12 ? 'pm' : 'am';
        hours = hours % 12;
        hours = hours ? hours : 12; // "0" should be "12"
        minutes = minutes < 10 ? '0' + minutes : minutes;
        return `${hours}:${minutes} ${ampm}`;
    }
    // If string "HH:mm:ss"
    if (typeof sfTime === "string") {
        let [hh, mm] = sfTime.split(':');
        let hours = parseInt(hh, 10);
        let ampm = hours >= 12 ? 'pm' : 'am';
        hours = hours % 12 || 12;
        return `${hours}:${mm} ${ampm}`;
    }
    return '';
}

    @wire(getEntries)
wiredEntries(result) {
    this.wiredEntriesResult = result;
    const { error, data } = result;
    if (data) {
        this.timesheetEntries = data.map(entry => ({
            id: entry.Id,
            date: entry.Date__c,
            day: this.getDayOfWeek(entry.Date__c),
            project: entry.Project__r ? entry.Project__r.Name : '',
            projectId: entry.Project__c,
            startTime: this.formatTime(entry.Start_Time__c),
            endTime: this.formatTime(entry.End_Time__c),
            hours: entry.Regular_Hours__c || 0,
            overtime: entry.Overtime_Hours__c || 0,
            status: entry.Status__c,
            task: entry.Task__c,
            approvalStatus: entry.Approval_Status__c || 'Draft',
            statusClass: this.getStatusClass(entry.Status__c),
            employmentStatus: entry.Billing_Status__c, 
            description: entry.Description__c,
            approvalStatusClass: this.getApprovalStatusClass(entry.Approval_Status__c)
        }));
    } else if (error) {
        console.error('Error fetching entries:', error);
    }
}

    // This method is called by the modal's 'entrycreated' event
    refreshEntries() {
        return refreshApex(this.wiredEntriesResult);
    }

    get myEntries() {
        return this.timesheetEntries.slice().sort((a, b) => new Date(b.Date__c)-new Date(a.Date__c));
    }
    
    get weeklyEntries() {
        const currentWeek = this.getWeekNumber(new Date());
        const currentYear = new Date().getFullYear();
        return this.timesheetEntries.filter(entry => {
            const entryDate = new Date(entry.Date__c);
            return this.getWeekNumber(entryDate) === currentWeek
                && entryDate.getFullYear() === currentYear;
        });
    }

    get monthlyEntries() {
        //const month = new Date().getMonth();
        //const year = new Date().getFullYear();
        return this.timesheetEntries.filter(e => {
            const d = new Date(e.date || e.Date__c);
        return d.getMonth() === this.selectedMonth && d.getFullYear() === this.selectedYear;
        });
    }
    get displayedMonthName() {
    return new Date(this.selectedYear, this.selectedMonth).toLocaleString('default', { month: 'long' });
}
    handlePrevMonth() {
    if (this.selectedMonth === 0) {
        this.selectedMonth = 11;
        this.selectedYear--;
    } else {
        this.selectedMonth--;
    }
}

handleNextMonth() {
    if (this.selectedMonth === 11) {
        this.selectedMonth = 0;
        this.selectedYear++;
    } else {
        this.selectedMonth++;
    }
}

handleMonthlyWeekDetails(event) {
    const weekId = event.detail; // e.g., "2025-W41"
    const [yearStr, weekLabel] = weekId.split('-W');
    const weekNumber = parseInt(weekLabel, 10);
    const year = parseInt(yearStr, 10);

    // Filter entries that match week/year
    this.weekDetailEntries = this.timesheetEntries.filter(e => {
        const entryDate = new Date(e.date || e.Date__c);
        const entryWeek = this.getWeekNumber(entryDate);
        const entryYear = entryDate.getFullYear();
        return entryWeek === weekNumber && entryYear === year;
    });

    this.selectedWeekId = weekId;
    this.isWeekModalOpen = true;
}

    get summaryEntries() { return this.timesheetEntries; }
// New getters for summary tab buttons
    get isWeeklySummary() {
        return this.summaryPeriod === 'weekly';
    }

    get isMonthlySummary() {
        return this.summaryPeriod === 'monthly';
    }

    // New getters for summary display
    get progressBarWidth() {
        let percentage = (this.totalHours / this.targetHours) * 100;
        if (percentage > 100) {
            percentage = 100;
        }
        return `width: ${percentage}%;`;
    }

    get showOvertimeWarning() {
        return this.overtimeHours > 0;
    }

    get summaryPeriodLabel() {
        return this.summaryPeriod === 'weekly' ? 'week' : 'month';
    }

    // New methods for summary logic
    calculateSummary() {
        const entries = this.summaryPeriod === 'weekly' ? this.weeklyEntries : this.monthlyEntries;
        
        let totalRegular = 0;
        let totalOvertime = 0;

        for (const entry of entries) {
            totalRegular += entry.Regular_Hours__c || 0;
            totalOvertime += entry.Overtime_Hours__c || 0;
        }

        this.regularHours = totalRegular;
        this.overtimeHours = totalOvertime;
        this.totalHours = totalRegular + totalOvertime;
        this.targetHours = this.summaryPeriod === 'weekly' ? 40 : 160; // Set target hours
    }

    setSummaryPeriod(event) {
        this.summaryPeriod = event.target.dataset.period;
        this.calculateSummary();
    }
    /*getDayOfWeek(dateStr) {
        const d = new Date(dateStr);
        return ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][d.getDay()];
    }*/
  getDayOfWeek(dateStr) {
        const d = new Date(dateStr);
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        return days[d.getDay()];
    }
    getWeekNumber(d) {
        d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
    }
    getStatusClass(status) {
        switch(status) {
            case 'Approved':
                return 'status-approved';
            case 'Pending':
                return 'status-pending';
            default:
                return 'status-other';
        }
    }
     getApprovalStatusClass(approvalStatus) {
        switch(approvalStatus) {
            case 'Approved':
                return 'approval-approved';
            case 'Submitted':
                return 'approval-submitted';
            case 'Rejected':
                return 'approval-rejected';
            case 'Draft':
            default:
                return 'approval-draft';
        }
    }
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    openModal() { this.modalEntry = null; this.isModalOpen = true; }
    
    handleEditEntry(event) { this.modalEntry = event.detail.entry; this.isModalOpen = true; }
    handleDeleteEntry(event) {
    const entryId = event.detail.entryId;
    if (entryId) {
        deleteTimesheetEntry({ entryId })
            .then(() => {
                this.refreshEntries();
                this.showToast('Success', 'Entry deleted successfully', 'success');
            })
            .catch(error => {
                let errMsg;
                // Defensive error extraction
                if (error && error.body && error.body.message) {
                    errMsg = error.body.message;
                } else if (error && error.message) {
                    errMsg = error.message;
                } else if (typeof error === 'string') {
                    errMsg = error;
                } else {
                    errMsg = 'Unknown error during deletion';
                }
                this.showToast('Error', errMsg, 'error');
            });
    }
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
 
    closeModal() { this.isModalOpen = false; this.modalEntry = null; }
    
    submitEntries() { /* backend logic here */ }
    
    refreshEntries() { return refreshApex(this.wiredEntriesResult); }
    // Reusable export logic
   
closeWeekModal() {
    this.isWeekModalOpen = false;
    this.selectedWeekId = null;
}
    
}