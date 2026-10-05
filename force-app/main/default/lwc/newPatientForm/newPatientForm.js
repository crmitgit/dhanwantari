import { LightningElement, track, api } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Import both logo static resources
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew'; // Original PMJAY logo
import Government_logo from '@salesforce/resourceUrl/Government_logo'; // New Government logo

// Import Account object and fields
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import FIRST_NAME_FIELD from '@salesforce/schema/Account.FirstName';
import LAST_NAME_FIELD from '@salesforce/schema/Account.LastName';
import PHONE_FIELD from '@salesforce/schema/Account.Phone';
import AGE_FIELD from '@salesforce/schema/Account.Age__c';

// Verhoeff algorithm implementation for Aadhar validation
const verhoeffValidation = {
    d: [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
        [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
        [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
        [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
        [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
        [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
        [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
        [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
        [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    ],
    p: [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
        [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
        [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
        [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
        [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
        [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
        [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
    ],
    inv: [0, 4, 3, 2, 1, 5, 6, 7, 8, 9],

    generateVerhoeff: function (num) {
        let c = 0;
        let numArray = num.split('').map(Number);
        for (let i = 0; i < numArray.length; i++) {
            c = this.d[c][this.p[((i + 1) % 8)][numArray[i]]];
        }
        return this.inv[c];
    },

    validateAadhaar: function (aadhaarNumber) {
        if (!aadhaarNumber || aadhaarNumber.length !== 12 || !/^\d+$/.test(aadhaarNumber)) {
            return false;
        }
        const cleanAadhaar = aadhaarNumber.replace(/\D/g, '');
        let c = 0;
        let numArray = cleanAadhaar.split('').map(Number);
        for (let i = 0; i < numArray.length; i++) {
            c = this.d[c][this.p[(i % 8)][numArray[numArray.length - 1 - i]]];
        }
        return (c === 0);
    }
};

export default class NewPatientForm extends NavigationMixin(LightningElement) {
    @track formData = {
        firstName: '',
        lastName: '',
        phone: '',
        gender: '',
        aadharNumber: '',
        age: ''
    };
    @api recordIds;
    @api recordTypeId = '012KY000001OVLRYA4';
    @track isLoading = false;
    validationTimeout;
    
    // Expose both logos to the template
    pmjayLogoUrl = pmjayLogo; // Keeps the original property name for PMJAY logo
    Government_logo = Government_logo; // New property for Government logo

    genderOptions = [
        { label: 'Male / पुरुष', value: 'Male' },
        { label: 'Female / महिला', value: 'Female' },
        { label: 'Other / अन्य', value: 'Other' },
        { label: 'Prefer not to say / बताना नहीं चाहते', value: 'Prefer not to say' }
    ];

    get today() {
        return new Date().toISOString().split('T')[0];
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;

        if (field === 'phone' || field === 'aadharNumber' || field === 'age') {
            value = value.replace(/\D/g, '');
            event.target.value = value; // Update the input value with cleaned version
        }

        this.formData[field] = value;
        this.validateField(event.target, field);
    }

    handleGenderChange(event) {
        this.formData.gender = event.detail.value;
        const genderInput = this.template.querySelector('[data-field="gender"]');
        this.validateField(genderInput, 'gender');
    }

    validateField(fieldElement, fieldName) {
        if (!fieldElement) return true;

        const fieldWrapper = fieldElement.closest('.field-wrapper');
        if (!fieldWrapper) return true;

        // Clear previous validation states
        fieldWrapper.classList.remove('field-error', 'field-success');
        const existingError = fieldWrapper.querySelector('.field-error-message');
        if (existingError) {
            existingError.remove();
        }

        const value = fieldName === 'gender' ? this.formData.gender : 
                            fieldElement.value ? fieldElement.value.trim() : '';

        let isValid = true;
        let errorMessage = '';
        let errorMessageHindi = '';

        // Required field validation
        if (['firstName', 'lastName', 'aadharNumber', 'gender', 'age', 'phone'].includes(fieldName)) {
            if (!value) {
                isValid = false;
                errorMessage = `${this.getFieldLabel(fieldName)} is required`;
                errorMessageHindi = this.getHindiErrorMessage(fieldName, 'required');
            }
        }

        // Field-specific validations (only if value exists)
        if (value && isValid) {
            switch(fieldName) {
                case 'aadharNumber':
                    const cleanAadhar = value.replace(/\D/g, '');
                    if (cleanAadhar.length !== 12) {
                        isValid = false;
                        errorMessage = 'AADHAR number must be exactly 12 digits';
                        errorMessageHindi = 'आधार नंबर 12 अंकों का होना चाहिए।';
                    } else if (!verhoeffValidation.validateAadhaar(cleanAadhar)) {
                        isValid = false;
                        errorMessage = 'Invalid AADHAR number';
                        errorMessageHindi = 'दर्ज किया गया आधार नंबर मान्य नहीं है';
                    }
                    break;
                
                case 'phone':
                    const cleanPhone = value.replace(/\D/g, '');
                    if (cleanPhone.length !== 10) {
                        isValid = false;
                        errorMessage = 'Phone number must be exactly 10 digits';
                        errorMessageHindi = 'फ़ोन नंबर 10 अंकों का होना चाहिए';
                    } else if (
                        /^(0{10}|1{10}|2{10}|3{10}|4{10}|5{10}|6{10}|7{10}|8{10}|9{10})$/.test(cleanPhone) ||
                        /(\d)\1{4,}/.test(cleanPhone) ||
                        /^(\d{3})\1+$/.test(cleanPhone)
                    ) {
                        isValid = false;
                        errorMessage = 'Invalid phone number pattern';
                        errorMessageHindi = 'अमान्य फ़ोन नंबर';
                    }
                    break;
                
                case 'age':
                    const ageValue = parseInt(value);
                    if (isNaN(ageValue) || ageValue <= 0) {
                        isValid = false;
                        errorMessage = 'Age must be greater than 0';
                        errorMessageHindi = 'उम्र 0 से अधिक होनी चाहिए';
                    } else if (ageValue > 150) {
                        isValid = false;
                        errorMessage = 'Age cannot be more than 150 years';
                        errorMessageHindi = 'उम्र 150 साल से अधिक नहीं हो सकती';
                    }
                    break;
            }
        }

        // Apply appropriate styling
        if (value && isValid) {
            fieldWrapper.classList.add('field-success');
        } else if (!isValid) {
            fieldWrapper.classList.add('field-error');
            const errorDiv = document.createElement('div');
            errorDiv.className = 'field-error-message slds-text-color_error slds-text-align_right';
            errorDiv.textContent = `${errorMessage} / ${errorMessageHindi}`; 
            fieldWrapper.appendChild(errorDiv);
        }

        return isValid;
    }

    getFieldLabel(fieldName) {
        const labels = {
            firstName: 'First Name',
            lastName: 'Last Name',
            aadharNumber: 'AADHAR Number',
            phone: 'Phone Number',
            gender: 'Gender',
            dateOfBirth: 'Age'
        };
        return labels[fieldName] || fieldName;
    }

    getHindiErrorMessage(fieldName, errorType) {
        const hindiMessages = {
            firstName: { required: 'पहला नाम आवश्यक है' },
            lastName: { required: 'अंतिम नाम आवश्यक है' },
            aadharNumber: { required: 'आधार नंबर आवश्यक है' },
            phone: { required: 'फ़ोन नंबर आवश्यक है' },
            gender: { required: 'लिंग आवश्यक है' },
            age: { required: 'उम्र आवश्यक है' }
        };
        return hindiMessages[fieldName]?.[errorType] || '';
    }

    validateForm() {
        let isFormValid = true;
        const inputFields = this.template.querySelectorAll('lightning-input, lightning-combobox');
        
        inputFields.forEach(field => {
            const fieldName = field.dataset.field || field.name;
            if (!this.validateField(field, fieldName)) {
                isFormValid = false;
            }
        });

        if (!this.formData.gender) {
            const genderInput = this.template.querySelector('[data-field="gender"]');
            if (genderInput && !this.validateField(genderInput, 'gender')) {
                isFormValid = false;
            }
        }

        return isFormValid;
    }

    async handleCreate() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        const fields = {
            [FIRST_NAME_FIELD.fieldApiName]: this.formData.firstName,
            [LAST_NAME_FIELD.fieldApiName]: this.formData.lastName,
            [PHONE_FIELD.fieldApiName]: this.formData.phone,
            [AGE_FIELD.fieldApiName]: parseInt(this.formData.age), 
            'Gender__c': this.formData.gender,
            'AADHAR_Number__c': this.formData.aadharNumber,
            'RecordTypeId': this.recordTypeId
        };
        console.log('fields',JSON.stringify(fields));

        try {
            const result = await createRecord({
                apiName: ACCOUNT_OBJECT.objectApiName,
                fields: fields
            });
            // console.log('Record Created', result);

            this.showToast('Success', 'Patient created successfully! (रोगी सफलतापूर्वक बनाया गया!)', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.id,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        } catch (error) {
            console.error('Create error:', JSON.stringify(error));
            
            let msg = 'Error creating patient (रोगी बनाने में त्रुटि)';
            
            // Check for Duplicate Rule errors
            if (error.body && error.body.output && error.body.output.errors) {
                const duplicateError = error.body.output.errors.find(e => e.errorCode === 'DUPLICATES_DETECTED');
                
                if (duplicateError) {
                    // This pulls the message you defined in the Duplicate Rule
                    msg = duplicateError.message; 
                } else if (error.body.message) {
                    msg = error.body.message;
                }
            } else if (error.body && error.body.message) {
                msg = error.body.message;
            }

            this.showToast('Duplicate Found / डुप्लिकेट पाया गया', msg, 'error');
        }  finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'list'
            },
            state: { filterName: 'Recent' }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}