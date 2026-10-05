import { LightningElement, api, track, wire } from 'lwc';
import suggestClinicalTests from '@salesforce/apex/ClinicalTestSuggestionService.suggestClinicalTests';
import getFormattedClinicalData from '@salesforce/apex/ClinicalTestSuggestionService.getFormattedClinicalData';
import getPatientGender from '@salesforce/apex/ClinicalTestSuggestionService.getPatientGender';
export default class ClinicalTestsAISuggestion extends LightningElement {
    @api recordId; // Encounter Id

    @track suggestedTests = '';
    @track isLoading = false;

    formattedData;
    error;

    @track showPregnancySection = false;
    @track pregnancyStatus = 'Not Applicable';
    @track gender;

    get pregnancyOptions() {
        return [
            { label: 'Not Applicable', value: 'Not Applicable' },
            { label: 'Pregnant', value: 'Pregnant' },
            { label: 'Lactating', value: 'Lactating' }
        ];
    }

    @wire(getPatientGender, { encounterId: '$recordId' })
    wiredGender({ error, data }) {
        if (data) {
            this.gender = data;
            console.log('Gender:', this.gender);
        } else if (error) {
            console.error('Error fetching gender:', error);
        }
    }

    handlePregnancyChange(event) {
        this.pregnancyStatus = event.detail.value;
        console.log('Pregnancy status: ', this.pregnancyStatus);
    }
   

    async fetchSuggestedTests() {

        if (this.gender === 'Female') {
            this.showPregnancySection = true;
            return;
        }

        this.callAI();

    }

    handleContinue() {
        this.showPregnancySection = false;
        this.callAI();
    }
    async callAI() {
        this.isLoading = true;

        try {
            const result = await suggestClinicalTests({
                encounterIds: [this.recordId],
                pregnancyStatus: this.pregnancyStatus   // 👈 IMPORTANT
            });

            if (result.success) {
                this.suggestedTests = result.suggestedTests;
                this.isLoading = false;
                console.log('Suggested Tests:', this.suggestedTests);
            } else {
                console.error('AI Error:', result.message);
            }

        } catch (error) {
            console.error('Unexpected Error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    get testsArray() {
    return this.suggestedTests
        ? this.suggestedTests.split(',').map(t => t.trim())
        : [];
    }

    @wire(getFormattedClinicalData, { encounterId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.formattedData = data;
            this.error = undefined;
            console.log('Formatted Data:', data);
        } else if (error) {
            this.error = error;
            this.formattedData = undefined;
            console.error(error);
        }
    }

   get sanitizedOutput() {
    if (!this.suggestedTests) return '';

    let sanitized = this.suggestedTests;

    // Convert markdown bold → HTML
    sanitized = sanitized.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');

    // Italics
    sanitized = sanitized.replace(/(^|[^*])\*(?!\*)(.*?)\*(?!\*)/g, '$1<i>$2</i>');

    // Line breaks
    sanitized = sanitized.replace(/\r?\n/g, '<br>');

    // 🔥 Fix merged words (your main issue)
    sanitized = sanitized.replace(/([a-z])([A-Z])/g, '$1, $2');

    return sanitized;
}

}