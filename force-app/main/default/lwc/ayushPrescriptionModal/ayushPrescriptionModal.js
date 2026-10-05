import { LightningElement, api, track, wire } from 'lwc';
import saveActiveMedications from '@salesforce/apex/ActiveMedicationController.saveActiveMedications';
import getActiveMedicationsUser from '@salesforce/apex/ActiveMedicationController.getAyushActiveMedicationsUser';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';
import getPatientGender from '@salesforce/apex/ActiveMedicationController.getPatientGender';
import saveAayushMedicine from '@salesforce/apex/ActiveMedicationController.saveAayushMedicine';
import leafIcon from '@salesforce/resourceUrl/AyushLeafIcon';


export default class ActiveMedicationModal extends LightningElement {
    @api recordId;

    /* ================== MEDICATIONS ================== */
    @track userMeds = [];
    disableAllopathyAddButton=false;
    @track savedMedications = [];
    @track hasSavedMeds = false;
    @track isEditMode = false;
    userAllopathyMeds=[];
    maxMeds = 4
    leafIcon = leafIcon;
    /* ================== ALLERGIES ================== */
    @track hasAllergiesValue = 'No'; // Radio value
    @track allergyDetails = '';
    @track hasSavedAllergies = false;
    patientGender;
    showPregnancySection = false;
    savedPregnancyStatus;
    isLoading = false;
    @track selectedLifestyle = [];
    selectedSeason = '';
    selectedSeasonLabel;

    lifestyleOptions = [
        { label: 'Smoking / धूम्रपान', value: 'Smoking' },
        { label: 'Alcohol Use / शराब का सेवन', value: 'Alcohol' },
        { label: 'Practices Yoga / योग अभ्यास करते हैं', value: 'Lack of physical activity' },
        { label: 'Sleep Deprivation / नींद की कमी', value: 'Sleep Deprivation' }
    ];

    connectedCallback() {
        console.log('recordId:', this.recordId);
        this.setCurrentSeason();
    }

    setCurrentSeason() {
        const monthIndex = new Date().getMonth(); // 0 = Jan
        const monthNames = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        ];

        const month = monthNames[monthIndex];

        const seasonMap = {
            January: 'Shishir (Winter)',
            February: 'Shishir (Winter)',
            March: 'Vasanta (Spring)',
            April: 'Vasanta (Spring)',
            May: 'Grishma (Summer)',
            June: 'Grishma (Summer)',
            July: 'Varsha (Monsoon)',
            August: 'Varsha (Monsoon)',
            September: 'Sharad (Autumn)',
            October: 'Sharad (Autumn)',
            November: 'Hemant (Pre-Winter)',
            December: 'Hemant (Pre-Winter)'
        };

        this.selectedSeason = month;
        this.selectedSeasonLabel = `${month} / ${seasonMap[month]}`;
    }

    @wire(getPatientGender, { consultationId: '$recordId' })
    wiredGender({ error, data }) {
        console.log('data', data);
        if (data) {
            this.patientGender = data;
            this.showPregnancySection = (data === 'Female');
        } else if (error) {
            console.error('Error fetching gender', error);
        }
    }

    allergyOptions = [
        { label: 'No Allergies', value: 'No' },
        { label: 'Has Allergies', value: 'Yes' }
    ];

    conditionOptions = [
        { label: 'Kidney disease', value: 'Kidney disease' },
        { label: 'Liver disease', value: 'Liver disease' },
        { label: 'Diabetes', value: 'Diabetes' },
        { label: 'Heart disease', value: 'Heart disease' },
        { label: 'Thyroid', value: 'Thyroid' }
    ];


    /* ================== PREGNANCY ================== */
    @track pregnancyStatus = 'Not Applicable';

    pregnancyOptions = [
    { label: 'Not applicable / लागू नहीं', value: 'Not Applicable' },
    { label: 'Pregnant / गर्भवती', value: 'Pregnant' },
    { label: 'Lactating / स्तनपान करा रही हैं', value: 'Breastfeeding' }
    ];


    /* ================== LIFESTYLE ================== */
    @track smoking = false;
    @track alcoholUse = false;

    /* ================== STATIC ================== */
    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;
    @track selectedConditions = []; // pre-existing known conditions
    @track existingConditions = ''; // full Medical_History__c text
    @track newCondition = '';

    handleNewCondition(event) {
        this.newCondition = event.target.value;
    }
    get hasSavedExistingConditions() {
        return (
            this.existingConditions &&
            this.existingConditions.trim().length > 0
        );
    }

    handleAllopathyMedChange(event) {
        const id = event.target.dataset.id;
        const med = this.userAllopathyMeds.find(m => m.id == id);
        if (med) {
            med.value = event.detail.recordId;
        }
    }

    /* ================== WIRE ================== */
    @wire(getActiveMedicationsUser, { consultationId: '$recordId' })
    wiredActiveMeds({ data, error }) {
        if (data) {
            console.log('data+++',data);
            this.savedMedications = data.ayurvedaMedications || [];
            this.hasSavedMeds = this.savedMedications.length > 0;
            this.userMeds = (data.ayurvedaMedications || []).map(med => ({
                id: Date.now() + Math.random(),
                value: med.Id
            }));
            this.savedAllopathicMedications=data.medications || [];
            this.userAllopathyMeds = (data.medications || []).map(med => ({
                id: Date.now() + Math.random(),
                value: med.Id
            }));
            // Allergies
            this.hasSavedAllergies = data.hasAllergies || false;
            console.log('hasSavedAllergies',this.hasSavedAllergies);
            this.hasAllergiesValue = this.hasSavedAllergies ? 'Yes' : 'No';
            this.allergyDetails = data.allergyDetails || '';
            this.pregnancyStatus = data.pregnancyStatus || 'Not Applicable';
            this.existingConditions = data.existingConditions || '';

            // Lifestyle
            this.selectedLifestyle = [];
            if (data.smoking) this.selectedLifestyle.push('Smoking');
            if (data.alcoholUse) this.selectedLifestyle.push('Alcohol');
            if (data.physicalInactivity) this.selectedLifestyle.push('Lack of physical activity');
            if (data.sleepDeprivation) this.selectedLifestyle.push('Sleep Deprivation');   
        }

        if (error) {
            console.error(error);
        }
    }

    /* ================== GETTERS ================== */
    get disableAddButton() {
        return this.userMeds.length >= this.maxMeds;
    }

    get disableAllopathyAddButton() {
        return this.userAllopathyMeds.length >= this.maxMeds;
    }

    // Comma-separated string for display
    get selectedConditionsString() {
        return this.selectedConditions.join(', ');
    }

    get showEditableAllergies() {
        return this.isEditMode || (!this.hasSavedMeds && !this.hasSavedAllergies);
    }

    get showSavedSection() {
        if (this.isEditMode) {
            return false;
        }

        const hasMeaningfulSavedData =
            this.hasSavedMeds ||
            this.hasSavedAllergies ||
            this.hasSavedPregnancy || this.hasSavedExistingConditions;

        return hasMeaningfulSavedData;
    }

    get hasSavedPregnancy() {
        return (
            this.savedPregnancyStatus &&
            this.savedPregnancyStatus !== 'Not Applicable'
        );
    }

    handleLifestyleChange(event) {
        this.selectedLifestyle = event.detail.value;
    }

    get hasSavedLifestyle() {
        return this.selectedLifestyle.length > 0;
    }
    // get hasSavedLifestyle() {
    //     return this.smoking || this.alcoholUse;
    // }


    get showAllergyTextbox() {
        return this.hasAllergiesValue === 'Yes';
    }

    /* ================== HANDLERS ================== */

    // ---------- Allergies ----------
    handleAllergyRadioChange(event) {
        this.hasAllergiesValue = event.target.value;

        if (this.hasAllergiesValue === 'No') {
            this.allergyDetails = '';
        }
    }
    get isNoAllergy() {
        return this.hasAllergiesValue === 'No';
    }

    get isHasAllergy() {
        return this.hasAllergiesValue === 'Yes';
    }



    handleAllergyChange(event) {
        this.allergyDetails = event.target.value;
    }

    // ---------- Pregnancy ----------
    handlePregnancyChange(event) {
        this.pregnancyStatus = event.target.value;
    }


    /* ================== MEDICATION LOGIC ================== */
    addMedication() {
        if (this.disableAddButton) return;

        this.userMeds = [
            ...this.userMeds,
            { id: Date.now(), value: null }
        ];
    }

    /* ================== MEDICATION LOGIC ================== */
    addAllopathyMedication() {
        if (this.disableAllopathyAddButton) return;

        this.userAllopathyMeds = [
            ...this.userAllopathyMeds,
            { id: Date.now(), value: null }
        ];
    }

    deleteMedication(event) {
        const id = event.target.dataset.id;
        this.userMeds = this.userMeds.filter(m => m.id != id);
    }

    deleteAllopathyMedication(event) {
        const id = event.target.dataset.id;
        this.userAllopathyMeds = this.userAllopathyMeds.filter(m => m.id != id);
    }

    handleMedChange(event) {
        const id = event.target.dataset.id;
        const med = this.userMeds.find(m => m.id == id);
        if (med) {
            med.value = event.detail.recordId;
        }
    }

    handleEdit() {
        this.hasSavedMeds = false;
        this.isEditMode = true;

        this.userMeds = this.savedMedications.map(med => ({
            id: Date.now() + Math.random(),
            value: med.Id
        }));

        this.userAllopathyMeds=this.savedAllopathicMedications.map(med => ({
            id: Date.now() + Math.random(),
            value: med.Id
        }));
    }

    /* ================== SAVE ================== */
    handleNext() {
        this.isLoading = true;

        const updatedConditions = this.existingConditions
            ? this.existingConditions + (this.newCondition ? ', ' + this.newCondition : '')
            : this.newCondition;

        const medsString = this.userMeds
            .filter(m => m.value)
            .map(m => m.value)
            .join(',');

        const allopathicMedsString = this.userAllopathyMeds
            .filter(m => m.value)
            .map(m => m.value)
            .join(',');

        // 🔑 Lifestyle selections
        const lifestyle = this.selectedLifestyle || [];

        const smoking = lifestyle.includes('Smoking');
        const alcoholUse = lifestyle.includes('Alcohol');
        const physicalInactivity = lifestyle.includes('Lack of physical activity');
        const sleepDeprivation = lifestyle.includes('Sleep Deprivation');

        // Optional: store everything as a single string
        const lifestyleString = lifestyle.join(', ');

        saveAayushMedicine({
            consultationId: this.recordId,
            userAllopathicMeds: allopathicMedsString,
            userMeds: medsString,
            hasAllergies: this.hasAllergiesValue === 'Yes',
            allergyDetails: this.allergyDetails,
            pregnancyStatus: this.pregnancyStatus,
            smoking: smoking,
            alcoholUse: alcoholUse,
            physicalInactivity: physicalInactivity,
            sleepDeprivation: sleepDeprivation,
            lifestyleHabits: lifestyleString,
            existingConditions: updatedConditions,
            otherCondition: ''
        })
            .then(() => {
                this.savedPregnancyStatus = this.pregnancyStatus;
                this.dispatchEvent(new CustomEvent('next'));
            })
            .catch(error => {
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    cancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}