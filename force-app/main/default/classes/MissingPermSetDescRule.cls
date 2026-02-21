/**
 * PS-006: Missing Description
 *
 * Flags permission sets that lack a description. Good security hygiene
 * requires every permission set to document its purpose, intended audience,
 * and reason for each access grant.
 */
public class MissingPermSetDescRule implements PermSetRule {

    private static final String RULE_ID = 'PS-006';
    private static final String RULE_NAME = 'Missing Permission Set Description';

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (String.isBlank(permSet.description)) {
            findings.add(new PermSetFinding()
                .withRule(RULE_ID, RULE_NAME)
                .withCategory('Design')
                .withSeverity('Low')
                .withWeight(2)
                .withItem('permissionSet', permSet.label != null ? permSet.label : 'Unknown')
                .withDescription('Permission set has no description. Without documentation, it\'s unclear who should have this access and why.')
                .withRemediation('Add a description explaining: (1) who this permission set is for, (2) what access it grants, (3) why it exists. Example: "Sales team access to Account and Opportunity data for daily pipeline management."')
                .withPurifyAction('FLAG')
            );
        }

        return findings;
    }
}
