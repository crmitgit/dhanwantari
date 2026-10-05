import { LightningElement, api, track } from 'lwc';
import grantManualConsent from '@salesforce/apex/PmjayReferralConsentService.grantManualConsent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class GrantManualConsent extends LightningElement {
    @api recordId;

    @track isAttested = false;
    @track reason;

    get reasonOptions() {
        return [
            { label: 'Patient does not have a phone', value: 'Patient does not have a phone' },
            { label: 'Emergency situation', value: 'Emergency situation' },
            { label: 'Patient illiterate / unable to use digital consent', value: 'Patient illiterate / unable to use digital consent' },
            { label: 'Consent obtained earlier in person', value: 'Consent obtained earlier in person' }
        ];
    }

    get disableSubmit() {
        return !(this.isAttested && this.reason);
    }

    handleAttestChange(event) {
        this.isAttested = event.target.checked;
    }

    handleReasonChange(event) {
        this.reason = event.detail.value;
    }

    handleSubmit() {
        grantManualConsent({
            referralId: this.recordId,
            reason: this.reason
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Consent Granted',
                    message: 'Manual consent recorded and referral sent.',
                    variant: 'success'
                })
            );
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }
}