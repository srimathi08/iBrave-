// teamLeadDashboard.js
// UPDATED: Timesheet__c.Employee__c = Lookup(User), NOT Contact
// Bridge: Contact → User (via ContactId on User) → Timesheet__c

import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import getMyTeamMembers            from '@salesforce/apex/TeamLeadDashboardController.getMyTeamMembers';
import getAttendanceRecords        from '@salesforce/apex/TeamLeadDashboardController.getAttendanceRecords';
import getTimesheetRecords         from '@salesforce/apex/TeamLeadDashboardController.getTimesheetRecords';
import getTimesheetEntries         from '@salesforce/apex/TeamLeadDashboardController.getTimesheetEntries';
import getLeaveRequests            from '@salesforce/apex/TeamLeadDashboardController.getLeaveRequests';
import getMonthlyAttendanceSummary from '@salesforce/apex/TeamLeadDashboardController.getMonthlyAttendanceSummary';
import updateLeaveStatus           from '@salesforce/apex/TeamLeadDashboardController.updateLeaveStatus';

import USER_ID    from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';

const COLORS = ['#7C3AED', '#0891B2', '#D97706', '#059669', '#DC2626'];

export default class TeamLeadDashboard extends LightningElement {

    userId = USER_ID;

    @wire(getRecord, { recordId: '$userId', fields: [NAME_FIELD] })
    currentUser;

    get managerName() {
        return getFieldValue(this.currentUser.data, NAME_FIELD) || 'Team Lead';
    }
    get managerInitials() {
        return this._initials(this.managerName);
    }

    // ── State ──
    @track teamMembers       = [];
    @track selectedEmpId     = null;
    @track selectedEmp       = null;
    @track activeTab         = 'attendance';

    @track attendanceRecords = [];
    @track timesheetRecords  = [];   // Timesheet__c (parent)
    @track tsEntries         = [];   // TimesheetEntry__c (children)
    @track leaveRequests     = [];
    @track attendanceSummary = { rate: 0, rateDisplay: '0%', present: 0, late: 0, absent: 0 };

    @track isLoading         = false;
    @track noTeamMembers     = false;

    // which timesheet row is expanded
    @track expandedSheetId   = null;

    get todayDisplay() {
        return new Date().toLocaleDateString('en-IN', {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
        });
    }

    /* ── Wire: auto-load team on mount ── */
    @wire(getMyTeamMembers)
    wiredTeam({ data, error }) {
        if (data) {
            if (data.length === 0) { this.noTeamMembers = true; return; }
            this.teamMembers = data.map((e, i) => ({
                ...e,
                initials:    this._initials(e.Name),
                accentColor: COLORS[i % COLORS.length],
                colorIndex:  (i % COLORS.length) + 1,
                isSelected:  false,
                cardClass:   'emp-card',
            }));
            this._select(this.teamMembers[0].Id);
        } else if (error) {
            this._toast('Error loading team', error.body?.message, 'error');
        }
    }

    /* ── Select employee ── */
    handleEmpSelect(event) { this._select(event.currentTarget.dataset.id); }

    _select(id) {
        this.selectedEmpId   = id;
        this.selectedEmp     = this.teamMembers.find(e => e.Id === id);
        this.activeTab       = 'attendance';
        this.expandedSheetId = null;
        this.teamMembers     = this.teamMembers.map(e => ({
            ...e,
            isSelected: e.Id === id,
            cardClass:  e.Id === id ? 'emp-card emp-card--active' : 'emp-card',
        }));
        this._loadData(id);
    }

    /* ── Load all records for selected employee ── */
    async _loadData(contactId) {
        this.isLoading = true;
        try {
            const [att, ts, entries, lv, sum] = await Promise.all([
                getAttendanceRecords({ contactId }),
                getTimesheetRecords({ contactId }),       // Timesheet__c parent rows
                getTimesheetEntries({ contactId }),       // TimesheetEntry__c detail rows
                getLeaveRequests({ contactId }),
                getMonthlyAttendanceSummary({ contactId }),
            ]);

            /* ── Employee_Attendance__c ── */
            this.attendanceRecords = att.map(r => ({
                ...r,
                displayDate:    this._fmtDate(r.Date__c),
                //displayDay:     this._fmtDay(r.Attendance_Date__c),
                displayCheckIn:  r.Check_In_Time__c  ? this._fmtTime(r.Check_In_Time__c)  : '—',
                displayCheckOut: r.Check_Out_Time__c ? this._fmtTime(r.Check_Out_Time__c) : '—',
                displayHours:    r.Work_Duration__c  ? `${r.Work_Duration__c}h`           : '—',
                statusBadge:    `status-badge status-${(r.Status__c || '').toLowerCase().replace(/\s+/g, '_')}`,
            }));

            /* ── Timesheet__c (parent headers) ── */
            this.timesheetRecords = ts.map(r => ({
                ...r,
                displayEndDate:  this._fmtDate(r.End_Date__c),
                employeeName:    r.Employee__r?.Name || '—',
                approvedByName:  r.Approved_By__r?.Name || '—',
                rejectedByName:  r.Rejected_By__r?.Name || '—',
                approvalBadge:   `status-badge status-${(r.Approval_Status__c || '').toLowerCase().replace(/\s+/g, '_')}`,
                // attach related entries
                entries:         entries
                    .filter(e => e.Timesheet__c === r.Id)
                    .map(e => ({
                        ...e,
                        displayDate:   this._fmtDate(e.Date__c),
                        displayStart:  e.Start_Time__c ? this._fmtTime(e.Start_Time__c) : '—',
                        displayEnd:    e.End_Time__c   ? this._fmtTime(e.End_Time__c)   : '—',
                        regularHrs:    e.Regular_Hours__c  ? `${e.Regular_Hours__c}h`  : '—',
                        overtimeHrs:   e.Overtime_Hours__c ? `${e.Overtime_Hours__c}h` : '—',
                        totalHrs:      e.Total_Hours__c    ? `${e.Total_Hours__c}h`    : '—',
                        projectName:   e.Project__r?.Name || e.Project__c || '—',
                        statusBadge:   `status-badge status-${(e.Status__c || '').toLowerCase()}`,
                        approvalBadge: `status-badge status-${(e.Approval_Status__c || '').toLowerCase().replace(/\s+/g, '_')}`,
                    })),
                isExpanded: false,
            }));

            /* ── Leave_Request__c ── */
            this.leaveRequests = lv.map(r => ({
                ...r,
                displayFrom:  this._fmtDate(r.Start_Date__c),
                displayTo:    this._fmtDate(r.End_Date__c),
                displayDays:  r.Total_Days__c ? `${r.Total_Days__c}d` : '—',
                isPending:    (r.Status__c || '').toLowerCase() === 'pending',
                statusBadge:  `status-badge status-${(r.Status__c || '').toLowerCase()}`,
                cardClass:    `leave-card leave-card--${(r.Status__c || 'pending').toLowerCase()}`,
            }));

            /* ── Monthly Summary ── */
            this.attendanceSummary = { ...sum, rateDisplay: `${sum.rate}%` };

        } catch (e) {
            this._toast('Error loading records', e.body?.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /* ── Tabs ── */
    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }
    get isAttendanceTab() { return this.activeTab === 'attendance'; }
    get isTimesheetTab()  { return this.activeTab === 'timesheet';  }
    get isLeaveTab()      { return this.activeTab === 'leave';      }
    get tabAttClass()  { return `tab-btn${this.activeTab === 'attendance' ? ' tab-active' : ''}`; }
    get tabTsClass()   { return `tab-btn${this.activeTab === 'timesheet'  ? ' tab-active' : ''}`; }
    get tabLvClass()   { return `tab-btn${this.activeTab === 'leave'      ? ' tab-active' : ''}`; }

    /* ── Expand/collapse timesheet row ── */
    handleSheetExpand(event) {
        const id = event.currentTarget.dataset.id;
        this.timesheetRecords = this.timesheetRecords.map(r => ({
            ...r,
            isExpanded: r.Id === id ? !r.isExpanded : r.isExpanded,
            expandIcon: r.Id === id ? (r.isExpanded ? '▶' : '▼') : (r.isExpanded ? '▼' : '▶'),
        }));
    }

    /* ── Leave approve / reject ── */
    async handleApprove(event) { await this._doLeave(event.currentTarget.dataset.id, 'Approved'); }
    async handleReject(event)  { await this._doLeave(event.currentTarget.dataset.id, 'Rejected'); }

    async _doLeave(id, status) {
        try {
            await updateLeaveStatus({ leaveRequestId: id, newStatus: status, comments: '' });
            this._toast('Done', `Leave request ${status.toLowerCase()} successfully.`, 'success');
            const lv = await getLeaveRequests({ contactId: this.selectedEmpId });
            this.leaveRequests = lv.map(r => ({
                ...r,
                displayFrom:  this._fmtDate(r.Start_Date__c),
                displayTo:    this._fmtDate(r.End_Date__c),
                displayDays:  r.Total_Days__c ? `${r.Total_Days__c}d` : '—',
                isPending:    (r.Status__c || '').toLowerCase() === 'pending',
                statusBadge:  `status-badge status-${(r.Status__c || '').toLowerCase()}`,
                cardClass:    `leave-card leave-card--${(r.Status__c || '').toLowerCase()}`,
            }));
        } catch (e) {
            this._toast('Error', e.body?.message, 'error');
        }
    }

    /* ── Computed ── */
    get teamCount()         { return this.teamMembers.length; }
    get hasTeam()           { return this.teamMembers.length > 0; }
    get hasAttendance()     { return this.attendanceRecords.length > 0; }
    get hasTimesheet()      { return this.timesheetRecords.length > 0; }
    get hasLeave()          { return this.leaveRequests.length > 0; }
    get pendingCount()      { return this.leaveRequests.filter(l => l.isPending).length; }
    get hasPending()        { return this.pendingCount > 0; }

    /* ── Helpers ── */
    _initials(name) {
        return (name || '').replace(/^(Ms\.|Mr\.|Dr\.)\s*/i, '')
            .split(' ').slice(0, 2).map(n => n[0] || '').join('').toUpperCase();
    }
    _fmtDate(d) {
        if (!d) return '—';
        return new Date(d).toLocaleDateString('en-IN',
            { day: '2-digit', month: 'short', year: 'numeric' });
    }
    _fmtDay(d) {
        if (!d) return '—';
        return new Date(d).toLocaleDateString('en-IN', { weekday: 'short' });
    }
    _fmtTime(t) {
        if (!t) return '—';
        const p = String(t).split(':');
        let h = parseInt(p[0] || 0);
        const m = p[1] || '00';
        const ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12 || 12;
        return `${h}:${m} ${ampm}`;
    }
    _toast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg || '', variant }));
    }
}