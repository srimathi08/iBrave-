/*import { LightningElement, track } from 'lwc';
import login from '@salesforce/apex/LoginController.login';
export default class CustomLoginForm extends LightningElement {
@track username = '';
@track password = '';
handleUsernameChange(event) {
this.username = event.target.value;
}
handlePasswordChange(event) {
this.password = event.target.value;
}
handleClick(event) {
login({ username: this.username, password: this.password })
.then(result => {
if (result && this.isValidURL(result)) {
window.location.href = result;
} else {
alert(result);
}
})
.catch(error => {
alert(error.body ? error.body.message : error.message);
});
}
// Optional - To check for a valid URL before redirect
isValidURL(url) {
try {
new URL(url);
return true;
} catch (_) {
return false;
}
}
}*/
/*import { LightningElement, track } from 'lwc';
import QBLogo from '@salesforce/resourceUrl/QBLogo';
import videoURL from '@salesforce/resourceUrl/BGvideo'; // import the static resource
import login from '@salesforce/apex/LoginController.login';

export default class CustomLogin extends LightningElement {
    @track username = '';
    @track password = '';
    @track passwordFieldType = 'password';
    bgVideoUrl = `${videoURL}`; // make it accessible to template

    logoUrl = QBLogo;
     get eyeIconName() {
        return this.passwordFieldType === 'password' ? 'utility:preview' : 'utility:hide';
    }

    // Handle Username input change
    handleUsernameChange(event) {
        this.username = event.target.value;
    }

    // Handle Password input change
    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    // Toggle password field between 'password' and 'text'
    togglePasswordVisibility() {
        this.passwordFieldType = this.passwordFieldType === 'password' ? 'text' : 'password';
    }

    // Computed label for the Show/Hide button
    get passwordToggleLabel() {
        return this.passwordFieldType === 'password' ? 'SHOW' : 'HIDE';
    }

    // Handle Sign In button click
    handleLogin() {
        // Log the captured values - replace with actual login logic
        console.log('Username:', this.username);
        console.log('Password:', this.password);

        // Placeholder: add real authentication or redirect here
        alert(`Login attempted for ${this.username}`);
    }
}*/

import { LightningElement } from 'lwc';
import QBLogo from '@salesforce/resourceUrl/QBLogo';
import videoURL from '@salesforce/resourceUrl/BGvideo';
import login from '@salesforce/apex/CustomLoginController.login';
import forgotPassword from '@salesforce/apex/CustomLoginController.forgotPassword';

export default class CustomLogin extends LightningElement {
    passwordFieldType = 'password';
    bgVideoUrl = videoURL;
    logoUrl = QBLogo;
    username = '';
    password = '';
    rememberMe = false;
    errorMsg = '';
    successMsg = '';

    get eyeIconName() {
        return this.passwordFieldType === 'password' ? 'utility:preview' : 'utility:hide';
    }

    togglePasswordVisibility() {
    const passwordInput = this.template.querySelector('.password-input');
    if (passwordInput.type === 'password') {
        passwordInput.type = 'text';
    } else {
        passwordInput.type = 'password';
    }
}

    connectedCallback() {
        // Auto-fill username if "Remember Me" was checked before
        const remembered = localStorage.getItem('rememberedUsername');
        if (remembered) {
            this.username = remembered;
            this.rememberMe = true;
        }
    }

    handleChange(event) {
        const field = event.target.name;
        if (field === 'username') {
            this.username = event.target.value;
        } else if (field === 'password') {
            this.password = event.target.value;
        } else if (field === 'remember') {
            this.rememberMe = event.target.checked;
        }
    }

    handleLogin(event) {
        event.preventDefault();
        this.errorMsg = '';
        this.successMsg = '';

        login({ username: this.username, password: this.password })
            .then(result => {
                if (result.startsWith('ERROR')) {
                    this.errorMsg = result;
                } else {
                    if (this.rememberMe) {
                        localStorage.setItem('rememberedUsername', this.username);
                    } else {
                        localStorage.removeItem('rememberedUsername');
                    }
                    window.location.href = result; // redirect
                }
            })
            .catch(error => {
                this.errorMsg = error.body.message;
            });
    }

    handleForgotPassword() {
        this.errorMsg = '';
        this.successMsg = '';
        if (!this.username) {
            this.errorMsg = 'Please enter your username first.';
            return;
        }
        forgotPassword({ username: this.username })
            .then(result => {
                if (result.startsWith('SUCCESS')) {
                    this.successMsg = result;
                } else {
                    this.errorMsg = result;
                }
            })
            .catch(error => {
                this.errorMsg = error.body.message;
            });
    }

}