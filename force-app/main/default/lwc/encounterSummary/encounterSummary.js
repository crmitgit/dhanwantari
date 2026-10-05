import { LightningElement, api, wire, track } from 'lwc';
import getEncounterDetails from '@salesforce/apex/EncounterSummaryController.getEncounterDetails';
import sendEncounterEmail from '@salesforce/apex/EncounterSummaryController.sendEncounterEmail';
import { CloseActionScreenEvent } from 'lightning/actions';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import doctorlogo from '@salesforce/resourceUrl/DoctorLogo';
import doctorLogoNew from '@salesforce/resourceUrl/DoctorLogoNew';
import getDoctorSignature from '@salesforce/apex/EncounterSummaryController.getDoctorSignature';
import sendEmail from '@salesforce/apex/PrescriptionApprovalController.sendEmail';
import getDoctoreImage from '@salesforce/apex/PrescriptionApprovalController.getDoctoreImage';
import crmitLogo from '@salesforce/apex/PrescriptionApprovalController.getDoctoreImage';
import { refreshApex } from '@salesforce/apex';

export default class EncounterSummary extends LightningElement {
    @api encounterName;
    recordId;
    summary = {};
    hospitalLogo = pmjayLogo;
    crmitLogo=crmitLogo;
    consultationLogo = doctorlogo;
    doctorLogoNew = doctorLogoNew;
    signature;
    @track isSending = false;
    showConfirmModal = false;
    dynamicSpinnerMessage = 'Sending email. Kindly wait...';
    doctorConsultationImage;
    doctorSignatureImage;

    @track wiredDetails;
    @wire(getEncounterDetails, { encounterName: '$encounterName' })
    wiredData(value) {
        const { data, error } = value;
        this.wiredDetails = value;
        if (data) {
            this.summary = data;
            console.log('patient name from encounter summary==  ',this.summary.patientName);
            this.fetchDoctoreImages();
            getDoctorSignature({ doctorId: data.prescribingDoctorId })
                .then(sig => { this.signature = sig; })
                .catch(err => { console.error('Sig error', err); });
        } else if (error) {
            console.error('Error loading encounter summary:', error);
        }
    }

    fetchDoctoreImages(){
        getDoctoreImage({})
        .then(result => {
            this.doctorConsultationImage = result.consultationImage;
            this.doctorSignatureImage = result.signatureImage;
            console.log('Doctor Consultation Image:', this.doctorConsultationImage);
            console.log('Doctor Signature Image:', this.doctorSignatureImage);
        })
        .catch(error => {
            console.log('Error fetching doctor images:', error);
            this.doctorConsultationImage = null;
            this.doctorSignatureImage = null;
        });
    }

    get isMedicationEmpty() {
        return !this.summary.medications || this.summary.medications.length === 0;
    }

    get isCsrEmpty() {
        return !this.summary.csrs || this.summary.csrs.length === 0;
    }

    get formattedCareInstructions() {
        if (!this.summary?.careInstructions) return '';
        return this.summary.careInstructions
            .split('\n')
            .map(line => `- ${line}`)
            .join('\n');
    }

    get formattedMedications() {
        if (!this.summary || !this.summary.medications) return [];
        return this.summary.medications.map((med) => {
            let parts = [];
            if (med.morning && med.morning !== "N/A") parts.push(`Morning ${med.morning}`);
            if (med.afternoon && med.afternoon !== "N/A") parts.push(`Afternoon ${med.afternoon}`);
            if (med.night && med.night !== "N/A") parts.push(`Night ${med.night}`);

            // Join dosage parts with ', ', then append food only if there's dosage
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


    handlePrint() {
        const container = this.template.querySelector('.encounter-summary-container');
        const recommendationText = this.template.querySelector('.recommendation-box')?.value || '';

        if (!container) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Encounter summary not found.',
                    variant: 'error'
                })
            );
            return;
        }

        const encodedRecommendation = encodeURIComponent(recommendationText);
        const vfUrl = `/apex/PrintEncounterSummary?id=${this.encounterName}&rec=${encodedRecommendation}`;
        window.open(vfUrl, '_blank');
    }

    handleClose() {
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
        // this.dispatchEvent(new CloseActionScreenEvent()); // Optional: use if this is in a quick action modal
    }

    get formattedDiagnosisList() {
    if (!this.summary?.diagnoses) return [];
    return this.summary.diagnoses.map(diag => {
        return {
            text: diag.text || 'N/A',
            type: diag.type || 'Unknown'
        };
    });
}

     promptEmailConfirmation() {
        this.showConfirmModal = true;
        console.log('email confirmation box open');
    }

    cancelEmail() {
        this.showConfirmModal = false;
    }

    handleEmail() {
        const email        = this.summary?.email;
        const encounterId  = this.encounterName;
        const patientName  = this.summary?.patientName || 'Patient';
        const facilityName = this.summary?.facilityName  || 'PHWC';
        const doctorName   = this.summary?.doctorName || 'Your Doctor';
        const endDate      = this.summary?.endDate || '';
        console.log(' The email is : ',email );
        this.showConfirmModal = false;

        if (!email) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Patient email not available.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isSending = true;

        sendEncounterEmail({
            encounterId:  encounterId,
            patientEmail: email,
            patientName:  patientName,
            facilityName: facilityName,
            endDate:      endDate,
            doctorName:   doctorName
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Email sent successfully!',
                    variant: 'success'
                })
            );
        })
        .catch(error => {
            console.error('Email send error:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to send email.',
                    variant: 'error'
                })
            );
        })
        .finally(() => {
            this.isSending = false;
        });
    }
    
    // Below method added by Karishma on 22nd July 2025
    handleSendForApproval() {
        if(this.summary && this.summary.status === 'Approval Pending'){
            this.showInfoToast('Info', 'This consultation summary is already pending approval.', 'info');
            return;
        }
        this.dynamicSpinnerMessage = 'Sending for Approval. Kindly wait...';
        this.isSending = true;
       sendEmail({
        cinicalEncounterId: this.encounterName
       })
        .then((result) => {
            this.isSending = false;
            if(result.status == 'Success'){
                this.refreshEncounterDetails();
                this.showInfoToast('Success', result.message, 'success');
                this.handleClose();
            }else if(result.status == 'Error'){
                this.showInfoToast('Error', result.message, 'error');
                this.handleClose();
            }
        })
        .catch(error => {
            this.isSending = false;
            console.log('Error sending email for approval:', error);
        });
    }

    showInfoToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    refreshEncounterDetails() {
        refreshApex(this.wiredDetails);
    }

    // Approved only when the doctor has actually approved (approval date stamped),
    // not just because the status was set to Completed / Referred.
    get isApproved() {
        return this.summary?.isDoctorApproved === true;
    }

    get isNotApproved() {
        return !this.isApproved;
    }

    get isPendingApproval() {
        return this.summary?.status === 'Approval Pending';
    }

    get canSendForApproval() {
        return !!this.summary
            && !this.isApproved
            && !this.isPendingApproval
            && this.summary.status !== 'Cancelled';
    }

    get isActionDisabled() {
    return this.isNotApproved || this.isMedicationEmpty;
    }

}