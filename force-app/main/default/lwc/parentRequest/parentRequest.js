import { LightningElement, wire, track, api } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import getAllowedRequests from '@salesforce/apex/WFH_Request.getAllowedRequests';

export default class ParentRequestContainer extends LightningElement {
    @api employeeId;
    @api employeeName;

    @track allowedRequests = [];
    @track activeTab = '';
    @track _pendingSubTab = '';    

    @wire(getAllowedRequests, { userId: USER_ID })
    wiredAccess({ data, error }) {
        if (data) {
            this.allowedRequests = data;
            this.activeTab = data.length ? data[0].toLowerCase() : '';
        } else if (error) {
            console.error(error);
        }
    }

        
    // ✅ Accept active-sub-tab from dashboard
    @api
    get activeSubTab() {
        return this._activeSubTab;
    }
    set activeSubTab(value) {
        this._activeSubTab = value;
        if (value) {
            this._pendingSubTab = value;
            this.activeTab = value;   // set immediately
            console.log('📌 activeSubTab set to:', value);
        }
    }
    _activeSubTab = '';

    // ✅ Also apply after render to handle timing issues
    renderedCallback() {
        if (this._pendingSubTab) {
            this.activeTab = this._pendingSubTab;
            this._pendingSubTab = '';
        }
    }


    /* ===== Visibility Flags ===== */
    get showLeave() {
        return this.allowedRequests.includes('Leave');
    }

    get showHybrid() {
        return this.allowedRequests.includes('Hybrid');
    }

    get showWFH() {
        return this.allowedRequests.includes('WFH');
    }

    get hasAccess() {
        return this.allowedRequests.length > 0;
    }
}

