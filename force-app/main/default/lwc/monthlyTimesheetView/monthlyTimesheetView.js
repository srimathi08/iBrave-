/*import { LightningElement, api } from 'lwc';

export default class MonthlyTimesheetView extends LightningElement {
    @api timesheetEntries = [];

    handleViewDetails(event) {
        const id = event.target.dataset.id;
        // Fire custom event to parent
        this.dispatchEvent(new CustomEvent('viewdetails', { detail: id }));
    }

    // Helper for status CSS
    get statusClass() {
        return (status) => status === 'Approved' ? 'status-approved' : status === 'Pending' ? 'status-pending' : '';
    }
}*/
/*import { LightningElement, api } from 'lwc';

export default class MonthlyTimesheetView extends LightningElement {
    _allEntries = [];
    monthlyWeeks = [];

  @api
set timesheetEntries(value) {
    this._allEntries = value || [];
    this.processMonthlyWeeks();
}
        get timesheetEntries() {
        return this.monthlyWeeks;
    }
    

getAggregatedApprovalStatus(entries) {
    if (entries.some(e => e.approvalStatus === 'Rejected' || e.Approval_Status__c === 'Rejected')) return 'Rejected';
    if (entries.some(e => e.approvalStatus === 'Submitted' || e.Approval_Status__c === 'Submitted')) return 'Submitted';
    if (entries.some(e => e.approvalStatus === 'Approved' || e.Approval_Status__c === 'Approved')) return 'Approved';
    return 'Draft';
}
    processMonthlyWeeks() {
        // Get current month/year
        const now = new Date();
        const month = now.getMonth();
        const year = now.getFullYear();

        // Group by week number { week: { ... } }
        const weeksMap = {};
        for (const e of this._allEntries) {
            // Accept both date and Date__c
            const dateStr = e.date || e.Date__c;
            if (!dateStr) continue;
            const d = new Date(dateStr);

            if (d.getMonth() === month && d.getFullYear() === year) {
                const week = this.getWeekNumber(d);
                if (!weeksMap[week]) {
                    weeksMap[week] = {
                        id: `${year}-W${week}`,
                        weekLabel: `Week ${week}`,
                        regularHours: 0,
                        overtimeHours: 0,
                        totalHours: 0,
                        approvalStatus: '', // Will be filled after
                    approvalStatusClass: ''
                    };
                }
                weeksMap[week].regularHours += e.hours || e.Regular_Hours__c || 0;
                weeksMap[week].overtimeHours += e.overtime || e.Overtime_Hours__c || 0;
                weeksMap[week].totalHours += e.totalHours || e.Total_Hours__c ||
                    ((e.hours || e.Regular_Hours__c || 0) + (e.overtime || e.Overtime_Hours__c || 0));
                
            }
        }
       
// Aggregate approvalStatus (after collecting all weekly entries)
    Object.keys(weeksMap).forEach(week => {
        // Get all entries for this week in the month/year
        const entriesForWeek = this._allEntries.filter(entry => {
            const d = new Date(entry.date || entry.Date__c);
            return d.getMonth() === month && d.getFullYear() === year && this.getWeekNumber(d) === Number(week);
        });
        weeksMap[week].approvalStatus = this.getAggregatedApprovalStatus(entriesForWeek);

        // Optional: Style class for coloring
        weeksMap[week].approvalStatusClass =
            weeksMap[week].approvalStatus === 'Approved'
                ? 'approval-approved'
                : weeksMap[week].approvalStatus === 'Submitted'
                    ? 'approval-submitted'
                    : weeksMap[week].approvalStatus === 'Rejected'
                        ? 'approval-rejected'
                        : 'approval-draft';
    });
        // Sort by week ascending
        this.monthlyWeeks = Object.values(weeksMap).sort((a, b) => a.weekLabel.localeCompare(b.weekLabel));
    }

    getWeekNumber(d) {
        d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
    }


    handleViewDetails(event) {
        const id = event.target.dataset.id;
        this.dispatchEvent(new CustomEvent('viewdetails', { detail: id }));
    }
}*/
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MonthlyTimesheetView extends LightningElement {
    @track _allEntries = [];
    @track monthlyWeeks = [];
    @track currentMonthOffset = 0;
    @track isLoading = false;

    @api
    set timesheetEntries(value) {
        this._allEntries = value || [];
        this.processMonthlyWeeks();
    }
    get timesheetEntries() {
        return this._allEntries;
    }

    // Get current month and year based on offset
    get currentDate() {
        const date = new Date();
        date.setMonth(date.getMonth() + this.currentMonthOffset);
        return date;
    }

    get currentMonth() {
        return this.currentDate.getMonth();
    }

    get currentYear() {
        return this.currentDate.getFullYear();
    }

    get monthDisplay() {
        const options = { month: 'long', year: 'numeric' };
        return this.currentDate.toLocaleDateString('en-US', options);
    }

    get isCurrentMonth() {
        return this.currentMonthOffset === 0;
    }

    get hasMonthlyData() {
        return this.monthlyWeeks && this.monthlyWeeks.length > 0;
    }

    // Calculate totals for the month
    get monthlyTotalRegular() {
        return this.monthlyWeeks.reduce((sum, week) => sum + (week.regularHours || 0), 0).toFixed(2);
    }

    get monthlyTotalOvertime() {
        return this.monthlyWeeks.reduce((sum, week) => sum + (week.overtimeHours || 0), 0).toFixed(2);
    }

    get monthlyTotalHours() {
        return this.monthlyWeeks.reduce((sum, week) => sum + (week.totalHours || 0), 0).toFixed(2);
    }

    // Process entries into weekly summaries
    processMonthlyWeeks() {
        const month = this.currentMonth;
        const year = this.currentYear;

        const weeksMap = {};

        for (const entry of this._allEntries) {
            const dateStr = entry.date || entry.Date__c;
            if (!dateStr) continue;

            const entryDate = new Date(dateStr);
            
            // Only process entries for current month/year
            if (entryDate.getMonth() === month && entryDate.getFullYear() === year) {
                const weekNum = this.getWeekNumber(entryDate);
                const weekKey = `${year}-W${weekNum}`;

                if (!weeksMap[weekKey]) {
                    weeksMap[weekKey] = {
                        id: weekKey,
                        weekNumber: weekNum,
                        weekLabel: `Week ${weekNum}`,
                        weekDateRange: this.getWeekDateRange(weekNum, year),
                        regularHours: 0,
                        overtimeHours: 0,
                        totalHours: 0,
                        entries: []
                    };
                }

                // Add to totals
                const regular = entry.hours || entry.Regular_Hours__c || 0;
                const overtime = entry.overtime || entry.Overtime_Hours__c || 0;

                weeksMap[weekKey].regularHours += regular;
                weeksMap[weekKey].overtimeHours += overtime;
                weeksMap[weekKey].totalHours += regular + overtime;
                weeksMap[weekKey].entries.push(entry);
            }
        }

        // Aggregate approval status for each week
        Object.keys(weeksMap).forEach(weekKey => {
            const week = weeksMap[weekKey];
            week.approvalStatus = this.getAggregatedApprovalStatus(week.entries);
            week.approvalStatusClass = this.getApprovalStatusClass(week.approvalStatus);
            
            // Round hours
            week.regularHours = parseFloat(week.regularHours.toFixed(2));
            week.overtimeHours = parseFloat(week.overtimeHours.toFixed(2));
            week.totalHours = parseFloat(week.totalHours.toFixed(2));
        });

        // Sort by week number
        this.monthlyWeeks = Object.values(weeksMap).sort((a, b) => a.weekNumber - b.weekNumber);
    }

    // Get aggregated approval status for a week
    getAggregatedApprovalStatus(entries) {
        if (!entries || entries.length === 0) return 'Draft';

        const statuses = entries.map(e => e.approvalStatus || e.Approval_Status__c || 'Draft');

        if (statuses.some(s => s === 'Rejected')) return 'Rejected';
        if (statuses.some(s => s === 'Submitted')) return 'Submitted';
        if (statuses.every(s => s === 'Approved')) return 'Approved';
        
        return 'Draft';
    }

    // Get CSS class for approval status
    getApprovalStatusClass(status) {
        switch(status) {
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

    // Get week date range string
    getWeekDateRange(weekNum, year) {
        const weekStart = this.getWeekStartDate(weekNum, year);
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekEnd.getDate() + 6);

        return `${this.formatDate(weekStart)} - ${this.formatDate(weekEnd)}`;
    }

    // Get Monday of a given week
    getWeekStartDate(weekNum, year) {
        const jan4 = new Date(year, 0, 4);
        const firstMonday = new Date(jan4);
        firstMonday.setDate(jan4.getDate() - (jan4.getDay() || 7) + 1);
        
        const targetDate = new Date(firstMonday);
        targetDate.setDate(firstMonday.getDate() + (weekNum - 1) * 7);
        
        return targetDate;
    }

    // Calculate ISO week number
    getWeekNumber(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    // Format date for display
    formatDate(date) {
        const options = { month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }

    // Navigation handlers
    handlePrevMonth() {
        this.currentMonthOffset -= 1;
        this.processMonthlyWeeks();
    }

    handleNextMonth() {
        if (!this.isCurrentMonth) {
            this.currentMonthOffset += 1;
            this.processMonthlyWeeks();
        }
    }

    // View week details
    /*handleViewDetails(event) {
        const weekId = event.target.dataset.id;
        const week = this.monthlyWeeks.find(w => w.id === weekId);
        
        if (week) {
            this.dispatchEvent(new CustomEvent('viewweekdetails', { 
                detail: { 
                    weekNumber: week.weekNumber,
                    year: this.currentYear,
                    weekLabel: week.weekLabel
                }
            }));
        }
    }*/
handleViewDetails(event) {
        const id = event.target.dataset.id;
        this.dispatchEvent(new CustomEvent('viewdetails', { detail: id }));
    }
    // Export to Excel (CSV)
    handleExportExcel() {
        console.log('=== Starting Monthly Export ===');
        this.isLoading = true;

        try {
            if (!this.monthlyWeeks || this.monthlyWeeks.length === 0) {
                this.showToast('Warning', 'No entries found for this month', 'warning');
                return;
            }

            console.log('Exporting', this.monthlyWeeks.length, 'weeks');

            // Generate CSV content
            let csvContent = '\uFEFF'; // UTF-8 BOM

            // Title
            csvContent += `Monthly Timesheet - ${this.monthDisplay}\n`;
            csvContent += '\n';

            // Headers
            csvContent += 'Week,Date Range,Regular Hours,Overtime Hours,Total Hours,Approval Status\n';

            // Week data
            this.monthlyWeeks.forEach(week => {
                const weekLabel = String(week.weekLabel || '').replace(/,/g, ';');
                const dateRange = String(week.weekDateRange || '').replace(/,/g, ' to ');
                const regular = week.regularHours || 0;
                const overtime = week.overtimeHours || 0;
                const total = week.totalHours || 0;
                const status = String(week.approvalStatus || 'Draft').replace(/,/g, ';');

                csvContent += `${weekLabel},${dateRange},${regular},${overtime},${total},${status}\n`;
            });

            // Summary section
            csvContent += '\n';
            csvContent += 'MONTH SUMMARY\n';
            csvContent += `Total Regular Hours,${this.monthlyTotalRegular}\n`;
            csvContent += `Total Overtime Hours,${this.monthlyTotalOvertime}\n`;
            csvContent += `Total Hours,${this.monthlyTotalHours}\n`;

            // Metadata
            csvContent += '\n';
            csvContent += `Month,${this.monthDisplay}\n`;
            csvContent += `Export Date,${new Date().toLocaleString()}\n`;

            console.log('CSV generated, size:', csvContent.length, 'characters');

            // Create filename
            const monthName = this.currentDate.toLocaleDateString('en-US', { month: 'long' });
            const filename = `Timesheet_${monthName}_${this.currentYear}.csv`;

            // Use data URI (LWS compatible)
            const dataUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);

            // Create and trigger download
            const link = document.createElement('a');
            link.setAttribute('href', dataUri);
            link.setAttribute('download', filename);
            link.style.display = 'none';

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            console.log('=== Export Completed Successfully ===');
            this.showToast('Success', 'Monthly timesheet exported successfully', 'success');

        } catch (error) {
            console.error('=== Export Failed ===');
            console.error('Error:', error);
            this.showToast('Error', 'Failed to export: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Show toast notification
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