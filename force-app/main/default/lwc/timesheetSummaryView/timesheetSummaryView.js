import { LightningElement, api, track } from 'lwc';

export default class TimesheetSummary extends LightningElement {
    //@api timesheetEntries = [];
_timesheetEntries = [];
@api 
get timesheetEntries() {
    return this._timesheetEntries;
}
set timesheetEntries(value) {
    this._timesheetEntries = value || [];
    this.calculateSummary();
}

    @track summaryPeriod = 'weekly';
    @track regularHours = 0;
    @track overtimeHours = 0;
    @track totalHours = 0;
    @track targetHours = 0;

    connectedCallback() {
        this.calculateSummary();
    }

    // Recalculate summary whenever the parent data changes
    @api
    refreshSummary() {
        this.calculateSummary();
    }

    get weeklyButtonVariant() {
        return this.summaryPeriod === 'weekly' ? 'brand' : 'neutral';
    }

    get monthlyButtonVariant() {
        return this.summaryPeriod === 'monthly' ? 'brand' : 'neutral';
    }

     get progressBarWidth() {
        if (!this.targetHours || this.targetHours === 0) return 'width: 0%;';
        let percentage = (this.totalHours / this.targetHours) * 100;
        if (isNaN(percentage) || percentage < 0) percentage = 0;
        if (percentage > 100) percentage = 100;
        return `width: ${percentage}%;`;
    }

    get showOvertimeWarning() {
        return this.overtimeHours > 0;
    }

    get summaryPeriodLabel() {
        return this.summaryPeriod === 'weekly' ? 'week' : 'month';
    }

    /*calculateSummary() {
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
        this.targetHours = this.summaryPeriod === 'weekly' ? 40 : 160;
    }*/
calculateSummary() {
        let entries = [];
        if (this.summaryPeriod === 'weekly') {
            entries = this.weeklyEntries;
            this.targetHours = 40;
        } else if (this.summaryPeriod === 'monthly') {
            entries = this.monthlyEntries;
            this.targetHours = 160;
        }

        let totalRegular = 0;
        let totalOvertime = 0;

        for (const entry of entries) {
            // Use fallback if alternate field names
            totalRegular += entry.Regular_Hours__c || entry.hours || 0;
            totalOvertime += entry.Overtime_Hours__c || entry.overtime || 0;
        }

        this.regularHours = totalRegular;
        this.overtimeHours = totalOvertime;
        this.totalHours = totalRegular + totalOvertime;
    }

    setSummaryPeriod(event) {
        this.summaryPeriod = event.target.dataset.period;
        this.calculateSummary();
    }

    // Helper functions for data filtering
    /*get weeklyEntries() {
        const d = new Date();
        const currentWeek = this.getWeekNumber(d);
        const currentYear = d.getFullYear();
        return this.timesheetEntries.filter(entry => {
            const entryDate = new Date(entry.Date__c);
            return this.getWeekNumber(entryDate) === currentWeek && entryDate.getFullYear() === currentYear;
        });
    }

    get monthlyEntries() {
        const d = new Date();
        const month = d.getMonth();
        const year = d.getFullYear();
        return this.timesheetEntries.filter(e => {
            const entryDate = new Date(e.Date__c);
            return entryDate.getMonth() === month && entryDate.getFullYear() === year;
        });
    }

    getWeekNumber(d) {
        d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
    }*/
get weeklyEntries() {
        const now = new Date();
        const currentWeek = this.getWeekNumber(now);
        const currentYear = now.getFullYear();
        return this.timesheetEntries.filter(entry => {
            const entryDate = new Date(entry.Date__c || entry.date);
            if (isNaN(entryDate)) return false; // Defensive check
            return this.getWeekNumber(entryDate) === currentWeek && entryDate.getFullYear() === currentYear;
        });
    }

    get monthlyEntries() {
        const now = new Date();
        const currentMonth = now.getMonth();
        const currentYear = now.getFullYear();
        return this.timesheetEntries.filter(entry => {
            const entryDate = new Date(entry.Date__c || entry.date);
            if (isNaN(entryDate)) return false; // Defensive check
            return entryDate.getMonth() === currentMonth && entryDate.getFullYear() === currentYear;
        });
    }

    getWeekNumber(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }
}