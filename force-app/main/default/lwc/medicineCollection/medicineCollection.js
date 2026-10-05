import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEncounterDetails from '@salesforce/apex/PrescriptionController.getEncounterDetails';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import verifyKendraCode from '@salesforce/apex/PrescriptionController.verifyKendraCode';
import fulfillMedications from '@salesforce/apex/PrescriptionController.fulfillMedications';



export default class MedicineCollection extends LightningElement {
    // Screen state management
    @track currentScreen = 'kendra'; // 'kendra', 'otp', 'prescription'
    
    // Screen 1: Kendra Code
    @track kendraCode = 'PMBJK';
    @track kendraDetails = {};

    @track isAllSelected = false;  
    @track selectedIds = [];
    leftCornerImageUrl = pmjayLogo;

    // Screen 2: OTP
    @track otpInputs = [
        { id: 'otp1', value: '' },
        { id: 'otp2', value: '' },
        { id: 'otp3', value: '' },
        { id: 'otp4', value: '' },
        { id: 'otp5', value: '' },
        { id: 'otp6', value: '' }
    ];
    
    // Screen 3: Prescription - Using your existing logic
    @track summary;
    @track isLoading = false;
    @track error;
    encounterId;
    token;
    
    // Loading overlay
    @track showLoadingOverlay = false;
    @track loadingMessage = '';

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.encounterId = currentPageReference.state.id;
            this.token = currentPageReference.state.token;
            
            // If we have URL parameters, skip to prescription screen
            if (this.encounterId) {
                
                this.loadEncounterDetails();
            }
        }
    }

    // Screen visibility getters
    get isKendraCodeScreen() {
        return this.currentScreen === 'kendra';
    }

    get isOTPScreen() {
        return this.currentScreen === 'otp';
    }

    get isPrescriptionScreen() {
        return this.currentScreen === 'prescription';
    }

    get isThankYouScreen() {
    return this.currentScreen === 'thankyou';
}

    get isKendraCodeEmpty() {
        return !this.kendraCode || this.kendraCode.trim().length === 0;
    }

    get isOTPIncomplete() {
        return this.otpInputs.some(input => !input.value || input.value.trim().length === 0);
    }

    get otpValue() {
        return this.otpInputs.map(input => input.value).join('');
    }

    // Prescription getters (from original component)
    get formattedMedications() {
        if (!this.summary || !this.summary.medications) return [];
        return this.summary.medications.map((med) => {
            let parts = [];
            if (med.morning && med.morning !== "N/A") parts.push(`Morning ${med.morning}`);
            if (med.afternoon && med.afternoon !== "N/A") parts.push(`Afternoon ${med.afternoon}`);
            if (med.night && med.night !== "N/A") parts.push(`Night ${med.night}`);
            
            let dosageStr = parts.length ? parts.join(', ') : '';
            if (med.food && med.food !== "N/A") {
                dosageStr += dosageStr ? ` (${med.food})` : `(${med.food})`;
            }
            return {
                ...med,
                dosage: dosageStr
            };
        });
    }

    get isMedicationEmpty() {
        return !this.formattedMedications || this.formattedMedications.length === 0;
    }

    get currentDate() {
        return new Date().toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    }

    // Event Handlers - Screen 1: Kendra Code
    handleKendraCodeChange(event) {
        this.kendraCode = event.target.value;
    }

    async handleSendOTP() {
        if (this.isKendraCodeEmpty) {
            this.showToast('Error', 'Please enter a valid Kendra code', 'error');
            return;
        }

        try {
            this.showLoadingOverlay = true;
            this.loadingMessage = 'Verifying Kendra code...';

            // Call Apex method to verify Kendra code
            const result = await verifyKendraCode({ kendraCode: this.kendraCode });
            
            if (result.isValid) {
                // Store Kendra details for later use
                this.kendraDetails = {
                    id: result.id,
                    name: result.name,
                    ownerName: result.ownerName,
                    contactNumber: result.contactNumber,
                    // address: result.address,
                    stateCode: result.stateCode,
                    city: result.city,
                    postalCode: result.postalCode,
                    street: result.street
                };

                this.showLoadingOverlay = false;
                this.currentScreen = 'otp';
                this.showToast('Success', 'OTP sent successfully to registered mobile number', 'success');
            } else {
                this.showLoadingOverlay = false;
                this.showToast('Error', result.message, 'error');
            }
            
        } catch (error) {
            this.showLoadingOverlay = false;
            this.showToast('Error', 'Failed to verify Kendra code. Please try again.', 'error');
            console.error('Error verifying Kendra code:', error);
        }
    }


      get maskedContactNumber() {
        if (this.kendraDetails.contactNumber) {
            const contactNumber = this.kendraDetails.contactNumber.toString();
            if (contactNumber.length >= 4) {
                return '******' + contactNumber.slice(-4);
            }
            return contactNumber;
        }
        return '';
    }

    handleOTPChange(event) {
    const index = parseInt(event.target.dataset.index);
    const value = event.target.value;
    
    
    const singleDigit = value.slice(-1);

    event.target.value = singleDigit;
    
    
    this.otpInputs = this.otpInputs.map((input, i) => {
        if (i === index) {
            return { ...input, value: singleDigit };
        }
        return input;
    });
    
    // Auto-focus to next input if current input has value and not the last input
    if (singleDigit && index < this.otpInputs.length - 1) {
        
            const nextInput = this.template.querySelector(`[data-index="${index + 1}"]`);
            if (nextInput) {
                nextInput.focus();
            }
       
    }
    

    // this.updateCompleteOTP();
}

    handleOTPKeydown(event) {
    const index = parseInt(event.target.dataset.index);
    
    // Handle backspace to clear current and move to previous input
    if (event.key === 'Backspace') {
        if (event.target.value) {
            // Clear current input
            event.target.value = '';
            this.otpInputs = this.otpInputs.map((input, i) => {
                if (i === index) {
                    return { ...input, value: '' };
                }
                return input;
            });
        } else if (index > 0) {
            // Move to previous input if current is empty
            const prevInput = this.template.querySelector(`[data-index="${index - 1}"]`);
            if (prevInput) {
                prevInput.focus();
                prevInput.value = '';
                this.otpInputs = this.otpInputs.map((input, i) => {
                    if (i === index - 1) {
                        return { ...input, value: '' };
                    }
                    return input;
                });
            }
        }
        // this.updateCompleteOTP();
        return;
    }
    
    // Handle number input - replace current value and move to next
    if (/[0-9]/.test(event.key)) {
        event.preventDefault(); // Prevent default input behavior
        
        // Set the new value
        event.target.value = event.key;
        
        // Update the OTP array
        this.otpInputs = this.otpInputs.map((input, i) => {
            if (i === index) {
                return { ...input, value: event.key };
            }
            return input;
        });
        
        // Move to next input if not the last one
        if (index < this.otpInputs.length - 1) {
           
                const nextInput = this.template.querySelector(`[data-index="${index + 1}"]`);
                if (nextInput) {
                    nextInput.focus();
                }
           
        }
        
        // this.updateCompleteOTP();
        return;
    }
    
    // Allow navigation keys
    if (['Tab', 'Enter', 'ArrowLeft', 'ArrowRight', 'Delete'].includes(event.key)) {
        return;
    }
    
   
    event.preventDefault();
}


    async handleResendOTP() {
        try {
            this.showLoadingOverlay = true;
            this.loadingMessage = 'Resending OTP...';

            
            await this.simulateDelay(1500);
            
            this.showLoadingOverlay = false;
            this.showToast('Success', 'OTP resent successfully', 'success');
            
            // Clear OTP inputs
            this.otpInputs = this.otpInputs.map(input => ({ ...input, value: '' }));
            
        } catch (error) {
            this.showLoadingOverlay = false;
            this.showToast('Error', 'Failed to resend OTP. Please try again.', 'error');
            console.error('Error resending OTP:', error);
        }
    }

    handleBack() {
        if (this.currentScreen === 'otp') {
            this.currentScreen = 'kendra';
            // Clear OTP inputs when going back
            this.otpInputs = this.otpInputs.map(input => ({ ...input, value: '' }));
        }
    }

    // Your existing prescription loading logic
    loadEncounterDetails() {
        this.isLoading = true;
        getEncounterDetails({ encounterName: this.encounterId })
            .then(result => {
                this.summary = result;
                this.isLoading = false;
                this.error = null;
            })
            .catch(error => {
                this.error = error;
                this.isLoading = false;
                this.showToast('Error', 'Failed to load prescription details', 'error');
                console.error('Error loading encounter details:', error);
            });
    }

    // Event Handlers - Screen 2: OTP

    

    
    async handleVerifyOTP() {
        if (this.isOTPIncomplete) {
            this.showToast('Error', 'Please enter the complete 6-digit OTP', 'error');
            return;
        }

        try {
            this.showLoadingOverlay = true;
            this.loadingMessage = 'Verifying OTP...';

            
            await this.simulateDelay(2000);            
            this.showLoadingOverlay = false;
            
            this.loadEncounterDetails();
            this.currentScreen = 'prescription';
            
        } catch (error) {
            this.showLoadingOverlay = false;
            this.showToast('Error', 'Invalid OTP. Please check and try again.', 'error');
            console.error('Error verifying OTP:', error);
        }
    }

    async handleResendOTP() {
        try {
            this.showLoadingOverlay = true;
            this.loadingMessage = 'Resending OTP...';

            // TODO: Replace with actual Apex call
            // await sendOTP({ kendraCode: this.kendraCode });
            
            // Simulate API call for demo
            await this.simulateDelay(1500);
            
            this.showLoadingOverlay = false;
            this.showToast('Success', 'OTP resent successfully', 'success');
            
            // Clear OTP inputs
            this.otpInputs = this.otpInputs.map(input => ({ ...input, value: '' }));
            
        } catch (error) {
            this.showLoadingOverlay = false;
            this.showToast('Error', 'Failed to resend OTP. Please try again.', 'error');
            console.error('Error resending OTP:', error);
        }
    }

    handlePrint() {
        window.print();
    }

    handleBackToStart() {
        this.currentScreen = 'kendra';
        this.kendraCode = '';
        this.otpInputs = this.otpInputs.map(input => ({ ...input, value: '' }));
        this.summary = null;
        this.error = null;
        this.isLoading = false;
    }

    // Utility Methods
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    // Simulate API delay for demo purposes - remove in production
    simulateDelay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }


handleMedicationSelect(event) {
        const medicationId = event.target.dataset.id;
        const isChecked = event.target.checked;

        // Update selected IDs array
        if (isChecked) {
            this.selectedIds = [...this.selectedIds, medicationId];
        } else {
            this.selectedIds = this.selectedIds.filter(id => id !== medicationId);
        }

        // Update select all state
        this.isAllSelected = this.selectedIds.length === this.formattedMedications.length;
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.isAllSelected = isChecked;

        if (isChecked) {
            this.selectedIds = this.formattedMedications.map(med => med.id);
        } else {
            this.selectedIds = [];
        }

        this.template.querySelectorAll('input[type="checkbox"][data-id]').forEach(checkbox => {
    checkbox.checked = isChecked;
});
    }

    isSelected(medicationId) {
        return this.selectedIds.includes(medicationId);
    }


async handleFulfill() {
    if (this.selectedIds.length === 0 || !this.kendraCode) {
        alert('Please select medications and enter Kendra code');
        return;
    }

    this.showLoadingOverlay = true;
    try {
        await fulfillMedications({
            medicationIds: this.selectedIds,
            kendraCode: this.kendraCode
        });
        
        this.showLoadingOverlay = false;
         this.currentScreen = 'thankyou';
        
    } catch (error) {
        this.showLoadingOverlay = false;
        alert('Error: ' + error.body.message);
    }
}

}