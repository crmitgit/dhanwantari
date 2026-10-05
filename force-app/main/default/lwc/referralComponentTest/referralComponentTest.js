import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';



// Corrected import path for createReferral
import createReferral from '@salesforce/apex/ClinicalEncounterController2.createReferral';

// Existing Apex Imports for Clinical Encounters and Provider Search
import getLatestEncountersWithDiagnosis from '@salesforce/apex/ClinicalEncounterController2.getLatestEncountersWithDiagnosis';
import searchProviders from '@salesforce/apex/HealthcareProviderController.searchProviders';
import getSpecialties from '@salesforce/apex/HealthcareProviderController.getSpecialties';


// Apex Imports for Case File Preview, using your existing controller names
import getCaseFileData from '@salesforce/apex/PreviewCaseFileController.getCaseFileData';
import getClinicalEncounterTimeline from '@salesforce/apex/PreviewCaseFileController.getClinicalEncounterTimeline';
import getMedicationData from '@salesforce/apex/MedicationController.getMedicationData';
import getTestReportsSummary from '@salesforce/apex/MedicationController.getTestReportsSummary';

// Import your static resources
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import Government_logo from '@salesforce/resourceUrl/Government_logo';
import caseFileLogo from '@salesforce/resourceUrl/caseFileLogo';
import generatedByAi from '@salesforce/resourceUrl/generatedByAI';
import generateAndAttachPDF from '@salesforce/apex/ClinicalEncounterController2.generateAndAttachPDF';
import sendPatientCasePrompt from '@salesforce/apex/ClinicalEncounterFormatter.sendPatientCasePrompt';
import getDraftReferrals from '@salesforce/apex/DraftReferralController.getDraftReferrals';


const FIELDS = ['Account.PMJAY_Scheme_Verified__c'];


export default class ClinicalEncounters extends NavigationMixin(LightningElement) {
    @api recordId; // This will hold the Account Id from the record page
    @track clinicalEncounters = [];
    @track selectedCount = 0;
    @track error;
    patientRecord;
    @track patientName = '';
    @track age = ''; // This property will store the patient's age
    @track isConsentChecked = false;
    @track isAiConfirmationChecked = false;

    leftCornerImageUrl = pmjayLogo;
    rightCornerImageUrl = Government_logo;
    logoUrl = caseFileLogo; // Renamed from logoUrl for clarity in this combined component
    genAI = generatedByAi;

    // --- Modal Visibility Flags ---
    @track isShowMainModel = true;
    @track isShowReferralModal = false;
    @track isShowCaseFileModal = false;
    @track isLoadingReferralCreation = false; // Added for spinner

    // --- Properties for Healthcare Provider Search Modal ---
    @track searchCriteria = {
        city: '',
        hospitalType: '',
        primarySpecialty: '',
        secondarySpecialty: ''
    };

    @track selectedCountArray = [];

    cityOptions = [
        { label: 'None', value: '' },
        { label: 'Almora', value: 'Almora' },
        { label: 'Bageshwar', value: 'Bageshwar' },
        { label: 'Chamoli', value: 'Chamoli' },
        { label: 'Champawat', value: 'Champawat' },
        { label: 'Dehradun', value: 'Dehradun' },
        { label: 'Haldwani', value: 'Haldwani' },
        { label: 'Haridwar', value: 'Haridwar' },
        { label: 'Kashipur', value: 'Kashipur' },
        { label: 'Kotdwar', value: 'Kotdwar' },
        { label: 'Laksar', value: 'Laksar' },
        { label: 'Manglaur', value: 'Manglaur' },
        { label: 'Mussoorie', value: 'Mussoorie' },
        { label: 'Nainital', value: 'Nainital' },
        { label: 'Pauri Garhwal', value: 'Pauri Garhwal' },
        { label: 'Pithoragarh', value: 'Pithoragarh' },
        { label: 'Ramnagar', value: 'Ramnagar' },
        { label: 'Rishikesh', value: 'Rishikesh' },
        { label: 'Roorkee', value: 'Roorkee' },
        { label: 'Rudraprayag', value: 'Rudraprayag' },
        { label: 'Tanakpur', value: 'Tanakpur' },
        { label: 'Tehri Garhwal', value: 'Tehri Garhwal' },
        { label: 'Udham Singh Nagar', value: 'Udham Singh Nagar' },
        { label: 'Uttarkashi', value: 'Uttarkashi' },
        { label: 'Vikasnagar', value: 'Vikasnagar' }
    ];
    @track searchResults = [];
    @track specialtyOptions = [];
    @track selectedProviderId = '';

    @track isLoadingProviders = false;
    @track showResults = false;

    hospitalTypeOptions = [
        { label: 'Public', value: 'Public' },
        { label: 'Private (Not For Profit)', value: 'Private(Not For Profit)' },
        { label: 'Private (For Profit)', value: 'Private(For Profit)' }
    ];

    // --- Properties for Case File Preview Modal ---
    @track reasonForReferral = '';
    @track careSummary = '';
    @track referralSummaryBYAI = '';
    @track caseData = {};
    @track isLoadingCaseFile = true;
    @track isLoadingTimeline = false;
    @track isLoadingMedications = false;
    @track isLoadingTestReports = false;
    // @track isLoading = true;
    @track caseFileError;
    @track medicationError;
    @track testReportsError;
    @track preliminaryDiagnosis = '';
    @track timelineData = [];
    @track activeMedications = [];
    @track pastMedications = [];
    @track testReportsData = [];
    @track recommendedVisitBy = '';
    @track referralPriority = '';
    @track latestEncounterId = [];

    primarySpecialityName;
    secondarySpecialityName;
    @track selectedEncounterList = [];

    _selectedEncounterIdsForCaseFile = [];
    @track isReferralDisabled = true;


    @track currentLoadingMessage = '';
    @track messageIndex = 0;
    loadingInterval;

    @track showConfirmationModal = false;

    showError = false;

    @track isShowDraftSelectionModal = false;
    @track draftReferrals = [];
    @track selectedDraftId = null;
    @track isDraftMode = false;
    @track currentReferralId = null;
    @track isInitialLoad = true; 
    @track currentReferralName = 'To be generated';
    wiredDraftResult;
    hasRefreshedOnLoad = false;


    //consent 
    @track isConsentPending = false;
    @track isDigitalConsentInitiated = true;
    @track isManualConsentChecked = false;
    @track manualConsentReason = '';
    
    subscription = {};
    channelName = '/event/Patient_Consent_Event__e';
    pollingInterval;

    get manualConsentReasonOptions() {
        return [
            {
                label: 'Emergency situation / आपातकालीन स्थिति',
                value: 'Emergency situation'
            },
            {
                label: 'Patient illiterate / unable to use digital consent / रोगी अशिक्षित है / डिजिटल सहमति का उपयोग करने में असमर्थ है',
                value: 'Patient illiterate / unable to use digital consent'
            },
            {
                label: 'Patient consent obtained earlier in person / रोगी की सहमति पूर्व में व्यक्तिगत रूप से प्राप्त की गई थी',
                value: 'Patient consent obtained earlier in person'
            }
        ];
    }


    // Computed Properties
    get hasAnyConsent() {
        return this.isDigitalConsentInitiated || 
               (this.isManualConsentChecked && this.manualConsentReason);
    }

    handleDigitalConsentToggle(event) {
    this.isDigitalConsentInitiated = event.target.checked;

    if (this.isDigitalConsentInitiated) {
        // Disable manual consent
        this.isManualConsentChecked = false;
        this.manualConsentReason = '';
    }
}



    handleManualConsentToggle(event) {
        this.isManualConsentChecked = event.target.checked;
        
        if (this.isManualConsentChecked) {
        // Disable digital consent
        this.isDigitalConsentInitiated = false;
    } else {
        // Clear reason when unchecked
        this.manualConsentReason = '';
    }
    }
handleManualConsentReasonChange(event) {
        this.manualConsentReason = event.detail.value;
        this.showError = !this.manualConsentReason;

    }

    validateManualConsent() {
        if (this.isManualConsentChecked && !this.manualConsentReason) {
            this.showError = true;
            return false;
        }
        this.showError = false;
        return true;
    }



 @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredPatient({ error, data }) {
        if (data) {
            this.patientRecord = data;
            this.validatePMJAYScheme();
            } else if (error) {
            console.error('Error loading patient record:', error);
        }
    }
    
    validatePMJAYScheme() {
        const isPMJAYVerified = this.patientRecord?.fields?.PMJAY_Scheme_Verified__c?.value;
        
        if (!isPMJAYVerified) {
            // Show toast message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'PMJAY Verification Required',
                    message: 'Patient must be verified under the PMJAY Scheme before referral can be processed.',
                    variant: 'warning',
                    mode: 'sticky'
                })
            );
            
            // Close the component
            this.dispatchEvent(new CloseActionScreenEvent());
            return false;
        }
        
        return true;
    }

    getLoadingMessages() {
        return [
            `Sending referral summary to ${this.selectedProviderName || 'healthcare provider'}...`,
            'Finalizing referral details...',
            'Almost done...'
        ];
    }

    connectedCallback() {
        this.loadSpecialties();
        document.addEventListener('keydown', this.handleEscapeKey.bind(this));
    }

    handlePreliminaryDiagnosisChange(event) {
        this.preliminaryDiagnosis = event.target.value;
        console.log('Preliminary Diagnosis updated:', this.preliminaryDiagnosis);
    }

    disconnectedCallback() {
        document.removeEventListener('keydown', this.handleEscapeKey.bind(this));
        this.stopLoadingMessages();
    }

    get isSelectedDraftDisabled() {
    return !this.selectedDraftId;
}


   @wire(getDraftReferrals, { patientId: '$recordId' })
wiredDraftReferrals(result) {
    this.wiredDraftResult = result; // Store the wire result
    const { error, data } = result;    
    if (data) {
        this.draftReferrals = data.map(draft => ({
            ...draft,
            selected: false
        }));
        
        // CRITICAL FIX: Handle initial flow based on draft existence
        // This happens when the component loads initially (e.g., button click to open referral)
        if (this.isInitialLoad) {
            this.isInitialLoad = false;
            if (this.draftReferrals.length > 0) {
                // Has drafts - show draft selection modal first
                this.isShowDraftSelectionModal = true;
                this.isShowMainModel = false;
            } else {
                // No drafts - show clinical encounter modal directly
                this.isShowMainModel = true;
                this.isShowDraftSelectionModal = false;
            }
        }
    } else if (error) {
        this.showToast('Error', 'Error loading draft referrals: ' + error.body.message, 'error');
        // On error, show clinical encounter modal
        if (this.isInitialLoad) {
            this.isInitialLoad = false;
            this.isShowMainModel = true;
            this.isShowDraftSelectionModal = false;
        }
    }
}

 handleReferralClick(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const referralId = event.target.dataset.id;
    console.log('Referral ID:', referralId);
    
    if (referralId) {
        // Method 1: Using NavigationMixin (preferred)
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: referralId,
                actionName: 'view'
            }
        }).then(url => {
            window.open(url, '_blank');
        }).catch(error => {
            console.error('Navigation error:', error);
            // Fallback method
            this.openReferralFallback(referralId);
        });
    }
}

// Fallback method
openReferralFallback(referralId) {
    const recordUrl = `/lightning/r/YourReferralObject__c/${referralId}/view`;
    window.open(recordUrl, '_blank');
}

renderedCallback() {
    // Only refresh once when component first renders
    if (!this.hasRefreshedOnLoad && this.wiredDraftResult) {
        this.hasRefreshedOnLoad = true;
        refreshApex(this.wiredDraftResult);
    }
}

handleStartReferral() {
    // Reset state for new referral flow
    this.isInitialLoad = true;
    this.isDraftMode = false;
    this.currentReferralId = null;
    this.selectedDraftId = null;
    this.resetReferralData();
    
    // The wire method will determine which modal to show based on draft existence
    // This will trigger the @wire method to re-evaluate and show appropriate modal
    this.isInitialLoad = true;
    
    // If drafts are already loaded, immediately show appropriate modal
    if (this.draftReferrals !== undefined) {
        if (this.draftReferrals.length > 0) {
            // Has drafts - show draft selection modal first
            this.isShowDraftSelectionModal = true;
            this.isShowMainModel = false;
        } else {
            // No drafts - show clinical encounter modal directly
            this.isShowMainModel = true;
            this.isShowDraftSelectionModal = false;
        }
    }
}

get hasDraftReferrals() {
    return this.draftReferrals && this.draftReferrals.length > 0;
}


get isSelectedDraft() {
    return this.selectedDraftId !== null;
}



handleDraftSelect(event) {
    this.selectedDraftId = event.target.dataset.id;
    // Update selection state
    this.draftReferrals = this.draftReferrals.map(draft => ({
        ...draft,
        selected: draft.referralId === this.selectedDraftId
    }));
}

// FIXED: Use selected draft with proper data population
handleUseSelectedDraft() {
    if (!this.selectedDraftId) {
        this.showToast('Warning', 'Please select a draft referral', 'warning');
        return;
    }

    const selectedDraft = this.draftReferrals.find(draft => draft.referralId === this.selectedDraftId);
    
    if (selectedDraft) {
        // Populate all form fields from draft
        this.searchCriteria = {
            city: selectedDraft.city || '',
            hospitalType: selectedDraft.hospitalType || '',
            primarySpecialty: selectedDraft.primarySpecialty || '',
            secondarySpecialty: selectedDraft.secondarySpecialty || ''
        };
        this.primarySpecialityName = selectedDraft.primarySpecialty;
        this.secondarySpecialityName = selectedDraft.secondarySpecialty;
        
        this.reasonForReferral = selectedDraft.reasonForReferral || '';
        this.careSummary = selectedDraft.chiefComplaints || '';
        this.preliminaryDiagnosis = selectedDraft.preliminaryDiagnosis || '';
        this.recommendedVisitBy = selectedDraft.recommendedVisitBy;
        this.referralPriority = selectedDraft.referralPriority ? selectedDraft.referralPriority.toLowerCase() : '';
        this.selectedProviderId = selectedDraft.referredTo;
        this.selectedProviderName = selectedDraft.referredToName;
        this.currentReferralId = selectedDraft.referralId;
        this.currentReferralName = selectedDraft.referralName;
        
        // Convert encounter auto numbers to IDs for timeline data
       if (selectedDraft.selectedEncounterIds) {
    const encounterAutoNumbers = selectedDraft.selectedEncounterIds.split(',').map(num => num.trim());
    
    console.log('Draft encounter auto numbers:', encounterAutoNumbers);
    console.log('All clinical encounters:', this.clinicalEncounters);
    
    // Debug: Check what encounterName values look like
    console.log('Available encounter names:', this.clinicalEncounters.map(enc => enc.encounterName));
    
    // Find matching encounter IDs from clinicalEncounters
    this._selectedEncounterIdsForCaseFile = this.clinicalEncounters
        .filter(encounter => {
            const isMatch = encounterAutoNumbers.includes(encounter.encounterName);
            console.log(`Checking: ${encounter.encounterName} against [${encounterAutoNumbers.join(', ')}] = ${isMatch}`);
            return isMatch;
        })
        .map(encounter => encounter.encounterId);
        
    console.log('Matched encounter IDs:', this._selectedEncounterIdsForCaseFile);
} else {
    // If no encounters specified in draft, use empty array
    this._selectedEncounterIdsForCaseFile = [];
}
        this.isDraftMode = true;
        
        // Skip to case file modal since we have all the data
        this.isShowDraftSelectionModal = false;
        this.isShowCaseFileModal = true;
        this.loadCaseFileData();
        this.loadCareSummaryFromPrompt();
    } else {
        this.showToast('Error', 'Selected draft referral not found', 'error');
    }
}


// FIXED: Create new referral with proper state reset
handleCreateNewReferral() {
    this.isDraftMode = false;
    this.currentReferralId = null;
    this.selectedDraftId = null;
    this.resetReferralData();
    this.isShowDraftSelectionModal = false;
    this.isShowMainModel = true;
}

// Navigation methods
handleBackToDraftSelection() {
    this.isShowReferralModal = false;
    this.isShowCaseFileModal = false;
    this.isShowDraftSelectionModal = true;
}

// FIXED: Reset all referral data
resetReferralData() {
    this.searchCriteria = {
        city: '',
        hospitalType: '',
        primarySpecialty: '',
        secondarySpecialty: ''
    };
    this.referralSummaryBYAI='';
    this.reasonForReferral = '';
    this.careSummary = '';
    this.preliminaryDiagnosis = '';
    this.recommendedVisitBy = '';
    this.referralPriority = '';
    this.selectedProviderId = '';
}

    @wire(getLatestEncountersWithDiagnosis, { accountId: '$recordId' })
    async wiredEncounters({ error, data }) {
        if (data) {
            this.error = undefined;
            // First, populate the patientName and age from the first encounter wrapper
            // This is the CRITICAL FIX for age and patientName at the top

            if (data && data.length > 0) {
                this.patientName = data[0].patientName || 'Name Not Available';
                this.age = (data[0].patientAge !== undefined && data[0].patientAge !== null)
                    ? String(data[0].patientAge)
                    : '';
            } else {
                await this.loadCaseFileData();
                this.patientName = this.caseData.patientName;
                this.age = this.caseData.patientAge;
            }

            const encounters = Array.isArray(data) ? data : [];
            console.log('encounters', encounters);

            this.clinicalEncounters = encounters.map(wrapper => {
    let formattedDate = '';
    if (wrapper.encounter.StartDate) {
        const dateObj = new Date(wrapper.encounter.StartDate);
        const year = dateObj.getFullYear();
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const month = monthNames[dateObj.getMonth()];
        const day = String(dateObj.getUTCDate()).padStart(2, '0');
        formattedDate = `${day}-${month}-${year}`;
        console.log('formatted date: ',formattedDate);
    }
    const diagnosisText = this.formatDiagnoses(wrapper.diagnoses);

    return {
        encounterId: wrapper.encounter.Id, // Used as data-id in HTML
        encounterName: wrapper.encounter.Name, // Displayed as Encounter ID
        diagnosis: diagnosisText,
        prescribingDoctorId: wrapper.encounter.Prescribing_Doctor__c,
        prescribingDoctor: wrapper.encounter.Prescribing_Doctor__r ? wrapper.encounter.Prescribing_Doctor__r.Name : 'N/A',
        encounterDate: formattedDate, // Displayed as Date
        selected: false
    };
});

            this.updateSelectionCount();
        } else if (error) {
            this.error = error;
            this.clinicalEncounters = [];
            this.patientName = 'Error Loading Name';
            this.age = ''; // Clear age on error
            this.updateSelectionCount();
            console.error('Error fetching clinical encounters:', JSON.stringify(error));
            this.showToast('Error loading encounters', error.body.message || 'An unknown error occurred.', 'error');
        }
    }

    formatDiagnoses(diagnoses) {
        if (diagnoses && diagnoses.length > 0) {
            return diagnoses.map(diag => diag.Diagnosis_Description__c || diag.Clinical_Diagnosis__c || diag.Name)
                .filter(text => text)
                .join('; ');
        }
        return 'N/A';
    }

    toggleDiagnosisExpansion(event) {
        event.stopPropagation();
        const diagnosisElement = event.target;

        // Toggle the expanded class
        if (diagnosisElement.classList.contains('expanded')) {
            diagnosisElement.classList.remove('expanded');
        } else {
            diagnosisElement.classList.add('expanded');
        }
    }

    get totalEncounters() {
        if (this.clinicalEncounters) {
            console.log('this.clinicalEncounters.length getter', this.clinicalEncounters.length);
            return this.clinicalEncounters.length;
        }

    }

    get proceedButtonDisabled() {
        return this.selectedCount === 0;
    }

    handleCardClick(event) {
        // Get the encounter ID from the clicked card
        const encounterId = event.currentTarget.dataset.id;

        // Find the encounter and toggle its selection
        this.clinicalEncounters = this.clinicalEncounters.map(encounter => {
            if (encounter.encounterId === encounterId) {
                return { ...encounter, selected: !encounter.selected };
            }
            return encounter;
        });

        this.updateSelectionCount();
    }

    handleCheckboxClick(event) {
        // Stop propagation to prevent card click from firing
        event.stopPropagation();
    }

    handleEncounterSelection(event) {
        const encounterId = event.target.dataset.id; // This is wrapper.encounter.Id now
        const isChecked = event.target.checked;

        this.clinicalEncounters = this.clinicalEncounters.map(encounter => {
            if (encounter.encounterId === encounterId) { // Match by the correct property
                return { ...encounter, selected: isChecked };
            }
            return encounter;
        });

        this.updateSelectionCount();
    }

    handleClearSelection() {
        this.clinicalEncounters = this.clinicalEncounters.map(encounter => ({
            ...encounter,
            selected: false
        }));
        this.updateSelectionCount();
    }

    updateSelectionCount() {
        this.selectedCountArray = this.clinicalEncounters.filter(encounter => encounter.selected);
        if (this.selectedCountArray) {
            this.selectedCount = this.selectedCountArray.length;
            console.log('This is a selected count array' + this.selectedCountArray, this.selectedCount);
        }
    }

    handleCancel() {
        this.showToast('Action Cancelled', 'Operation cancelled successfully.', 'info');
        this.closeModal();
    }

    async handleProceed() { // Made async to await handleSearch
        const selectedEncounters = this.clinicalEncounters.filter(encounter => encounter.selected);
        console.log('selectedEncounters :' + selectedEncounters);

        if (selectedEncounters && selectedEncounters.length > 0) {


            this.isShowReferralModal = true;
            this.isShowMainModel = false;
            // Use encounterId property (from wrapper.encounter.Id)
            this._selectedEncounterIdsForCaseFile = selectedEncounters.map(encounter => encounter.encounterId);

            // Set default HospitalType to 'Public' and trigger search
            // this.searchCriteria = {
            //     ...this.searchCriteria,
            //     hospitalType: 'Public' // Set default to Public
            // };
            // await this.handleSearch(); // Automatically trigger search

            this.selectedEncounterList = selectedEncounters;
            console.log('selectedEncounterList:::' + JSON.stringify(this.selectedEncounterList));
            console.log('Proceeding with selected encounters for referral:', JSON.stringify(selectedEncounters, null, 2));
            // this.showToast('Proceeding to Referral', `Preparing to find a healthcare provider for ${selectedEncounters.length} selected encounters.`, 'success');
        } else {
            // this.showToast('No Selection', 'Please select at least one encounter to proceed.', 'warning');
        }
    }

    handleEscapeKey(event) {
        if (event.key === 'Escape') {
            if (this.isShowCaseFileModal) {
                this.handleBackToReferralModal();
            } else if (this.isShowReferralModal) {
                this.handleBackToMainModal();
            }
        }
    }

    async loadSpecialties() {
        try {
            const result = await getSpecialties();
            this.specialtyOptions = result.map(specialty => ({
                label: specialty.label,
                value: specialty.label
            }));
            console.log('here are the specility options' + this.specialtyOptions);
        } catch (error) {
            console.error('Error loading specialties:', error);
            this.showToast('Error', 'Failed to load specialties', 'error');
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;

        // Handle combobox (lightning-combobox) vs input (lightning-input)
        const value = event.detail ? event.detail.value : event.target.value;

        this.searchCriteria = {
            ...this.searchCriteria,
            [field]: value
        };

        if (field == 'primarySpecialty') {
            let selectedOption = this.specialtyOptions.find(option => option.value == value);
            this.primarySpecialityName = selectedOption.label;
        } else if (field == 'secondarySpecialty') {
            let selectedOption = this.specialtyOptions.find(option => option.value == value);
            this.secondarySpecialityName = selectedOption.label;
        } else if (field == 'city') {

            let selectedOption = this.cityOptions.find(option => option.value == value);
            this.selectedCityName = selectedOption ? selectedOption.label : '';
            console.log('Selected City:', value);
        }
    }

    async handleSearch() {

    if (!this.searchCriteria.primarySpecialty) {
    this.showToast('Missing', 'Primary Specialty is required / प्राथमिक स्पेशलिटी आवश्यक है', 'error');
    return;
}

if (!this.searchCriteria.city) {
    this.showToast('Missing', 'City is required / शहर आवश्यक है', 'error');
    return;
}
        this.isLoadingProviders = true;
        this.showResults = false;
        this.selectedProviderId = '';
        this.selectedProviderName = '';

        try {
            console.log('this.searchCriteria::' + JSON.stringify(this.searchCriteria));
            const result = await searchProviders({ searchCriteria: this.searchCriteria });

            this.searchResults = result.map(provider => ({
                ...provider,
                isSelected: false,
                cardClass: 'provider-card',
                displayAddress: provider.formattedAddress || 'Address not available',
                streetAddress: provider.street || '',
                cityName: provider.city || '',
                postalCodeValue: provider.postalCode || '',
                Id: provider.id,
                Name: provider.name,
                HospitalType: provider.hospitalType || ''
            }));

            this.showResults = true;
            this.isLoadingProviders = false;

            if (result.length > 0) {
               this.showToast('Success', 
                `Found ${result.length} healthcare provider(s) / ${result.length} स्वास्थ्य सेवा प्रदाता मिले`, 
                'success'
                );
            } else {
                this.showToast('Info', 'No providers found matching your criteria. Try adjusting your search parameters.', 'info');
            }
        } catch (error) {
            console.error('Error searching providers:', error);
            let errorMessage = 'Failed to search providers. Please try again.';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            }
            this.showToast('Error', errorMessage, 'error');
            this.isLoadingProviders = false;
            this.showResults = false;
        }
    }

    handleProviderSelection(event) {
        event.stopPropagation();
        const providerId = event.target.value;
        this.selectProvider(providerId);
    }

    handleProviderCardClick(event) {
        const providerId = event.currentTarget.dataset.id;
        if (providerId) {
            this.selectProvider(providerId);
        }
    }

    selectProvider(providerId) {
        this.selectedProviderId = providerId;

        const selectedProvider = this.searchResults.find(provider => provider.Id === providerId);
        this.selectedProviderName = selectedProvider ? selectedProvider.Name : '';

        this.searchResults = this.searchResults.map(provider => ({
            ...provider,
            isSelected: provider.Id === providerId,
            cardClass: provider.Id === providerId ? 'provider-card selected' : 'provider-card'
        }));
    }

    get hasResults() {
        console.log('this.searchResults.length > 0', this.searchResults.length > 0);
        return this.searchResults && this.searchResults.length > 0;
    }

    get isProceedToCaseFileDisabled() {
        return !this.selectedProviderId || this.isLoadingProviders;
    }

    async handleProceedToCaseFile() {
        if (!this.selectedProviderId) {
            this.showToast('Warning', 'Please select a healthcare provider to proceed.', 'warning');
            return;
        }

        this.isShowReferralModal = false;
        this.isShowCaseFileModal = true;
        await this.loadCaseFileData();
        //Automatically load care summary when the case file modal is opened
        await this.loadCareSummaryFromPrompt();
    }

    handleBackToMainModal() {

        this.isLoadingProviders = false;

        this.isShowReferralModal = false;
        this.isShowMainModel = true;
    }


    async loadCaseFileData() {
        this.isLoadingCaseFile = true;
        this.caseFileError = undefined;

        try {
            const caseFileResult = await getCaseFileData({ accountId: this.recordId });
            this.caseData = { ...caseFileResult };
            console.log('DATA 👉', caseFileResult);
            // if (this.caseData && this.caseData.latestDiagnosis && this.caseData.latestDiagnosisDesc) {
            //     this.preliminaryDiagnosis = `${this.caseData.latestDiagnosis} —— ${this.caseData.latestDiagnosisDesc}`;
            // }
             if (this.caseData) {
                if(!this.isDraftMode){
                this.preliminaryDiagnosis = `${this.caseData.latestDiagType} Diagnosis —— ${this.caseData.latestDiagnosis}`;
                this.careSummary = this.caseData.latestChiefComplaints;

                }   
            }

        // this has t be handled when its a draft I have to take the selected Ids 
        // from the fields then find the encounters 
            await this.fetchTimelineData(this._selectedEncounterIdsForCaseFile);
            await this.loadMedicationData();
            await this.loadTestReportsData();

        } catch (error) {
            console.error('Error loading full case file data:', error);
            this.caseFileError = error.body?.message || 'An error occurred while fetching case file data.';
            this.showToast('Error', 'Failed to load case file data: ' + this.caseFileError, 'error');
        } finally {
            this.isLoadingCaseFile = false;
        }
    }



    handleReasonChange(event) {
        this.reasonForReferral = event.target.value;
        const textLength = this.reasonForReferral.length;
        
        // Show error if less than 50 characters
        this.showError = textLength < 50;
        
        // Clear any native validation messages
        event.target.setCustomValidity('');
    }

      get characterCount() {
        return this.reasonForReferral ? this.reasonForReferral.length : 0;
    }

    get textareaClass() {
        return this.showError ? 'custom-textarea error' : 'custom-textarea';
    }

    get characterCountClass() {
        if (this.characterCount >= 50) {
        return 'character-count hidden'; // Add hidden class
    }
    return this.showError ? 'character-count error' : 'character-count';
    }

    validateReasonForReferralTextarea() {
        return this.reasonForReferral.length >= 50;
    }

    handleCareChange(event) {
        this.careSummary = event.target.value;
    }
    handleReferralSummaryChange(event){
        this.referralSummaryBYAI = event.target.value; 
    }

    async fetchTimelineData(encounterIds) {
        this.isLoadingTimeline = true;
        try {
            const result = await getClinicalEncounterTimeline({ clinicalEncounterIds: encounterIds });
            this.timelineData = result.map(encounter => ({
                ...encounter,
                date: encounter.date || 'N/A',
                doctorFacility: encounter.doctorFacility || 'N/A',
                symptoms: encounter.symptoms || 'No symptoms recorded',
                diagnosis: encounter.diagnosis || 'No diagnosis recorded'
            }));
            // console.log(this.timelineData);
        } catch (error) {
            console.error('Error fetching timeline data:', error);
            this.showToast('Error', 'Failed to load timeline data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoadingTimeline = false;
        }
    }

    async loadMedicationData() {
        this.isLoadingMedications = true;
        this.medicationError = undefined;
        try {
            const data = await getMedicationData({ patientId: this.recordId });
            this.activeMedications = data.activeMedications || [];
            this.pastMedications = data.pastMedications || [];
        } catch (error) {
            console.error('Error loading medication data:', error);
            this.medicationError = error.body?.message || 'An error occurred while loading medication data';
        } finally {
            this.isLoadingMedications = false;
        }
    }

    async loadTestReportsData() {
        this.isLoadingTestReports = true;
        this.testReportsError = undefined;
        try {
            this.testReportsData = await getTestReportsSummary({ patientId: this.recordId });
        } catch (error) {
            console.error('Error loading test reports data:', error);
            this.testReportsError = 'Failed to load test reports data';
        } finally {
            this.isLoadingTestReports = false;
        }
    }

    get formattedTestReportsData() {
                console.log('this.testReportsData', this.testReportsData);

        return this.testReportsData.map(report => ({
            ...report,
            formattedDate: this.formatDate(report.testDate)
        }));

    }

    get hasTestReports() {
        console.log('this.formattedTestReportsData.length', this.formattedTestReportsData.length);
                console.log('this.formattedTestReportsData', this.formattedTestReportsData);

        return this.formattedTestReportsData && this.formattedTestReportsData.length > 0;
    }

    get hasTimelineData() {
        console.log(' this.timelineData.length > 0', this.timelineData.length);
        return this.timelineData && this.timelineData.length > 0;
    }

    get hasActiveMedications() {
        console.log('this.activeMedications.length', this.activeMedications);
        return this.activeMedications && this.activeMedications.length > 0;
    }

    get hasPastMedications() {
        console.log('this.hasPastMedications.length', this.pastMedications);
        return this.pastMedications && this.pastMedications.length > 0;
    }

    // Unified function to format date
    formatDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    // This method is from the second component, now integrated
    async loadCareSummaryFromPrompt() {
        if (!this.recordId || !this._selectedEncounterIdsForCaseFile || this._selectedEncounterIdsForCaseFile.length === 0) {
            console.warn('Missing recordId or selectedEncounterIds for prompt template');
            return;
        }

        // if (!this.recordId || !this.caseData.latestEncounterId || this.caseData.latestEncounterId.length === 0) {
        //     console.warn('Missing recordId or selectedEncounterIds for prompt template');
        //     return;
        // }

        try {
            // Set isLoadingCaseFile to true if this is the only loading indicator for prompt
            this.isLoadingCaseFile = true;

            const result = await sendPatientCasePrompt({
                accountId: this.recordId,
                encounterIds: this._selectedEncounterIdsForCaseFile,
                latestEncounterId: this.getLatestEncounterId() 
                // encounterIds: this.caseData.latestEncounterId
            });

            if (result && result.finalContent) {
                this.referralSummaryBYAI = result.finalContent;
            } else {
                console.warn('No content returned from prompt template');
                this.referralSummaryBYAI = 'Unable to generate care summary at this time.';
            }

        } catch (error) {
            console.error('Error invoking prompt template:', error);
            this.caseFileError = 'Failed to generate care summary: ' + (error.body?.message || error.message);
            this.referralSummaryBYAI = 'Error generating care summary. Please try again later.';
            this.showToast('Error', 'Failed to generate care summary', 'error');
        } finally {
            this.isLoadingCaseFile = false; // Hide spinner
        }
    }


    startLoadingMessages() {
        const loadingMessages = this.getLoadingMessages();
        console.log(loadingMessages);

        this.currentLoadingMessage = loadingMessages[0];
        this.messageIndex = 0;

        this.loadingInterval = setInterval(() => {
            this.messageIndex++;
            if (this.messageIndex < loadingMessages.length) {
                this.currentLoadingMessage = loadingMessages[this.messageIndex];
            } else {
                // Optionally cycle back to first message or keep the last one
                this.messageIndex = 0;
                this.currentLoadingMessage = loadingMessages[this.messageIndex];
            }
        }, 3000); // Change message every 2 seconds
    }

    stopLoadingMessages() {
        if (this.loadingInterval) {
            clearInterval(this.loadingInterval);
            this.loadingInterval = null;
            this.currentLoadingMessage = '';
            this.messageIndex = 0;
        }
    }


 async handleSaveAsDraft() {
    try {
        let visitByDate = '';
        if (this.recommendedVisitBy) {
            visitByDate = new Date(this.recommendedVisitBy);
        }

        const referralId = await createReferral({
            referralId: this.currentReferralId, // null for new, ID for update
            patientId: this.recordId,
            // referredById: '',
            referredToId: this.selectedProviderId,
            referralSummary: this.reasonForReferral,
            primarySpecialty: this.searchCriteria.primarySpecialty,
            secondarySpecialty: this.searchCriteria.secondarySpecialty || 'N/A',
            encounterWrap: this.selectedEncounterList,
            recommendedVisitBy: visitByDate,
            referralPriority: this.referralPriority,
            chiefComplaints: this.careSummary,
            preliminaryDiagnosis: this.preliminaryDiagnosis,
            saveAsDraft: 'true',
            consentMode: this.isManualConsentChecked ? 'Manual' : '',
            manualConsentReason: this.manualConsentReason,
            referralSummaryByAI: this.referralSummaryBYAI

        });

        // CRITICAL: Update state after save
        this.currentReferralId = referralId;
        this.isDraftMode = true;

        const message = this.currentReferralId && this.isDraftMode ? 
            'Draft referral updated successfully / ड्राफ़्ट रेफ़रल सफलतापूर्वक अपडेट हो गया' : 
            'The case file has been successfully saved as Draft / केस फ़ाइल सफलतापूर्वक ड्राफ़्ट के रूप में सेव हो गई है';
            
        this.showToast('Success', message, 'success');
        this.closeModal();


        // Refresh draft list
        this.refreshDraftList();

    } catch (error) {
        this.showToast('Error', error.body?.message || error.message, 'error');
    }
}

async handleCreateReferral() {
    this.showConfirmationModal = false;
    this.isLoadingReferralCreation = true;
    this.startLoadingMessages();

    try {
        let visitByDate = '';
        if (this.recommendedVisitBy) {
            visitByDate = new Date(this.recommendedVisitBy);
        }

        // CRITICAL: If updating draft, use existing ID; if new, pass null
        const referralId = await createReferral({
            referralId: this.currentReferralId, // Will be null for new, ID for draft update
            patientId: this.recordId,
            // referredById: '',
            referredToId: this.selectedProviderId,
            referralSummary: this.reasonForReferral,
            primarySpecialty: this.searchCriteria.primarySpecialty,
            secondarySpecialty: this.searchCriteria.secondarySpecialty || 'N/A',
            encounterWrap: this.selectedEncounterList,
            recommendedVisitBy: visitByDate,
            referralPriority: this.referralPriority,
            chiefComplaints: this.careSummary,
            preliminaryDiagnosis: this.preliminaryDiagnosis,
            saveAsDraft: 'false', // This sets status to 'Referral Summarized'
            consentMode: this.isDigitalConsentInitiated ? 'Digital' : 'Manual',
            manualConsentReason: this.manualConsentReason,
            referralSummaryByAI: this.referralSummaryBYAI
        });

        console.log('referralId::' + referralId);

        // Generate and attach PDF
        const result = await generateAndAttachPDF({
            referralId: referralId,
            patientId: this.recordId,
            timelineDataJSON: JSON.stringify(this.timelineData),
            medicationsJSON: JSON.stringify({ active: this.activeMedications, past: this.pastMedications }),
            testReportsJSON: JSON.stringify(this.testReportsData)
        });
        
        // CRITICAL: Send email and show VF page
        // Add your email sending logic here
        // Add your VF page navigation logic here

        this.showToast('Success', 'The case file has been successfully sent to the Healthcare Provider / केस फ़ाइल सफलतापूर्वक स्वास्थ्य सेवा प्रदाता को भेज दी गई है', 'success');
        this.closeModal();

    } catch (error) {
        this.showToast('Error', error.body?.message || error.message, 'error');
    } finally {
        this.isLoadingReferralCreation = false;
        this.stopLoadingMessages();
    }
}

    /**
     * Handles the click event for the "Send Case File to Providersss" button (or similar).
     * Creates a new Referral__c record, linking it only to the Patient and Referred To Provider.
     */
    
    handleBackToReferralModal() {
        this.isShowCaseFileModal = false;
       if (this.isDraftMode) {
        this.isShowDraftSelectionModal = true;
    } else {
        this.isShowReferralModal = true;
    }
        // No explicit re-search needed here as search criteria and results are retained
        // from the previous search in the referral modal.
        this.isConsentChecked = false;
        this.isAiConfirmationChecked = false;

    }

    showToast(title, message, variant) {
        try {
            const toastEvent = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            });
            this.dispatchEvent(toastEvent);
        } catch (error) {
            console.error('Error dispatching toast:', error);
            console.log(`Toast (Fallback): ${variant.toUpperCase()} - ${title}: ${message}`);
        }
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // New API method from the second component, now integrated
    @api
    refreshData() {
        if (this._selectedEncounterIdsForCaseFile && this._selectedEncounterIdsForCaseFile.length > 0) {
            this.fetchTimelineData(this._selectedEncounterIdsForCaseFile);

        }
       // Also refresh the care summary when data is refreshed
       this.loadCareSummaryFromPrompt();
    }

    get hasError() {
        return this.error !== undefined;
    }

    get hasData() {
        return this.timelineData && this.timelineData.length > 0;
    }
    



    handleConsentChange(event) {
        this.isConsentChecked = event.target.checked;
    }

    handleAiConfirmationChange(event) {
        this.isAiConfirmationChecked = event.target.checked;
    }

    get buttonDisabled() {
        //const shouldEnable = this.isConsentChecked && this.isAiConfirmationChecked;
        const shouldEnable = this.hasAnyConsent;
        return shouldEnable ? undefined : true;
    }

    get buttonClass() {
        // const shouldEnable = this.isConsentChecked && this.isAiConfirmationChecked;
        const shouldEnable = this.hasAnyConsent;
        return shouldEnable ? 'createReferral' : 'createReferral disabled';
    }


    handleEncounterClick(event) {
        event.preventDefault();
        event.stopPropagation();

        const encounterId = event.target.dataset.id;
        console.log('Encounter ID:', encounterId);

        if (encounterId) {
            // Method 1: Using NavigationMixin (preferred)
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: encounterId,
                    actionName: 'view'
                }
            }).then(url => {
                window.open(url, '_blank');
            }).catch(error => {
                console.error('Navigation error:', error);
                // Fallback method
                this.openRecordFallback(encounterId);
            });
        }
    }
    // Fallback method if NavigationMixin fails
    openRecordFallback(encounterId) {
        const baseUrl = window.location.origin;
        const recordUrl = `${baseUrl}/lightning/r/${encounterId}/view`;
        window.open(recordUrl, '_blank');
    }

    get priorityOptions() {
        return [
            { label: 'Emergency', value: 'emergency' },
            { label: 'Urgent', value: 'urgent' },
            { label: 'Routine', value: 'routine' }
        ];
    }

    handleRecommendedVisitByChange(event) {
         const selectedDate = event.target.value;
    const today = new Date().toISOString().split('T')[0];
    
    // Always set the value first
    this.recommendedVisitBy = selectedDate;
    
    if (selectedDate < today) {
        event.target.setCustomValidity('Date cannot be in the past / पुरानी तारीख मान्य नहीं है');
    } else {
        event.target.setCustomValidity('');
    }
    
    event.target.reportValidity();
    }

    handleReferralPriorityChange(event) {
        this.referralPriority = event.target.value;
        console.log('Referral Priority changed to:', this.referralPriority);
    }

    validateReferralFields() {
        const isValid = this.recommendedVisitBy && this.referralPriority;
        if (!isValid) {
            this.showToast('Validation Error', 'Please fill in all required referral fields.', 'error');
        }
        return isValid;
    }


handleReferButtonClick() {
    // Validate recommended visit date
    
    const today = new Date().toISOString().split('T')[0];
    if (!this.recommendedVisitBy) {
        this.showToast('Error', 'Recommended Visit By date is required  / अनुशंसित यात्रा तिथि आवश्यक है', 'error');
        return;
    }
    
    if (this.recommendedVisitBy < today) {
        this.showToast('Error', 'Recommended Visit By date cannot be in the past / अनुशंसित यात्रा तिथि भूतकाल की नहीं हो सकती', 'error');
        return;
    }

    const oneYearFromToday = new Date();
    oneYearFromToday.setFullYear(oneYearFromToday.getFullYear() + 1);
    const oneYearFromTodayString = oneYearFromToday.toISOString().split('T')[0];
    
    if (this.recommendedVisitBy > oneYearFromTodayString) {
        this.showToast('Error', 'The recommended visit date cannot be later than one year from today. / अनुशंसित यात्रा तिथि आज की तिथि से एक वर्ष के भीतर होनी चाहिए', 'error');
        return;
    }

    if(!this.isAiConfirmationChecked){
        this.showToast('Review Required / समीक्षा आवश्यक है','Please confirm that you have reviewed the AI-generated summary. / कृपया पुष्टि करें कि आपने एआई-जेनरेट किए गए सारांश की समीक्षा कर ली है।', 'warning');
        return;
    }
    
    // Validate reason for referral
    if (!this.reasonForReferral || this.reasonForReferral.trim().length === 0) {
        this.showToast('Error', 'Reason for Referral is mandatory / रेफरल का कारण अनिवार्य है', 'error');
        return;
    }
    
    if (this.reasonForReferral.trim().length < 50) {
        this.showToast('Error', 'Reason for Referral must be at least 50 characters / रेफरल कारण कम से कम 50 अक्षर का होना चाहिए', 'error');
        return;
    }

    if(this.caseData.pmjayVerified != true) {
         this.showToast('Error', 'The patient must be PMJAY scheme verified / मरीज़ का PMJAY योजना सत्यापन आवश्यक है।', 'error');
    return;
    }
    
    // Validate patient has familyId or caseId
    if (!this.caseData.pmJayId && !this.caseData.familyId) {
    this.showToast('Error', 'Patient must have PMJAY ID or PMJAY Family ID / मरीज़ के पास पीएमजे आईडी या पीएमजे फैमिली आईडी होना चाहिए', 'error');
    return;
}
    
    // Validate referral priority
    if (!this.referralPriority) {
        this.showToast('Error', 'Referral Priority is required / रेफरल प्राथमिकता आवश्यक है', 'error');
        return;
    }
    
    // All validations passed
    this.showConfirmationModal = true;
}

handleConfirmationCancel() {
    this.showConfirmationModal = false;
}


get displaySecondarySpecialty() {
    return this.secondarySpecialityName || 'N/A';
}

get summaryTitle() {
    return this.isDraftMode ? 'Patient Referral Summary (Draft)' : 'Patient Referral Summary';

}



async refreshDraftList() {
    try {
        // Refresh the wire cache
        await refreshApex(this.wiredDraftResult);
    } catch (error) {
        console.error('Error refreshing draft list:', error);
    }
}

getLatestEncounterId() {
    if (!this.selectedEncounterList?.length) {
        return null;
    }

    const latest = [...this.selectedEncounterList]
        .sort((a, b) => new Date(b.encounterDate) - new Date(a.encounterDate))[0];

    return latest.encounterId;
}

// UTILI

}