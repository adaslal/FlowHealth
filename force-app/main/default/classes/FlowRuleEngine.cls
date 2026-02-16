/**
 * FlowRuleEngine - Loads active rules from Custom Metadata and
 * dynamically executes them against a parsed flow definition.
 *
 * DESIGN PATTERN: Strategy + Factory
 * - Flow_Health_Rule__mdt records define WHICH rules to run
 * - Detection_Class__c names the Apex class that implements FlowRule
 * - Type.forName() dynamically instantiates each rule at runtime
 *
 * This means admins can toggle rules on/off from Setup → Custom Metadata
 * without any code deployment. New rules are automatically picked up
 * when their Custom Metadata record is created with Is_Active__c = true.
 *
 * FAULT TOLERANCE:
 * If a single rule class fails (missing class, runtime error, etc.),
 * the engine logs the error and continues with remaining rules. One
 * bad rule never kills the entire analysis.
 */
public class FlowRuleEngine {

    /**
     * Main entry point: run all active rules against a flow.
     *
     * @param flow  The parsed flow definition from the Tooling API
     * @return List<FlowFinding>  All findings from all rules, with weights applied
     */
    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow) {
        List<FlowFinding> allFindings = new List<FlowFinding>();

        // Build analysis context (pre-computes loop bodies, element map)
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        // Load active rules from Custom Metadata
        List<Flow_Health_Rule__mdt> activeRules = [
            SELECT Rule_Id__c, MasterLabel, Category__c, Severity__c,
                   Weight__c, Detection_Class__c, Description__c,
                   Remediation__c, Max_Deduction__c
            FROM Flow_Health_Rule__mdt
            WHERE Is_Active__c = true
            ORDER BY Rule_Id__c
        ];

        for (Flow_Health_Rule__mdt ruleMeta : activeRules) {
            try {
                // Dynamic instantiation via reflection
                Type ruleType = Type.forName(ruleMeta.Detection_Class__c);
                if (ruleType == null) {
                    System.debug(LoggingLevel.WARN,
                        'FlowRuleEngine: Class not found: ' + ruleMeta.Detection_Class__c +
                        ' (Rule: ' + ruleMeta.Rule_Id__c + ')');
                    continue;
                }

                FlowRule ruleInstance = (FlowRule) ruleType.newInstance();
                List<FlowFinding> findings = ruleInstance.evaluate(flow, ctx);

                // Apply weight from metadata (overrides any weight set by the rule)
                for (FlowFinding f : findings) {
                    if (ruleMeta.Weight__c != null) {
                        f.weight = (Integer) ruleMeta.Weight__c;
                    }
                }

                allFindings.addAll(findings);

            } catch (Exception e) {
                // One bad rule should never kill the whole analysis
                System.debug(LoggingLevel.ERROR,
                    'FlowRuleEngine: Rule ' + ruleMeta.Rule_Id__c + ' failed: ' +
                    e.getMessage() + '\n' + e.getStackTraceString());
            }
        }

        return allFindings;
    }
}
