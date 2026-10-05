import { LightningElement, track } from 'lwc';
import getConsentDetails from '@salesforce/apex/PmjayReferralConsentService.getConsentDetails';
import saveConsent from '@salesforce/apex/PmjayReferralConsentService.saveConsent';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';


export default class PatientConsentPortal extends LightningElement {
    // Static OTP for verification (dummy)
    STATIC_OTP = '123456';
    
    // Screen control
    @track showOTPScreen = true;
    @track showConsentScreen = false;
    @track showErrorState = false;
    @track isLoading = false;
    
    // OTP
    @track enteredOTP = '';
    @track otpError = '';
    
    // Referral data
    @track referralId = '';
    @track referralRecordId = '';
    
    // Patient data
    @track patientName = '';
    @track patientAge = '';
    @track patientGender = '';
    @track phoneNumber = '';
    @track phwcName = '';
    @track referredBy = '';
    @track referredTo = '';
    @track consentStatus = '';
    @track showExpiredState = '';
    
    // Files
    @track summaryFiles = [];
    @track diagnosticFiles = [];
    
    // Messages
    @track errorMessage = '';
    @track successMessage = '';
    
    leftCornerImageUrl = pmjayLogo;


    checkLinkValidity() {
        this.isLoading = true;
        getConsentDetails({ referralId: this.referralId })
            .then(result => {
                if (result.expired) {
                    this.showExpiredState = true;
                    this.showOTPScreen = false;
                    this.errorMessage = result.message;
                } else {
            console.log('summaryFiles:', result.summaryFiles);
            console.log('summaryFiles count:', result.summaryFiles?.length);

            // 🔍 Check diagnostic files
            console.log('===== STEP 4: DIAGNOSTIC FILES =====');
            console.log('diagnosticFiles:', result.diagnosticFiles);
            console.log('diagnosticFiles count:', result.diagnosticFiles?.length);
                    // Link is good! Now show the OTP screen
                    this.showOTPScreen = true;
                    this.showExpiredState = false;
                }
            })
            .catch(error => {
                this.showErrorState = true;
                this.errorMessage = 'Connection error.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Computed properties
    get isAlreadyConsented() {
        return this.consentStatus === 'Granted';
    }
    
    get isConsentRevoked() {
        return this.consentStatus === 'Revoked';
    }
    
    get hasSummaryFiles() {
        return this.summaryFiles && this.summaryFiles.length > 0;
    }
    
    get hasDiagnosticFiles() {
        return this.diagnosticFiles && this.diagnosticFiles.length > 0;
    }
    

    otpInputs = [
    { id: 1, value: '' }, { id: 2, value: '' }, { id: 3, value: '' },
    { id: 4, value: '' }, { id: 5, value: '' }, { id: 6, value: '' }
];
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
    
    if (singleDigit && index < this.otpInputs.length - 1) {
        const nextInput = this.template.querySelector(`[data-index="${index + 1}"]`);
        if (nextInput) {
            nextInput.focus();
        }
    }

    // CRITICAL: Update the string used for verification
    this.updateCompleteOTP();
}
    handleOTPKeydown(event) {
    const index = parseInt(event.target.dataset.index);
    
    if (event.key === 'Backspace') {
        if (event.target.value) {
            event.target.value = '';
            this.otpInputs = this.otpInputs.map((input, i) => {
                if (i === index) return { ...input, value: '' };
                return input;
            });
        } else if (index > 0) {
            const prevInput = this.template.querySelector(`[data-index="${index - 1}"]`);
            if (prevInput) {
                prevInput.focus();
                // Optional: Clear previous input when jumping back
                this.otpInputs = this.otpInputs.map((input, i) => {
                    if (i === index - 1) return { ...input, value: '' };
                    return input;
                });
            }
        }
        this.updateCompleteOTP(); // Update after backspace
        return;
    }
    
    if (/[0-9]/.test(event.key)) {
        event.preventDefault();
        event.target.value = event.key;
        
        this.otpInputs = this.otpInputs.map((input, i) => {
            if (i === index) return { ...input, value: event.key };
            return input;
        });
        
        if (index < this.otpInputs.length - 1) {
            const nextInput = this.template.querySelector(`[data-index="${index + 1}"]`);
            if (nextInput) nextInput.focus();
        }
        
        this.updateCompleteOTP(); // Update after number input
        return;
    }
}


   connectedCallback() {
        this.extractReferralIdFromUrl();
        if (this.referralId) {
            this.checkLinkValidity(); // Check validity IMMEDIATELY
        } else {
            this.showErrorState = true;
            this.errorMessage = 'Invalid Link.';
        }
    }  
    // Extract referral ID from URL
    extractReferralIdFromUrl() {
        try {
            const urlParams = new URLSearchParams(window.location.search);
            this.referralId = urlParams.get('referralId') || urlParams.get('refId') || '';
            console.log('referralId',this.referralId);
            
            if (!this.referralId && window.location.hash) {
                const hashParams = new URLSearchParams(window.location.hash.substring(1));
                this.referralId = hashParams.get('referralId') || hashParams.get('refId') || '';
            }
        } catch (error) {
            console.error('Error extracting referral ID from URL:', error);
            this.referralId = '';
        }
    }
    
    updateCompleteOTP() {
    this.enteredOTP = this.otpInputs.map(input => input.value).join('');
}
    
    // Verify OTP (Static)
    handleVerifyOTP() {
        if (!this.enteredOTP) {
            this.otpError = 'Please enter the verification code / कृपया सत्यापन कोड दर्ज करें';
            return;
        }
        
        if (this.enteredOTP.length !== 6) {
            this.otpError = 'Code must be 6 digits / कोड 6 अंकों का होना चाहिए';
            return;
        }
        
        if (this.enteredOTP !== this.STATIC_OTP) {
            this.otpError = 'Invalid verification code. Please try again / अमान्य सत्यापन कोड। कृपया पुन: प्रयास करें';
            return;
        }
        
        // OTP verified, load consent details
        this.otpError = '';
        this.loadConsentDetails();
    }
    
    // Load consent details
    loadConsentDetails() {
        this.isLoading = true;
        this.errorMessage = '';
        console.log('referralId', this.referralId);
        getConsentDetails({ referralId: this.referralId })
            .then(result => {
                if (result.expired) {
                    this.showExpiredState = true;
                    this.errorMessage = result.message;
                    console.log('expiredState', this.showExpiredState);
                    return;
                    
                }
                if (result.success) {
                    // Set patient data
                    this.patientName = result.patientFullName;
                    this.patientAge = result.patientAge;
                    this.patientGender = result.patientGender;
                    this.phoneNumber = result.patientPhone;
                    this.phwcName = result.phwcName;
                    this.referredBy = result.referredBy;
                    this.referredTo = result.referredTo;
                    this.referralRecordId = result.referralRecordId;
                    this.consentStatus = result.consentStatus || 'Pending';
                    
                    // Get previously consented file IDs if consent was granted
                    let previouslyConsentedIds = [];
                    if (result.consentedFileIds) {
                        previouslyConsentedIds = result.consentedFileIds.split(',');
                    }
                    
                    // Process summary files
                    if (result.summaryFiles) {
                        this.summaryFiles = result.summaryFiles.map(file => ({
                            ...file,
                            checked: this.isAlreadyConsented ? 
                                previouslyConsentedIds.includes(file.Id) : true,
                            isPDF: file.Extension === 'pdf'
                        }));
                    }
                    
                    // Process diagnostic files
                    if (result.diagnosticFiles) {
                        console.log(result.diagnosticFiles)
                        this.diagnosticFiles = result.diagnosticFiles.map(file => ({
                            ...file,
                            checked: this.isAlreadyConsented ? 
                                previouslyConsentedIds.includes(file.Id) : true,
                            isPDF: file.Extension === 'pdf'
                        }));
                    }
                    
                    // Switch screens
                    this.showOTPScreen = false;
                    this.showConsentScreen = true;
                    this.showErrorState = false;
                } else {
                    this.showOTPScreen = false;
                    this.showErrorState = true;
                    this.showConsentScreen = false;
                    this.errorMessage = result.message || 'Unable to load consent details.';
                }
            })
            .catch(error => {
                this.showOTPScreen = false;
                this.showErrorState = true;
                this.showConsentScreen = false;
                this.errorMessage = 'An error occurred: ' + 
                    (error.body?.message || error.message || 'Unknown error');
                console.error('Error loading consent details:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Handle file selection
    handleFileSelection(event) {
        const fileId = event.target.dataset.fileId;
        const isChecked = event.target.checked;
        
        this.summaryFiles = this.summaryFiles.map(file => {
            if (file.Id === fileId) {
                return { ...file, checked: isChecked };
            }
            return file;
        });
        
        this.diagnosticFiles = this.diagnosticFiles.map(file => {
            if (file.Id === fileId) {
                return { ...file, checked: isChecked };
            }
            return file;
        });
    }
    
    // Get selected file IDs
    getSelectedFileIds() {
        const selectedIds = [];
        
        this.summaryFiles.forEach(file => {
            if (file.checked) {
                selectedIds.push(file.Id);
            }
        });
        
        this.diagnosticFiles.forEach(file => {
            if (file.checked) {
                selectedIds.push(file.Id);
            }
        });
        
        return selectedIds;
    }
    
    // Grant consent
    handleGrantConsent() {
        const selectedFileIds = this.getSelectedFileIds();
        
        if (selectedFileIds.length === 0) {
            this.errorMessage = 'Please select at least one file to proceed / कृपया आगे बढ़ने के लिए कम से कम एक फ़ाइल चुनें';
            this.successMessage = '';
            return;
        }
        
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';
        
        saveConsent({
            referralRecordId: this.referralRecordId,
            consentStatus: 'Granted',
            selectedFileIds: selectedFileIds
        })
            .then(result => {
                if (result.success) {
                    this.consentStatus = 'Granted';
                    this.successMessage = 'Thank you! Your consent has been recorded successfully. / धन्यवाद! आपकी सहमति सफलतापूर्वक दर्ज कर ली गई है।';
                    this.errorMessage = '';
                } else {
                    this.errorMessage = result.message;
                    this.successMessage = '';
                }
            })
            .catch(error => {
                this.errorMessage = 'Error saving consent: ' + 
                    (error.body?.message || error.message || 'Unknown error');
                this.successMessage = '';
                console.error('Error saving consent:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Decline consent
    handleDeclineConsent() {
        const confirmMessage = 'Are you sure you want to decline consent?\n\n' +
            'This will prevent sharing your medical records with ' + this.referredTo + '.\n\n' +
            'क्या आप वाकई सहमति अस्वीकार करना चाहते हैं?';
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';
        
        saveConsent({
            referralRecordId: this.referralRecordId,
            consentStatus: 'Denied',
            selectedFileIds: []
        })
            .then(result => {
                if (result.success) {
                    this.consentStatus = 'Denied';
                    this.successMessage = 'Consent declined. Your medical records will not be shared. / ' +
                        'सहमति अस्वीकृत। आपके चिकित्सा रिकॉर्ड साझा नहीं किए जाएंगे।';
                    this.errorMessage = '';
                } else {
                    this.errorMessage = result.message;
                    this.successMessage = '';
                }
            })
            .catch(error => {
                this.errorMessage = 'Error declining consent: ' + 
                    (error.body?.message || error.message || 'Unknown error');
                this.successMessage = '';
                console.error('Error declining consent:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Revoke consent
    handleRevokeConsent() {
        const confirmMessage = 'Are you sure you want to revoke your consent?\n\n' +
            'This will stop sharing your medical records with ' + this.referredTo + '.\n' +
            'The hospital will no longer have access to your shared records.\n\n' +
            'क्या आप वाकई अपनी सहमति रद्द करना चाहते हैं?\n' +
            'इससे ' + this.referredTo + ' के साथ आपके चिकित्सा रिकॉर्ड साझा करना बंद हो जाएगा।';
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';
        
        saveConsent({
            referralRecordId: this.referralRecordId,
            consentStatus: 'Revoked',
            selectedFileIds: []
        })
            .then(result => {
                if (result.success) {
                    this.consentStatus = 'Revoked';
                    this.successMessage = 'Consent has been revoked successfully. ' +
                        'Medical records are no longer shared. / ' +
                        'सहमति सफलतापूर्वक रद्द कर दी गई है। चिकित्सा रिकॉर्ड अब साझा नहीं किए जाएंगे।';
                    this.errorMessage = '';
                    
                    // // Reload page after 3 seconds
                    // setTimeout(() => {
                    //     window.location.reload();
                    // }, 3000);
                } else {
                    this.errorMessage = result.message;
                    this.successMessage = '';
                }
            })
            .catch(error => {
                this.errorMessage = 'Error revoking consent: ' + 
                    (error.body?.message || error.message || 'Unknown error');
                this.successMessage = '';
                console.error('Error revoking consent:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}