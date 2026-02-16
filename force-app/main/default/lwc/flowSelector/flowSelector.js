/**
 * flowSelector - Searchable dropdown for selecting a Flow to analyze.
 *
 * Uses @wire to call getFlowList() (cacheable) for fast loading.
 * Fires a 'flowselect' custom event when the user picks a flow,
 * passing the flow's developer name to the parent component.
 */
import { LightningElement, wire, track } from 'lwc';
import getFlowList from '@salesforce/apex/FlowHealthController.getFlowList';

// Map processType API values to human-readable labels
const PROCESS_TYPE_LABELS = {
    'AutoLaunchedFlow': 'Autolaunched',
    'Flow': 'Screen Flow',
    'Workflow': 'Record-Triggered',
    'CustomEvent': 'Platform Event',
    'InvocableProcess': 'Invocable',
    'RecordTriggeredFlow': 'Record-Triggered'
};

export default class FlowSelector extends LightningElement {

    @track flowOptions = [];
    @track filteredOptions = [];
    @track selectedFlow = null;
    @track isLoading = true;
    @track error = null;
    @track searchTerm = '';

    // All flows from Apex (raw data)
    allFlows = [];

    /**
     * @wire fetches the flow list on component load.
     * Since getFlowList() is cacheable=true, this data is
     * cached by the Lightning Data Service — subsequent loads
     * are instant.
     */
    @wire(getFlowList)
    wiredFlows({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.allFlows = data;
            this.buildOptions(data);
            this.error = null;
        } else if (error) {
            this.error = this.extractError(error);
            this.flowOptions = [];
        }
    }

    /**
     * Builds combobox options from the flow list.
     * Format: "Label (Type)" as the display text.
     */
    buildOptions(flows) {
        this.flowOptions = flows.map(flow => ({
            label: `${flow.masterLabel} (${this.getTypeLabel(flow.processType)})`,
            value: flow.developerName,
            description: flow.developerName
        }));
        this.filteredOptions = [...this.flowOptions];
    }

    /**
     * Converts the processType to a readable label.
     */
    getTypeLabel(processType) {
        return PROCESS_TYPE_LABELS[processType] || processType || 'Unknown';
    }

    /**
     * Handles the combobox selection change.
     * Fires a custom 'flowselect' event with the selected flow's developer name.
     */
    handleFlowChange(event) {
        this.selectedFlow = event.detail.value;

        // Find the full flow info to pass along
        const flowInfo = this.allFlows.find(
            f => f.developerName === this.selectedFlow
        );

        // Dispatch the event to the parent component
        this.dispatchEvent(new CustomEvent('flowselect', {
            detail: {
                developerName: this.selectedFlow,
                flowInfo: flowInfo
            }
        }));
    }

    /**
     * Handles the search input for filtering flows.
     */
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        if (this.searchTerm) {
            this.filteredOptions = this.flowOptions.filter(opt =>
                opt.label.toLowerCase().includes(this.searchTerm) ||
                opt.value.toLowerCase().includes(this.searchTerm)
            );
        } else {
            this.filteredOptions = [...this.flowOptions];
        }
    }

    /**
     * Extracts a readable error message from the LWC error object.
     */
    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unknown error occurred while loading flows.';
    }

    // Computed properties for the template
    get hasFlows() {
        return this.flowOptions.length > 0;
    }

    get flowCount() {
        return this.flowOptions.length;
    }

    get placeholder() {
        return this.hasFlows
            ? `Select a flow (${this.flowCount} found)...`
            : 'No active flows found';
    }
}
