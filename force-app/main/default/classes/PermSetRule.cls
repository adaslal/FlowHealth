/**
 * PermSetRule - Interface for PermSet Purifier rules.
 *
 * Each rule analyzes a PermissionSetDefinition and returns findings.
 * Rules can also mark items for removal during purification.
 *
 * This mirrors the FlowRule pattern from Flow Health for consistency.
 */
public interface PermSetRule {

    /**
     * Evaluate the permission set against this rule.
     *
     * @param permSet  The parsed permission set definition
     * @return List of PermSetFinding objects (empty if rule passes)
     */
    List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet);
}
