import { LightningElement, track } from 'lwc';
import loginUser from '@salesforce/apex/CustomLoginController.loginUser';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomLoginForm extends NavigationMixin(LightningElement) {
    @track username = '';
    @track password = '';
    @track rememberMe = false;
    @track showError = false;
    @track errorMessage = '';

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
    }

    handleRememberMe(event) {
        this.rememberMe = event.target.checked;
    }

    async handleSubmit(event) {
        event.preventDefault();
        try {
            const result = await loginUser({ username: this.username, password: this.password });
            if(result === 'SUCCESS'){
                this.showError = false;
                // Navigate to next page/component, e.g., Check In
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: {
                        name: 'CheckIn__c' // update with your actual Experience page name
                    }
                });
            } else {
                this.showError = true;
                this.errorMessage = 'Invalid username or password';
            }
        } catch(error) {
            this.showError = true;
            this.errorMessage = 'Login failed. Please try again.';
        }
    }
}