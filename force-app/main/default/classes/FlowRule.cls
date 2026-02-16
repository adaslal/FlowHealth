/**
 * FlowRule - Interface that all health check rules must implement.
 *
 * DESIGN PATTERN: Strategy
 * Each rule is a separate class with its own detection logic.
 * The FlowRuleEngine discovers rules from Custom Metadata and
 * dynamically instantiates them using Type.forName().
 *
 * NOTE: FlowMetadata also has an inner class called FlowRule (for
 * Decision outcome rules). That's FlowMetadata.FlowRule — different
 * from this top-level interface.
 *
 * TO CREATE A NEW RULE:
 * 1. Create a class that implements FlowRule
 * 2. Implement the evaluate() method
 * 3. Add a Flow_Health_Rule__mdt record with Detection_Class__c = your class name
 * That's it — the engine picks it up automatically.
 */
public interface FlowRule {

    /**
     * Evaluates a flow against this rule and returns any findings.
     *
     * @param flow  The parsed flow metadata to analyze
     * @param ctx   Pre-computed analysis context (element map, loop bodies, etc.)
     * @return List<FlowFinding>  Zero or more findings (empty list = rule passed)
     */
    List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx);
}
