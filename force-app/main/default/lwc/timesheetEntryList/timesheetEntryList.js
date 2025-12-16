import { LightningElement, track, api,wire } from 'lwc';


export default class TimesheetEntryList extends LightningElement {
    @api entries = [];
    @track currentPage = 1;
    pageSize = 10;

    // Compute total pages
    get totalPages() {
        return Math.ceil(this.entries.length / this.pageSize);
    }

    // Slice entries for current page
    get paginatedEntries() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.entries.slice(start, start + this.pageSize);
      
    }

    // Getters for pagination button disabled state
    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }



    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    editEntry(event) {
        const entryId = event.target.dataset.id;
        const entry = this.entries.find(e => e.id === entryId);
        if (entry) {
            // Create a complete entry object with all necessary fields
            const entryToEdit = {
                Id: entry.id,
                Date__c: entry.date,
                Project__c: entry.projectId,
                Task__c: entry.task,
                Start_Time__c: entry.startTime,
                End_Time__c: entry.endTime,
                Regular_Hours__c: entry.hours,
                Overtime_Hours__c: entry.overtime,
                Status__c: entry.status,
                Approval_Status__c: entry.approvalStatus || 'Draft',
                Billing_Status__c: entry.employmentStatus, 
                Description__c: entry.description,
                // Include any other fields needed by the modal
                project: entry.project,
                startTime: entry.startTime,
                endTime: entry.endTime,
                hours: entry.hours,
                overtime: entry.overtime,
                date: entry.date
            };
        this.dispatchEvent(new CustomEvent('editentry', {
            detail: { entry },
            bubbles: true,
            composed: true
        }));
    }
}
    
    deleteEntry(event) {
        const entryId = event.target.dataset.id;
        this.dispatchEvent(new CustomEvent('refreshentries', {
            detail: { entryId },
            bubbles: true,
            composed: true
        }));
    }
   
}