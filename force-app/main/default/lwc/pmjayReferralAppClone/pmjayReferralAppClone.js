import { LightningElement, track, api } from 'lwc';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import Government_logo from '@salesforce/resourceUrl/Government_logo';

// Import Apex methods
import getPatientDetailsByReferralId from '@salesforce/apex/PmjayReferralService.getPatientDetailsByReferralId';
import sendOTP from '@salesforce/apex/PmjayReferralService.sendOTP';
import verifyOTP from '@salesforce/apex/PmjayReferralService.verifyOTP';
import getDistinctCities from '@salesforce/apex/PmjayReferralService.getDistinctCities';
import getCityFromLatLong from '@salesforce/apex/PmjayReferralService.getCityFromLatLong';
import getHospitalsByCity from '@salesforce/apex/PmjayReferralService.getHospitalsByCity';
import createCarePlanRecord from '@salesforce/apex/PmjayReferralService.createCarePlanRecord';
import createCareTransitionRecord from '@salesforce/apex/PmjayReferralService.createCareTransitionRecord';
import updateReferralReceivedDate from '@salesforce/apex/PmjayReferralService.updateReferralReceivedDate';
import PMLOGO2 from '@salesforce/resourceUrl/PMLOGO2'; // Import the left image static resource
import PMLOGO from '@salesforce/resourceUrl/PMLOGO';
import downloadZip from '@salesforce/apex/PmjayReferralService.downloadZip';
import getInactivityTime from '@salesforce/apex/PmjayReferralService.getInactivityTime';
// Import ToastContainer for advanced toast management
import ToastContainer from 'lightning/toastContainer';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // Keep this for dispatching the event
import cardContainer from '@salesforce/resourceUrl/cardContainer'; // Assuming 'cardContainer' is your static resource name


export default class PmjayReferralAppClone extends LightningElement {
    inactivityTimer; 
    INACTIVITY_LIMIT = 10 * 60 * 1000; // 10 minutes
    isLoggedIn = false;
    loggedInHospital;
    loggedInCity;
    isConsentGranted = true;
    @api recordId;
    @track currentStep = '1';
    @track pmjayLogoUrl = pmjayLogo;
    detectedCity;
    isLocationAllowed = false;
    recommendedDiagnosis='';
    attendantRelation='';
    attendantPhone='';
    attendantName='';
    recommendedSpeciality='';
    isZipping=false;
    phwcName='';
    drName='';
    summaryFiles = [];
    diagnosticFiles = [];
    @track Government_logoUrl = Government_logo;
    @track PMLOGO2Url = PMLOGO2; // Make the imported URL available to the template
    @track PMLOGONUrl = PMLOGO;
    @track showMainContent = true; // NEW: Controls visibility of the entire main form/flow
    @track showInitialSelection = false;
    @track selectedFlowType = ''; // 'PatientReceived' or 'PatientCareTransition'
    @track showCityHospitalInput = true;
    @track showOtpInput = false;
    @track maskedPhoneNumber = '';
    isStep3Report=false;

    // --- Input Data Properties ---
    selectedCity = '';
    selectedHospital = '';
    otp1 = ''; otp2 = ''; otp3 = ''; otp4 = ''; otp5 = ''; otp6 = '';
    officerFullName = '';
    officerEmployeeId = '';
    phwcReferralIdInput = '';
    @track phwcReferralId = ''; // This holds the actual Referral ID from Apex for display
    @track patientAccountId = '';
    @track patientFullName = '';
    @track patientAge = '';
    @track patientGender = '';
    @track pmjayId = '';
    @track memberId = '';
    @track patientMrnId = '';
    @track phwcDoctorId = '';

    @track isPatientDetailsReadonly = true; // Still used for patient details section

    @track finalConfirmedDiagnosis = '';
    @track proceduresPerformed = '';
    @track dischargeSummary = '';
    @track outcomesOfIntervention = '';

    @track careInstructions = '';
    @track nextFollowupDate = '';
    @track redFlagsToMonitor = '';
    @track anyFurtherReferralPlanned = 'No';
    @track furtherReferralTo = '';

    @track treatingPhysicianNameDesignation = '';
    @track declarationConsent = false;
    @track notes = '';
    @track uploadedFileIds = [];

    @track isLabReportsChecked = false;
    @track isImagingReportsChecked = false;
    @track isDischargeSummaryChecked = false;
    @track isPrescriptionsChecked = false;
    @track isOtherAttachmentChecked = false;
    @track otherAttachmentDetails = '';
    MAX_FILE_SIZE = 2500000;
    showPatientReport=false;
    showValidationSearch = false;
    validationReferralInput = '';
    validationReferralName = null;
    @track uploadedAllFiles = [];
    @track carePlanId = '';
    @track careTransitionId = '';
    patientPhone='';
    @track medicationListFromChild = [];
    @track isLoading = false;

    @track showMedicationTable = false;

    // NEW: Property for Patient Received Date (now part of Step 3 for Patient Received flow)
    @track receivedDate = null;
    @track portalHeaderTitle = 'Empanelled Healthcare Portal / सूचीबद्ध स्वास्थ्य सेवा पोर्टल';

    @track showThankYouPage = false; // Controls visibility of the dedicated thank you page


    // Accordion Toggle States (remain hardcoded true for always open)
    @track isPatientDetailsOpen = true;
    @track isDiagnosisDetailsOpen = true;
    @track isFollowupCarePlanOpen = true;
    @track isContactDetailsOpen = true;
    isDataVisible=false;
    @track isReportsOpen = false;

    // Completion tracking for steps
    @track isStep1Complete = false;
    @track isStep2Complete = false;
    @track isStep3Complete = false; // Step 3 in Patient Care Transition, or final step for Patient Received
    @track isStep4Complete = false; // Only for Patient Care Transition's final step


    // --- Combobox Options ---
    @track cityOptions = [];
    @track hospitalOptions = [];



    @track backgroundStyle = `background: linear-gradient(rgba(255, 255, 255, .92), rgba(255, 255, 255, .99)),url(${cardContainer});
                             background-size: cover;
                             background-position: center;
                             background-repeat: no-repeat;`;


    // handleSearchReferral() {
    //     if (dataFound) {
    //         this.patientFullName = result.name;
    //         this.patientAge = result.age;
    //         this.patientGender = result.gender;
    //         this.patientFiles = result.files;
            
    //         this.isDataVisible = true; // Ye table aur details box dikha dega
    //     } else {
    //         this.isDataVisible = false;
    //         // Show Toast error (Referral ID not found)
    //     }
    // }

    connectedCallback() {
        ['click', 'keydown', 'mousemove', 'scroll', 'touchstart']
        .forEach(event =>
            document.addEventListener(event, this.resetInactivityTimer)
        );
        this.getUserLocation();
        this.fetchInactivityTime();
        this.restoreSession(); // page refresh support
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = 'top-center';
        this.fetchDistinctCities();

        // Set receivedDate to today's date if it's null (e.g., on initial load)
        if (this.receivedDate === null) {
            const today = new Date();
            const year = today.getFullYear();
            const month = String(today.getMonth() + 1).padStart(2, '0');
            const day = String(today.getDate()).padStart(2, '0');
            this.receivedDate = `${year}-${month}-${day}`;
        }
    }

    fetchCityFromLatLong(latitude, longitude) {
        getCityFromLatLong({ lat: latitude, lng: longitude })
            .then(city => {
                console.log('Detected city:', city);
                this.detectedCity = city;
                this.selectedCity = city; // auto select dropdown
                this.fetchHospitalsByCity(city);
            })
            .catch(error => {
                console.error('Error fetching city', error);
            });
    }

    getUserLocation() {
        // Check browser support
        if (!navigator.geolocation) {
            console.error('Geolocation not supported by browser');
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                // const latitude = position.coords.latitude;
                // const longitude = position.coords.longitude;

                // 🔥 TEMP HARDCODE FOR TESTING (Dehradun)
                const latitude = 30.3165;
                const longitude = 78.0322;
                this.isLocationAllowed = true;
                console.log('User location:', latitude, longitude);

                // Call Apex method
                this.fetchCityFromLatLong(latitude, longitude);
            },
            (error) => {
                // Handle different error cases
                this.isLocationAllowed = false;
                switch (error.code) {
                    case error.PERMISSION_DENIED:
                        console.error('User denied location permission');
                        break;
                    case error.POSITION_UNAVAILABLE:
                        console.error('Location information unavailable');
                        break;
                    case error.TIMEOUT:
                        console.error('Location request timed out');
                        break;
                    default:
                        console.error('Unknown geolocation error');
                }
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,   // 10 seconds
                maximumAge: 0
            }
        );
    }

    async fetchDistinctCities() {
        try {
            const result = await getDistinctCities();
            this.cityOptions = result;
            console.log('LWC: Successfully fetched cities:', JSON.stringify(result));
        } catch (error) {
            console.error('LWC Error fetching cities:', JSON.stringify(error));
            this.showToast('Error / त्रुटि', 'Could not fetch list of cities: ' + this.getErrorMessage(error) + ' / शहर लोड नहीं हो सके: ' + this.getErrorMessage(error), 'error');
        }
    }

    async fetchHospitalsByCity(city) {
        try {
            const result = await getHospitalsByCity({ city: city });
            this.hospitalOptions = result;
            console.log('LWC: Successfully fetched hospitals:', JSON.stringify(result));
        } catch (error) {
            console.error('LWC Error fetching hospitals:', JSON.stringify(error));
            this.showToast('Error / त्रुटि', 'Could not load hospitals: ' + this.getErrorMessage(error) + ' / अस्पताल लोड नहीं हो सके: ' + this.getErrorMessage(error), 'error');
        }
    }

    async fetchInactivityTime(){
        try{
            const result = await getInactivityTime();
            this.INACTIVITY_LIMIT = result * 60 * 1000;
            console.log('Inactivity time is set to = ', this.INACTIVITY_LIMIT);
        } catch(error){
            console.error('Error fetching inactivity time from custom metadata');
        }
    }

    // --- Getters to control conditional rendering and classes for stepper ---
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; } // This is now where Patient Received ends or Patient Care Transition proceeds
    get isStep4() { return this.currentStep === '4'; } // Only for Patient Care Transition's final step

    // Getters for flow type specific rendering
    get isPatientCareTransitionFlow() {
        return this.selectedFlowType === 'PatientCareTransition';
    }

    get isPatientReceivedFlow() {
        return this.selectedFlowType === 'PatientReceived';
    }

    // Getter for displaying Declaration Consent (addresses LWC1060 error)
    get displayDeclarationConsent() {
        return this.declarationConsent ? 'Yes' : 'No';
    }

    get step1Class() {
        let cls = 'step';
        if (this.currentStep === '1') cls += ' active';
        if (this.isStep1Complete) cls += ' completed';
        return cls;
    }
    get step2Class() {
        let cls = 'step';
        if (this.currentStep === '2') cls += ' active';
        if (this.isStep2Complete) cls += ' completed';
        return cls;
    }
    get step3Class() {
        let cls = 'step';
        if (this.currentStep === '3') cls += ' active';
        if (this.isStep3Complete) cls += ' completed';
        return cls;
    }
    get step4Class() { // This step is only relevant for Patient Care Transition
        let cls = 'step';
        if (this.currentStep === '4') cls += ' active';
        if (this.isStep4Complete) cls += ' completed';
        return cls;
    }

    get line1Class() {
        let cls = 'line';
        if (this.isStep1Complete) cls += ' completed-line';
        return cls;
    }
    get line2Class() {
        let cls = 'line';
        if (this.isStep2Complete) cls += ' completed-line';
        return cls;
    }
    get line3Class() {
        let cls = 'line';
        if (this.isStep3Complete) cls += ' completed-line';
        return cls;
    }

    get isReferralYes() { return this.anyFurtherReferralPlanned === 'Yes'; }
    get isReferralNo() { return this.anyFurtherReferralPlanned === 'No'; }
    get showFurtherReferralTo() { return this.anyFurtherReferralPlanned === 'Yes'; }

    handlePatientReportCard(){
        this.showInitialSelection=false;
        this.showPatientReport=true;
        this.currentStep='';
        this.isStep3Report=true;
        this.portalHeaderTitle = 'Patient Referral & Diagnostic Reports / रोगी रेफरल एवं जांच रिपोर्ट';
    }

    // --- Initial Selection Handlers ---
    handlePatientReceivedClick() {
        this.showMainContent = true; // Ensure main content is visible
        this.showInitialSelection = false;
        this.currentStep = '3';
        this.selectedFlowType = 'PatientReceived';
        this.portalHeaderTitle = 'Patient Received Portal / रोगी प्राप्त पोर्टल';

        // Set receivedDate to today's date when Patient Received flow is selected
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        this.receivedDate = `${year}-${month}-${day}`;
        console.log('LWC: Selected Patient Received. Transitioning to Step 1. Received Date set to today.');
        this.showThankYouPage = false; // Ensure thank you page is hidden
        this.resetCompletionFlags(); // Clear any previous completion state
    }

    handlePatientCareTransitionClick() {
        this.showMainContent = true; // Ensure main content is visible
        this.showInitialSelection = false;
        this.currentStep = '3';
        this.selectedFlowType = 'PatientCareTransition';
        this.portalHeaderTitle = 'Patient Care Transition Portal / रोगी देखभाल संक्रमण पोर्टल';

        console.log('LWC: Selected Patient Care Transition. Transitioning to Step 1.');
        this.showThankYouPage = false; // Ensure thank you page is hidden
        this.resetCompletionFlags(); // Clear any previous completion state
    }

    // --- Referral Validation (4th card) ---
    handleReferralValidationClick() {
        this.showMainContent = true;
        this.showInitialSelection = false;
        this.showValidationSearch = true;
        this.currentStep = '';
        this.selectedFlowType = 'ReferralValidation';
        this.validationReferralInput = '';
        this.validationReferralName = null;
        this.portalHeaderTitle = 'Referral Validation / रेफरल सत्यापन';
    }

    handleValidationInput(event) {
        this.validationReferralInput = event.target.value;
    }

    handleValidationKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleOpenValidation();
        }
    }

    handleOpenValidation() {
        const referralName = (this.validationReferralInput || '').trim();
        if (!referralName) {
            this.showToast('Error / त्रुटि', 'Please enter a Referral ID. / कृपया एक रेफरल आईडी दर्ज करें।', 'error');
            return;
        }
        this.validationReferralName = referralName;
    }

    handleValidationClose() {
        this.validationReferralName = null;
    }

    handleValidationError(event) {
        this.validationReferralName = null;
        this.showToast('Error / त्रुटि', event.detail.message, 'error');
    }

    handleGoBackToSelection() {
        this.showMainContent = true; // Ensure main content is visible
        this.showInitialSelection = true;
        this.currentStep = '1';
        this.resetFormOnBack(); // This also calls resetCompletionFlags
        this.portalHeaderTitle = 'Empanelled Healthcare Portal / सूचीबद्ध स्वास्थ्य सेवा पोर्टल';
        this.showThankYouPage = false; // Ensure thank you page is hidden when going back to selection
        console.log('LWC: Going back to initial selection screen.');
    }

    isCityMatching(selectedCity, detectedCity) {
        return detectedCity.toLowerCase().includes(selectedCity.toLowerCase());
    }

    // --- Step 1 (OTP) Handlers ---
    async handleSendOtp() {
        if (!this.selectedCity || !this.selectedHospital) {
            this.showToast('Error / त्रुटि', 'City and Empanelled Hospital are mandatory fields. Please select both. / शहर और सूचीबद्ध अस्पताल अनिवार्य हैं। कृपया दोनों चुनें।', 'error');
            return;
        }
        if (this.isLocationAllowed && this.detectedCity) {
            if (!this.isCityMatching(this.selectedCity, this.detectedCity)) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Access Restricted / प्रवेश प्रतिबंधित',
                        message: `You are currently in ${this.detectedCity}.
                        आप केवल अपने वर्तमान शहर से ही लॉगिन कर सकते हैं।
                        कृपया सही शहर चुनें या स्थान अनुमति की जाँच करें।`,
                        variant: 'error',
                        mode: 'sticky'   // ✅ yahan allowed hai
                    })
                );
                return; // ⛔ STOP OTP
            }
        }

        this.isLoading = true;
        try {
            const result = await sendOTP({
                selectedCity: this.selectedCity,
                selectedHospital: this.selectedHospital
            });

            let toastMessage = result.message;
            if (result.status === 'success') {
                toastMessage += ' / ओटीपी सफलतापूर्वक भेजा गया है।';
                if (result.message && result.message.includes('ending in ')) {
                    const match = result.message.match(/\(ending in (\*{6}\d{4})\)\./);
                    if (match && match[1]) {
                        this.maskedPhoneNumber = match[1];
                    }
                } else {
                    this.maskedPhoneNumber = '******XXXX';
                }
                this.showCityHospitalInput = false;
                this.showOtpInput = true;
            } else {
                toastMessage += ' / ओटीपी भेजने में विफल रहा।';
                this.maskedPhoneNumber = '';
            }
            this.showToast(result.status === 'success' ? 'Success / सफल' : 'Error / त्रुटि', toastMessage, result.status);
        } catch (error) {
            this.showToast('Error / त्रुटि', 'Failed to send OTP: ' + this.getErrorMessage(error) + ' / ओटीपी नहीं भेजा जा सका: ' + this.getErrorMessage(error), 'error');
            this.maskedPhoneNumber = '';
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerifyOtp() {
        const otp = `${this.otp1}${this.otp2}${this.otp3}${this.otp4}${this.otp5}${this.otp6}`;
        if (otp.length !== 6) {
            this.showToast('Error / त्रुटि', 'Please enter the complete 6-digit OTP. / कृपया पूरा 6 अंकों का ओटीपी दर्ज करें।', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await verifyOTP({
                selectedCity: this.selectedCity,
                selectedHospital: this.selectedHospital,
                enteredOTP: otp
            });

            if (result.status === 'success') {
                const sessionData = {
                    city: this.selectedCity,
                    hospital: this.selectedHospital,
                    loginTime: Date.now()
                };

                sessionStorage.setItem(
                    'hospitalSession',
                    JSON.stringify(sessionData)
                );
                // UI STATE
                this.loggedInHospital = this.selectedHospital;
                this.loggedInCity = this.selectedCity;
                this.isLoggedIn = true;

                this.isStep1Complete = true;
                // this.currentStep = '2'; // Always move to Step 2 next
                this.showCityHospitalInput = true; // Reset view for next step
                this.showInitialSelection=true;
                this.showOtpInput = false; // Hide OTP input

                this.startInactivityTimer(); // 👈 Session Management

                this.showToast('Success / सफल', result.message + ' / ओटीपी सफलतापूर्वक सत्यापित किया गया।', 'success');
            } else {
                this.showToast('Error / त्रुटि', result.message + ' / ओटीपी सत्यापन विफल रहा।', 'error');
            }
        } catch (error) {
            this.showToast('Error / त्रुटि', 'An unexpected error occurred during OTP verification: ' + this.getErrorMessage(error) + ' / ओटीपी सत्यापन के दौरान एक अप्रत्याशित त्रुटि हुई: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    startInactivityTimer() {
        
        this.clearInactivityTimer();

        this.inactivityTimer = setTimeout(() => {
            this.autoLogout();
        }, this.INACTIVITY_LIMIT);
    }

    clearInactivityTimer() {
        if (this.inactivityTimer) {
            clearTimeout(this.inactivityTimer);
            this.inactivityTimer = null;
        }
    }

    resetInactivityTimer = () => {
        
        if (this.isLoggedIn) {
            
            this.clearInactivityTimer();
            this.startInactivityTimer();
        }
    }

    disconnectedCallback() {
        ['click', 'keydown', 'mousemove', 'scroll', 'touchstart']
        .forEach(event =>
            document.removeEventListener(event, this.resetInactivityTimer)
        );
        this.clearInactivityTimer();
    }

    autoLogout() {
        this.showToast(
            'Session Expired / सत्र समाप्त',
            'You have been logged out due to inactivity / निष्क्रियता के कारण लॉगआउट किया गया।',
            'warning'
        );
        this.handleLogout();
    }

    handleLogout() {
        this.resetFormData();
        this.resetUiState();
        sessionStorage.removeItem('hospitalSession');
        this.clearInactivityTimer();

        // RESET EVERYTHING
        this.isLoggedIn = false;
        this.loggedInHospital = null;
        this.loggedInCity = null;

        this.selectedCity = null;
        this.selectedHospital = null;

        this.showInitialSelection = false;
        this.showCityHospitalInput = true;
        this.showOtpInput = false;
        this.currentStep='1';
        this.showInitialSelection=false;
        this.showPatientReport=false;
        this.resetOtpInputs();
        this.referralId=null;
        this.phwcReferralIdInput=null;
    }

    resetOtpInputs() {
        this.otp1 = this.otp2 = this.otp3 =
        this.otp4 = this.otp5 = this.otp6 = '';
    }

    restoreSession() {
        const session = sessionStorage.getItem('hospitalSession');
        if (session) {
            const data = JSON.parse(session);
            this.isLoggedIn = true;
            this.loggedInHospital = data.hospital;
            this.loggedInCity = data.city;
            this.showInitialSelection = true;
            this.showCityHospitalInput = false;
            this.startInactivityTimer();
        }
    }

    handleResendOtp() {
        this.otp1 = ''; this.otp2 = ''; this.otp3 = ''; this.otp4 = ''; this.otp5 = ''; this.otp6 = '';
        this.handleSendOtp();
    }

    // --- Step 2 (Identify Yourself) Handler ---
    handleContinue() {
        const fullNameInput = this.template.querySelector('[name="officerFullName"]');
        const employeeIdInput = this.template.querySelector('[name="officerEmployeeId"]');

        let isValid = true;
        if (!this.officerFullName) {
            fullNameInput.setCustomValidity('Full Name is required. / पूरा नाम अनिवार्य है।');
            isValid = false;
        } else {
            fullNameInput.setCustomValidity('');
        }
        fullNameInput.reportValidity();

        if (!this.officerEmployeeId) {
            employeeIdInput.setCustomValidity('Employee ID is required. / कर्मचारी आईडी अनिवार्य है।');
            isValid = false;
        } else {
            employeeIdInput.setCustomValidity('');
        }
        employeeIdInput.reportValidity();

        if (!isValid) {
            this.showToast('Error / त्रुटि', 'Please enter both Full Name and Employee ID. / कृपया पूरा नाम और कर्मचारी आईडी दोनों दर्ज करें।', 'error');
            return;
        }
        console.log('showPatientReport+++',this.showPatientReport);
        if(this.showPatientReport!=true){
            this.isStep2Complete = true;
            this.currentStep = '3'; // Always move to Step 3 next for both flows
        }else{
            this.currentStep='';
            this.isStep3Report=true;
        }
        this.showToast('Success / सफल', 'Employee details captured. Moving to Patient Details. / अब कृपया मरीज़ का विवरण दर्ज करें', 'success');
    }

    handleViewFile(event) {
        const attachmentId = event.currentTarget.dataset.id;
        window.open(
            `/servlet/servlet.FileDownload?file=${attachmentId}`,
            '_blank'
        );
    }

    handleDownloadFile(event) {
        const fileId = event.currentTarget.dataset.id;
        // Find the file in your existing arrays
        const file = [...this.summaryFiles, ...this.diagnosticFiles].find(f => f.Id === fileId);

        if (file && file.Base64Data) {
            this.downloadBase64File(file.Base64Data, file.Title, file.Extension);
        }
    }

    downloadBase64File(base64String, fileName, extension) {
        // 1. Determine the correct MIME type
        let mimeType = 'application/octet-stream';

        if (extension === 'pdf') {
            mimeType = 'application/pdf';
        } else if (extension === 'docx') {
            mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (extension === 'zip') {
            mimeType = 'application/zip';   // 👈 YE YAHAN ADD KARNA HAI
        }

        // 2. Convert Base64 to Blob
        const byteCharacters = atob(base64String);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: mimeType });

        // 3. Trigger download
        const blobUrl = URL.createObjectURL(blob);
        const anchor = document.createElement('a');
        anchor.href = blobUrl;
        anchor.download = fileName;
        document.body.appendChild(anchor);
        anchor.click();

        document.body.removeChild(anchor);
        URL.revokeObjectURL(blobUrl);
    }

    // handleDownloadAll() {
    //     // 1. Combine all files into one array
    //     const allFiles = [...this.summaryFiles, ...this.diagnosticFiles];

    //     if (allFiles.length === 0) {
    //         // Show a message if no files are found
    //         console.log('No files to download');
    //         return;
    //     }

    //     // 2. Loop through each file and trigger download
    //     // We use a small timeout (300ms) between downloads so the browser 
    //     // doesn't block them as "spam popups"
    //     allFiles.forEach((file, index) => {
    //         setTimeout(() => {
    //             if (file.Base64Data) {
    //                 this.downloadBase64File(file.Base64Data, file.Title, file.Extension);
    //             }
    //         }, index * 300); 
    //     });
    // }

    handleDownloadAll() {
        const contentVersionIds = [];
        const attachmentIds = [];

        [...this.summaryFiles, ...this.diagnosticFiles].forEach(f => {

            if (f.Type === 'File' && f.Id) {
                contentVersionIds.push(f.Id);
            } else if (f.Type === 'Attachment' && f.Id) {
                attachmentIds.push(f.Id);
            }
        });

        // console.log('contentVersionIds+++',contentVersionIds);

        if (!contentVersionIds.length && !attachmentIds.length) return;
        const zipName = `${this.phwcReferralIdInput}_${this.patientFullName}.zip`;
        this.isZipping=true;
        downloadZip({
            contentVersionIds: contentVersionIds,
            attachmentIds: attachmentIds
        })
            .then(base64Zip => {
                this.downloadBase64File(base64Zip, zipName, 'zip');
                this.isZipping=false;
            })
            .catch(error => {
                console.error(error);
            });
    }

    triggerInternalDownload(fileId, type) {
        let baseUrl = window.location.origin;
        let finalUrl = '';

        if (type === 'File') {
            // Internal Salesforce path for ContentVersion
            finalUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + fileId + '?asPdf=false&operationContext=CHATTER';
        } else {
            // Internal path for Attachment
            finalUrl = baseUrl + '/servlet/servlet.FileDownload?file=' + fileId;
        }

        // Creating a hidden link to bypass the viewer
        const anchor = document.createElement('a');
        anchor.href = finalUrl;
        anchor.target = '_blank'; // Standard for internal SF downloads
        document.body.appendChild(anchor);
        anchor.click();
        
        // Cleanup
        setTimeout(() => {
            document.body.removeChild(anchor);
        }, 500);
    }

    // --- Step 3 (Patient Details/Summary) Handlers ---
    async handleSearchReferral() {
        const referralId = this.phwcReferralIdInput;
        this.resetPatientDetailsAndEditability(); // Clears all patient fields and sets editability

        if (!referralId) {
            this.showToast('Error / त्रुटि', 'Please enter a Referral ID. / कृपया एक रेफरल आईडी दर्ज करें।', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await getPatientDetailsByReferralId({ referralId: referralId });
            if (result.consentGranted === false) {
                this.isConsentGranted = false;
                this.isDataVisible = false;

                this.showToast(
                    'Consent Pending / सहमति लंबित',
                    result.message +
                    ' / रोगी की सहमति लंबित है। विवरण प्रदर्शित नहीं किया जा सकता।',
                    'warning'
                );
                return;
            }
            if (result.success) {

                if (this.isPatientReceivedFlow && result.alreadyReceived) {
                    this.showToast(
                        'Already Received / पहले ही प्राप्त',
                        'Patient is already received / मरीज पहले ही प्राप्त किया जा चुका है',
                        'error'
                    );
                    return;
                }

                if (this.isPatientCareTransitionFlow && result.carePlanExists) {
                    this.showToast(
                        'Care Plan Exists / केयर प्लान मौजूद है',
                        'Care plan already exists for this patient / इस मरीज के लिए पहले से केयर प्लान मौजूद है',
                        'error'
                    );
                    return;
                }
                   if (result.diagnosticFiles) {
                        console.log('diagnostic files: ',result.diagnosticFiles);
                    }
                this.phwcReferralId = referralId;
                this.patientAccountId = result.patientAccountId || '';
                this.patientFullName = result.patientFullName || '';
                this.patientAge = result.patientAge || '';
                this.patientGender = result.patientGender || '';
                this.pmjayId = result.pmjayId || '';
                this.memberId = result.memberId || '';
                this.phwcDoctorId = result.phwcDoctorId || '';
                this.patientPhone=result.patientPhone||'';
                this.isPatientDetailsReadonly = true;
                this.isDataVisible=true;
                this.drName=result.drName || '';
                this.phwcName=result.phwcName || '';
                this.summaryFiles = this.processFileData(result.summaryFiles || []);
                this.diagnosticFiles = this.processFileData(result.diagnosticFiles || []);
                this.recommendedSpeciality=result.recommendedSpeciality;
                this.recommendedDiagnosis=result.recommendedDiagnosis;
                this.attendantRelation=result.attendantRelation;
                this.attendantPhone=result.attendantPhone;
                this.attendantName=result.attendantName;
                this.showToast('Success / सफल', result.message + ' / रोगी विवरण सफलतापूर्वक प्राप्त हुए।', 'success');
            } else {
                this.showToast('Error / त्रुटि', (result.message || 'No patient data found for this Referral ID. / इस रेफरल आईडी के लिए कोई रोगी डेटा नहीं मिला।'), 'error');
                this.patientAccountId = '';
                this.phwcDoctorId = '';
                this.resetFormData();
                this.isPatientDetailsReadonly = false; // Allow manual entry if not found
            }
        } catch (error) {
            this.showToast('Error / त्रुटि', 'An unexpected error occurred: ' + this.getErrorMessage(error) + ' / एक अप्रत्याशित त्रुटि हुई: ' + this.getErrorMessage(error), 'error');
            this.patientAccountId = '';
            this.phwcDoctorId = '';
            this.isPatientDetailsReadonly = false;
        } finally {
            this.isLoading = false;
        }
    }

    // THE HELPER FUNCTION
    processFileData(files) {
        return files.map(file => {
            let icon = 'doctype:unknown';
            const ext = file.Extension ? file.Extension.toLowerCase() : '';
            
            // Mapping extension to Salesforce SLDS Doctype Icons
            if (['pdf'].includes(ext)) icon = 'doctype:pdf';
            else if (['doc', 'docx'].includes(ext)) icon = 'doctype:word';
            else if (['xls', 'xlsx', 'csv'].includes(ext)) icon = 'doctype:excel';
            else if (['jpg', 'jpeg', 'png', 'gif'].includes(ext)) icon = 'doctype:image';
            else if (['zip', 'rar'].includes(ext)) icon = 'doctype:zip';
            else if (['ppt', 'pptx'].includes(ext)) icon = 'doctype:ppt';

            return { 
                ...file, 
                iconName: icon // This is what {file.iconName} uses in HTML
            };
        });
    }

    get hasAnyFiles() {
        return (this.summaryFiles && this.summaryFiles.length > 0) || 
            (this.diagnosticFiles && this.diagnosticFiles.length > 0);
    }

    // This method is the "Submit" action for Patient Received flow (on Step 3)
    async handleSubmitPatientReceivedDate() {
        console.log('LWC: handleSubmitPatientReceivedDate called for Patient Received flow.');

        // Validate required fields for Patient Received flow
        if (!this.phwcReferralId) {
            this.showToast('Error / त्रुटि', 'Referral ID is required. / रेफरल आईडी अनिवार्य है', 'error');
            return;
        }
        if (!this.receivedDate) {
            this.showToast('Error / त्रुटि', 'Received Date is required. / प्राप्त तिथि अनिवार्य है।', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await updateReferralReceivedDate({
                referralName: this.phwcReferralId,
                receivedDate: this.receivedDate
            });

            if (result.status === 'success') {
                this.showToast('Success / सफल', result.message + ' / रेफरल प्राप्त तिथि सफलतापूर्वक अपडेट की गई।', 'success');

                // *** CRITICAL CHANGE FOR FULL PAGE THANK YOU DISPLAY ***
                this.showMainContent = false; // Hides the entire main form content (header, stepper, current form steps)
                this.showThankYouPage = true; // Displays ONLY the thank you page
                // Set step completion flags AFTER hiding main content, to avoid flicker and ensure they are ready for next time
                this.isStep1Complete = true;
                this.isStep2Complete = true;
                this.isStep3Complete = true; // This is the final step for Patient Received flow
                this.isStep4Complete = false; // Ensure this is false for this flow
                this.currentStep = '3'; // Set current step to the final step number so the stepper displays completed state if showMainContent was true

                // Reset form data in the background for a clean slate when they return to login
                this.resetForm();

            } else {
                this.showToast('Error / त्रुटि', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error / त्रुटि', 'An unexpected error occurred while updating Received Date: ' + this.getErrorMessage(error) + ' / प्राप्त तिथि अपडेट करते समय एक अप्रत्याशित त्रुटि हुई: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // This method is the "Complete Care Transition" action for Patient Care Transition flow (on Step 3)
    async handleCompleteCareTransition() {
        console.log('LWC: handleCompleteCareTransition called for Patient Care Transition flow.');


        // Access child component method for medications
        let allInputs = [];
        const prescriptionFormsCmp = this.template.querySelector('c-prescription-forms');
        if (prescriptionFormsCmp) {
            allInputs = prescriptionFormsCmp.getPrescriptionsData();
        }

        // Basic validation for Patient Care Transition fields
        if (!this.declarationConsent) {
            this.showToast('Error / त्रुटि', 'Please accept the declaration to proceed. / कृपया आगे बढ़ने के लिए घोषणा स्वीकार करें', 'error');
            return;
        }
        const careInstructionsInput = this.template.querySelector('[name="careInstructions"]');
        if (!this.careInstructions) {
            careInstructionsInput.setCustomValidity('Care Instructions are required. / देखभाल निर्देश अनिवार्य हैं।');
            careInstructionsInput.reportValidity();
            this.showToast('Error / त्रुटि', 'Please enter Care Instructions. / कृपया देखभाल निर्देश दर्ज करें।', 'error');
            return;
        } else {
            careInstructionsInput.setCustomValidity('');
            careInstructionsInput.reportValidity();
        }
        if (!this.patientAccountId) {
            this.showToast('Error / त्रुटि', 'This Referral ID was not found. Please enter a valid Referral ID. / रेफरल आईडी नहीं मिली। कृपया एक मान्य रेफरल आईडी दर्ज करें', 'error');
            return;
        }
        if (!this.pmjayId && !this.memberId) {
            this.showToast('Error / त्रुटि', 'Either PMJAY ID or Member ID is mandatory in Patient Details. / रोगी विवरण में पीएमजेएवाई आईडी या सदस्य आईडी अनिवार्य है।', 'error');
            return;
        }
        if (this.isOtherAttachmentChecked && !this.otherAttachmentDetails) {
            this.showToast('Error / त्रुटि', 'Please specify details for "Other" attachments if checked. / यदि "अन्य" संलग्नक का चयन किया गया है, तो कृपया विवरण निर्दिष्ट करें।', 'error');
            return;
        }
        const patientMrnInput = this.template.querySelector('[name="patientMrnId"]');
        // This check for patientMrnId is *only* relevant for Patient Care Transition flow
        if (this.isPatientCareTransitionFlow && patientMrnInput && !patientMrnInput.value) {
            patientMrnInput.setCustomValidity('Patient MRN ID is required. / रोगी एमआरएन आईडी अनिवार्य है।');
            patientMrnInput.reportValidity();
            this.showToast('Error / त्रुटि', 'Please enter Patient MRN ID. / कृपया रोगी एमआरएन आईडी दर्ज करें।', 'error');
            return;
        } else if (patientMrnInput) {
            patientMrnInput.setCustomValidity('');
            patientMrnInput.reportValidity();
        }

        let attachmentNotesParts = [];
        const selectedCheckboxes = [];
        if (this.isLabReportsChecked) selectedCheckboxes.push('Lab Reports / लैब रिपोर्ट');
        if (this.isImagingReportsChecked) selectedCheckboxes.push('Imaging Reports / इमेजिंग रिपोर्ट');
        if (this.isDischargeSummaryChecked) selectedCheckboxes.push('Discharge Summary / डिस्चार्ज सारांश');
        if (this.isPrescriptionsChecked) selectedCheckboxes.push('Prescriptions / नुस्खे');
        if (this.isOtherAttachmentChecked) {
            selectedCheckboxes.push(`Other: ${this.otherAttachmentDetails} / अन्य: ${this.otherAttachmentDetails}`);
        }
        if (selectedCheckboxes.length > 0) {
            attachmentNotesParts.push('Attachments Included (via checkboxes): ' + selectedCheckboxes.join(', ') + '.');
        }
        if (this.uploadedAllFiles.length > 0) {
            const uploadedFileNames = this.uploadedAllFiles.map(file => file.name).join(', ');
            attachmentNotesParts.push(`Total Files Uploaded: ${uploadedFileNames}. / कुल अपलोड की गई फाइलें: ${uploadedFileNames}.`);
        }
        this.notes = attachmentNotesParts.join('\n');

        this.isLoading = true;
        try {
            const carePlanResult = await createCarePlanRecord({
                patientId: this.patientAccountId,
                careInstructions: this.careInstructions,
                nextFollowupDate: this.nextFollowupDate ? this.nextFollowupDate : null,
                redFlagsToMonitor: this.redFlagsToMonitor,
                medicationsJson: JSON.stringify(allInputs)
            });

            if (carePlanResult.status === 'success') {
                this.carePlanId = carePlanResult.recordId;
                 this.showToast('Success / सफल', 'Care Plan created successfully. / देखभाल योजना सफलतापूर्वक बनाई गई है', 'success');                
                    const careTransitionData = {
                    officerFullName: this.officerFullName,
                    officerEmployeeId: this.officerEmployeeId,
                    patientAccountId: this.patientAccountId,
                    carePlanId: this.carePlanId,
                    notes: this.notes,
                    uploadedFileIds: this.referralFile,
                    proceduresPerformed: this.proceduresPerformed,
                    outcomesOfIntervention: this.outcomesOfIntervention,
                    treatingPhysicianNameDesignation: this.treatingPhysicianNameDesignation,
                    dischargeSummary: this.dischargeSummary,
                    anyFurtherReferralPlanned: this.anyFurtherReferralPlanned,
                    furtherReferralTo: this.furtherReferralTo,
                    patientMrnIdSpecificToTheirHms: this.patientMrnId,
                    phwcDoctorId: this.phwcDoctorId,
                    finalConfirmedDiagnosis: this.finalConfirmedDiagnosis,
                    selectedHospitalName: this.loggedInHospital,
                    selectedCity: this.loggedInCity
                };

                console.log('Selected Hospital:', this.loggedInHospital);

                const careTransitionResult = await createCareTransitionRecord(careTransitionData);

                 if (careTransitionResult.status === 'success') {
                     this.showToast('Success / सफल', 'Care Transition record created successfully. / केयर ट्रांजिशन रिकॉर्ड सफलतापूर्वक बनाया गया।', 'success');

                    // *** CRITICAL CHANGE FOR FULL PAGE THANK YOU DISPLAY ***
                     this.showMainContent = false; // Hides the entire main form content (header, stepper, current form steps)
                    this.showThankYouPage = true; // Displays ONLY the thank you page
                     // Set step completion flags AFTER hiding main content, to avoid flicker and ensure they are ready for next time
                    this.isStep1Complete = true;
                  this.isStep2Complete = true;
                   this.isStep3Complete = true;
                 this.isStep4Complete = true; // This is the final step for Patient Care Transition flow
                  this.currentStep = '4'; // Set current step to the final step number so the stepper displays completed state

                     // Reset form data in the background for a clean slate when they return to login
                     this.resetForm();

                 } else {
                     this.showToast('Error / त्रुटि', 'Failed to create Care Transition record: ' + careTransitionResult.message + ' / केयर ट्रांजिशन रिकॉर्ड बनाने में विफल रहा: ' + careTransitionResult.message, 'error');
                 }

            } else {
                this.showToast('Error / त्रुटि', 'Failed to create Care Plan: ' + carePlanResult.message + ' / केयर प्लान बनाने में विफल रहा: ' + carePlanResult.message, 'error');
            }
        } catch (error) {
            this.showToast('Error / त्रुटि', 'An unexpected error occurred during record creation: ' + this.getErrorMessage(error) + ' / रिकॉर्ड निर्माण के दौरान एक अप्रत्याशित त्रुटि हुई: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- File Upload Handlers ---
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        let fileNames = uploadedFiles.map(file => file.name).join(', ');
        this.showToast('Success / सफल', uploadedFiles.length + ' files uploaded: ' + fileNames + ' / ' + uploadedFiles.length + ' फाइलें अपलोड की गईं: ' + fileNames, 'success');

        const newFileDetails = uploadedFiles.map(file => ({ id: file.documentId, name: file.name }));
        this.uploadedFileIds = [...this.uploadedFileIds, ...newFileDetails.map(f => f.id)];
        this.uploadedAllFiles = [...this.uploadedAllFiles, ...newFileDetails];
    }

    handleRemoveFile(event) {
        const fileNameToRemove = event.target.dataset.fileName;

        if (!fileNameToRemove) {
            return;
        }

        this.referralFile = this.referralFile.filter(file => file.fileName !== fileNameToRemove);
        this.uploadedAllFiles = this.uploadedAllFiles.filter(file => file.name !== fileNameToRemove);

        this.showToast('Success / सफल', 'File removed successfully: ' + fileNameToRemove + ' / दस्तावेज़ सफलतापूर्वक हटाया गया: ' + fileNameToRemove, 'success');
    }

    // --- Navigation ---
    handlePrevious() {
        // if (this.currentStep === '1' && this.showOtpInput) {
        //     this.showOtpInput = false;
        //     this.showCityHospitalInput = true;
        // } else if (this.currentStep === '2') {
        //     this.currentStep = '1';
        //     this.isStep1Complete = false;
        //     this.showCityHospitalInput = false; // Stay on OTP input view for step 1
        //     this.showOtpInput = true; // Show OTP input if returning from step 2
        // } else if (this.currentStep === '3') {
        //     this.currentStep = '2';
        //     this.isStep2Complete = false;
        // } else if (this.currentStep === '4') { // Only Patient Care Transition reaches here
        //     this.currentStep = '3';
        //     this.isStep3Complete = false;
        //     this.isStep4Complete = false;
        // }
        this.isLoggedIn = true;
        this.fetchInactivityTime();
        this.startInactivityTimer();    
        this.currentStep = '';
        this.isStep3Complete = false;
        this.isStep4Complete = false;
        this.isStep2Complete = false;
        this.isStep1Complete = false;
        this.showOtpInput = false;
        this.showCityHospitalInput = false;
        this.showInitialSelection=true;
        this.showPatientReport=false;
        this.isStep3Report=false;
        this.phwcReferralIdInput=null;
        this.resetFormData();   // clear current flow data
        this.resetUiState();    // go back to cards
    }

    resetUiState() {
        this.currentStep = '';
        this.selectedFlowType = '';
        this.showInitialSelection = true;
        this.showPatientReport = false;
        this.isStep3Report = false;
        this.showValidationSearch = false;
        this.validationReferralInput = '';
        this.validationReferralName = null;
        this.showThankYouPage = false;
        this.showMainContent = true;
        this.isZipping=false;
        this.portalHeaderTitle = 'Empanelled Healthcare Portal / सूचीबद्ध स्वास्थ्य सेवा पोर्टल';
    }

    resetFormData() {
        // City / Hospital / OTP
        this.selectedCity = '';
        this.selectedHospital = '';
        this.otp1 = this.otp2 = this.otp3 =
        this.otp4 = this.otp5 = this.otp6 = '';
        this.isDataVisible=false;
        this.isConsentGranted = true;

        // Officer
        this.officerFullName = '';
        this.officerEmployeeId = '';

        // Referral / Patient
        this.phwcReferralIdInput = '';
        this.phwcReferralId = '';
        this.patientAccountId = '';
        this.patientFullName = '';
        this.patientAge = '';
        this.patientGender = '';
        this.pmjayId = '';
        this.memberId = '';
        this.patientMrnId = '';
        this.phwcDoctorId = '';
        this.patientPhone = '';

        // Medical
        this.finalConfirmedDiagnosis = '';
        this.proceduresPerformed = '';
        this.dischargeSummary = '';
        this.outcomesOfIntervention = '';
        this.careInstructions = '';
        this.nextFollowupDate = '';
        this.redFlagsToMonitor = '';
        this.anyFurtherReferralPlanned = 'No';
        this.furtherReferralTo = '';

        // Files
        this.summaryFiles = [];
        this.diagnosticFiles = [];
        this.uploadedAllFiles = [];
        this.uploadedFileIds = [];
        this.referralFile = [];

        // Checkboxes
        this.isLabReportsChecked = false;
        this.isImagingReportsChecked = false;
        this.isDischargeSummaryChecked = false;
        this.isPrescriptionsChecked = false;
        this.isOtherAttachmentChecked = false;
        this.otherAttachmentDetails = '';

        // IDs
        this.carePlanId = '';
        this.careTransitionId = '';

        this.resetCompletionFlags();
    }

    handleInputChange(event) {
        const { name, value, type, checked } = event.target;
        const field = event.target.name;
        this[field] = event.detail ? event.detail.value : event.target.value;
        if (field === 'selectedCity' && this.isLocationAllowed && this.detectedCity) {
            if (!this.isCityMatching(this.selectedCity, this.detectedCity)&& !this.cityMismatchToastShown) {
               const toast = new ShowToastEvent({
                    title: 'Location Mismatch / स्थान असंगति',
                    message:
                        `Your current location appears to be ${this.detectedCity}.
                आप जिस शहर से लॉगिन कर रहे हैं, वह चयनित शहर से मेल नहीं खाता।`,
                    variant: 'warning'
                });
                this.dispatchEvent(toast);
            }
        }

        if (type === 'radio') {
            this[name] = value;
            if (name === 'anyFurtherReferralPlanned' && value === 'No') {
                this.furtherReferralTo = '';
            }
        } else if (type === 'checkbox') {
            if (name === 'declarationConsent') {
                this.declarationConsent = checked;
            } else {
                this[name] = checked;
            }
        } else {
            this[name] = value;
        }

        // Specifically for city, clear hospital options when city changes
        if (name === 'selectedCity') {
            this.selectedHospital = '';
            this.hospitalOptions = [];
            if (value) {
                this.fetchHospitalsByCity(value);
            }
        }
    }

    // --- NEW: General Key Down Handler for 'Enter' to navigate/submit ---
    handleKeyDown(event) {
        if (event.key === 'Enter') {
            const currentField = event.target;
            const fieldName = currentField.name; // Use 'name' attribute for consistency
            const elementType = currentField.tagName.toLowerCase(); // 'input', 'textarea', 'lightning-combobox', etc.
            const inputType = currentField.type; // 'text', 'date', 'checkbox', 'radio'

            // Prevent default form submission behavior (important for single-line inputs to avoid page refresh)
            event.preventDefault();

            // Special handling for specific scenarios/buttons on Enter
            if (this.currentStep === '1') {
                if (this.showCityHospitalInput) {
                    if (fieldName === 'selectedCity') {
                        const hospitalInput = this.template.querySelector('[name="selectedHospital"]');
                        if (hospitalInput) {
                            hospitalInput.focus();
                        }
                    } else if (fieldName === 'selectedHospital') {
                        // Enter on hospital dropdown triggers Send OTP
                        this.handleSendOtp();
                    }
                }
                // OTP 'Enter' key handling is now exclusively in handleOtpKeydown,
                // so we don't need a specific block for showOtpInput here.
                // The handleOtpKeydown will call handleVerifyOtp directly from otp6.
            } else if (this.currentStep === '2') {
                if (fieldName === 'officerFullName') {
                    const employeeIdInput = this.template.querySelector('[name="officerEmployeeId"]');
                    if (employeeIdInput) {
                        employeeIdInput.focus();
                    }
                } else if (fieldName === 'officerEmployeeId') {
                    // Enter on Employee ID triggers Continue
                    this.handleContinue();
                }
            } else if (this.currentStep === '3') {
                if (fieldName === 'phwcReferralIdInput') {
                    // Enter on Referral ID input triggers search
                    this.handleSearchReferral();
                } else if (this.isPatientReceivedFlow && fieldName === 'receivedDate') {
                    // Enter on Received Date input triggers submission for Patient Received flow
                    this.handleSubmitPatientReceivedDate();
                } else if (this.isPatientCareTransitionFlow) {
                    // For Patient Care Transition flow, try to find the next focusable element.
                    // If no more, then consider submitting.

                    // Get all focusable elements within the main content card
                    const focusableElements = [...this.template.querySelectorAll(
                        'input:not([type="hidden"]):not([disabled]), textarea:not([disabled]), select:not([disabled]), button:not([disabled]), a[href]:not([disabled]), [tabindex]:not([tabindex="-1"]):not([disabled])'
                    )].filter(el => {
                        // Only consider elements that are currently visible and part of step 3 content.
                        // This is a heuristic and might need fine-tuning based on your CSS.
                        return el.offsetParent !== null && !el.closest('.initial-selection-container') && !el.closest('.progress-stepper');
                    });

                    const currentIndex = focusableElements.findIndex(el => el === currentField);

                    if (currentIndex > -1 && currentIndex < focusableElements.length - 1) {
                        let nextElement = focusableElements[currentIndex + 1];
                        // Skip read-only inputs unless it's the specific target for review
                        while (nextElement && (nextElement.readOnly || nextElement.disabled)) {
                            nextElement = focusableElements[++currentIndex + 1];
                        }
                        if (nextElement) {
                            nextElement.focus();
                        } else {
                            // If no more focusable elements found, try to submit
                            this.handleCompleteCareTransition();
                        }
                    } else if (currentIndex === focusableElements.length - 1) {
                        // If it's the last focusable element in the list, attempt to submit.
                        this.handleCompleteCareTransition();
                    } else if (currentField.tagName === 'TEXTAREA' || currentType === 'checkbox') {
                        // Specific check for textarea or checkbox where Enter might not naturally go to next field
                        // If it's a textarea, usually Enter adds a new line. We prevent that here to navigate.
                        // For checkboxes, just try to navigate next or submit if it's the last.
                        // This block can be refined; a simpler approach is below.
                        this.handleCompleteCareTransition(); // For simplicity, submit if it's a textarea/checkbox and nothing else to focus.
                    }
                }
            }
        }
    }

    handleOtpInput(event) {
        const { name, value } = event.target;
        let inputIndex = parseInt(name.replace('otp', ''), 10);

        // Prioritize paste event first.
        // The 'paste' event typically fires before 'input' event content is processed.
        // We handle paste using 'onpaste' attribute in HTML directly for better control.
        // So this 'if (event.clipboardData)' block is actually better handled by a dedicated 'handleOtpPaste' method.
        // For now, if somehow paste changes 'value', we will process it as below.

        const sanitizedValue = value.replace(/\D/g, '').charAt(0); // Ensure it's a single digit

        // Update the LWC property first
        this[name] = sanitizedValue;

        // If a digit was entered and it's not the last input, move focus to the next input
        if (sanitizedValue && inputIndex < 6) {
            const nextInput = this.template.querySelector(`[name="otp${inputIndex + 1}"]`);
            if (nextInput) {
                // Use a tiny timeout to ensure the DOM is ready for focus change
                setTimeout(() => {
                    nextInput.focus();
                }, 0);
            }
        } else if (sanitizedValue && inputIndex === 6) {
            // If the last OTP box is filled, attempt to verify OTP
            // This is primarily for users who manually type the last digit
            this.handleVerifyOtp();
        }
    }

    handleOtpKeydown(event) {
        const { name, value, selectionStart } = event.target;
        const inputIndex = parseInt(name.replace('otp', ''), 10);

        if (event.key === 'Backspace') {
            event.preventDefault(); // Prevent browser back navigation

            if (value.length > 0) {
                // If current field has a value, clear it
                this[name] = '';
            } else if (inputIndex > 1) {
                // If current field is empty, move to previous field and clear it
                const prevInputName = `otp${inputIndex - 1}`;
                const prevInput = this.template.querySelector(`[name="${prevInputName}"]`);
                if (prevInput) {
                    this[prevInputName] = ''; // Clear the previous field
                    // Use a tiny timeout for focus to ensure LWC reactivity handles the value update first
                    setTimeout(() => {
                        prevInput.focus();
                    }, 0);
                }
            }
        } else if (event.key === 'Delete') {
            // Standard Delete key behavior: clear current char, don't shift focus usually
            if (value.length > 0) {
                this[name] = '';
            }
        } else if (event.key === 'Enter' && inputIndex === 6) {
            // Allow Enter key to trigger verification from the last OTP input
            event.preventDefault(); // Prevent any default form submission
            this.handleVerifyOtp();
        }
        // For other keys, let default input handling proceed via handleOtpInput
    }

    handleOtpFocus(event) {
        const inputElement = event.target;
        // Set a tiny timeout to ensure focus is applied after any internal LWC rendering updates
        setTimeout(() => {
            if (inputElement) {
                const valueLength = inputElement.value ? inputElement.value.length : 0;
                inputElement.setSelectionRange(valueLength, valueLength);
            }
        }, 0);
    }

    // New dedicated paste handler for OTP inputs
    handleOtpPaste(event) {
        event.preventDefault(); // Prevent default paste action to handle it manually

        const pastedData = event.clipboardData.getData('text').replace(/\D/g, ''); // Get only digits
        if (pastedData.length >= 6) { // If pasted data has at least 6 digits
            this.otp1 = pastedData[0];
            this.otp2 = pastedData[1];
            this.otp3 = pastedData[2];
            this.otp4 = pastedData[3];
            this.otp5 = pastedData[4];
            this.otp6 = pastedData[5];

            // Manually update the DOM elements to show the pasted values instantly
            // This is important because LWC's reactivity might be slightly delayed
            this.template.querySelector('[name="otp1"]').value = this.otp1;
            this.template.querySelector('[name="otp2"]').value = this.otp2;
            this.template.querySelector('[name="otp3"]').value = this.otp3;
            this.template.querySelector('[name="otp4"]').value = this.otp4;
            this.template.querySelector('[name="otp5"]').value = this.otp5;
            this.template.querySelector('[name="otp6"]').value = this.otp6;

            // Move focus to the last input after successful paste
            setTimeout(() => {
                this.template.querySelector('[name="otp6"]').focus();
                // Optionally, trigger verification right after a successful paste of a full OTP
                this.handleVerifyOtp();
            }, 0);
        } else {
            // If less than 6 digits were pasted, maybe just paste into the current field
            // Or show an error/warning. For simplicity, we'll let handleOtpInput handle it
            // if only a single digit or non-digit was pasted.
            // To ensure it processes as a single char, you might want to force the target's value.
            const targetInput = event.target;
            const singleDigit = pastedData.charAt(0);
            targetInput.value = singleDigit;
            this[targetInput.name] = singleDigit;

            // Trigger the auto-focus logic if a single digit was pasted
            this.handleOtpInput({ target: targetInput, clipboardData: null }); // Call without clipboardData to prevent re-processing paste
        }
    }


    handleKeyDown(event) {
        if (event.key === 'Enter') {
            const currentField = event.target;
            const fieldName = currentField.name; // Use 'name' attribute for consistency

            // Prevent default form submission behavior (important for single-line inputs to avoid page refresh)
            event.preventDefault();

            // Special handling for specific scenarios/buttons on Enter
            if (this.currentStep === '1') {
                if (this.showCityHospitalInput) {
                    if (fieldName === 'selectedCity') {
                        const hospitalInput = this.template.querySelector('[name="selectedHospital"]');
                        if (hospitalInput) {
                            hospitalInput.focus();
                        }
                    } else if (fieldName === 'selectedHospital') {
                        // Enter on hospital dropdown triggers Send OTP
                        this.handleSendOtp();
                    }
                }
                // OTP 'Enter' key handling is now exclusively in handleOtpKeydown,
                // so we don't need a specific block for showOtpInput here.
                // The handleOtpKeydown will call handleVerifyOtp directly from otp6.
            } else if (this.currentStep === '2') {
                if (fieldName === 'officerFullName') {
                    const employeeIdInput = this.template.querySelector('[name="officerEmployeeId"]');
                    if (employeeIdInput) {
                        employeeIdInput.focus();
                    }
                } else if (fieldName === 'officerEmployeeId') {
                    // Enter on Employee ID triggers Continue
                    this.handleContinue();
                }
            } else if (this.currentStep === '3') {
                if (fieldName === 'phwcReferralIdInput') {
                    // Enter on Referral ID input triggers search
                    this.handleSearchReferral();
                } else if (this.isPatientReceivedFlow && fieldName === 'receivedDate') {
                    // Enter on Received Date input triggers submission for Patient Received flow
                    this.handleSubmitPatientReceivedDate();
                } else if (this.isPatientCareTransitionFlow) {
                    // For Patient Care Transition flow, try to find the next focusable element.
                    // If no more, then consider submitting.

                    // Get all focusable elements within the main content card
                    const focusableElements = [...this.template.querySelectorAll(
                        'input:not([type="hidden"]):not([disabled]), textarea:not([disabled]), select:not([disabled]), button:not([disabled]), a[href]:not([disabled]), [tabindex]:not([tabindex="-1"]):not([disabled])'
                    )].filter(el => {
                        // Only consider elements that are currently visible and part of step 3 content.
                        // This is a heuristic and might need fine-tuning based on your CSS.
                        return el.offsetParent !== null && !el.closest('.initial-selection-container') && !el.closest('.progress-stepper');
                    });

                    const currentIndex = focusableElements.findIndex(el => el === currentField);

                    if (currentIndex > -1 && currentIndex < focusableElements.length - 1) {
                        let nextElement = focusableElements[currentIndex + 1];
                        // Skip read-only inputs unless it's the specific target for review
                        while (nextElement && (nextElement.readOnly || nextElement.disabled)) {
                            nextElement = focusableElements[++currentIndex + 1];
                        }
                        if (nextElement) {
                            nextElement.focus();
                        } else {
                            // If no more focusable elements found, try to submit
                            this.handleCompleteCareTransition();
                        }
                    } else if (currentIndex === focusableElements.length - 1) {
                        // If it's the last focusable element in the list, attempt to submit.
                        this.handleCompleteCareTransition();
                    } else if (currentField.tagName === 'TEXTAREA' || currentType === 'checkbox') {
                        // Specific check for textarea or checkbox where Enter might not naturally go to next field
                        // If it's a textarea, usually Enter adds a new line. We prevent that here to navigate.
                        // For checkboxes, just try to navigate next or submit if it's the last.
                        // This block can be refined; a simpler approach is below.
                        this.handleCompleteCareTransition(); // For simplicity, submit if it's a textarea/checkbox and nothing else to focus.
                    }
                }
            }
        }
    }


    // --- Helper Functions ---
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    @track referralFile = [];
    handleReferralFile(event) {
        if (event.target.files.length > 0) {
            for (let i = 0; i < event.target.files.length; i++) {
                let file = event.target.files[i];

                if (file.size > this.MAX_FILE_SIZE) {
                    this.showToast('Error / त्रुटि', 'The maximum file size is 2.5 MB (' + file.name + ') / अधिकतम 2.5 MB प्रति दस्तावेज़ (' + file.name + ')', 'error');
                    continue;
                }

                if (this.uploadedAllFiles.some(existingFile => existingFile.name === file.name)) {
                    this.showToast('Warning / चेतावनी', 'A file with this name has already been added: ' + file.name + ' / इस नाम का दस्तावेज़ पहले से संलग्न है: ' + file.name, 'warning');
                    continue;
                }

                let reader = new FileReader();
                reader.onload = () => {
                    let base64 = reader.result.split(',')[1];
                    let referralObj = {
                        base64: base64,
                        fileName: file.name,
                        fileSize: file.size
                    };

                    this.referralFile = [...this.referralFile, referralObj];
                    this.uploadedAllFiles = [...this.uploadedAllFiles, { id: null, name: file.name }];
                };
                reader.readAsDataURL(file);
            }
        }
    }


    getErrorMessage(error) {
        let message = 'Unknown error / अज्ञात त्रुटि';
        if (error.body) {
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length > 0) {
                message = error.body.pageErrors[0].message;
            } else if (error.body.message) {
                message = error.body.message;
            } else if (typeof error.body === 'string') {
                message = error.body;
            }
        } else if (error.message) {
            message = error.message;
        }
        return message;
    }

    // --- Reset Functions ---
    // This function is now solely responsible for resetting form fields and stepper completion flags.
    // It does NOT control which "page" is visible (showInitialSelection, showThankYouPage, showMainContent).
    resetForm() {
        this.selectedCity = '';
        this.selectedHospital = '';
        this.otp1 = ''; this.otp2 = ''; this.otp3 = ''; this.otp4 = ''; this.otp5 = ''; this.otp6 = '';
        this.officerFullName = '';
        this.officerEmployeeId = '';
        this.phwcReferralIdInput = '';
        this.resetAllPatientDetails(); // This also resets many fields related to patient data

        this.declarationConsent = false;
        this.receivedDate = null;

        // Stepper completion flags are handled in the success methods for the final state
        this.isStep1Complete = false;
        this.isStep2Complete = false;
        this.isStep3Complete = false;
        this.isStep4Complete = false;

        this.carePlanId = '';
        this.careTransitionId = '';
        this.medicationListFromChild = [];
        this.fetchDistinctCities(); // Re-fetch cities for fresh start

        this.showCityHospitalInput = true; // Ensure Step 1 starts with city/hospital input
        this.showOtpInput = false;
        this.showMedicationTable = false;
        // Importantly, NO changes to showInitialSelection, showThankYouPage, or showMainContent here.
        // Those are managed by the flow completion or navigation methods.
    }

    // This function is specifically for when navigating *back* to the initial selection page
    // from any step of the main form. It ensures all relevant flags are reset for a fresh start.
    resetFormOnBack() {
        this.selectedCity = '';
        this.selectedHospital = '';
        this.otp1 = ''; this.otp2 = ''; this.otp3 = ''; this.otp4 = ''; this.otp5 = ''; this.otp6 = '';
        this.officerFullName = '';
        this.officerEmployeeId = '';
        this.phwcReferralIdInput = '';
        this.resetAllPatientDetails();

        this.declarationConsent = false;
        this.receivedDate = null;

        this.isStep1Complete = false;
        this.isStep2Complete = false;
        this.isStep3Complete = false;
        this.isStep4Complete = false;
        this.carePlanId = '';
        this.careTransitionId = '';
        this.medicationListFromChild = [];
        this.fetchDistinctCities();

        this.showCityHospitalInput = true;
        this.showOtpInput = false;
        this.showMedicationTable = false;
        this.selectedFlowType = ''; // Clear selected flow type to show both initial cards
        this.showThankYouPage = false; // Ensure thank you page is hidden
        this.showMainContent = true; // Ensure main content (header, stepper, initial selection) is visible
        this.showInitialSelection = true; // Make sure initial selection is visible
        this.resetCompletionFlags(); // Ensure all stepper ticks are cleared
    }

    resetPatientDetailsAndEditability() {
        this.isConsentGranted = true; // clear consent-pending warning from a previous search
        this.phwcReferralId = '';
        this.patientAccountId = '';
        this.patientFullName = '';
        this.patientAge = '';
        this.patientGender = '';
        this.pmjayId = '';
        this.memberId = '';
        this.patientMrnId = '';
        this.phwcDoctorId = '';
        this.isPatientDetailsReadonly = true;

        this.finalConfirmedDiagnosis = '';
        this.proceduresPerformed = '';
        this.dischargeSummary = '';
        this.outcomesOfIntervention = '';
        this.careInstructions = '';
        this.nextFollowupDate = '';
        this.redFlagsToMonitor = '';
        this.anyFurtherReferralPlanned = 'No';
        this.furtherReferralTo = '';
        this.treatingPhysicianNameDesignation = '';
        this.notes = '';
        this.uploadedFileIds = [];

        this.isLabReportsChecked = false;
        this.isImagingReportsChecked = false;
        this.isDischargeSummaryChecked = false;
        this.isPrescriptionsChecked = false;
        this.isOtherAttachmentChecked = false;
        this.otherAttachmentDetails = '';
        this.uploadedAllFiles = [];

        this.careTransitionId = '';
        this.showMedicationTable = false;
    }

    resetAllPatientDetails() {
        this.phwcReferralId = '';
        this.patientAccountId = '';
        this.patientFullName = '';
        this.patientAge = '';
        this.patientGender = '';
        this.pmjayId = '';
        this.memberId = '';
        this.patientMrnId = '';
        this.phwcDoctorId = '';
        this.isPatientDetailsReadonly = true;

        this.finalConfirmedDiagnosis = '';
        this.proceduresPerformed = '';
        this.dischargeSummary = '';
        this.outcomesOfIntervention = '';
        this.careInstructions = '';
        this.nextFollowupDate = '';
        this.redFlagsToMonitor = '';
        this.anyFurtherReferralPlanned = 'No';
        this.furtherReferralTo = '';
        this.treatingPhysicianNameDesignation = '';
        this.notes = '';
        this.uploadedFileIds = [];
        this.medicationListFromChild = [];

        this.isLabReportsChecked = false;
        this.isImagingReportsChecked = false;
        this.isDischargeSummaryChecked = false;
        this.isPrescriptionsChecked = false;
        this.isOtherAttachmentChecked = false;
        this.otherAttachmentDetails = '';
        this.uploadedAllFiles = [];

        this.careTransitionId = '';
        this.showMedicationTable = false;
    }

    // NEW: Helper to reset all step completion flags
    resetCompletionFlags() {
        this.isStep1Complete = false;
        this.isStep2Complete = false;
        this.isStep3Complete = false;
        this.isStep4Complete = false;
    }


    handleMedication(event) {
        this.medicationListFromChild = event.detail;
        this.showMedicationTable = (this.medicationListFromChild && this.medicationListFromChild.length > 0);
    }

    // NEW: Handler for the "Return to Login Page" button on the thank you page
    handleReturnToLogin() {
        this.showThankYouPage = false; // Hide the thank you page
        this.showMainContent = true; // Show the main application content (header, stepper, initial selection)
        this.showInitialSelection = true; // Display the initial flow selection cards
        this.currentStep = '1'; // Reset current step for new flow, this also manages stepper display to '1'
        this.selectedFlowType = ''; // Clear selected flow type

        this.portalHeaderTitle = 'Empanelled Healthcare Portal / सूचीबद्ध स्वास्थ्य सेवा पोर्टल'; // Reset header title
        this.resetForm(); // Reset all form input data for a fresh start
        this.resetCompletionFlags(); // Ensure all stepper ticks are cleared for a new user journey
        console.log('LWC: Returned to initial selection from thank you page.');
        this.resetFormData();
        this.resetUiState();
    }
}