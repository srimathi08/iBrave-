/*import { LightningElement, api, track, wire } from 'lwc';
import getProjects from '@salesforce/apex/TimesheetController.getProjects';
import createTimesheetEntry from '@salesforce/apex/TimesheetController.createTimesheetEntry';
import updateTimesheetEntry from '@salesforce/apex/TimesheetController.updateTimesheetEntry';
import getStatusPicklistValues from '@salesforce/apex/TimesheetController.getStatusPicklistValues';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TimesheetEntryModal extends LightningElement {
    _entry;

@api
set entry(value) {
    this._entry = value;
    this.initializeEntry(value);
}
get entry() {
    return this._entry;
}

    @api isOpen = false;
    //@api modalEntry = null; // Use this to pre-populate for editing
    @track entryId = null;
    @track entryDate;
    @track entryProject;
    @track startTime = '09:30';
    @track endTime = '18:30';
    @track task;
    @track description;
    @track regularHours = 0;
    @track overtimeHours = 0;
    @track totalHours = 0;
    @track projectOptions = [];
    @track status;
    @track statusOptions = [];
    @track approvalStatus = 'Draft';
    @track employmentStatus = ''; // Holds Billable / Non-Billable


    // Wire method to get project options
    @wire(getProjects)
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = data;
        } else if (error) {
            console.error('Error fetching projects:', error);
        }
    }
@wire(getStatusPicklistValues)
wiredStatusPicklist({ error, data }) {
    if (data) {
        this.statusOptions = data.map(option => ({
            label: option,
            value: option
        }));
    } else if (error) {
        console.error('Error loading status picklist values', error);
    }
}

    // Lifecycle hook to handle modal opening and pre-populate if editing
    
   formatTimeString(sfTime) {
    // Handles null, undefined, Salesforce Time, '09:00:00.000Z', '09:00:00', '09:00'
    if (!sfTime) return null;
    if (typeof sfTime === 'string') {
        // If already 'HH:mm'
        if (sfTime.length === 5 && /^\d{2}:\d{2}$/.test(sfTime)) {
            return sfTime;
        }
        // If 'HH:mm:ss' or 'HH:mm:ss.SSSZ'
        const match = sfTime.match(/^(\d{2}):(\d{2})/);
        if (match) return `${match[1]}:${match[2]}`;
    }
    // If it's a Salesforce Time object, convert to 'HH:mm'
    if (typeof sfTime === 'object' && sfTime.hours !== undefined && sfTime.minutes !== undefined) {
        const hh = String(sfTime.hours).padStart(2, '0');
        const mm = String(sfTime.minutes).padStart(2, '0');
        return `${hh}:${mm}`;
    }
    return null;
}

initializeEntry(entry) {
    if (entry) {
        this.entryId      = entry.id || entry.Id || null;
        this.entryDate    = entry.Date__c || entry.date || null;
        this.entryProject = entry.Project__c || entry.projectId || null;
        this.startTime    = this.formatTimeString(entry.Start_Time__c || entry.startTime) || '09:00';
        this.endTime      = this.formatTimeString(entry.End_Time__c || entry.endTime)   || '18:00';
        this.task         = entry.Task__c || entry.task || '';
        this.description  = entry.Description__c || entry.description || '';
        this.regularHours = entry.Regular_Hours__c || entry.regularHours || 0;
        this.overtimeHours= entry.Overtime_Hours__c || entry.overtimeHours || 0;
        this.totalHours   = entry.Total_Hours__c || entry.totalHours || 0;
        this.status       = entry.Status__c || entry.status || null;
        this.approvalStatus = entry.Approval_Status__c || entry.approvalStatus || 'Draft';
        this.employmentStatus = entry.Billing_Status__c || entry.employmentStatus || '';
    } else {
        this.entryId = null;
        this.entryDate = null;
        this.entryProject = null;
        this.startTime = '09:30';
        this.endTime = '18:30';
        this.task = '';
        this.description = '';
        this.regularHours = 0;
        this.overtimeHours = 0;
        this.totalHours = 0;
        this.status = null;
        this.approvalStatus = 'Draft';
    }
}

    handleInputChange(event) {
        const field = event.target.label;
        const value = event.target.value;
        
        switch (field) {
            case 'Date':
                this.entryDate = value;
                break;
            case 'Project *': // Use the full label as in your HTML
                this.entryProject = value;
                const selectedProj = this.projectOptions.find(p => p.value === value);
            if (selectedProj) {
                this.employmentStatus = selectedProj.employmentStatus;
            } else {
                this.employmentStatus = '';
            }
                break;
            case 'Start Time':
                this.startTime = value;
                break;
            case 'End Time':
                this.endTime = value;
                break;
            case 'Task *': // Use the full label
                this.task = value;
                break;
            case 'Description':
                this.description = value;
                break;
            case 'Status *':  // Add this case
            this.status = value;
            break;
        }
        
        this.calculateHours();
    }

    calculateHours() {
        if (this.startTime && this.endTime) {
            
            const [startH, startM] = this.startTime.split(':');
            const [endH, endM] = this.endTime.split(':');
            const startMinutes = parseInt(startH, 10) * 60 + parseInt(startM, 10);
            const endMinutes = parseInt(endH, 10) * 60 + parseInt(endM, 10);
            const totalMinutes = Math.max(0, endMinutes - startMinutes);
            const totalHoursCalc = totalMinutes / 60;
            this.totalHours = totalHoursCalc;
            this.regularHours = totalHoursCalc > 8 ? 8 : totalHoursCalc;
            this.overtimeHours = totalHoursCalc > 8 ? totalHoursCalc - 8 : 0;
        } else {
            this.totalHours = 0;
            this.regularHours = 0;
            this.overtimeHours = 0;
        }
    }

    saveEntry() {
        // Validate required fields
        if (!this.entryDate || !this.entryProject || !this.task) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return;
        }

        const fields = {
            //'Id': this.entryId,
            'Date__c': this.entryDate,
            'Project__c': this.entryProject,
            'Start_Time__c': this.startTime,
            'End_Time__c': this.endTime,
            'Task__c': this.task,
            'Description__c': this.description,
             'Status__c': this.status, 
            'Regular_Hours__c': this.regularHours,
            'Overtime_Hours__c': this.overtimeHours,
            'Total_Hours__c': this.totalHours,
            'Billing_Status__c':this.employmentStatus,
            'Approval_Status__c': this.approvalStatus
        };
if (this.entryId) {
             fields.Id = this.entryId;
            updateTimesheetEntry({ entryFields: fields })
                .then(() => {
                    this.showToast('Success', 'Timesheet entry updated.', 'success');
                    this.handleClose();
                    this.dispatchEvent(new CustomEvent('entrycreated'));
                })
                .catch(error => {
    this.showToast('Error', 'Failed to update entry: ' + this.extractErrorMessage(error), 'error');
});
        } else {
       createTimesheetEntry({ newEntryFields: fields })
            .then(() => {
                this.showToast('Success', 'Timesheet entry created.', 'success');
                this.handleClose(); // Close modal
                this.dispatchEvent(new CustomEvent('entrycreated')); // Notify parent to refresh
            })
            .catch(error => {
                this.showToast('Error', 'Failed to create entry: ' + error.body.message, 'error');
            });
        }
            
    }
extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        } else if (error && error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
    handleClose() {
        this.isOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
    }


    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
    get modalTitle() {
        return this.entryId ? 'Edit Timesheet Entry' : 'New Timesheet Entry';
    }
get modalSubtitle() {
    return this.entryId ? 'Update your work details.' : 'Fill in your work details.';
}
    get saveButtonLabel() {
        return this.entryId ? 'Update' : 'Save';
    }

}*/
import { LightningElement, api, track, wire } from 'lwc';
import getProjects from '@salesforce/apex/TimesheetController.getProjects';
import createTimesheetEntry from '@salesforce/apex/TimesheetController.createTimesheetEntry';
import updateTimesheetEntry from '@salesforce/apex/TimesheetController.updateTimesheetEntry';
import getStatusPicklistValues from '@salesforce/apex/TimesheetController.getStatusPicklistValues';
import createMultipleTimesheetEntries from '@salesforce/apex/TimesheetController.createMultipleTimesheetEntries';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TimesheetEntryModal extends LightningElement {
    _entry;
    @api set entry(value) { this._entry = value; this.initializeEntry(value); }
    get entry() { return this._entry; }

    @api isOpen = false;
    @track isSaving = false;

    // single-entry fields
    @track entryId = null;
    @track entryDate; entryProject; startTime = '09:30'; endTime = '18:30';
    @track task; description; regularHours = 0; overtimeHours = 0; totalHours = 0;
    @track projectOptions = []; status; statusOptions = []; approvalStatus = 'Draft'; employmentStatus = '';

    // multi-row
    @track rows = []; rowIdCounter = 0;

    /* -------------------------
       Wire: Projects (normalize to label/value)
       ------------------------- */
    @wire(getProjects) wiredProjects({ error, data }) {
        if (data) {
            // Apex returns list of maps. Normalize to combobox friendly objects.
            try {
                this.projectOptions = data.map(d => {
                    // d may be a plain object with label/value/employmentStatus or {Name, Id}
                    const label = d.label || d.Name || d.name || '';
                    const value = d.value || d.Id || d.id || '';
                    const employmentStatus = d.employmentStatus || d.employmentstatus || d.Employment_Status__c || '';
                    return { label: String(label), value: String(value), employmentStatus: employmentStatus };
                }).filter(o => o.label && o.value);
            } catch (e) {
                console.error('Normalization failed for projects', e);
                this.projectOptions = data; // fallback
            }
        } else if (error) {
            if (error) {
    this.showToast('Error', 'getProjects error: ' + JSON.stringify(error), 'error');
    this.projectOptions = [];
}

            console.error('getProjects error', error);
            this.projectOptions = [];
        }
    }

    /* -------------------------
       Wire: Status picklist -> label/value form
       ------------------------- */
    @wire(getStatusPicklistValues) wiredStatus({ error, data }) {
        if (data) {
            this.statusOptions = data.map(s => ({ label: s, value: s }));
        } else if (error) {
            console.error('status picklist error', error);
            this.statusOptions = [];
        }
    }

    createEmptyRow() {
        return {
            clientKey: 'r-' + (this.rowIdCounter++),
            date: null,
            projectId: null,
            employmentStatus: '',
            startTime: '09:30',
            endTime: '18:30',
            task: '',
            description: '',
            status: null,
            regularHours: 0,
            overtimeHours: 0,
            totalHours: 0,
            approvalStatus: 'Draft'
        };
    }

    initializeEntry(entry) {
        if (entry) {
            console.log('Initializing modal in edit mode with entry', JSON.stringify(entry));
            // edit mode
            this.entryId = entry.Id || entry.id || null;
            this.entryDate = entry.Date__c || entry.date || null;
            this.entryProject = entry.Project__c || entry.projectId || null;
            this.startTime = (entry.Start_Time__c || entry.startTime ? this.formatTimeString(entry.Start_Time__c || entry.startTime) : '09:30');
            this.endTime = (entry.End_Time__c || entry.endTime ? this.formatTimeString(entry.End_Time__c || entry.endTime) : '18:30');
            this.task = entry.Task__c || entry.task || '';
            this.description = entry.Description__c || entry.description || '';
            this.regularHours = entry.Regular_Hours__c || entry.hours || 0;
            this.overtimeHours = entry.Overtime_Hours__c || entry.overtime || 0;
            this.totalHours = entry.Total_Hours__c || entry.totalHours || 0;
            this.status = entry.Status__c || entry.status || null;
            this.approvalStatus = entry.Approval_Status__c || entry.approvalStatus || 'Draft';
            this.employmentStatus = entry.Billing_Status__c || entry.employmentStatus || '';
            this.rows = [];
        } else {
            // new multi-row
            this.entryId = null;
            this.entryDate = null; this.entryProject = null; this.startTime = '09:30'; this.endTime = '18:30';
            this.task = ''; this.description = ''; this.regularHours = 0; this.overtimeHours = 0; this.totalHours = 0;
            this.status = null; this.approvalStatus = 'Draft'; this.employmentStatus = '';
            this.rows = [ this.createEmptyRow() ];
        }
    }

    formatTimeString(sfTime) {
        if (!sfTime) return null;
        if (typeof sfTime === 'string') {
            const m = sfTime.match(/^(\d{2}):(\d{2})/);
            if (m) return `${m[1]}:${m[2]}`;
            return sfTime;
        }
        if (typeof sfTime === 'object' && sfTime.hours !== undefined) {
            return String(sfTime.hours).padStart(2,'0') + ':' + String(sfTime.minutes || 0).padStart(2,'0');
        }
        return null;
    }

    /* ================= Single-entry handlers ================= */
    handleInputChange(event) {
        // Note: using label is fine for single inputs in your current HTML, but we also
        // guard on input name/data attributes if you change labels later.
        const label = event.target.label;
        const name = event.target.name;
        const value = event.target.value;

        // Project combobox sets employmentStatus from projectOptions
        if (label === 'Project *' || name === 'entryProject') {
            this.entryProject = value;
            const sel = this.projectOptions.find(p => p.value === value);
            this.employmentStatus = sel ? sel.employmentStatus : '';
        } else if (label === 'Date' || name === 'entryDate') {
            this.entryDate = value;
        } else if (label === 'Start Time') {
            this.startTime = value;
        } else if (label === 'End Time') {
            this.endTime = value;
        } else if (label === 'Task *') {
            this.task = value;
        } else if (label === 'Description') {
            this.description = value;
        } else if (label === 'Status *' || name === 'entryStatus') {
            this.status = value;
        }
        this.calculateHours();
    }

    calculateHours() {
        if (this.startTime && this.endTime) {
            const [sh, sm] = this.startTime.split(':'); const [eh, em] = this.endTime.split(':');
            const start = parseInt(sh,10)*60 + parseInt(sm,10);
            const end = parseInt(eh,10)*60 + parseInt(em,10);
            const totalM = Math.max(0, end - start);
            const total = totalM / 60;
            this.totalHours = Math.round(total * 100) / 100;
            this.regularHours = Math.round((total > 8 ? 8 : total) * 100) / 100;
            this.overtimeHours = Math.round((total > 8 ? total - 8 : 0) * 100) / 100;
        } else {
            this.totalHours = this.regularHours = this.overtimeHours = 0;
        }
    }

    async saveEntry() {
        // Validate required
        if (!this.entryDate || !this.entryProject || !this.task) {
            this.showToast('Error','Please fill required fields (Date, Project, Task).','error'); return;
        }

        // Normalize date -> YYYY-MM-DD
        let normalizedDate = this.normalizeDate(this.entryDate);
        if (!normalizedDate) { this.showToast('Error','Invalid date format','error'); return; }

        const normalizeTime = t => {
            if (!t) return null;
            if (/^\d{2}:\d{2}$/.test(t)) return t;
            const parts = String(t).split(':');
            if (parts.length>=2) return String(parts[0]).padStart(2,'0') + ':' + String(parts[1]).padStart(2,'0');
            return null;
        };

        const st = normalizeTime(this.startTime);
        const et = normalizeTime(this.endTime);
        if (st && et) {
            const [sh,sm] = st.split(':'), [eh,em] = et.split(':');
            if ((parseInt(eh,10)*60+parseInt(em,10)) < (parseInt(sh,10)*60+parseInt(sm,10))) {
                this.showToast('Error','End time must be after start time','error'); return;
            }
        }

        const fields = {
            Date__c: normalizedDate,
            Project__c: this.entryProject,
            Start_Time__c: st,
            End_Time__c: et,
            Task__c: (this.task || '').trim(),
            Description__c: (this.description || '').trim(),
            Status__c: this.status || (this.statusOptions.length ? this.statusOptions[0].value : null),
            Regular_Hours__c: this.regularHours || 0,
            Overtime_Hours__c: this.overtimeHours || 0,
            Total_Hours__c: this.totalHours || 0,
            Billing_Status__c: this.employmentStatus || null,
            Approval_Status__c: this.approvalStatus || 'Draft'
        };
        console.log('Saving entry with fields', fields);
        console.log('Saving entry with fields1',JSON.stringify(fields));
        console.log('Entry ID:', this.entryId);
        this.isSaving = true;
        try {
            if (this.entryId) {
                console.log('Updating entry ID:', this.entryId);
                fields.Id = this.entryId;
                console.log('Fields to update:', JSON.stringify(fields));
                await updateTimesheetEntry({ fields: fields });
                this.showToast('Success','Timesheet entry updated','success');
            } else {
                // call single-entry create; the Apex controller delegates to multi-row internally
                const id = await createTimesheetEntry({ newEntryFields: fields });
                if (id) this.showToast('Success','Timesheet entry created','success');
                else this.showToast('Success','Timesheet entry created','success');
            }
            this.handleClose();
            this.dispatchEvent(new CustomEvent('entrycreated'));
        } catch (err) {
            this.showToast('Error','Failed to save entry: ' + this.extractErrorMessage(err), 'error');
            console.error('saveEntry error', err);
        } finally {
            this.isSaving = false;
        }
    }

    /* ================= Multi-row handlers ================= */
    addRow() { this.rows = [...this.rows, this.createEmptyRow()]; }

    deleteRow(event) {
        // event comes from lightning-button-icon; dataset on the button is used
        const idx = parseInt(event.currentTarget.dataset.index,10);
        if (this.rows.length === 1) { this.showToast('Warning','At least one row required','warning'); return; }
        const c = [...this.rows]; c.splice(idx,1); this.rows = c;
    }

    handleRowChange(event) {
        const idx = parseInt(event.target.dataset.index,10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        const copy = [...this.rows];
        const row = { ...copy[idx] };
        if (field === 'projectId') {
            row.projectId = value;
            const proj = this.projectOptions.find(p => p.value === value);
            row.employmentStatus = proj ? proj.employmentStatus : '';
            console.log( 'row.employmentStatus'+row.employmentStatus )
        } else if (field === 'date') row.date = value;
        else if (field === 'startTime') row.startTime = value;
        else if (field === 'endTime') row.endTime = value;
        else if (field === 'task') row.task = value ? value.trim() : '';
        else if (field === 'description') row.description = value ? value.trim() : '';
        else if (field === 'status') row.status = value;
        copy[idx] = row; this.rows = copy;
        if (field === 'startTime' || field === 'endTime') this.calculateRowHours(idx);
    }

    calculateRowHours(index) {
        const copy = [...this.rows]; const row = { ...copy[index] };
        if (row.startTime && row.endTime) {
            const [sh, sm] = row.startTime.split(':'); const [eh, em] = row.endTime.split(':');
            const start = parseInt(sh,10)*60 + parseInt(sm,10);
            const end = parseInt(eh,10)*60 + parseInt(em,10);
            const totalM = Math.max(0, end - start); const total = Math.round((totalM/60) * 100) / 100;
            row.totalHours = total;
            row.regularHours = Math.round((total > 8 ? 8 : total) * 100) / 100;
            row.overtimeHours = Math.round((total > 8 ? total - 8 : 0) * 100) / 100;
        } else {
            row.totalHours = row.regularHours = row.overtimeHours = 0;
        }
        copy[index] = row; this.rows = copy;
    }

    async saveAllEntries() {
        console.log( 'this.rows'+JSON.stringify(this.rows))
    if (!this.rows || this.rows.length === 0) {
        this.showToast('Error', 'Add at least one row', 'error');
        return;
    }

    const payload = [];
    for (let i = 0; i < this.rows.length; i++) {
        const r = this.rows[i];
        if (!r.date || !r.projectId || !r.task || !r.status) {
            this.showToast('Error', `Row ${i + 1}: Date, Project, Task and Status required`, 'error');
            return;
        }
        const normalized = this.normalizeDate(r.date);
        if (!normalized) {
            this.showToast('Error', `Row ${i + 1}: invalid date`, 'error');
            return;
        }

        const normalizeTime = t => {
            if (!t) return null;
            if (/^\d{2}:\d{2}$/.test(t)) return t;
            const parts = String(t).split(':');
            if (parts.length >= 2) return String(parts[0]).padStart(2, '0') + ':' + String(parts[1]).padStart(2, '0');
            return null;
        };
        const st = normalizeTime(r.startTime), et = normalizeTime(r.endTime);
        if (st && et) {
            const [sh, sm] = st.split(':'), [eh, em] = et.split(':');
            if ((parseInt(eh, 10) * 60 + parseInt(em, 10)) < (parseInt(sh, 10) * 60 + parseInt(sm, 10))) {
                this.showToast('Error', `Row ${i + 1}: End time must be after start time`, 'error');
                return;
            }
        }
        console.log('r.wemp',r.employmentStatus)
        payload.push({
            Date__c: normalized,
            Project__c: r.projectId,
            Start_Time__c: st,
            End_Time__c: et,
            Task__c: r.task,
            Description__c: r.description || '',
            Status__c: r.status,
            Regular_Hours__c: r.regularHours || 0,
            Overtime_Hours__c: r.overtimeHours || 0,
            Total_Hours__c: r.totalHours || 0,
            Billing_Status__c: r.employmentStatus || null,
            Approval_Status__c: r.approvalStatus || 'Draft'
        });
    }
    console.log('payload'+JSON.stringify(payload))
    this.isSaving = true;
    try {
        const ids = await createMultipleTimesheetEntries({ rows: payload });
        this.showToast('Success', `${ids.length} entries created`, 'success');
        this.handleClose();
        this.dispatchEvent(new CustomEvent('entrycreated'));
    } catch (err) {
        this.showToast('Error', 'Failed to create entries: ' + this.extractErrorMessage(err), 'error');
        console.error('createMultipleTimesheetEntries error', err);
    } finally {
        this.isSaving = false;
    }
}


    normalizeDate(input) {
        // Accept YYYY-MM-DD or Date-like strings. Return YYYY-MM-DD or null.
        try {
            if (!input) return null;
            // If already in YYYY-MM-DD
            if (/^\d{4}-\d{2}-\d{2}$/.test(input)) return input;
            const dt = new Date(input);
            if (isNaN(dt.getTime())) return null;
            return dt.toISOString().slice(0,10);
        } catch (e) { return null; }
    }

    extractErrorMessage(error) {
        try {
            if (error && error.body && error.body.message) return error.body.message;
            if (error && error.message) return error.message;
            if (typeof error === 'string') return error;
        } catch(e){}
        return 'Unknown error';
    }

    handleClose() { this.isOpen = false; this.dispatchEvent(new CustomEvent('close')); }
    showToast(title,msg,variant) { this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant })); }
    get isEditMode() { return this.entryId !== null; }
    get modalTitle() { 
         return this.isEditMode ? 'Edit Timesheet Entry' : 'New Timesheet Entries';}
}