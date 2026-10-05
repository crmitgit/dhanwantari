import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

// Apex
import searchProviders from '@salesforce/apex/HealthcareProviderController.searchProviders';
import getSpecialties from '@salesforce/apex/HealthcareProviderController.getSpecialties';
import cloneReferralToNewProvider from '@salesforce/apex/ReferralToAnotherProvider.cloneReferralToNewProvider';

// Static resources (for header UI)
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import Government_logo from '@salesforce/resourceUrl/Government_logo';

export default class ReferralToSecondaryProvider extends NavigationMixin(LightningElement) {

    @api recordId;

    // UI
    leftCornerImageUrl = pmjayLogo;
    rightCornerImageUrl = Government_logo;

    @track isLoading = false;

    // Search
    @track searchCriteria = {
        city: '',
        hospitalType: '',
        primarySpecialty: '',
        secondarySpecialty: ''
    };

    @track searchResults = [];
    @track specialtyOptions = [];
    @track showResults = false;

    @track selectedProviderId = '';
    selectedProviderName = '';


    @track reasonForReferral = '';

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

    hospitalTypeOptions = [
        { label: 'Public', value: 'Public' },
        { label: 'Private (Not For Profit)', value: 'Private(Not For Profit)' },
        { label: 'Private (For Profit)', value: 'Private(For Profit)' }
    ];

    connectedCallback() {
        this.loadSpecialties();
    }

    async loadSpecialties() {
        try {
            const result = await getSpecialties();
            this.specialtyOptions = result.map(s => ({
                label: s.label,
                value: s.label
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load specialties', 'error');
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;

        this.searchCriteria = {
            ...this.searchCriteria,
            [field]: value
        };
    }

    async handleSearch() {

        if (!this.searchCriteria.primarySpecialty || !this.searchCriteria.city) {
            this.showToast('Error', 'Primary Specialty and City are required', 'error');
            return;
        }

        this.isLoading = true;
        this.showResults = false;

        try {
            const result = await searchProviders({ searchCriteria: this.searchCriteria });

            this.searchResults = result.map(provider => ({
                Id: provider.id,
                Name: provider.name,
                displayAddress: provider.formattedAddress || 'Address not available',
                isSelected: false,
                cardClass: 'provider-card'
            }));

            this.showResults = true;

        } catch (error) {
            this.showToast('Error', 'Failed to search providers', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleProviderSelection(event) {
        const providerId = event.currentTarget.dataset.id;
        this.selectProvider(providerId);
    }

    selectProvider(providerId) {
        this.selectedProviderId = providerId;

        const selected = this.searchResults.find(p => p.Id === providerId);
        this.selectedProviderName = selected ? selected.Name : '';

        this.searchResults = this.searchResults.map(p => ({
            ...p,
            isSelected: p.Id === providerId,
            cardClass: p.Id === providerId ? 'provider-card selected' : 'provider-card'
        }));
    }

    handleReasonChange(event) {
        this.reasonForReferral = event.target.value;
    }

    get isDisabled() {
        return !this.selectedProviderId || !this.reasonForReferral || this.isLoading;
    }

    async handleSendEmail() {

        if (this.isDisabled) {
            this.showToast('Error', 'Select provider and enter reason', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const newReferralId = await cloneReferralToNewProvider({
                originalReferralId: this.recordId,
                newProviderId: this.selectedProviderId,
                reason: this.reasonForReferral
            });

            this.showToast('Success', 'Referral sent successfully', 'success');

            this.closeModal();

            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: newReferralId,
                    actionName: 'view'
                }
            }).then(url => {
                window.open(url, '_blank');
            });

        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error sending referral', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}