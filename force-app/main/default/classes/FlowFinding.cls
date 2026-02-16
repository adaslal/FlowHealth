/**
 * FlowFinding - Represents a single health check violation found in a flow.
 *
 * Created by rule classes when they detect an issue.
 * Carried through the scoring engine and displayed in the UI.
 */
public class FlowFinding {

    @AuraEnabled public String ruleId;           // e.g., 'PERF-001'
    @AuraEnabled public String ruleName;         // e.g., 'DML Inside Loop'
    @AuraEnabled public String category;         // e.g., 'Performance'
    @AuraEnabled public String severity;         // Critical, High, Medium, Low
    @AuraEnabled public String elementName;      // API name of the offending element
    @AuraEnabled public String elementType;      // e.g., 'recordCreate', 'loop'
    @AuraEnabled public String description;      // What was found
    @AuraEnabled public String remediation;      // How to fix it
    @AuraEnabled public Integer weight;          // Score deduction weight

    /**
     * Builder-style constructor for clean rule class code.
     */
    public FlowFinding(String ruleId, String ruleName, String category, String severity) {
        this.ruleId = ruleId;
        this.ruleName = ruleName;
        this.category = category;
        this.severity = severity;
    }

    public FlowFinding withElement(String name, String elementType) {
        this.elementName = name;
        this.elementType = elementType;
        return this;
    }

    public FlowFinding withDescription(String description) {
        this.description = description;
        return this;
    }

    public FlowFinding withRemediation(String remediation) {
        this.remediation = remediation;
        return this;
    }

    public FlowFinding withWeight(Integer weight) {
        this.weight = weight;
        return this;
    }
}
