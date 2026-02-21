/**
 * FlowXmlParser - Parses raw Salesforce Flow XML into FlowMetadata.FlowDefinition objects.
 *
 * PURPOSE:
 * This is the Privacy Mode bridge. It decouples the analysis engine from the
 * Tooling API by accepting raw XML (e.g., from a file upload or SFDX retrieve)
 * and producing the exact same FlowDefinition objects that FlowMetadataService
 * returns from the Tooling API.
 *
 * This means the entire downstream pipeline (FlowAnalysisContext → FlowRuleEngine
 * → FlowScoreCalculator) works identically regardless of input source.
 *
 * FLOW XML STRUCTURE (simplified):
 * <Flow xmlns="http://soap.sforce.com/2006/04/metadata">
 *   <apiVersion>62.0</apiVersion>
 *   <description>My flow description</description>
 *   <label>My Flow</label>
 *   <processType>AutoLaunchedFlow</processType>
 *   <status>Active</status>
 *   <recordCreates>
 *     <name>Create_Case</name>
 *     <label>Create Case</label>
 *     <object>Case</object>
 *     <connector><targetReference>Next_Element</targetReference></connector>
 *     ...
 *   </recordCreates>
 *   ...
 * </Flow>
 *
 * SPRINT 6A — Flow Health Analyzer
 */
public class FlowXmlParser {

    /**
     * Parses a raw Flow XML string into a FlowDefinition.
     *
     * @param xmlContent  The raw XML content of a .flow-meta.xml file
     * @return FlowMetadata.FlowDefinition  The parsed flow definition
     * @throws FlowMetadataService.FlowHealthException  If XML is invalid
     */
    public static FlowMetadata.FlowDefinition parse(String xmlContent) {
        if (String.isBlank(xmlContent)) {
            throw new FlowMetadataService.FlowHealthException('Flow XML content cannot be blank.');
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlContent);
            Dom.XmlNode root = doc.getRootElement();

            if (root == null) {
                throw new FlowMetadataService.FlowHealthException('Invalid Flow XML: no root element found.');
            }

            return parseFlowDefinition(root);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw e;
        } catch (Exception e) {
            throw new FlowMetadataService.FlowHealthException('Failed to parse Flow XML: ' + e.getMessage());
        }
    }

    // =========================================================================
    // FLOW DEFINITION PARSER
    // =========================================================================

    private static FlowMetadata.FlowDefinition parseFlowDefinition(Dom.XmlNode root) {
        String ns = root.getNamespace();
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();

        // Scalar properties
        flow.apiVersion    = getChildText(root, 'apiVersion', ns);
        flow.description   = getChildText(root, 'description', ns);
        flow.label         = getChildText(root, 'label', ns);
        flow.processType   = getChildText(root, 'processType', ns);
        flow.status        = getChildText(root, 'status', ns);
        flow.runInMode     = getChildText(root, 'runInMode', ns);
        flow.triggerType   = getChildText(root, 'triggerType', ns);

        // Element arrays
        flow.actionCalls   = new List<FlowMetadata.FlowActionCall>();
        flow.assignments   = new List<FlowMetadata.FlowAssignment>();
        flow.decisions     = new List<FlowMetadata.FlowDecision>();
        flow.loops         = new List<FlowMetadata.FlowLoop>();
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>();
        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>();
        flow.recordDeletes = new List<FlowMetadata.FlowRecordDelete>();
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>();
        flow.screens       = new List<FlowMetadata.FlowScreen>();
        flow.subflows      = new List<FlowMetadata.FlowSubflow>();
        flow.waits         = new List<FlowMetadata.FlowWait>();

        // Variables and resources
        flow.variables     = new List<FlowMetadata.FlowVariable>();
        flow.formulas      = new List<FlowMetadata.FlowFormula>();
        flow.constants     = new List<FlowMetadata.FlowConstant>();
        flow.textTemplates = new List<FlowMetadata.FlowTextTemplate>();
        flow.choices       = new List<FlowMetadata.FlowChoice>();

        // Iterate all child nodes and route by element name
        for (Dom.XmlNode child : root.getChildElements()) {
            String nodeName = child.getName();

            if (nodeName == 'start')              { flow.start = parseStart(child, ns); }
            else if (nodeName == 'actionCalls')    { flow.actionCalls.add(parseActionCall(child, ns)); }
            else if (nodeName == 'assignments')    { flow.assignments.add(parseAssignment(child, ns)); }
            else if (nodeName == 'decisions')      { flow.decisions.add(parseDecision(child, ns)); }
            else if (nodeName == 'loops')          { flow.loops.add(parseLoop(child, ns)); }
            else if (nodeName == 'recordCreates')  { flow.recordCreates.add(parseRecordCreate(child, ns)); }
            else if (nodeName == 'recordUpdates')  { flow.recordUpdates.add(parseRecordUpdate(child, ns)); }
            else if (nodeName == 'recordDeletes')  { flow.recordDeletes.add(parseRecordDelete(child, ns)); }
            else if (nodeName == 'recordLookups')  { flow.recordLookups.add(parseRecordLookup(child, ns)); }
            else if (nodeName == 'screens')        { flow.screens.add(parseScreen(child, ns)); }
            else if (nodeName == 'subflows')       { flow.subflows.add(parseSubflow(child, ns)); }
            else if (nodeName == 'waits')          { flow.waits.add(parseWait(child, ns)); }
            else if (nodeName == 'variables')      { flow.variables.add(parseVariable(child, ns)); }
            else if (nodeName == 'formulas')       { flow.formulas.add(parseFormula(child, ns)); }
            else if (nodeName == 'constants')      { flow.constants.add(parseConstant(child, ns)); }
            else if (nodeName == 'textTemplates')  { flow.textTemplates.add(parseTextTemplate(child, ns)); }
            else if (nodeName == 'choices')        { flow.choices.add(parseChoice(child, ns)); }
            // Unknown element types are silently ignored (forward-compatible)
        }

        return flow;
    }

    // =========================================================================
    // START ELEMENT
    // =========================================================================

    private static FlowMetadata.FlowStart parseStart(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowStart s = new FlowMetadata.FlowStart();
        s.locationX          = getChildText(node, 'locationX', ns);
        s.locationY          = getChildText(node, 'locationY', ns);
        s.connector          = parseConnector(node, 'connector', ns);
        s.scheduledConnector = parseConnector(node, 'scheduledConnector', ns);
        s.object_x           = getChildText(node, 'object', ns);
        s.triggerType        = getChildText(node, 'triggerType', ns);
        s.recordTriggerType  = getChildText(node, 'recordTriggerType', ns);
        s.filterLogic        = getChildText(node, 'filterLogic', ns);
        s.filters            = parseRecordFilters(node, ns);
        return s;
    }

    // =========================================================================
    // ELEMENT PARSERS
    // =========================================================================

    private static FlowMetadata.FlowActionCall parseActionCall(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowActionCall el = new FlowMetadata.FlowActionCall();
        parseBaseElement(el, node, ns);
        el.actionName                = getChildText(node, 'actionName', ns);
        el.actionType                = getChildText(node, 'actionType', ns);
        el.storeOutputAutomatically  = getBooleanChild(node, 'storeOutputAutomatically', ns);
        el.flowTransactionModel      = getChildText(node, 'flowTransactionModel', ns);
        el.inputParameters           = parseInputParameters(node, ns);
        el.outputParameters          = parseOutputParameters(node, ns);
        return el;
    }

    private static FlowMetadata.FlowAssignment parseAssignment(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowAssignment el = new FlowMetadata.FlowAssignment();
        parseBaseElement(el, node, ns);
        el.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>();
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'assignmentItems') {
                FlowMetadata.FlowAssignmentItem item = new FlowMetadata.FlowAssignmentItem();
                item.assignToReference = getChildText(child, 'assignToReference', ns);
                item.operator          = getChildText(child, 'operator', ns);
                item.value             = parseValue(child, ns);
                el.assignmentItems.add(item);
            }
        }
        return el;
    }

    private static FlowMetadata.FlowDecision parseDecision(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowDecision el = new FlowMetadata.FlowDecision();
        parseBaseElement(el, node, ns);
        el.defaultConnector      = parseConnector(node, 'defaultConnector', ns);
        el.defaultConnectorLabel = getChildText(node, 'defaultConnectorLabel', ns);
        el.rules = new List<FlowMetadata.FlowRule>();
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'rules') {
                el.rules.add(parseRule(child, ns));
            }
        }
        return el;
    }

    private static FlowMetadata.FlowLoop parseLoop(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowLoop el = new FlowMetadata.FlowLoop();
        parseBaseElement(el, node, ns);
        el.collectionReference        = getChildText(node, 'collectionReference', ns);
        el.iterationOrder             = getChildText(node, 'iterationOrder', ns);
        el.nextValueConnector         = parseConnector(node, 'nextValueConnector', ns);
        el.noMoreValuesConnector      = parseConnector(node, 'noMoreValuesConnector', ns);
        el.assignNextValueToReference = getChildText(node, 'assignNextValueToReference', ns);
        return el;
    }

    private static FlowMetadata.FlowRecordCreate parseRecordCreate(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowRecordCreate el = new FlowMetadata.FlowRecordCreate();
        parseBaseElement(el, node, ns);
        el.object_x                   = getChildText(node, 'object', ns);
        el.inputReference             = getChildText(node, 'inputReference', ns);
        el.assignRecordIdToReference  = getChildText(node, 'assignRecordIdToReference', ns);
        el.storeOutputAutomatically   = getBooleanChild(node, 'storeOutputAutomatically', ns);
        el.inputAssignments           = parseInputAssignments(node, ns);
        return el;
    }

    private static FlowMetadata.FlowRecordUpdate parseRecordUpdate(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowRecordUpdate el = new FlowMetadata.FlowRecordUpdate();
        parseBaseElement(el, node, ns);
        el.object_x          = getChildText(node, 'object', ns);
        el.inputReference    = getChildText(node, 'inputReference', ns);
        el.filterLogic       = getChildText(node, 'filterLogic', ns);
        el.inputAssignments  = parseInputAssignments(node, ns);
        el.filters           = parseRecordFilters(node, ns);
        return el;
    }

    private static FlowMetadata.FlowRecordDelete parseRecordDelete(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowRecordDelete el = new FlowMetadata.FlowRecordDelete();
        parseBaseElement(el, node, ns);
        el.object_x       = getChildText(node, 'object', ns);
        el.inputReference  = getChildText(node, 'inputReference', ns);
        el.filterLogic     = getChildText(node, 'filterLogic', ns);
        el.filters         = parseRecordFilters(node, ns);
        return el;
    }

    private static FlowMetadata.FlowRecordLookup parseRecordLookup(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowRecordLookup el = new FlowMetadata.FlowRecordLookup();
        parseBaseElement(el, node, ns);
        el.object_x                  = getChildText(node, 'object', ns);
        el.outputReference           = getChildText(node, 'outputReference', ns);
        el.getFirstRecordOnly        = getBooleanChild(node, 'getFirstRecordOnly', ns);
        el.storeOutputAutomatically  = getBooleanChild(node, 'storeOutputAutomatically', ns);
        el.sortField                 = getChildText(node, 'sortField', ns);
        el.sortOrder                 = getChildText(node, 'sortOrder', ns);
        el.filterLogic               = getChildText(node, 'filterLogic', ns);
        el.filters                   = parseRecordFilters(node, ns);
        el.outputAssignments         = parseOutputAssignments(node, ns);
        return el;
    }

    private static FlowMetadata.FlowScreen parseScreen(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowScreen el = new FlowMetadata.FlowScreen();
        parseBaseElement(el, node, ns);
        el.allowBack   = getBooleanChild(node, 'allowBack', ns);
        el.allowFinish = getBooleanChild(node, 'allowFinish', ns);
        el.allowPause  = getBooleanChild(node, 'allowPause', ns);
        el.showHeader  = getBooleanChild(node, 'showHeader', ns);
        el.showFooter  = getBooleanChild(node, 'showFooter', ns);
        el.fields      = parseScreenFields(node, ns);
        return el;
    }

    private static FlowMetadata.FlowSubflow parseSubflow(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowSubflow el = new FlowMetadata.FlowSubflow();
        parseBaseElement(el, node, ns);
        el.flowName = getChildText(node, 'flowName', ns);
        el.inputAssignments  = parseInputParameters(node, ns);
        el.outputAssignments = parseOutputParameters(node, ns);
        return el;
    }

    private static FlowMetadata.FlowWait parseWait(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowWait el = new FlowMetadata.FlowWait();
        parseBaseElement(el, node, ns);
        el.defaultConnector      = parseConnector(node, 'defaultConnector', ns);
        el.defaultConnectorLabel = getChildText(node, 'defaultConnectorLabel', ns);
        el.waitEvents = new List<FlowMetadata.FlowWaitEvent>();
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'waitEvents') {
                FlowMetadata.FlowWaitEvent evt = new FlowMetadata.FlowWaitEvent();
                evt.name           = getChildText(child, 'name', ns);
                evt.label          = getChildText(child, 'label', ns);
                evt.eventType      = getChildText(child, 'eventType', ns);
                evt.connector      = parseConnector(child, 'connector', ns);
                evt.conditionLogic = getChildText(child, 'conditionLogic', ns);
                evt.conditions     = parseConditions(child, ns);
                el.waitEvents.add(evt);
            }
        }
        return el;
    }

    // =========================================================================
    // RESOURCE PARSERS (Variables, Formulas, Constants, etc.)
    // =========================================================================

    private static FlowMetadata.FlowVariable parseVariable(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowVariable v = new FlowMetadata.FlowVariable();
        v.name         = getChildText(node, 'name', ns);
        v.description  = getChildText(node, 'description', ns);
        v.dataType     = getChildText(node, 'dataType', ns);
        v.isCollection = getBooleanChild(node, 'isCollection', ns);
        v.isInput      = getBooleanChild(node, 'isInput', ns);
        v.isOutput     = getBooleanChild(node, 'isOutput', ns);
        v.objectType   = getChildText(node, 'objectType', ns);
        v.defaultValue = parseValue(node, ns);
        return v;
    }

    private static FlowMetadata.FlowFormula parseFormula(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowFormula f = new FlowMetadata.FlowFormula();
        f.name        = getChildText(node, 'name', ns);
        f.description = getChildText(node, 'description', ns);
        f.dataType    = getChildText(node, 'dataType', ns);
        f.expression  = getChildText(node, 'expression', ns);
        return f;
    }

    private static FlowMetadata.FlowConstant parseConstant(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowConstant c = new FlowMetadata.FlowConstant();
        c.name        = getChildText(node, 'name', ns);
        c.description = getChildText(node, 'description', ns);
        c.dataType    = getChildText(node, 'dataType', ns);
        c.value       = parseValue(node, ns);
        return c;
    }

    private static FlowMetadata.FlowTextTemplate parseTextTemplate(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowTextTemplate t = new FlowMetadata.FlowTextTemplate();
        t.name                = getChildText(node, 'name', ns);
        t.description         = getChildText(node, 'description', ns);
        t.text                = getChildText(node, 'text', ns);
        t.isViewedAsPlainText = getBooleanChild(node, 'isViewedAsPlainText', ns);
        return t;
    }

    private static FlowMetadata.FlowChoice parseChoice(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowChoice ch = new FlowMetadata.FlowChoice();
        ch.name       = getChildText(node, 'name', ns);
        ch.choiceText = getChildText(node, 'choiceText', ns);
        ch.dataType   = getChildText(node, 'dataType', ns);
        ch.value      = parseValue(node, ns);
        return ch;
    }

    // =========================================================================
    // SHARED SUB-STRUCTURE PARSERS
    // =========================================================================

    private static void parseBaseElement(FlowMetadata.FlowElement el, Dom.XmlNode node, String ns) {
        el.name           = getChildText(node, 'name', ns);
        el.label          = getChildText(node, 'label', ns);
        el.description    = getChildText(node, 'description', ns);
        el.locationX      = getChildText(node, 'locationX', ns);
        el.locationY      = getChildText(node, 'locationY', ns);
        el.connector      = parseConnector(node, 'connector', ns);
        el.faultConnector = parseConnector(node, 'faultConnector', ns);
    }

    private static FlowMetadata.FlowConnector parseConnector(Dom.XmlNode parent, String childName, String ns) {
        Dom.XmlNode connNode = parent.getChildElement(childName, ns);
        if (connNode == null) return null;
        FlowMetadata.FlowConnector conn = new FlowMetadata.FlowConnector();
        conn.targetReference = getChildText(connNode, 'targetReference', ns);
        return conn;
    }

    private static FlowMetadata.FlowRule parseRule(Dom.XmlNode node, String ns) {
        FlowMetadata.FlowRule r = new FlowMetadata.FlowRule();
        r.name           = getChildText(node, 'name', ns);
        r.label          = getChildText(node, 'label', ns);
        r.conditionLogic = getChildText(node, 'conditionLogic', ns);
        r.connector      = parseConnector(node, 'connector', ns);
        r.conditions     = parseConditions(node, ns);
        return r;
    }

    private static List<FlowMetadata.FlowCondition> parseConditions(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowCondition> conditions = new List<FlowMetadata.FlowCondition>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'conditions') {
                FlowMetadata.FlowCondition c = new FlowMetadata.FlowCondition();
                c.leftValueReference = getChildText(child, 'leftValueReference', ns);
                c.operator           = getChildText(child, 'operator', ns);
                c.rightValue         = parseValue(child, ns);
                conditions.add(c);
            }
        }
        return conditions;
    }

    private static FlowMetadata.FlowValue parseValue(Dom.XmlNode parent, String ns) {
        Dom.XmlNode valNode = parent.getChildElement('value', ns);
        if (valNode == null) {
            // Also check 'rightValue' for conditions
            valNode = parent.getChildElement('rightValue', ns);
        }
        if (valNode == null) return null;

        FlowMetadata.FlowValue v = new FlowMetadata.FlowValue();
        v.stringValue      = getChildText(valNode, 'stringValue', ns);
        v.elementReference  = getChildText(valNode, 'elementReference', ns);

        String numStr = getChildText(valNode, 'numberValue', ns);
        if (numStr != null) {
            try { v.numberValue = Decimal.valueOf(numStr); } catch (Exception e) { /* ignore */ }
        }

        String boolStr = getChildText(valNode, 'booleanValue', ns);
        if (boolStr != null) {
            v.booleanValue = Boolean.valueOf(boolStr);
        }

        return v;
    }

    private static List<FlowMetadata.FlowRecordFilter> parseRecordFilters(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowRecordFilter> filters = new List<FlowMetadata.FlowRecordFilter>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'filters') {
                FlowMetadata.FlowRecordFilter f = new FlowMetadata.FlowRecordFilter();
                f.field    = getChildText(child, 'field', ns);
                f.operator = getChildText(child, 'operator', ns);
                f.value    = parseValue(child, ns);
                filters.add(f);
            }
        }
        return filters;
    }

    private static List<FlowMetadata.FlowInputAssignment> parseInputAssignments(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowInputAssignment> items = new List<FlowMetadata.FlowInputAssignment>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'inputAssignments') {
                FlowMetadata.FlowInputAssignment item = new FlowMetadata.FlowInputAssignment();
                item.field = getChildText(child, 'field', ns);
                item.value = parseValue(child, ns);
                items.add(item);
            }
        }
        return items;
    }

    private static List<FlowMetadata.FlowInputParameter> parseInputParameters(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowInputParameter> items = new List<FlowMetadata.FlowInputParameter>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'inputParameters' || child.getName() == 'inputAssignments') {
                FlowMetadata.FlowInputParameter item = new FlowMetadata.FlowInputParameter();
                item.name  = getChildText(child, 'name', ns);
                item.value = parseValue(child, ns);
                items.add(item);
            }
        }
        return items;
    }

    private static List<FlowMetadata.FlowOutputParameter> parseOutputParameters(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowOutputParameter> items = new List<FlowMetadata.FlowOutputParameter>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'outputParameters' || child.getName() == 'outputAssignments') {
                FlowMetadata.FlowOutputParameter item = new FlowMetadata.FlowOutputParameter();
                item.name              = getChildText(child, 'name', ns);
                item.assignToReference = getChildText(child, 'assignToReference', ns);
                items.add(item);
            }
        }
        return items;
    }

    private static List<FlowMetadata.FlowOutputAssignment> parseOutputAssignments(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowOutputAssignment> items = new List<FlowMetadata.FlowOutputAssignment>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'outputAssignments') {
                FlowMetadata.FlowOutputAssignment item = new FlowMetadata.FlowOutputAssignment();
                item.field             = getChildText(child, 'field', ns);
                item.assignToReference = getChildText(child, 'assignToReference', ns);
                items.add(item);
            }
        }
        return items;
    }

    private static List<FlowMetadata.FlowScreenField> parseScreenFields(Dom.XmlNode parent, String ns) {
        List<FlowMetadata.FlowScreenField> fields = new List<FlowMetadata.FlowScreenField>();
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (child.getName() == 'fields') {
                FlowMetadata.FlowScreenField f = new FlowMetadata.FlowScreenField();
                f.name         = getChildText(child, 'name', ns);
                f.fieldType    = getChildText(child, 'fieldType', ns);
                f.fieldText    = getChildText(child, 'fieldText', ns);
                f.dataType     = getChildText(child, 'dataType', ns);
                f.isRequired   = getBooleanChild(child, 'isRequired', ns);
                f.defaultValue = getChildText(child, 'defaultValue', ns);
                // Recurse for nested fields (sections)
                f.fields       = parseScreenFields(child, ns);
                fields.add(f);
            }
        }
        return fields;
    }

    // =========================================================================
    // XML UTILITY HELPERS
    // =========================================================================

    private static String getChildText(Dom.XmlNode parent, String childName, String ns) {
        Dom.XmlNode child = parent.getChildElement(childName, ns);
        return child != null ? child.getText() : null;
    }

    private static Boolean getBooleanChild(Dom.XmlNode parent, String childName, String ns) {
        String val = getChildText(parent, childName, ns);
        return val != null ? Boolean.valueOf(val) : null;
    }
}
