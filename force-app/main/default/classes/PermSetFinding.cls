/**
 * PermSetFinding - Data class for a single permission set analysis finding.
 *
 * Similar to FlowFinding but tailored for permission set analysis.
 * Uses a fluent builder pattern for clean rule implementations.
 *
 * Each finding can optionally carry a "purifyAction" which tells the
 * PermSetPurifyService what to do during transformation:
 *   - 'REMOVE'     — Remove this permission entry entirely
 *   - 'DOWNGRADE'  — Reduce permission level (e.g., edit → read-only)
 *   - 'FLAG'       — Just flag it, don't transform (informational)
 */
public class PermSetFinding {

    @AuraEnabled public String ruleId;
    @AuraEnabled public String ruleName;
    @AuraEnabled public String category;       // Security, Hygiene, Compliance, Design
    @AuraEnabled public String severity;       // Critical, High, Medium, Low
    @AuraEnabled public Integer weight;
    @AuraEnabled public String itemType;       // objectPermission, fieldPermission, userPermission, etc.
    @AuraEnabled public String itemName;       // API name of the specific item
    @AuraEnabled public String description;
    @AuraEnabled public String remediation;
    @AuraEnabled public String purifyAction;   // REMOVE, DOWNGRADE, FLAG

    public PermSetFinding() {}

    // =========================================================================
    // Fluent builder
    // =========================================================================

    public PermSetFinding withRule(String ruleId, String ruleName) {
        this.ruleId = ruleId;
        this.ruleName = ruleName;
        return this;
    }

    public PermSetFinding withCategory(String category) {
        this.category = category;
        return this;
    }

    public PermSetFinding withSeverity(String severity) {
        this.severity = severity;
        return this;
    }

    public PermSetFinding withWeight(Integer weight) {
        this.weight = weight;
        return this;
    }

    public PermSetFinding withItem(String itemType, String itemName) {
        this.itemType = itemType;
        this.itemName = itemName;
        return this;
    }

    public PermSetFinding withDescription(String description) {
        this.description = description;
        return this;
    }

    public PermSetFinding withRemediation(String remediation) {
        this.remediation = remediation;
        return this;
    }

    public PermSetFinding withPurifyAction(String purifyAction) {
        this.purifyAction = purifyAction;
        return this;
    }
}
