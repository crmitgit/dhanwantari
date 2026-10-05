import { LightningElement, api, wire, track } from 'lwc';
import getAISummary from '@salesforce/apex/MedicationGuideController.getAISummary';
import getEncounterDetails from '@salesforce/apex/DiagnosisController.getEncounterDetails';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';
import getPatientConsiderations from '@salesforce/apex/ActiveMedicationController.getPatientConsiderations';
import crmitLogo from '@salesforce/resourceUrl/crmitLogo';

export default class AiSummaryModal extends LightningElement {
    @api recordId;
    @track isModalOpen = true;
    @track aiSummary;
    @track encounterName;
    @track patientName;
    @track patientId;
    @track patientUrl;
    isLoading = false;
    crmitLogo=crmitLogo;

    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;

    @wire(getPatientConsiderations, { consultationId: '$recordId' })
    considerations;

    @wire(getAISummary, { clinicalEncounterId: '$recordId' })
    wiredSummary({ error, data }) {
        if (data) {
            this.aiSummary = data;
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
    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }


    renderedCallback() {
        this.renderSummary();
    }

    renderSummary() {
        const container = this.template.querySelector('[data-id="aiSummaryContainer"]');
        if (container && this.aiSummary) {
            container.innerHTML = this.sanitizeHtml(this.aiSummary);
        }
    }

    sanitizeHtml(html) {
        if (!html) return '';

        let sanitized = html;

        // Convert Markdown-style bold to HTML (optional)
        sanitized = sanitized.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');

        // Convert Markdown italics to HTML (optional)
        sanitized = sanitized.replace(/(^|[^*])\*(?!\*)(.*?)\*(?!\*)/g, '$1<i>$2</i>');

        // Normalize line breaks. HTML output already carries its own <br>/<p> tags,
        // so converting its newlines as well doubled every line break.
        if (/<(br|p|h3|b)\b/i.test(sanitized)) {
            sanitized = sanitized.replace(/\r?\n/g, '');
        } else {
            sanitized = sanitized.replace(/\r?\n/g, '<br>');
        }
        sanitized = sanitized.replace(/(<br\s*\/?>\s*){3,}/gi, '<br><br>');

        return sanitized;
    }
    get filteredConsiderations() {
        if (!this.considerations?.data) {
            return [];
        }

        return this.considerations.data.filter(row => {
            if (!row.value) return false;

            const value = row.value.trim().toLowerCase();

            // hide empty or not applicable values
            return value !== '' && value !== 'not applicable' && value !== 'n/a';
        });
    }



    decodeHtmlEntities(str) {
        if (!str) return '';

        const doc = new DOMParser().parseFromString(str, 'text/html');
        let decoded = doc.documentElement.textContent || '';

        // Bold formatting
        decoded = decoded.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');

        // Italic formatting
        decoded = decoded.replace(/(^|[^*])\*(?!\*)(.*?)\*(?!\*)/g, '$1<i>$2</i>');

        // Headings like "Disclaimer:"
        decoded = decoded.replace(/^(.+?:)$/gm, '<span class="section-title">$1</span>');

        // Bullets
        decoded = decoded.replace(/^(?!\s)-\s(.*)/gm, '&nbsp;&nbsp;&nbsp;- $1');
        decoded = decoded.replace(/^\s{2,}-\s(.*)/gm, '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;- $1');

        // Paragraphs
        decoded = decoded.replace(/(\r?\n){2,}/g, '<br><br>');
        decoded = decoded.replace(/(\r?\n)/g, '<br>');

        return decoded.trim();
    }

    closeModal() {
        this.isModalOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
        window.location.reload();
    }
}