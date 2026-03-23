import { LightningElement, api, track, wire } from 'lwc';
import getProjects from '@salesforce/apex/TimesheetController.getProjects';
import createTimesheetEntry from '@salesforce/apex/TimesheetController.createTimesheetEntry';
import updateTimesheetEntry from '@salesforce/apex/TimesheetController.updateTimesheetEntry';
import getStatusPicklistValues from '@salesforce/apex/TimesheetController.getStatusPicklistValues';
import createMultipleTimesheetEntries from '@salesforce/apex/TimesheetController.createMultipleTimesheetEntries';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningAlert from 'lightning/alert';

export default class TimesheetEntryModal extends LightningElement {
    _entry;
    @api set entry(value) { this._entry = value; this.initializeEntry(value); }
    get entry() { return this._entry; }

    @api isOpen = false;
    @track isSaving = false;
    @track warningMessage = '';  // For inline warning messages

    get maxDate() {
        return new Date().toISOString().split('T')[0];
    }
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
            startTime: null,  // Blank for user to enter
            endTime: null,    // Blank for user to enter
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
            this.rows = [this.createEmptyRow()];
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
            return String(sfTime.hours).padStart(2, '0') + ':' + String(sfTime.minutes || 0).padStart(2, '0');
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
            const start = parseInt(sh, 10) * 60 + parseInt(sm, 10);
            const end = parseInt(eh, 10) * 60 + parseInt(em, 10);
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
            //this.showToast('Error', 'Please fill required fields (Date, Project, Task).', 'error'); return;
            await this.showToast('Error', 'Please fill required fields (Date, Project, Task)', 'error');
            return;
        }

        // Normalize date -> YYYY-MM-DD
        let normalizedDate = this.normalizeDate(this.entryDate);
        if (!normalizedDate) { this.showToast('Error', 'Invalid date format', 'error'); return; }

        const normalizeTime = t => {
            if (!t) return null;
            if (/^\d{2}:\d{2}$/.test(t)) return t;
            const parts = String(t).split(':');
            if (parts.length >= 2) return String(parts[0]).padStart(2, '0') + ':' + String(parts[1]).padStart(2, '0');
            return null;
        };

        const st = normalizeTime(this.startTime);
        const et = normalizeTime(this.endTime);
        if (st && et) {
            const [sh, sm] = st.split(':'), [eh, em] = et.split(':');
            if ((parseInt(eh, 10) * 60 + parseInt(em, 10)) < (parseInt(sh, 10) * 60 + parseInt(sm, 10))) {
                this.showToast('Error', 'End time must be after start time', 'error'); return;
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
        console.log('Saving entry with fields1', JSON.stringify(fields));
        console.log('Entry ID:', this.entryId);
        this.isSaving = true;
        try {
            if (this.entryId) {
                console.log('Updating entry ID:', this.entryId);
                fields.Id = this.entryId;
                console.log('Fields to update:', JSON.stringify(fields));
                await updateTimesheetEntry({ fields: fields });
                // Close modal and reset state BEFORE showing alert
                this.isSaving = false;
                this.handleClose();
                this.dispatchEvent(new CustomEvent('entrycreated'));
                await this.showToast('Success', 'Timesheet entry updated successfully', 'success');
            } else {
                // call single-entry create; the Apex controller delegates to multi-row internally
                await createTimesheetEntry({ newEntryFields: fields });
                // Close modal and reset state BEFORE showing alert
                this.isSaving = false;
                this.handleClose();
                this.dispatchEvent(new CustomEvent('entrycreated'));
                await this.showToast('Success', 'Timesheet entry created successfully', 'success');
            }
        } catch (err) {
            this.isSaving = false;
            await this.showToast('Error', 'Failed to save entry: ' + this.extractErrorMessage(err), 'error');
            console.error('saveEntry error', err);
        }
    }

    /* ================= Multi-row handlers ================= */
    addRow() { this.rows = [...this.rows, this.createEmptyRow()]; }

    deleteRow(event) {
        // event comes from lightning-button-icon; dataset on the button is used
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (this.rows.length === 1) {
            // Show inline warning instead of alert (which appears behind modal)
            this.warningMessage = 'At least one row is required';
            // Auto-clear after 3 seconds
            setTimeout(() => { this.warningMessage = ''; }, 3000);
            return;
        }
        this.warningMessage = '';  // Clear any existing warning
        const c = [...this.rows]; c.splice(idx, 1); this.rows = c;
    }

    handleRowChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        const copy = [...this.rows];
        const row = { ...copy[idx] };
        if (field === 'projectId') {
            row.projectId = value;
            const proj = this.projectOptions.find(p => p.value === value);
            row.employmentStatus = proj ? proj.employmentStatus : '';
            console.log('row.employmentStatus' + row.employmentStatus)
        } else if (field === 'date') {
            row.date = value;
            // Weekend validation
            if (value) {
                const selectedDate = new Date(value);
                const dayOfWeek = selectedDate.getDay(); // 0 = Sunday, 6 = Saturday
                if (dayOfWeek === 0 || dayOfWeek === 6) {
                    event.target.setCustomValidity('Weekends (Sat/Sun) are not allowed');
                } else {
                    event.target.setCustomValidity(''); // Clear error
                }
                event.target.reportValidity();
            }
        }
        else if (field === 'startTime') row.startTime = value;
        else if (field === 'endTime') row.endTime = value;
        else if (field === 'task') row.task = value ? value.trim() : '';
        else if (field === 'description') row.description = value ? value.trim() : '';
        else if (field === 'status') row.status = value;
        copy[idx] = row; this.rows = copy;
        if (field === 'startTime' || field === 'endTime') this.calculateRowHours(idx);
    }

    // Helper to check if a date is a weekend
    isWeekend(dateString) {
        if (!dateString) return false;
        const date = new Date(dateString);
        const day = date.getDay();
        return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
    }

    calculateRowHours(index) {
        const copy = [...this.rows]; const row = { ...copy[index] };
        if (row.startTime && row.endTime) {
            const [sh, sm] = row.startTime.split(':'); const [eh, em] = row.endTime.split(':');
            const start = parseInt(sh, 10) * 60 + parseInt(sm, 10);
            const end = parseInt(eh, 10) * 60 + parseInt(em, 10);
            const totalM = Math.max(0, end - start); const total = Math.round((totalM / 60) * 100) / 100;
            row.totalHours = total;
            row.regularHours = Math.round((total > 8 ? 8 : total) * 100) / 100;
            row.overtimeHours = Math.round((total > 8 ? total - 8 : 0) * 100) / 100;
        } else {
            row.totalHours = row.regularHours = row.overtimeHours = 0;
        }
        copy[index] = row; this.rows = copy;
    }

    /*async saveAllEntries() {
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
}*/

    async saveAllEntries() {
        console.log('this.rows: ' + JSON.stringify(this.rows));

        if (!this.rows || this.rows.length === 0) {
            await this.showToast('Error', 'Please add at least one row.', 'error');
            return;
        }

        // --- STEP 1: UI VALIDATION (Highlighting red boxes with inline errors) ---
        // This finds all inputs/comboboxes in your HTML and triggers their built-in validation
        const allValid = [
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-combobox'),
            ...this.template.querySelectorAll('lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid) {
            // Inline validation messages will show at each field
            return;
        }

        // --- STEP 2: PAYLOAD BUILDING ---
        const payload = [];
        for (let i = 0; i < this.rows.length; i++) {
            const r = this.rows[i];

            // Manual check for required data logic
            if (!r.date || !r.projectId || !r.task || !r.status) {
                await this.showToast('Error', `Row ${i + 1}: Date, Project, Task and Status are required.`, 'error');
                return;
            }

            const normalized = this.normalizeDate(r.date);
            const st = this.formatTimeString(r.startTime);
            const et = this.formatTimeString(r.endTime);

            // Time logic check
            if (st && et) {
                const [sh, sm] = st.split(':'), [eh, em] = et.split(':');
                if ((parseInt(eh, 10) * 60 + parseInt(em, 10)) < (parseInt(sh, 10) * 60 + parseInt(sm, 10))) {
                    await this.showToast('Error', `Row ${i + 1}: End time must be after start time.`, 'error');
                    return;
                }
            }

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

        // --- STEP 3: SERVER CALL ---
        this.isSaving = true;
        try {
            const ids = await createMultipleTimesheetEntries({ rows: payload });
            const successMsg = ids.length === 1
                ? 'Timesheet entry created successfully'
                : `${ids.length} Timesheet entries created successfully`;
            // Close modal and reset state BEFORE showing alert (so "Saving..." doesn't persist)
            this.isSaving = false;
            this.handleClose();
            this.dispatchEvent(new CustomEvent('entrycreated'));
            // Show success alert after modal is closed
            await this.showToast('Success', successMsg, 'success');
        } catch (err) {
            // Capture Apex Errors
            this.isSaving = false;
            const errorMsg = 'Failed to create entries: ' + this.extractErrorMessage(err);
            await this.showToast('Error', errorMsg, 'error');
            console.error('Save Error', err);
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
            return dt.toISOString().slice(0, 10);
        } catch (e) { return null; }
    }

    extractErrorMessage(error) {
        try {
            if (error && error.body && error.body.message) return error.body.message;
            if (error && error.message) return error.message;
            if (typeof error === 'string') return error;
        } catch (e) { }
        return 'Unknown error';
    }

    handleClose() { this.isOpen = false; this.dispatchEvent(new CustomEvent('close')); }
    /*showToast(title,msg,variant) { 
       this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant })); }*/
    async showToast(title, msg, variant) {
        await LightningAlert.open({
            message: msg,
            theme: variant, // success | error | warning | info
            label: title
        });
    }
    get isEditMode() { return this.entryId !== null; }
    get modalTitle() {
        return this.isEditMode ? 'Edit Timesheet Entry' : 'New Timesheet Entries';
    }
}