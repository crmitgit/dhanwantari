import { LightningElement, api, wire, track } from 'lwc';
import getAyushAISummary from '@salesforce/apex/MedicationGuideController.getAyushAISummary';
import getEncounterDetails from '@salesforce/apex/DiagnosisController.getEncounterDetails';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';
import getAyushPatientConsiderations from '@salesforce/apex/ActiveMedicationController.getAyushPatientConsiderations';
import crmitLogo from '@salesforce/resourceUrl/crmitLogo';

export default class AiSummaryModal extends LightningElement {
    @api recordId;

    @track isModalOpen = true;
    @track aiSummary;
    @track encounterName;
    @track patientName;
    @track patientId;
    @track patientUrl;
    @track isEmergency;
    @track emergencyMessage; 
    crmitLogo=crmitLogo;

    @api isLoading = false;

    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;

    /* ------------------- WIRES ------------------- */

    @wire(getAyushPatientConsiderations, { consultationId: '$recordId' })
    considerations;

    @wire(getAyushAISummary, { clinicalEncounterId: '$recordId' })
    wiredSummary({ error, data }) {
        if (data) {
            try {
            const parsedJson = JSON.parse(data);
            if (parsedJson.emergency_status && parsedJson.emergency_status.is_emergency) {
                this.isEmergency = true;
                this.emergencyMessage = 'This is a MEDICAL EMERGENCY. Do NOT give any medicines or remedies. Escalate immediately for urgent specialist/hospital assessment and management./यह मेडिकल इमरजेंसी है। कोई भी दवा, जड़ी-बूटी या उपाय न दें। तुरंत उपस्थित स्वास्थ्य सेवा प्रदाता से तत्काल मूल्यांकन और उच्च स्तर की सुविधा में रेफरल करवाएँ।s';
            } else {
                this.isEmergency = false;
                this.aiSummary = this.formatAyushJson(parsedJson);
            }
            } catch (e) {
                console.error('AI Summary is not valid JSON:', e);
                this.aiSummary = data;
            }
            this.isLoading = false;
            this.renderSummary();
        } else if (error) {
            this.isLoading = false;
            console.error('AI Summary fetch error:', error);
        }
    }

    @wire(getEncounterDetails, { encounterId: '$recordId' })
    wiredEncounter({ error, data }) {
        if (data) {
            this.encounterName = data.EncounterName;
            this.patientId = data.PatientId;
            this.patientName = data.PatientName;
            this.patientUrl = `/lightning/r/Contact/${this.patientId}/view`;
        } else if (error) {
            console.error('Encounter details fetch error:', error);
        }
    }

    /* ------------------- LIFECYCLE ------------------- */

    renderedCallback() {
        this.renderSummary();
        if (this._rendered) return;
        this._rendered = true;
        this.dispatchEvent(new CustomEvent('ready'));
    }

    /* ------------------- CORE RENDER ------------------- */

    renderSummary() {
        const container = this.template.querySelector('[data-id="aiSummaryContainer"]');
        if (container && this.aiSummary && container.innerHTML === '') {
            container.innerHTML = this.sanitizeHtml(this.aiSummary);
        }
    }

    /* ------------------- FORMATTER ------------------- */

    formatAyushJson(json) {
        let output = '';

        // Morbidity
        if (json.morbidity_classification) {
            output += `**Morbidity Classification**\n`;
            output += `NAMC Code: ${json.morbidity_classification.namc_code}\n`;
            output += `Doshas Involved: ${json.morbidity_classification.doshas_involved.join(', ')}\n\n`;
        }

        // Medications
        if (json.ayurvedic_formulary_recommendations?.length) {
            output += `**Ayurvedic Formulary of India Recommendation**`;
            json.ayurvedic_formulary_recommendations.forEach((med, index) => {
                output += `\n${index + 1}. **${med.formulation_name}**\n`;
                output += `   **Dose:** ${med.adjusted_dosage}\n`;
                output += `   **Anupana:** ${med.anupana}\n`;
                output += `   **Timing:** ${med.timing}\n`;
            });
            output += `\n\n`;
        }

        // Safety
        if (json.safety_and_interactions) {
            output += `**Safety & Interactions**\n`;
            output += `**Herb-Drug Check:** ${json.safety_and_interactions.herb_drug_check}\n`;
            output += `**Contraindications:** ${json.safety_and_interactions.contraindications}\n`;
            output += `**Red Flags:** ${json.safety_and_interactions.red_flags}\n\n`;
        }

        // Non-pharmacological
        if (json.non_pharmacological_advice) {
            output += `**Ayurveda-based non-pharmacological advice aligned with Pathya-Apathya, Dinacharya, and Ahara-Vihara principles**\n`;
            (json.non_pharmacological_advice.ahara || []).forEach(a => {
                output += `- ${a}\n`;
            });
            (json.non_pharmacological_advice.vihara || []).forEach(v => {
                output += `- ${v}\n`;
            });
            (json.non_pharmacological_advice.ritucharya || []).forEach(r => {
                output += `- ${r}\n`;
            });
            output += `\n`;
        }

        // Shastriya Validation
        // if (json.shastriya_safety_validation) {
        //     output += `**Shastriya Safety Validation**\n`;
        //     output += `${json.shastriya_safety_validation}\n`;
        // }

        return output;
    }

    /* ------------------- SANITIZER ------------------- */

    sanitizeHtml(text) {
        if (!text) return '';

        let sanitized = text;

        // Bold (**text**)
        sanitized = sanitized.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');

        // Italic (*text*)
        sanitized = sanitized.replace(/(^|[^*])\*(?!\*)(.*?)\*(?!\*)/g, '$1<i>$2</i>');

        // Line breaks
        sanitized = sanitized.replace(/\r?\n/g, '<br>');

        return sanitized;
    }

    /* ------------------- COMPUTED ------------------- */

    get filteredConsiderations() {
        if (!this.considerations?.data) {
            return [];
        }

        return this.considerations.data.filter(row => {
            if (!row.value) return false;
            const value = row.value.trim().toLowerCase();
            return value !== '' && value !== 'not applicable' && value !== 'n/a';
        });
    }

    get showNormalContent() {
    return !this.isEmergency;
}

    /* ------------------- EVENTS ------------------- */

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    closeModal() {
        this.isModalOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
    }
}