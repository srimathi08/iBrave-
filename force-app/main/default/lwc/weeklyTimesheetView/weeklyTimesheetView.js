/*import { LightningElement, api, track,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitWeeklyEntriesForApproval from '@salesforce/apex/TimesheetController.submitWeeklyEntriesForApproval';
import checkWeeklySubmissionStatus from '@salesforce/apex/TimesheetController.checkWeeklySubmissionStatus';
import getWeeklyDataForExport from '@salesforce/apex/TimesheetController.getWeeklyDataForExport';
import getEntriesForWeek from '@salesforce/apex/TimesheetController.getEntriesForWeek';
import { refreshApex } from '@salesforce/apex';

export default class WeeklyTimesheetView extends LightningElement {
    _entries = [];
    weeklyEntries = [];
    wiredEntriesResult;
    @track currentWeekOffset = 0;
    @track currentWeekNumber = 0;
    @track currentYear = new Date().getFullYear();
    @track isLoading = false;
    @track weeklySubmissionStatus = {
        hasEntries: false,
        canSubmit: false,
        allSubmitted: false,
        anySubmitted: false,
        entryCount: 0
    };
@wire(getEntriesForWeek, { weekNumber: '$currentWeekNumber', year: '$currentYear' })
    wiredEntriesHandler(result) {
        this.wiredEntriesResult = result; // Store for refreshApex
        if (result.data) {
            this._entries = result.data;
            this.processEntries();
        } else if (result.error) {
            console.error('Error loading entries:', result.error);
            this._entries = [];
            this.weeklyEntries = [];
        }
    }

    @api
    set timesheetEntries(value) {
        this._entries = value || [];
        this.filterWeek();
    }
    get timesheetEntries() { 
        return this.weeklyEntries; 
    }

   connectedCallback() {
            this.checkSubmissionStatus();
    }
    // Calculate current week number and year
  
    // Check if viewing current week
    get isCurrentWeek() {
        return this.currentWeekOffset === 0;
    }

    // Disable submit button based on status
    get disableSubmitButton() {
        return !this.weeklySubmissionStatus.canSubmit || 
               this.weeklyEntries.length === 0 ||
               this.isLoading;
    }

    // Get week start and end dates for display
    get weekStartDate() {
        const date = this.getWeekStartDate(this.currentWeekOffset);
        return this.formatDate(date);
    }

    get weekEndDate() {
        const startDate = this.getWeekStartDate(this.currentWeekOffset);
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + 6);
        return this.formatDate(endDate);
    }

    // Calculate weekly totals
    get weekTotalHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.totalHours || 0), 0).toFixed(2);
    }

    get weekRegularHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.hours || 0), 0).toFixed(2);
    }

    get weekOvertimeHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.overtime || 0), 0).toFixed(2);
    }

    filterWeek() {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + (this.currentWeekOffset * 7));
        
        const week = this.getWeekNumber(targetDate);
        const year = targetDate.getFullYear();
        
        this.currentWeekNumber = week;
        this.currentYear = year;

        this.weeklyEntries = this._entries
            .filter(e => {
                const d = new Date(e.Date__c || e.date);
                return this.getWeekNumber(d) === week && d.getFullYear() === year;
            })
            .map(entry => {
                const regular = entry.Regular_Hours__c || entry.hours || 0;
                const overtime = entry.Overtime_Hours__c || entry.overtime || 0;
                const entryDate = new Date(entry.Date__c || entry.date);
                
                return {
                    id: entry.Id,
                    date: this.formatDate(entryDate),
                    day: this.getDayName(entryDate),
                    project: entry.Project__r?.Name || entry.project || '-',
                    task: entry.Task__c || entry.task || '-',
                    hours: regular,
                    overtime: overtime,
                    totalHours: regular + overtime,
                    status: entry.Status__c || entry.status,
                    approvalStatus: entry.Approval_Status__c || 'Draft',
                    statusClass: this.getStatusClass(entry.Approval_Status__c)
                };
            })
            .sort((a, b) => new Date(a.date) - new Date(b.date));

        this.checkSubmissionStatus();
    }

    getStatusClass(status) {
        switch(status) {
            case 'Approved': return 'slds-text-color_success';
            case 'Submitted': return 'slds-text-color_warning';
            case 'Rejected': return 'slds-text-color_error';
            default: return '';
        }
    }

    handlePrevWeek() {
        this.currentWeekOffset -= 1;
        this.filterWeek();
    }

    handleNextWeek() {
        if (!this.isCurrentWeek) {
            this.currentWeekOffset += 1;
            this.filterWeek();
        }
    }

    // Check submission status from server
    async checkSubmissionStatus() {
        try {
            const status = await checkWeeklySubmissionStatus({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            this.weeklySubmissionStatus = status;
        } catch (error) {
            console.error('Error checking submission status:', error);
        }
    }

    // Submit weekly entries for approval
    async handleWeeklySubmitForApproval() {
        this.isLoading = true;
        try {
            const result = await submitWeeklyEntriesForApproval({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            
            this.showToast('Success', result.message, 'success');
            // Force reload entries here
        await this.reloadEntries();
            // Refresh entries
            //this.dispatchEvent(new CustomEvent('refreshentries'));
            
            // Update submission status
            await this.checkSubmissionStatus();
            
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to submit timesheet', 'error');
        } finally {
            this.isLoading = false;
        }
        
    }
// Example reload method
async reloadEntries() {
    try {
        const newEntries = await getEntriesForWeek({
            weekNumber: this.currentWeekNumber,
            year: this.currentYear
        });
        this._entries = newEntries;
        this.filterWeek(); // repopulate weeklyEntries and totals
    } catch (error) {
        console.error('Error reloading entries:', error);
        this.showToast('Error', 'Failed to reload updated timesheet entries', 'error');
    }
}


  
// Reliable Excel export handler
async handleExportExcel() {
    this.isLoading = true;
    try {
        const data = await getWeeklyDataForExport({
            weekNumber: this.currentWeekNumber,
            year: this.currentYear
        });

        if (!data.entries || data.entries.length === 0) {
            this.showToast('Error', 'No entries found for this week', 'error');
            this.isLoading = false;
            return;
        }

        this.downloadCSV(data);
        this.showToast('Success', 'Excel file downloaded successfully', 'success');
    } catch (error) {
    this.showToast('Error', error.body && error.body.message ? error.body.message : error.message || 'Failed to export Excel', 'error');
    console.error('Export error:', error);


    }
    this.isLoading = false;
}

// Robust CSV download logic
downloadCSV(data) {
    let csv = '\uFEFF'; // BOM for Excel
    csv += 'Date,Day,Project,Task,Regular Hours,Overtime Hours,Total Hours,Status\n';
    data.entries.forEach(entry => {
        const dateObj = new Date(entry.Date__c);
        csv += `"${this.formatDate(dateObj)}",`;
        csv += `"${this.getDayName(dateObj)}",`;
        csv += `"${entry.Project__r?.Name || '-'}",`;
        csv += `"${entry.Task__c || '-'}",`;
        csv += `${entry.Regular_Hours__c || 0},`;
        csv += `${entry.Overtime_Hours__c || 0},`;
        csv += `${entry.Total_Hours__c != null ? entry.Total_Hours__c : ((entry.Regular_Hours__c || 0) + (entry.Overtime_Hours__c || 0))},`;
        csv += `"${entry.Approval_Status__c || 'Draft'}"\n`;
    });

    csv += `\nWeek Total:,,,${data.totalRegularHours},${data.totalOvertimeHours},${data.totalHours}\n`;
    csv += `\nEmployee:,${data.employeeName}\n`;
    csv += `Week:,${data.weekNumber} - ${data.year}\n`;
    csv += `Export Date:,${data.exportDate}\n`;

   
    const blob = new Blob([csv], { type: '' }); // SIMPLIFY the content type

    const link = document.createElement('a');
    if ('download' in link) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `Timesheet_Week${data.weekNumber}_${data.year}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
}

// Supporting utilities
formatDate(date) {
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}
getDayName(date) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[date.getDay()];
}
showToast(title, message, variant) {
    this.dispatchEvent(
        new ShowToastEvent({ title, message, variant })
    );
}
  
getWeekStartDate(weekOffset) {
    const date = new Date();
    date.setDate(date.getDate() + (weekOffset * 7));
    // Find Monday for ISO week
    const day = date.getDay();
    const mondayOffset = day === 0 ? -6 : 1 - day;
    date.setDate(date.getDate() + mondayOffset);
    return date;
}
    formatDate(date) {
        const options = { month: 'short', day: 'numeric', year: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    getDayName(date) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        return days[date.getDay()];
    }

   
getWeekNumber(date) {
    // Copy date so changes don't affect original
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    // Set to nearest Thursday: current date + 4 - day-of-week (ISO 8601)
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
    // Week number is the number of weeks between start of year and nearest Thursday
    return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
}
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}*/

/*import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import submitWeeklyEntriesForApproval from '@salesforce/apex/TimesheetController.submitWeeklyEntriesForApproval';
import checkWeeklySubmissionStatus from '@salesforce/apex/TimesheetController.checkWeeklySubmissionStatus';
import getWeeklyDataForExport from '@salesforce/apex/TimesheetController.getWeeklyDataForExport';
import getEntriesForWeek from '@salesforce/apex/TimesheetController.getEntriesForWeek';

export default class WeeklyTimesheetView extends LightningElement {
    _entries = [];
    weeklyEntries = [];
    wiredEntriesResult;
    useWireAdapter = true; // Flag to determine data source
    
    @track currentWeekOffset = 0;
    @track currentWeekNumber = 0;
    @track currentYear = new Date().getFullYear();
    @track isLoading = false;
    @track weeklySubmissionStatus = {
        hasEntries: false,
        canSubmit: false,
        allSubmitted: false,
        anySubmitted: false,
        entryCount: 0
    };

    // Wire adapter - only active when useWireAdapter is true
    @wire(getEntriesForWeek, { 
        weekNumber: '$currentWeekNumber', 
        year: '$currentYear' 
    })
    wiredEntriesHandler(result) {
        this.wiredEntriesResult = result;
        if (this.useWireAdapter) {
            if (result.data) {
                this._entries = result.data;
                this.processEntries();
            } else if (result.error) {
                console.error('Error loading entries:', result.error);
                this._entries = [];
                this.weeklyEntries = [];
            }
        }
    }

    // API property setter (for parent component passing data)
    @api
    set timesheetEntries(value) {
        this.useWireAdapter = false; // Disable wire adapter when using @api
        this._entries = value || [];
        this.filterWeek();
    }
    get timesheetEntries() { 
        return this.weeklyEntries; 
    }

    connectedCallback() {
        this.calculateCurrentWeek();
        this.checkSubmissionStatus();
    }

    // Calculate current week number and year
    calculateCurrentWeek() {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + (this.currentWeekOffset * 7));
        this.currentWeekNumber = this.getWeekNumber(targetDate);
        this.currentYear = targetDate.getFullYear();
    }

    // Process entries into display format
    processEntries() {
        this.weeklyEntries = this._entries.map(entry => {
            const regular = entry.Regular_Hours__c || 0;
            const overtime = entry.Overtime_Hours__c || 0;
            const entryDate = new Date(entry.Date__c);
            
            return {
                id: entry.Id,
                date: this.formatDate(entryDate),
                day: this.getDayName(entryDate),
                project: entry.Project__r?.Name || '-',
                task: entry.Task__c || '-',
                hours: regular,
                overtime: overtime,
                totalHours: regular + overtime,
                status: entry.Status__c,
                approvalStatus: entry.Approval_Status__c || 'Draft',
                statusClass: this.getStatusClass(entry.Approval_Status__c)
            };
        }).sort((a, b) => new Date(a.date) - new Date(b.date));

        this.checkSubmissionStatus();
    }

    // For @api usage - filter entries by week
    filterWeek() {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + (this.currentWeekOffset * 7));
        
        const week = this.getWeekNumber(targetDate);
        const year = targetDate.getFullYear();
        
        this.currentWeekNumber = week;
        this.currentYear = year;

        this.weeklyEntries = this._entries
            .filter(e => {
                const d = new Date(e.Date__c || e.date);
                return this.getWeekNumber(d) === week && d.getFullYear() === year;
            })
            .map(entry => {
                const regular = entry.Regular_Hours__c || entry.hours || 0;
                const overtime = entry.Overtime_Hours__c || entry.overtime || 0;
                const entryDate = new Date(entry.Date__c || entry.date);
                
                return {
                    id: entry.Id,
                    date: this.formatDate(entryDate),
                    day: this.getDayName(entryDate),
                    project: entry.Project__r?.Name || entry.project || '-',
                    task: entry.Task__c || entry.task || '-',
                    hours: regular,
                    overtime: overtime,
                    totalHours: regular + overtime,
                    status: entry.Status__c || entry.status,
                    approvalStatus: entry.Approval_Status__c || 'Draft',
                    statusClass: this.getStatusClass(entry.Approval_Status__c)
                };
            })
            .sort((a, b) => new Date(a.date) - new Date(b.date));

        this.checkSubmissionStatus();
    }

    // Get CSS class based on approval status
    getStatusClass(approvalStatus) {
        switch(approvalStatus) {
            case 'Approved':
                return 'status-approved';
            case 'Submitted':
                return 'status-submitted';
            case 'Rejected':
                return 'status-rejected';
            case 'Draft':
            default:
                return 'status-draft';
        }
    }

    // Check if there are weekly entries
    get hasWeeklyEntries() {
        return this.weeklyEntries && this.weeklyEntries.length > 0;
    }

    // Check if viewing current week
    get isCurrentWeek() {
        return this.currentWeekOffset === 0;
    }

    // Disable submit button based on status
    get disableSubmitButton() {
        return !this.weeklySubmissionStatus.canSubmit || 
               this.weeklyEntries.length === 0 ||
               this.isLoading;
    }

    // Get week start and end dates for display
    get weekStartDate() {
        const date = this.getWeekStartDate(this.currentWeekOffset);
        return this.formatDate(date);
    }

    get weekEndDate() {
        const startDate = this.getWeekStartDate(this.currentWeekOffset);
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + 6);
        return this.formatDate(endDate);
    }

    // Calculate weekly totals
    get weekTotalHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.totalHours || 0), 0).toFixed(2);
    }

    get weekRegularHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.hours || 0), 0).toFixed(2);
    }

    get weekOvertimeHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.overtime || 0), 0).toFixed(2);
    }

    handlePrevWeek() {
        this.currentWeekOffset -= 1;
        if (this.useWireAdapter) {
            this.calculateCurrentWeek();
        } else {
            this.filterWeek();
        }
    }

    handleNextWeek() {
        if (!this.isCurrentWeek) {
            this.currentWeekOffset += 1;
            if (this.useWireAdapter) {
                this.calculateCurrentWeek();
            } else {
                this.filterWeek();
            }
        }
    }

    // Check submission status from server
    async checkSubmissionStatus() {
        try {
            const status = await checkWeeklySubmissionStatus({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            this.weeklySubmissionStatus = status;
        } catch (error) {
            console.error('Error checking submission status:', error);
        }
    }

    // Submit weekly entries for approval - FIXED VERSION
    async handleWeeklySubmitForApproval() {
        this.isLoading = true;
        try {
            const result = await submitWeeklyEntriesForApproval({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            
            this.showToast('Success', result.message, 'success');
             await this.forceReloadEntries();
            // Refresh data based on source
            if (this.useWireAdapter) {
                await refreshApex(this.wiredEntriesResult);
            } else {
                // If using @api, dispatch event to parent to refresh
                this.dispatchEvent(new CustomEvent('refreshentries'));
            }
            
            // Update submission status
            await this.checkSubmissionStatus();
            
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to submit timesheet', 'error');
        } finally {
            this.isLoading = false;
        }
    }
// Force reload entries with fresh data from server
    async forceReloadEntries() {
        try {
            // Make imperative call to bypass cache
            const freshEntries = await getEntriesForWeek({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            
            this._entries = freshEntries || [];
            
            if (this.useWireAdapter) {
                this.processEntries();
            } else {
                this.filterWeek();
            }
            
            console.log('Entries reloaded:', freshEntries.length);
        } catch (error) {
            console.error('Error reloading entries:', error);
        }
    }
    // Reliable Excel export handler
    async handleExportExcel() {
        this.isLoading = true;
        try {
            const data = await getWeeklyDataForExport({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });

            if (!data.entries || data.entries.length === 0) {
                this.showToast('Error', 'No entries found for this week', 'error');
                this.isLoading = false;
                return;
            }

            this.downloadCSV(data);
            this.showToast('Success', 'Excel file downloaded successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to export Excel', 'error');
            console.error('Export error:', error);
        }
        this.isLoading = false;
    }

    // Robust CSV download logic
    downloadCSV(data) {
        let csv = '\uFEFF'; // BOM for Excel
        csv += 'Date,Day,Project,Task,Regular Hours,Overtime Hours,Total Hours,Status\n';
        data.entries.forEach(entry => {
            const dateObj = new Date(entry.Date__c);
            csv += `"${this.formatDate(dateObj)}",`;
            csv += `"${this.getDayName(dateObj)}",`;
            csv += `"${entry.Project__r?.Name || '-'}",`;
            csv += `"${entry.Task__c || '-'}",`;
            csv += `${entry.Regular_Hours__c || 0},`;
            csv += `${entry.Overtime_Hours__c || 0},`;
            csv += `${entry.Total_Hours__c != null ? entry.Total_Hours__c : ((entry.Regular_Hours__c || 0) + (entry.Overtime_Hours__c || 0))},`;
            csv += `"${entry.Approval_Status__c || 'Draft'}"\n`;
        });

        csv += `\nWeek Total:,,,${data.totalRegularHours},${data.totalOvertimeHours},${data.totalHours}\n`;
        csv += `\nEmployee:,${data.employeeName}\n`;
        csv += `Week:,${data.weekNumber} - ${data.year}\n`;
        csv += `Export Date:,${data.exportDate}\n`;

        const blob = new Blob([csv], { type: 'text/csv' });
        const link = document.createElement('a');
        if ('download' in link) {
            const url = URL.createObjectURL(blob);
            link.setAttribute('href', url);
            link.setAttribute('download', `Timesheet_Week${data.weekNumber}_${data.year}.csv`);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        }
    }

    // Supporting utilities
    getWeekStartDate(weekOffset) {
        const date = new Date();
        date.setDate(date.getDate() + (weekOffset * 7));
        // Find Monday for ISO week
        const day = date.getDay();
        const mondayOffset = day === 0 ? -6 : 1 - day;
        date.setDate(date.getDate() + mondayOffset);
        return date;
    }

    formatDate(date) {
        const options = { month: 'short', day: 'numeric', year: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    getDayName(date) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        return days[date.getDay()];
    }

    getWeekNumber(date) {
        // Copy date so changes don't affect original
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        // Set to nearest Thursday: current date + 4 - day-of-week (ISO 8601)
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        // Week number is the number of weeks between start of year and nearest Thursday
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}*/
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import submitWeeklyEntriesForApproval from '@salesforce/apex/TimesheetController.submitWeeklyEntriesForApproval';
import checkWeeklySubmissionStatus from '@salesforce/apex/TimesheetController.checkWeeklySubmissionStatus';
//import getWeeklyDataForExport from '@salesforce/apex/TimesheetController.getWeeklyDataForExport';
import getEntriesForWeek from '@salesforce/apex/TimesheetController.getEntriesForWeek';
import getPendingApprovals from '@salesforce/apex/TimesheetApprovalService.getPendingApprovals';

export default class WeeklyTimesheetView extends LightningElement {
    @track weeklyEntries = [];
    @track currentWeekOffset = 0;
    @track currentWeekNumber = 0;
    @track currentYear = new Date().getFullYear();
    @track isLoading = false;
    @track weeklySubmissionStatus = {
        hasEntries: false,
        canSubmit: false,
        allSubmitted: false,
        entryCount: 0
    };
    wiredEntriesResult;
    wiredStatusResult;
   
@wire(getPendingApprovals)
pendingApprovals;
    // Wire adapter to fetch entries for the current week
    @wire(getEntriesForWeek, { 
        weekNumber: '$currentWeekNumber', 
        year: '$currentYear' 
    })
    wiredEntriesHandler(result) {
        this.wiredEntriesResult = result;
       if (result.data) {
    this.processEntries(result.data);

    // Wait for LWC reactivity to update currentWeekNumber
    setTimeout(() => {
        this.checkSubmissionStatus();
    }, 50);

        } else if (result.error) {
            console.error('Error loading entries:', result.error);
            this.weeklyEntries = [];
            this.showToast('Error', 'Failed to load timesheet entries', 'error');
        }
    }

    connectedCallback() {
        this.calculateCurrentWeek();
        this.getCurrentUserName();
    }

    // Calculate current week number and year based on offset
    calculateCurrentWeek() {
        const targetDate = new Date();
        targetDate.setDate(targetDate.getDate() + (this.currentWeekOffset * 7));
        this.currentWeekNumber = this.getWeekNumber(targetDate);
        this.currentYear = targetDate.getFullYear();
    }

    // Process entries into display format
    processEntries(entries) {
        this.weeklyEntries = entries.map(entry => {
            const regular = entry.Regular_Hours__c || 0;
            const overtime = entry.Overtime_Hours__c || 0;
            const entryDate = new Date(entry.Date__c);
            
            return {
                id: entry.Id,
                date: this.formatDate(entryDate),
                day: this.getDayName(entryDate),
                project: entry.Project__r?.Name || '-',
                task: entry.Task__c || '-',
                description: entry.Description__c || '-',
                hours: regular,
                overtime: overtime,
                totalHours: regular + overtime,
                status: entry.Status__c,
                approvalStatus: entry.Approval_Status__c || 'Draft',
                statusClass: this.getStatusClass(entry.Approval_Status__c)
            };
        }).sort((a, b) => new Date(a.date) - new Date(b.date));
    }

    // Get CSS class based on approval status
    getStatusClass(approvalStatus) {
        switch(approvalStatus) {
            case 'Approved':
                return 'status-approved';
            case 'Submitted':
                return 'status-submitted';
            case 'Rejected':
                return 'status-rejected';
            case 'Draft':
            default:
                return 'status-draft';
        }
    }

    // Computed properties
    get hasWeeklyEntries() {
        return this.weeklyEntries && this.weeklyEntries.length > 0;
    }

    get isCurrentWeek() {
        return this.currentWeekOffset === 0;
    }

    get disableSubmitButton() {
        return !this.weeklySubmissionStatus.canSubmit || 
               this.weeklyEntries.length === 0 ||
               this.isLoading;
    }

    get weekStartDate() {
        const date = this.getWeekStartDate(this.currentWeekOffset);
        return this.formatDate(date);
    }

    get weekEndDate() {
        const startDate = this.getWeekStartDate(this.currentWeekOffset);
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + 6);
        return this.formatDate(endDate);
    }

    // Calculate weekly totals
    get weekTotalHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.totalHours || 0), 0).toFixed(2);
    }

    get weekRegularHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.hours || 0), 0).toFixed(2);
    }

    get weekOvertimeHours() {
        return this.weeklyEntries.reduce((sum, entry) => sum + (entry.overtime || 0), 0).toFixed(2);
    }

    // Navigation handlers
    handlePrevWeek() {
    this.currentWeekOffset -= 1;
    this.calculateCurrentWeek();

    setTimeout(() => {
        this.checkSubmissionStatus();
    }, 50);
}

handleNextWeek() {
    if (!this.isCurrentWeek) {
        this.currentWeekOffset += 1;
        this.calculateCurrentWeek();

        setTimeout(() => {
            this.checkSubmissionStatus();
        }, 50);
    }
}

    // Check submission status from server
    async checkSubmissionStatus() {
        try {
            const status = await checkWeeklySubmissionStatus({
    weekNumber: Number(this.currentWeekNumber),
    year: Number(this.currentYear)
});
            this.weeklySubmissionStatus = status;
        } catch (error) {
            console.error('Error checking submission status:', error);
        }
    }

    // Submit weekly entries for approval
    async handleWeeklySubmitForApproval() {
          console.log('=== SUBMIT STARTED ===');
        console.log('Week:', this.currentWeekNumber, 'Year:', this.currentYear);
        this.isLoading = true;
        try {
            const result = await submitWeeklyEntriesForApproval({
                weekNumber: this.currentWeekNumber,
                year: this.currentYear
            });
            // Show success message with manager info
            const message = result.message || 
                          `Timesheet submitted successfully to ${result.managerName || 'your manager'}`;
            this.showToast('Success', message, 'success');
            
            // Refresh the entries to show updated approval status
             console.log('Refreshing entries...');
            await refreshApex(this.wiredEntriesResult);
// Wait a bit for Salesforce to update
            await this.delay(200);
            
setTimeout(() => {
    this.checkSubmissionStatus();
}, 100);
            // Update submission status
            console.log('Checking submission status...');
            await this.checkSubmissionStatus();
            
            // Notify parent component to refresh (if needed)
            this.dispatchEvent(new CustomEvent('refreshentries'));
            console.log('=== SUBMIT COMPLETED ===');
        } catch (error) {
            console.error('=== SUBMIT FAILED ===');
            console.error('Error details:', error);
            const errorMsg = error.body?.message || 'Failed to submit timesheet for approval';
            this.showToast('Error', errorMsg, 'error');
            console.error('Submission error:', error);
        } finally {
            this.isLoading = false;
        }
    }
    // Helper function to create delays
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
handleExportExcel() {
        console.log('=== Starting Export ===');
        this.isLoading = true;
        
        try {
            if (!this.weeklyEntries || this.weeklyEntries.length === 0) {
                this.showToast('Warning', 'No entries found for this week', 'warning');
                return;
            }
            
            console.log('Exporting', this.weeklyEntries.length, 'entries');
            
            let csvContent = '\uFEFF';
            
            csvContent += `Weekly Timesheet - Week ${this.currentWeekNumber}, ${this.currentYear}\n`;
            csvContent += `${this.weekStartDate} - ${this.weekEndDate}\n`;
            csvContent += '\n';
            
            csvContent += 'Date,Day,Project,Task,Regular Hours,Overtime Hours,Total Hours,Approval Status\n';
            
            this.weeklyEntries.forEach(entry => {
                const date = String(entry.date || '').replace(/,/g, ';');
                const day = String(entry.day || '').replace(/,/g, ';');
                const project = String(entry.project || '').replace(/,/g, ';');
                const task = String(entry.task || '').replace(/,/g, ';');
                const description = String(entry.description || '').replace(/,/g, ';');
                const regular = entry.hours || 0;
                const overtime = entry.overtime || 0;
                const total = entry.totalHours || 0;
                const status = String(entry.approvalStatus || 'Draft').replace(/,/g, ';');
                
                csvContent += `${date},${day},${project},${task},${regular},${overtime},${total},${status}\n`;
            });
            
            csvContent += '\n';
            csvContent += 'WEEK SUMMARY\n';
            csvContent += `Total Regular Hours,${this.weekRegularHours}\n`;
            csvContent += `Total Overtime Hours,${this.weekOvertimeHours}\n`;
            csvContent += `Total Hours,${this.weekTotalHours}\n`;
            
            csvContent += '\n';
            csvContent += `Week Number,${this.currentWeekNumber}\n`;
            csvContent += `Year,${this.currentYear}\n`;
            csvContent += `Export Date,${new Date().toLocaleString()}\n`;
            
            console.log('CSV generated, size:', csvContent.length, 'characters');
            
            const filename = `Timesheet_Week${this.currentWeekNumber}_${this.currentYear}.csv`;
            
            const dataUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            
            const link = document.createElement('a');
            link.setAttribute('href', dataUri);
            link.setAttribute('download', filename);
            link.style.display = 'none';
            
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            console.log('=== Export Completed Successfully ===');
            this.showToast('Success', 'Timesheet exported successfully', 'success');
            
        } catch (error) {
            console.error('=== Export Failed ===');
            console.error('Error:', error);
            
            this.showToast('Error', 'Failed to export: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    


// Get current user name
getCurrentUserName() {
    // This will be available from the component context
    // If not, it will show as 'Unknown' in export
    try {
        this.currentUserName = this.weeklyEntries[0]?.CreatedBy?.Name || 'Employee';
    } catch (e) {
        this.currentUserName = 'Employee';
    }
}
    // Utility methods
    getWeekStartDate(weekOffset) {
        const date = new Date();
        date.setDate(date.getDate() + (weekOffset * 7));
        // Find Monday (ISO week start)
        const day = date.getDay();
        const mondayOffset = day === 0 ? -6 : 1 - day;
        date.setDate(date.getDate() + mondayOffset);
        return date;
    }

    formatDate(date) {
        const options = { month: 'short', day: 'numeric', year: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    getDayName(date) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        return days[date.getDay()];
    }

    getWeekNumber(date) {
        // ISO 8601 week number calculation
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
}