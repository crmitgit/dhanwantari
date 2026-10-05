import { LightningElement, api, track, wire } from 'lwc';
import search from '@salesforce/apex/CustomLookupController.search';

export default class CustomLookupNew extends LightningElement {
    @api objName;
    @api iconName;
    @api filter = '';
    @api searchPlaceholder = 'Search';
    @api initialSelectedName;
    @api initialSelectedId;

    @track searchTerm = '';
    @track records = [];
    @track selectedId;
    @track selectedName;
    @track isValueSelected = false;
    @track showDropdown = false; // Initialize to false by default

    // Initialize component
    connectedCallback() {
        if (this.initialSelectedName && this.initialSelectedId) {
            this.selectedName = this.initialSelectedName;
            this.selectedId = this.initialSelectedId;
            this.isValueSelected = true;
            this.searchTerm = this.initialSelectedName; // Pre-fill search term if an initial value exists
            this.showDropdown = false; // Ensure dropdown is hidden if an initial value is set
        } else {
            this.showDropdown = false; // Explicitly ensure it's false on load if no initial value
        }
    }

    // Wire method for search
    @wire(search, { searchTerm: '$searchTerm', myObject: '$objName', filter: '$filter' })
    wiredRecords({ error, data }) {

        console.log('searchTerm:', this.searchTerm);
        console.log('objName:', this.objName);
        if (data) {
            this.records = data;
            console.log('Apex returned records:', data);
            console.log('Record count:', data.length);
            // Only show dropdown if there are records, a search term exists, AND no value is currently selected
            // This prevents showing all records on initial load if searchTerm is empty
            this.showDropdown = (this.records.length > 0 && this.searchTerm.length > 0 && !this.isValueSelected);
        } else if (error) {
            console.error('Search error:', error);
            this.records = [];
            this.showDropdown = false;
        }
    }

    // Handle input changes (user types)
    handleInputChange = (event) => {
        this.searchTerm = event.target.value;
        this.selectedId = null;
        this.selectedName = '';
        this.isValueSelected = false;
        // If user types, show dropdown immediately if there's a search term
        this.showDropdown = (this.searchTerm.length > 0);
    };

    // Handle click on the input field
    handleClick = () => {
        // Only show dropdown if no value is currently selected AND there's a search term (or if you want to show all on click of empty field)
        // If you want to show all available options on click of an empty field, remove `this.searchTerm.length > 0` condition.
        if (!this.isValueSelected) { 
             this.showDropdown = true; // Show dropdown on click if nothing selected
        } else {
            this.showDropdown = false; // Keep it hidden if a value is selected
        }
    };

    // Handle item selection
    handleItemSelect = (event) => {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        this.selectedId = selectedId;
        this.selectedName = selectedName;
        this.isValueSelected = true;
        this.searchTerm = selectedName; // Update search term to show selected name
        this.showDropdown = false; // Hide dropdown after selection

        this.dispatchEvent(new CustomEvent('lookupselected', {
            detail: {
                lookupId: selectedId,
                lookupValue: selectedName,
                sectionId: this.template.host.dataset.id
            }
        }));
    };

    // Handle removal of selection
    handleRemoveSelection = () => {
        this.selectedId = null;
        this.selectedName = '';
        this.isValueSelected = false;
        this.searchTerm = ''; // Clear search term to allow new input
        this.records = []; // Clear records to prevent old list from reappearing
        this.showDropdown = false; // Ensure dropdown is hidden

        this.dispatchEvent(new CustomEvent('lookupremoved', {
            detail: { sectionId: this.template.host.dataset.id }
        }));
    };

    // Public method to clear selection
    @api
    clearSelection() {
        this.handleRemoveSelection();
    }

    // New getter to apply conditional class for lookup-container styling
    get containerClass() {
        let classes = 'lookup-container';
        if (this.isValueSelected) {
            classes += ' selected-mode';
        }
        return classes;
    }
}