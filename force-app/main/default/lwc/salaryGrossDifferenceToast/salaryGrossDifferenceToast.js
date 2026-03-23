import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = ['Salary_Details__c.Gross_Difference__c'];

export default class SalaryGrossDifferenceToast extends LightningElement {
    @api recordId;
    toastShown = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredSalary({ error, data }) {
        if (data && !this.toastShown) {
            const grossDiff = data.fields.Gross_Difference__c.value;

            if (grossDiff !== null && grossDiff !== 0) {
                this.toastShown = true;

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Gross Salary Difference',
                        message: `Gross Salary difference is ${grossDiff}. Please adjust the salary components so that the Gross Difference becomes 0.`,
                        variant: 'warning',
                        mode: 'sticky'
                    })
                );
            }
        }

        if (error) {
            console.error('Error fetching Gross Difference', error);
        }
    }
}