/**
 * PS-005: Excessive Permission Count
 *
 * Flags permission sets with an unusually high total permission count.
 * Bloated permission sets are:
 *   - Hard to audit and review
 *   - More likely to contain over-provisioned access
 *   - A sign that the perm set needs to be split
 *
 * Thresholds (configurable):
 *   - > 500 total permissions: Medium (needs review)
 *   - > 1000 total permissions: High (likely bloated)
 *   - > 2000 total permissions: Critical (definitely needs splitting)
 */
public class ExcessivePermCountRule implements PermSetRule {

    private static final String RULE_ID = 'PS-005';
    private static final String RULE_NAME = 'Excessive Permission Count';

    private static final Integer THRESHOLD_MEDIUM = 500;
    private static final Integer THRESHOLD_HIGH = 1000;
    private static final Integer THRESHOLD_CRITICAL = 2000;

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        Integer totalCount = permSet.getTotalPermissionCount();

        if (totalCount >= THRESHOLD_CRITICAL) {
            findings.add(new PermSetFinding()
                .withRule(RULE_ID, RULE_NAME)
                .withCategory('Design')
                .withSeverity('Critical')
                .withWeight(8)
                .withItem('permissionSet', permSet.label != null ? permSet.label : 'Unknown')
                .withDescription('Permission set contains ' + totalCount + ' total permission entries — far exceeding recommended limits. This is a major security review risk.')
                .withRemediation('Split this permission set into multiple smaller, role-based permission sets. Group permissions by function (e.g., Sales Data Access, Marketing Tools, Admin Operations).')
                .withPurifyAction('FLAG')
            );
        } else if (totalCount >= THRESHOLD_HIGH) {
            findings.add(new PermSetFinding()
                .withRule(RULE_ID, RULE_NAME)
                .withCategory('Design')
                .withSeverity('High')
                .withWeight(6)
                .withItem('permissionSet', permSet.label != null ? permSet.label : 'Unknown')
                .withDescription('Permission set contains ' + totalCount + ' total permission entries — likely bloated and hard to audit.')
                .withRemediation('Consider splitting into smaller, function-specific permission sets for better manageability.')
                .withPurifyAction('FLAG')
            );
        } else if (totalCount >= THRESHOLD_MEDIUM) {
            findings.add(new PermSetFinding()
                .withRule(RULE_ID, RULE_NAME)
                .withCategory('Design')
                .withSeverity('Medium')
                .withWeight(4)
                .withItem('permissionSet', permSet.label != null ? permSet.label : 'Unknown')
                .withDescription('Permission set contains ' + totalCount + ' total permission entries — review for unnecessary entries.')
                .withRemediation('Review the permission set for disabled entries, orphaned field permissions, and unnecessary access grants.')
                .withPurifyAction('FLAG')
            );
        }

        return findings;
    }
}
