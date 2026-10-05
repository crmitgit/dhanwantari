import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getHealthcareProviders from '@salesforce/apex/ReferralToAnotherProvider.getHealthcareProviders';
import cloneReferralToNewProvider from '@salesforce/apex/ReferralToAnotherProvider.cloneReferralToNewProvider';

const REFERRAL_FIELDS = ['Referral__c.Name', 'Referral__c.Id'];

export default class SelectEmpanelledProvider extends NavigationMixin(LightningElement) {
    @api recordId; // Current Referral record ID
    @track selectedProviderId = '';
    @track healthcareProviders = [];
    @track isLoading = false;
    @track reasonForReferral = '';
    
    // Get referral record data
    @wire(getRecord, { recordId: '$recordId', fields: REFERRAL_FIELDS })
    referralRecord;

    // Get healthcare providers for picklist
    @wire(getHealthcareProviders)
    wiredProviders({ error, data }) {
        if (data) {
            this.healthcareProviders = data.map(provider => ({
                label: provider.Name,
                value: provider.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load Healthcare Providers', 'error');
            console.log(error, 'error');
        }
    }

    closeModal() {
        // Close the screen action
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleProviderChange(event) {
        this.selectedProviderId = event.detail.value;
    }

    handleReasonChange(event) {
    this.reasonForReferral = event.detail.value;
}

    async handleSendEmail() {
        if (!this.selectedProviderId) {
            this.showToast('Error', 'Please select a Healthcare Provider', 'error');
            return;
        }

        if (!this.reasonForReferral || this.reasonForReferral.trim() === '') {
    this.showToast('Error', 'Please provide a reason for referral', 'error');
    return;
}

        this.isLoading = true;
        
        try {
            const newReferralId = await cloneReferralToNewProvider({
                originalReferralId: this.recordId,
                newProviderId: this.selectedProviderId,
                reason: this.reasonForReferral.trim()
            });
            
            if (newReferralId) {
                this.showToast('Success', 'Referral Case File successfully sent to the Empanelled Provider.', 'success');
                
                this.closeModal();      
        // Method 1: Using NavigationMixin (preferred)
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: newReferralId,
                actionName: 'view'
            }
        }).then(url => {
            window.open(url, '_blank');
        }).catch(error => {
            console.error('Navigation error:', error);
        
        });
    
                
            } else {
                this.showToast('Error', 'Failed to clone referral', 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Failed to clone referral: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    get providerOptions() {
        return this.healthcareProviders;
    }

   get isDisabled() {
    return !this.selectedProviderId || !this.reasonForReferral || this.reasonForReferral.trim() === '' || this.isLoading;
}

}