/**
 * CustomRuleEvaluator - Evaluates user-defined declarative rules.
 *
 * This class implements the FlowRule interface so it integrates seamlessly
 * with the existing rule engine. However, instead of hardcoded detection logic,
 * it reads rule definitions from the Flow_Health_Custom_Rule__c custom object
 * and evaluates them dynamically.
 *
 * SUPPORTED RULE TYPES:
 *
 * 1. Element Count Threshold
 *    "Flag if the number of [Target Element Type] exceeds [Threshold Value]"
 *    Example: "Flag if more than 10 Record Lookups" → Performance concern
 *
 * 2. Element Name Pattern
 *    "Flag elements whose names match [Name Pattern] regex"
 *    Example: "Flag names starting with 'myRule_'" → Auto-generated naming
 *
 * 3. Flow Property Check
 *    "Flag if [Flow Property] does NOT equal [Expected Value]"
 *    Example: "Flag if Run Mode ≠ SystemModeWithSharing" → Security policy
 *
 * 4. Element In Loop Check
 *    "Flag if [Target Element Type] elements are inside loops"
 *    Example: "Flag if Screens are inside loops" → UX anti-pattern
 *
 * 5. Missing Fault Path Check
 *    "Flag [Target Element Type] elements without fault connectors"
 *    Example: "Flag Action Calls without fault paths" → Error handling
 *
 * WHY A CUSTOM OBJECT (not Custom Metadata)?
 * Custom Metadata requires a metadata deployment to create/update records,
 * which needs API access and is complex for non-developer admins. A custom
 * object allows admins to create rules via the standard Salesforce UI —
 * just create a record, fill in fields, and the rule is live immediately.
 */
public class CustomRuleEvaluator implements FlowRule {

    // Cache custom rules to avoid re-querying per analysis
    private static List<Flow_Health_Custom_Rule__c> cachedRules;

    /**
     * Main evaluation method — loads all active custom rules and evaluates each.
     */
    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        List<Flow_Health_Custom_Rule__c> rules = getActiveRules();
        if (rules.isEmpty()) return findings;

        for (Flow_Health_Custom_Rule__c rule : rules) {
            try {
                List<FlowFinding> ruleFindings = evaluateSingleRule(rule, flow, ctx);
                findings.addAll(ruleFindings);
            } catch (Exception e) {
                // Fault tolerance: one bad custom rule shouldn't kill the engine
                System.debug(LoggingLevel.WARN,
                    'Custom rule "' + rule.Name + '" failed: ' + e.getMessage());
            }
        }

        return findings;
    }

    /**
     * Evaluates a single custom rule against the flow.
     */
    private List<FlowFinding> evaluateSingleRule(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow,
        FlowAnalysisContext ctx
    ) {
        String ruleType = rule.Rule_Type__c;

        if (ruleType == 'Element Count Threshold') {
            return evaluateCountThreshold(rule, flow);
        } else if (ruleType == 'Element Name Pattern') {
            return evaluateNamePattern(rule, flow);
        } else if (ruleType == 'Flow Property Check') {
            return evaluateFlowProperty(rule, flow);
        } else if (ruleType == 'Element In Loop Check') {
            return evaluateElementInLoop(rule, flow, ctx);
        } else if (ruleType == 'Missing Fault Path Check') {
            return evaluateMissingFaultPath(rule, flow);
        }

        return new List<FlowFinding>();
    }

    // =========================================================================
    // RULE TYPE 1: Element Count Threshold
    // =========================================================================

    private List<FlowFinding> evaluateCountThreshold(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow
    ) {
        List<FlowFinding> findings = new List<FlowFinding>();
        if (rule.Threshold_Value__c == null) return findings;

        Integer threshold = (Integer) rule.Threshold_Value__c;
        Integer count = getElementCount(flow, rule.Target_Element_Type__c);

        if (count > threshold) {
            findings.add(buildFinding(rule)
                .withDescription(
                    rule.Name + ': Found ' + count + ' ' +
                    (rule.Target_Element_Type__c != null ? rule.Target_Element_Type__c : 'elements') +
                    ' (threshold: ' + threshold + '). ' +
                    (rule.Description__c != null ? rule.Description__c : '')
                )
            );
        }
        return findings;
    }

    private Integer getElementCount(FlowMetadata.FlowDefinition flow, String elementType) {
        if (elementType == null || elementType == 'All Elements') {
            return flow.getAllElements().size();
        }
        switch on elementType {
            when 'Record Creates' { return flow.recordCreates != null ? flow.recordCreates.size() : 0; }
            when 'Record Updates' { return flow.recordUpdates != null ? flow.recordUpdates.size() : 0; }
            when 'Record Deletes' { return flow.recordDeletes != null ? flow.recordDeletes.size() : 0; }
            when 'Record Lookups' { return flow.recordLookups != null ? flow.recordLookups.size() : 0; }
            when 'Loops' { return flow.loops != null ? flow.loops.size() : 0; }
            when 'Decisions' { return flow.decisions != null ? flow.decisions.size() : 0; }
            when 'Assignments' { return flow.assignments != null ? flow.assignments.size() : 0; }
            when 'Screens' { return flow.screens != null ? flow.screens.size() : 0; }
            when 'Action Calls' { return flow.actionCalls != null ? flow.actionCalls.size() : 0; }
            when 'Subflows' { return flow.subflows != null ? flow.subflows.size() : 0; }
            when else { return flow.getAllElements().size(); }
        }
    }

    // =========================================================================
    // RULE TYPE 2: Element Name Pattern
    // =========================================================================

    private List<FlowFinding> evaluateNamePattern(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow
    ) {
        List<FlowFinding> findings = new List<FlowFinding>();
        if (String.isBlank(rule.Name_Pattern__c)) return findings;

        Pattern namePattern;
        try {
            namePattern = Pattern.compile(rule.Name_Pattern__c);
        } catch (Exception e) {
            return findings; // Invalid regex, skip
        }

        List<FlowMetadata.FlowElement> elements = getTargetElements(flow, rule.Target_Element_Type__c);

        for (FlowMetadata.FlowElement el : elements) {
            if (el.name != null && namePattern.matcher(el.name).find()) {
                String displayName = el.label != null ? el.label : el.name;
                findings.add(buildFinding(rule)
                    .withElement(el.name, rule.Target_Element_Type__c != null ? rule.Target_Element_Type__c : 'Element')
                    .withDescription(
                        'Element "' + displayName + '" matches pattern "' +
                        rule.Name_Pattern__c + '". ' +
                        (rule.Description__c != null ? rule.Description__c : '')
                    )
                );
            }
        }
        return findings;
    }

    // =========================================================================
    // RULE TYPE 3: Flow Property Check
    // =========================================================================

    private List<FlowFinding> evaluateFlowProperty(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow
    ) {
        List<FlowFinding> findings = new List<FlowFinding>();
        if (String.isBlank(rule.Flow_Property__c)) return findings;

        String actualValue = getFlowPropertyValue(flow, rule.Flow_Property__c);
        String expectedValue = rule.Expected_Value__c;

        Boolean violated = false;
        if (rule.Flow_Property__c == 'Has Description') {
            // Special case: check for presence
            violated = String.isBlank(flow.description);
        } else if (expectedValue != null && actualValue != null) {
            violated = !actualValue.equalsIgnoreCase(expectedValue);
        } else if (expectedValue != null && actualValue == null) {
            violated = true;
        }

        if (violated) {
            String flowLabel = flow.label != null ? flow.label : 'This flow';
            findings.add(buildFinding(rule)
                .withDescription(
                    flowLabel + ': ' + rule.Flow_Property__c + ' is "' +
                    (actualValue != null ? actualValue : 'not set') + '"' +
                    (expectedValue != null ? ' (expected: "' + expectedValue + '")' : '') + '. ' +
                    (rule.Description__c != null ? rule.Description__c : '')
                )
            );
        }
        return findings;
    }

    private String getFlowPropertyValue(FlowMetadata.FlowDefinition flow, String property) {
        switch on property {
            when 'Has Description' { return flow.description; }
            when 'Process Type' { return flow.processType; }
            when 'Run Mode' { return flow.runInMode; }
            when 'Trigger Type' { return flow.triggerType; }
            when 'API Version' { return flow.apiVersion; }
            when else { return null; }
        }
    }

    // =========================================================================
    // RULE TYPE 4: Element In Loop Check
    // =========================================================================

    private List<FlowFinding> evaluateElementInLoop(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow,
        FlowAnalysisContext ctx
    ) {
        List<FlowFinding> findings = new List<FlowFinding>();
        List<FlowMetadata.FlowElement> elements = getTargetElements(flow, rule.Target_Element_Type__c);

        for (FlowMetadata.FlowElement el : elements) {
            if (el.name != null && ctx.isInsideLoop(el.name)) {
                String displayName = el.label != null ? el.label : el.name;
                List<String> loops = ctx.getContainingLoops(el.name);
                String loopNames = String.join(loops, ', ');

                findings.add(buildFinding(rule)
                    .withElement(el.name, rule.Target_Element_Type__c != null ? rule.Target_Element_Type__c : 'Element')
                    .withDescription(
                        'Element "' + displayName + '" is inside loop "' + loopNames + '". ' +
                        (rule.Description__c != null ? rule.Description__c : '')
                    )
                );
            }
        }
        return findings;
    }

    // =========================================================================
    // RULE TYPE 5: Missing Fault Path Check
    // =========================================================================

    private List<FlowFinding> evaluateMissingFaultPath(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow
    ) {
        List<FlowFinding> findings = new List<FlowFinding>();
        List<FlowMetadata.FlowElement> elements = getTargetElements(flow, rule.Target_Element_Type__c);

        for (FlowMetadata.FlowElement el : elements) {
            if (el.faultConnector == null) {
                String displayName = el.label != null ? el.label : el.name;
                findings.add(buildFinding(rule)
                    .withElement(el.name, rule.Target_Element_Type__c != null ? rule.Target_Element_Type__c : 'Element')
                    .withDescription(
                        'Element "' + displayName + '" has no fault path. ' +
                        (rule.Description__c != null ? rule.Description__c : '')
                    )
                );
            }
        }
        return findings;
    }

    // =========================================================================
    // SHARED HELPERS
    // =========================================================================

    private List<FlowMetadata.FlowElement> getTargetElements(
        FlowMetadata.FlowDefinition flow, String elementType
    ) {
        if (elementType == null || elementType == 'All Elements') {
            return flow.getAllElements();
        }
        List<FlowMetadata.FlowElement> result = new List<FlowMetadata.FlowElement>();
        switch on elementType {
            when 'Record Creates' { if (flow.recordCreates != null) result.addAll(flow.recordCreates); }
            when 'Record Updates' { if (flow.recordUpdates != null) result.addAll(flow.recordUpdates); }
            when 'Record Deletes' { if (flow.recordDeletes != null) result.addAll(flow.recordDeletes); }
            when 'Record Lookups' { if (flow.recordLookups != null) result.addAll(flow.recordLookups); }
            when 'Loops' { if (flow.loops != null) result.addAll(flow.loops); }
            when 'Decisions' { if (flow.decisions != null) result.addAll(flow.decisions); }
            when 'Assignments' { if (flow.assignments != null) result.addAll(flow.assignments); }
            when 'Screens' { if (flow.screens != null) result.addAll(flow.screens); }
            when 'Action Calls' { if (flow.actionCalls != null) result.addAll(flow.actionCalls); }
            when 'Subflows' { if (flow.subflows != null) result.addAll(flow.subflows); }
            when else { return flow.getAllElements(); }
        }
        return result;
    }

    private FlowFinding buildFinding(Flow_Health_Custom_Rule__c rule) {
        return new FlowFinding(
            rule.Rule_Id__c,
            rule.Name,
            rule.Category__c != null ? rule.Category__c : 'Design',
            rule.Severity__c != null ? rule.Severity__c : 'Medium'
        ).withRemediation(
            rule.Remediation__c != null ? rule.Remediation__c : 'Review and address this custom rule finding.'
        ).withWeight(
            rule.Weight__c != null ? (Integer) rule.Weight__c : 5
        );
    }

    private List<Flow_Health_Custom_Rule__c> getActiveRules() {
        if (cachedRules != null) return cachedRules;

        cachedRules = [
            SELECT Id, Name, Rule_Id__c, Category__c, Severity__c, Weight__c,
                   Is_Active__c, Description__c, Remediation__c,
                   Rule_Type__c, Target_Element_Type__c, Threshold_Value__c,
                   Name_Pattern__c, Flow_Property__c, Expected_Value__c
            FROM Flow_Health_Custom_Rule__c
            WHERE Is_Active__c = true
            ORDER BY Rule_Id__c ASC
        ];
        return cachedRules;
    }

    /**
     * Tests a single rule against a flow without saving the rule.
     * Used by the "Test Rule" button in the custom rule builder.
     *
     * @param rule  An in-memory (unsaved) Flow_Health_Custom_Rule__c
     * @param flow  The flow definition to test against
     * @param ctx   The pre-computed analysis context
     * @return List of findings from this single rule
     */
    public static List<FlowFinding> testRule(
        Flow_Health_Custom_Rule__c rule,
        FlowMetadata.FlowDefinition flow,
        FlowAnalysisContext ctx
    ) {
        CustomRuleEvaluator evaluator = new CustomRuleEvaluator();
        return evaluator.evaluateSingleRule(rule, flow, ctx);
    }

    /**
     * Clears the rule cache (call after creating/updating custom rules).
     */
    public static void clearCache() {
        cachedRules = null;
    }
}
