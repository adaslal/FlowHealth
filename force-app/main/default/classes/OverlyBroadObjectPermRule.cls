/**
 * PS-002: Overly Broad Object Permissions
 *
 * Flags object permissions that grant more access than typically needed:
 *   - ModifyAllRecords without a clear need (should be rare)
 *   - ViewAllRecords on sensitive objects
 *   - Delete access on objects that rarely need deletion
 *
 * The principle of least privilege says: grant the minimum access needed.
 */
public class OverlyBroadObjectPermRule implements PermSetRule {

    private static final String RULE_ID = 'PS-002';
    private static final String RULE_NAME = 'Overly Broad Object Permissions';

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (permSet.objectPermissions == null) return findings;

        for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
            // ModifyAllRecords is almost always too broad
            if (op.modifyAllRecords == true) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('Critical')
                    .withWeight(8)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('ModifyAllRecords on ' + op.object_x + ' — bypasses all sharing rules and gives full write access to every record')
                    .withRemediation('Remove ModifyAllRecords. Use sharing rules, manual sharing, or ownership-based access instead. This permission should only exist on dedicated admin permission sets.')
                    .withPurifyAction('DOWNGRADE')
                );
            }

            // ViewAllRecords is often unnecessary
            if (op.viewAllRecords == true && op.modifyAllRecords != true) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('High')
                    .withWeight(6)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('ViewAllRecords on ' + op.object_x + ' — bypasses sharing rules for read access')
                    .withRemediation('Consider using sharing rules or role hierarchy for read access instead of ViewAllRecords.')
                    .withPurifyAction('FLAG')
                );
            }

            // Delete access — check if it's really needed
            if (op.allowDelete == true) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('Medium')
                    .withWeight(4)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('Delete access on ' + op.object_x + ' — users can permanently remove records')
                    .withRemediation('Review whether Delete access is necessary. Consider using archival processes instead of direct deletion.')
                    .withPurifyAction('FLAG')
                );
            }
        }

        return findings;
    }
}
