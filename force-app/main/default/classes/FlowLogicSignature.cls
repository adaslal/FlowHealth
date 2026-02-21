/**
 * FlowLogicSignature - Computes deterministic "Logic Signatures" for flow elements.
 *
 * A Logic Signature captures ONLY the business-logic attributes of a flow element,
 * deliberately ignoring cosmetic/layout attributes like locationX, locationY,
 * connector targets, and faultConnector targets.
 *
 * PURPOSE:
 * When two versions of a flow element share the same Logic Signature, any detected
 * differences are purely cosmetic (canvas repositioning, connector rerouting).
 * When signatures differ, the element's actual behavior has changed.
 *
 * SIGNATURE FORMAT:
 * - Fields are concatenated with '|' delimiters
 * - List items are separated by '~'
 * - Sub-fields within a list item use ':' separators
 * - Null values serialize as empty string
 * - Lists are sorted by a stable key before concatenation (order-independent)
 *
 * USAGE:
 *   String sig = FlowLogicSignature.forDecision(myDecisionElement);
 *   Boolean isSameLogic = (oldSig == newSig);
 */
public class FlowLogicSignature {

    // =========================================================================
    // Element Signatures
    // =========================================================================

    /**
     * Generic FlowElement signature (ActionCall, Assignment, Wait base).
     * Subtype-specific methods add their own fields on top.
     */
    public static String forElement(FlowMetadata.FlowElement el) {
        if (el == null) return '';
        return safe(el.label) + '|' + safe(el.description);
    }

    /**
     * ActionCall: label + actionName + actionType + inputParams + outputParams + storeOutput + transactionModel
     */
    public static String forActionCall(FlowMetadata.FlowActionCall el) {
        if (el == null) return '';
        String base = safe(el.label) + '|' + safe(el.actionName) + '|' + safe(el.actionType);
        base += '|' + serializeInputParams(el.inputParameters);
        base += '|' + serializeOutputParams(el.outputParameters);
        base += '|' + String.valueOf(el.storeOutputAutomatically);
        base += '|' + safe(el.flowTransactionModel);
        return base;
    }

    /**
     * Assignment: label + assignmentItems(assignTo:operator:value)
     */
    public static String forAssignment(FlowMetadata.FlowAssignment el) {
        if (el == null) return '';
        String base = safe(el.label);
        if (el.assignmentItems != null) {
            List<String> items = new List<String>();
            for (FlowMetadata.FlowAssignmentItem ai : el.assignmentItems) {
                items.add(safe(ai.assignToReference) + ':' + safe(ai.operator) + ':' + serializeValue(ai.value));
            }
            items.sort();
            base += '|' + String.join(items, '~');
        }
        return base;
    }

    /**
     * Decision: label + rules(name:label:conditionLogic:conditions) + defaultConnectorLabel
     */
    public static String forDecision(FlowMetadata.FlowDecision el) {
        if (el == null) return '';
        String base = safe(el.label);
        if (el.rules != null) {
            List<String> ruleSigs = new List<String>();
            for (FlowMetadata.FlowRule rule : el.rules) {
                String ruleSig = safe(rule.name) + ':' + safe(rule.label) + ':' + safe(rule.conditionLogic);
                ruleSig += ':' + serializeConditions(rule.conditions);
                ruleSigs.add(ruleSig);
            }
            ruleSigs.sort();
            base += '|' + String.join(ruleSigs, '~');
        }
        base += '|' + safe(el.defaultConnectorLabel);
        return base;
    }

    /**
     * Loop: label + collectionReference + iterationOrder + assignNextValueToReference
     */
    public static String forLoop(FlowMetadata.FlowLoop el) {
        if (el == null) return '';
        return safe(el.label) + '|' + safe(el.collectionReference) + '|'
            + safe(el.iterationOrder) + '|' + safe(el.assignNextValueToReference);
    }

    /**
     * RecordCreate: label + object + inputAssignments + inputReference + assignRecordIdTo + storeOutput
     */
    public static String forRecordCreate(FlowMetadata.FlowRecordCreate el) {
        if (el == null) return '';
        String base = safe(el.label) + '|' + safe(el.object_x);
        base += '|' + serializeInputAssignments(el.inputAssignments);
        base += '|' + safe(el.inputReference);
        base += '|' + safe(el.assignRecordIdToReference);
        base += '|' + String.valueOf(el.storeOutputAutomatically);
        return base;
    }

    /**
     * RecordUpdate: label + object + inputAssignments + inputReference + filters + filterLogic
     */
    public static String forRecordUpdate(FlowMetadata.FlowRecordUpdate el) {
        if (el == null) return '';
        String base = safe(el.label) + '|' + safe(el.object_x);
        base += '|' + serializeInputAssignments(el.inputAssignments);
        base += '|' + safe(el.inputReference);
        base += '|' + serializeFilters(el.filters);
        base += '|' + safe(el.filterLogic);
        return base;
    }

    /**
     * RecordDelete: label + object + filters + filterLogic + inputReference
     */
    public static String forRecordDelete(FlowMetadata.FlowRecordDelete el) {
        if (el == null) return '';
        return safe(el.label) + '|' + safe(el.object_x)
            + '|' + serializeFilters(el.filters)
            + '|' + safe(el.filterLogic)
            + '|' + safe(el.inputReference);
    }

    /**
     * RecordLookup: label + object + filters + filterLogic + getFirstRecordOnly
     *   + sortField + sortOrder + outputAssignments + storeOutput
     */
    public static String forRecordLookup(FlowMetadata.FlowRecordLookup el) {
        if (el == null) return '';
        String base = safe(el.label) + '|' + safe(el.object_x);
        base += '|' + serializeFilters(el.filters);
        base += '|' + safe(el.filterLogic);
        base += '|' + String.valueOf(el.getFirstRecordOnly);
        base += '|' + safe(el.sortField) + '|' + safe(el.sortOrder);
        base += '|' + serializeOutputAssignments(el.outputAssignments);
        base += '|' + String.valueOf(el.storeOutputAutomatically);
        return base;
    }

    /**
     * Screen: label + fields (recursively serialized)
     */
    public static String forScreen(FlowMetadata.FlowScreen el) {
        if (el == null) return '';
        String base = safe(el.label);
        base += '|' + String.valueOf(el.allowBack) + '|' + String.valueOf(el.allowFinish);
        base += '|' + String.valueOf(el.allowPause);
        base += '|' + String.valueOf(el.showHeader) + '|' + String.valueOf(el.showFooter);
        base += '|' + serializeScreenFields(el.fields);
        return base;
    }

    /**
     * Subflow: label + flowName + inputAssignments + outputAssignments
     */
    public static String forSubflow(FlowMetadata.FlowSubflow el) {
        if (el == null) return '';
        String base = safe(el.label) + '|' + safe(el.flowName);
        base += '|' + serializeInputParams(el.inputAssignments);
        base += '|' + serializeOutputParams(el.outputAssignments);
        return base;
    }

    /**
     * Wait: label + waitEvents(name:label:eventType:conditionLogic:conditions)
     */
    public static String forWait(FlowMetadata.FlowWait el) {
        if (el == null) return '';
        String base = safe(el.label);
        base += '|' + safe(el.defaultConnectorLabel);
        if (el.waitEvents != null) {
            List<String> eventSigs = new List<String>();
            for (FlowMetadata.FlowWaitEvent evt : el.waitEvents) {
                String evtSig = safe(evt.name) + ':' + safe(evt.label) + ':' + safe(evt.eventType);
                evtSig += ':' + safe(evt.conditionLogic) + ':' + serializeConditions(evt.conditions);
                eventSigs.add(evtSig);
            }
            eventSigs.sort();
            base += '|' + String.join(eventSigs, '~');
        }
        return base;
    }

    // =========================================================================
    // Start Element Signature
    // =========================================================================

    /**
     * Start: object + triggerType + recordTriggerType + filters + filterLogic
     */
    public static String forStart(FlowMetadata.FlowStart el) {
        if (el == null) return '';
        return safe(el.object_x) + '|' + safe(el.triggerType)
            + '|' + safe(el.recordTriggerType)
            + '|' + serializeFilters(el.filters)
            + '|' + safe(el.filterLogic);
    }

    // =========================================================================
    // Resource Signatures
    // =========================================================================

    /**
     * Variable: name + dataType + isCollection + isInput + isOutput + objectType + defaultValue
     */
    public static String forVariable(FlowMetadata.FlowVariable v) {
        if (v == null) return '';
        return safe(v.name) + '|' + safe(v.dataType)
            + '|' + String.valueOf(v.isCollection)
            + '|' + String.valueOf(v.isInput)
            + '|' + String.valueOf(v.isOutput)
            + '|' + safe(v.objectType)
            + '|' + serializeValue(v.defaultValue);
    }

    /**
     * Formula: name + dataType + expression
     */
    public static String forFormula(FlowMetadata.FlowFormula f) {
        if (f == null) return '';
        return safe(f.name) + '|' + safe(f.dataType) + '|' + safe(f.expression);
    }

    /**
     * Constant: name + dataType + value
     */
    public static String forConstant(FlowMetadata.FlowConstant c) {
        if (c == null) return '';
        return safe(c.name) + '|' + safe(c.dataType) + '|' + serializeValue(c.value);
    }

    /**
     * TextTemplate: name + text + isViewedAsPlainText
     */
    public static String forTextTemplate(FlowMetadata.FlowTextTemplate t) {
        if (t == null) return '';
        return safe(t.name) + '|' + safe(t.text) + '|' + String.valueOf(t.isViewedAsPlainText);
    }

    /**
     * Choice: name + choiceText + dataType + value
     */
    public static String forChoice(FlowMetadata.FlowChoice ch) {
        if (ch == null) return '';
        return safe(ch.name) + '|' + safe(ch.choiceText) + '|' + safe(ch.dataType)
            + '|' + serializeValue(ch.value);
    }

    // =========================================================================
    // Configuration Signature
    // =========================================================================

    /**
     * Configuration fields are always functional — never cosmetic.
     * This method returns a signature for the full flow config.
     */
    public static String forConfiguration(FlowMetadata.FlowDefinition flow) {
        if (flow == null) return '';
        return safe(flow.processType) + '|' + safe(flow.apiVersion)
            + '|' + safe(flow.triggerType) + '|' + safe(flow.runInMode)
            + '|' + safe(flow.description) + '|' + safe(flow.label);
    }

    // =========================================================================
    // Serialization Helpers
    // =========================================================================

    private static String serializeValue(FlowMetadata.FlowValue v) {
        if (v == null) return '';
        if (v.elementReference != null) return 'ref:' + v.elementReference;
        if (v.stringValue != null) return 'str:' + v.stringValue;
        if (v.numberValue != null) return 'num:' + String.valueOf(v.numberValue);
        if (v.booleanValue != null) return 'bool:' + String.valueOf(v.booleanValue);
        return '';
    }

    private static String serializeConditions(List<FlowMetadata.FlowCondition> conditions) {
        if (conditions == null || conditions.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowCondition c : conditions) {
            parts.add(safe(c.leftValueReference) + ':' + safe(c.operator) + ':' + serializeValue(c.rightValue));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeFilters(List<FlowMetadata.FlowRecordFilter> filters) {
        if (filters == null || filters.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowRecordFilter f : filters) {
            parts.add(safe(f.field) + ':' + safe(f.operator) + ':' + serializeValue(f.value));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeInputAssignments(List<FlowMetadata.FlowInputAssignment> items) {
        if (items == null || items.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowInputAssignment ia : items) {
            parts.add(safe(ia.field) + ':' + serializeValue(ia.value));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeInputParams(List<FlowMetadata.FlowInputParameter> params) {
        if (params == null || params.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowInputParameter p : params) {
            parts.add(safe(p.name) + ':' + serializeValue(p.value));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeOutputParams(List<FlowMetadata.FlowOutputParameter> params) {
        if (params == null || params.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowOutputParameter p : params) {
            parts.add(safe(p.name) + ':' + safe(p.assignToReference));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeOutputAssignments(List<FlowMetadata.FlowOutputAssignment> items) {
        if (items == null || items.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowOutputAssignment oa : items) {
            parts.add(safe(oa.field) + ':' + safe(oa.assignToReference));
        }
        parts.sort();
        return String.join(parts, '~');
    }

    private static String serializeScreenFields(List<FlowMetadata.FlowScreenField> fields) {
        if (fields == null || fields.isEmpty()) return '';
        List<String> parts = new List<String>();
        for (FlowMetadata.FlowScreenField f : fields) {
            String fSig = safe(f.name) + ':' + safe(f.fieldType) + ':' + safe(f.fieldText)
                + ':' + safe(f.dataType) + ':' + String.valueOf(f.isRequired)
                + ':' + safe(f.defaultValue);
            // Recurse into nested fields (screen sections)
            if (f.fields != null && !f.fields.isEmpty()) {
                fSig += ':' + serializeScreenFields(f.fields);
            }
            parts.add(fSig);
        }
        // Screen fields are order-dependent (UI layout matters), so do NOT sort
        return String.join(parts, '~');
    }

    // =========================================================================
    // Utility
    // =========================================================================

    private static String safe(String val) {
        return val != null ? val : '';
    }
}
