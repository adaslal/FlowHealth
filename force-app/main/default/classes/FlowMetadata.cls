/**
 * FlowMetadata - Wrapper classes for deserializing Salesforce Flow metadata
 * returned by the Tooling API.
 *
 * The Tooling API query:
 *   SELECT Id, FullName, MasterLabel, Status, Metadata
 *   FROM Flow
 *   WHERE Definition.DeveloperName = :flowName AND Status = 'Active'
 *
 * returns a JSON structure where the 'Metadata' field contains the full
 * flow definition. These inner classes map to that structure so we can
 * deserialize with JSON.deserialize() and work with strongly-typed objects
 * instead of raw Maps.
 *
 * NOTE: Salesforce's JSON serializer ignores properties not present in the
 * JSON, so we only need to define the fields we actually inspect. If a new
 * element type appears in a future API version, it simply won't deserialize
 * — it won't cause errors. This makes the parser forward-compatible.
 */
public class FlowMetadata {

    // =========================================================================
    // TOP-LEVEL: Tooling API response wrapper
    // =========================================================================

    /**
     * Represents the top-level Tooling API response.
     * The query returns a 'records' array, each with a 'Metadata' field.
     */
    public class ToolingQueryResult {
        public Integer size;
        public List<FlowRecord> records;
    }

    /**
     * A single Flow record from the Tooling API.
     * 'Metadata' contains the entire flow definition.
     */
    public class FlowRecord {
        public String Id;
        public String FullName;
        public String MasterLabel;
        public String Status;
        public FlowDefinition Metadata;
    }

    // =========================================================================
    // FLOW DEFINITION: The root of the flow structure
    // =========================================================================

    /**
     * The root flow definition. Contains all elements, variables, and
     * configuration for a single flow.
     *
     * Key fields for health analysis:
     * - processType: 'AutoLaunchedFlow', 'Flow' (screen), 'RecordTriggeredFlow', etc.
     * - triggerType: 'RecordBeforeSave', 'RecordAfterSave', 'Scheduled', etc.
     * - start: The entry point element
     * - All element arrays (decisions, loops, recordCreates, etc.)
     */
    public class FlowDefinition {
        // Flow metadata
        public String description;
        public String label;
        public String processType;       // AutoLaunchedFlow, Flow, RecordTriggeredFlow, etc.
        public String apiVersion;
        public String status;
        public String runInMode;         // SystemModeWithSharing, SystemModeWithoutSharing, DefaultMode
        public String triggerType;       // RecordBeforeSave, RecordAfterSave, RecordBeforeDelete, Scheduled, PlatformEvent

        // Entry point
        public FlowStart start;

        // Element arrays - these are the building blocks your rules will inspect
        public List<FlowActionCall> actionCalls;
        public List<FlowAssignment> assignments;
        public List<FlowDecision> decisions;
        public List<FlowLoop> loops;
        public List<FlowRecordCreate> recordCreates;
        public List<FlowRecordUpdate> recordUpdates;
        public List<FlowRecordDelete> recordDeletes;
        public List<FlowRecordLookup> recordLookups;
        public List<FlowScreen> screens;
        public List<FlowSubflow> subflows;
        public List<FlowWait> waits;

        // Variables and resources
        public List<FlowVariable> variables;
        public List<FlowFormula> formulas;
        public List<FlowConstant> constants;
        public List<FlowTextTemplate> textTemplates;
        public List<FlowChoice> choices;

        // =====================================================================
        // HELPER METHODS: Make it easy for rules to traverse the flow
        // =====================================================================

        /**
         * Returns all elements in the flow as a flat list.
         * Useful for rules that need to check every element regardless of type
         * (e.g., "missing description" or "auto-generated name" checks).
         */
        public List<FlowElement> getAllElements() {
            List<FlowElement> all = new List<FlowElement>();
            if (actionCalls != null)    all.addAll(actionCalls);
            if (assignments != null)    all.addAll(assignments);
            if (decisions != null)      all.addAll(decisions);
            if (loops != null)          all.addAll(loops);
            if (recordCreates != null)  all.addAll(recordCreates);
            if (recordUpdates != null)  all.addAll(recordUpdates);
            if (recordDeletes != null)  all.addAll(recordDeletes);
            if (recordLookups != null)  all.addAll(recordLookups);
            if (screens != null)        all.addAll(screens);
            if (subflows != null)       all.addAll(subflows);
            if (waits != null)          all.addAll(waits);
            return all;
        }

        /**
         * Returns all DML elements (create, update, delete).
         * Performance rules need this to check if DML is inside loops.
         */
        public List<FlowElement> getDmlElements() {
            List<FlowElement> dml = new List<FlowElement>();
            if (recordCreates != null)  dml.addAll(recordCreates);
            if (recordUpdates != null)  dml.addAll(recordUpdates);
            if (recordDeletes != null)  dml.addAll(recordDeletes);
            return dml;
        }

        /**
         * Returns all SOQL elements (record lookups).
         * Used by the "SOQL in loop" rule.
         */
        public List<FlowRecordLookup> getSoqlElements() {
            return recordLookups != null ? recordLookups : new List<FlowRecordLookup>();
        }

        /**
         * Builds a map of elementName -> FlowElement for quick lookup.
         * Rules that need to traverse connectors use this to follow
         * the flow's execution path.
         */
        public Map<String, FlowElement> getElementMap() {
            Map<String, FlowElement> elementMap = new Map<String, FlowElement>();
            for (FlowElement el : getAllElements()) {
                if (el.name != null) {
                    elementMap.put(el.name, el);
                }
            }
            return elementMap;
        }
    }

    // =========================================================================
    // FLOW START: Entry point configuration
    // =========================================================================

    public class FlowStart {
        public String locationX;
        public String locationY;
        public FlowConnector connector;
        public FlowConnector scheduledConnector;
        public String object_x;           // The SObject for record-triggered flows (serialized as "object")
        public String triggerType;
        public String recordTriggerType;   // Create, Update, CreateAndUpdate, Delete
        public List<FlowRecordFilter> filters;
        public String filterLogic;
    }

    // =========================================================================
    // BASE ELEMENT: All flow elements extend this
    // =========================================================================

    /**
     * Base class for all flow elements. Every node on the flow canvas
     * has at least a name, label, description, and position.
     *
     * The connector field points to the next element in the flow path.
     * The faultConnector points to the error-handling path (if any).
     */
    public virtual class FlowElement {
        public String name;
        public String label;
        public String description;
        public String locationX;
        public String locationY;
        public FlowConnector connector;
        public FlowConnector faultConnector;
    }

    // =========================================================================
    // CONNECTORS: Links between elements
    // =========================================================================

    /**
     * A connector links one element to the next.
     * targetReference is the API name of the destination element.
     */
    public class FlowConnector {
        public String targetReference;
    }

    // =========================================================================
    // ELEMENT TYPES: One class per flow element type
    // =========================================================================

    /**
     * Action Call - invocable actions (Apex, email alerts, Chatter posts, etc.)
     */
    public class FlowActionCall extends FlowElement {
        public String actionName;
        public String actionType;         // apex, emailAlert, chatterPost, etc.
        public List<FlowInputParameter> inputParameters;
        public List<FlowOutputParameter> outputParameters;
        public Boolean storeOutputAutomatically;
        public String flowTransactionModel;
    }

    /**
     * Assignment - sets variable values
     */
    public class FlowAssignment extends FlowElement {
        public List<FlowAssignmentItem> assignmentItems;
    }

    /**
     * Decision - branching logic with rules/outcomes
     */
    public class FlowDecision extends FlowElement {
        public FlowConnector defaultConnector;
        public String defaultConnectorLabel;
        public List<FlowRule> rules;
    }

    /**
     * Loop - iterates over a collection variable
     */
    public class FlowLoop extends FlowElement {
        public String collectionReference;
        public String iterationOrder;
        public FlowConnector nextValueConnector;      // "inside the loop" path
        public FlowConnector noMoreValuesConnector;    // "after the loop" path
        public String assignNextValueToReference;
    }

    /**
     * Record Create - inserts records (DML)
     */
    public class FlowRecordCreate extends FlowElement {
        public String object_x;           // SObject type (serialized as "object")
        public List<FlowInputAssignment> inputAssignments;
        public String inputReference;
        public String assignRecordIdToReference;
        public Boolean storeOutputAutomatically;
    }

    /**
     * Record Update - updates records (DML)
     */
    public class FlowRecordUpdate extends FlowElement {
        public String object_x;
        public List<FlowInputAssignment> inputAssignments;
        public String inputReference;
        public List<FlowRecordFilter> filters;
        public String filterLogic;
    }

    /**
     * Record Delete - deletes records (DML)
     */
    public class FlowRecordDelete extends FlowElement {
        public String object_x;
        public List<FlowRecordFilter> filters;
        public String filterLogic;
        public String inputReference;
    }

    /**
     * Record Lookup - queries records (SOQL)
     */
    public class FlowRecordLookup extends FlowElement {
        public String object_x;
        public List<FlowRecordFilter> filters;
        public String filterLogic;
        public String outputReference;
        public List<FlowOutputAssignment> outputAssignments;
        public Boolean getFirstRecordOnly;
        public Boolean storeOutputAutomatically;
        public String sortField;
        public String sortOrder;
    }

    /**
     * Screen - interactive screen elements (Screen Flows only)
     */
    public class FlowScreen extends FlowElement {
        public List<FlowScreenField> fields;
        public Boolean allowBack;
        public Boolean allowFinish;
        public Boolean allowPause;
        public Boolean showHeader;
        public Boolean showFooter;
    }

    /**
     * Subflow - calls another flow
     */
    public class FlowSubflow extends FlowElement {
        public String flowName;
        public List<FlowInputParameter> inputAssignments;
        public List<FlowOutputParameter> outputAssignments;
    }

    /**
     * Wait - pauses flow execution (Scheduled Paths, etc.)
     */
    public class FlowWait extends FlowElement {
        public List<FlowWaitEvent> waitEvents;
        public FlowConnector defaultConnector;
        public String defaultConnectorLabel;
    }

    // =========================================================================
    // SUB-STRUCTURES: Used within elements
    // =========================================================================

    public class FlowRule {
        public String name;
        public String label;
        public String conditionLogic;
        public List<FlowCondition> conditions;
        public FlowConnector connector;
    }

    public class FlowCondition {
        public String leftValueReference;
        public String operator;
        public FlowValue rightValue;
    }

    public class FlowValue {
        public String stringValue;
        public Decimal numberValue;
        public Boolean booleanValue;
        public String elementReference;
    }

    public class FlowInputParameter {
        public String name;
        public FlowValue value;
    }

    public class FlowOutputParameter {
        public String name;
        public String assignToReference;
    }

    public class FlowInputAssignment {
        public String field;
        public FlowValue value;
    }

    public class FlowOutputAssignment {
        public String field;
        public String assignToReference;
    }

    public class FlowRecordFilter {
        public String field;
        public String operator;
        public FlowValue value;
    }

    public class FlowAssignmentItem {
        public String assignToReference;
        public String operator;
        public FlowValue value;
    }

    public class FlowScreenField {
        public String name;
        public String fieldType;
        public String fieldText;
        public String dataType;
        public Boolean isRequired;
        public String defaultValue;
        public List<FlowScreenField> fields;   // nested screen fields (sections)
    }

    public class FlowWaitEvent {
        public String name;
        public String label;
        public String eventType;
        public FlowConnector connector;
        public List<FlowCondition> conditions;
        public String conditionLogic;
    }

    // =========================================================================
    // VARIABLES AND RESOURCES
    // =========================================================================

    public class FlowVariable {
        public String name;
        public String description;
        public String dataType;
        public Boolean isCollection;
        public Boolean isInput;
        public Boolean isOutput;
        public String objectType;
        public FlowValue defaultValue;
    }

    public class FlowFormula {
        public String name;
        public String description;
        public String dataType;
        public String expression;
    }

    public class FlowConstant {
        public String name;
        public String description;
        public String dataType;
        public FlowValue value;
    }

    public class FlowTextTemplate {
        public String name;
        public String description;
        public String text;
        public Boolean isViewedAsPlainText;
    }

    public class FlowChoice {
        public String name;
        public String choiceText;
        public String dataType;
        public FlowValue value;
    }
}