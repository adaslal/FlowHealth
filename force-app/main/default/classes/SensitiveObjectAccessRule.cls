/**
 * PS-007: Sensitive Data Object Access
 *
 * Flags object permissions on objects that typically contain PII,
 * financial data, or other sensitive information. These require
 * extra scrutiny during security reviews.
 *
 * Sensitive object patterns:
 *   - User, Contact, Lead (PII)
 *   - Financial objects (Payment, Invoice, Billing)
 *   - Auth objects (AuthSession, LoginHistory, PermissionSet)
 *   - Setup objects (Profile, UserRole)
 */
public class SensitiveObjectAccessRule implements PermSetRule {

    private static final String RULE_ID = 'PS-007';
    private static final String RULE_NAME = 'Sensitive Data Object Access';

    private static final Set<String> PII_OBJECTS = new Set<String>{
        'user', 'contact', 'lead', 'individual', 'personaccount',
        'userrole', 'profile', 'group', 'groupmember'
    };

    private static final Set<String> FINANCIAL_OBJECTS = new Set<String>{
        'payment', 'invoice', 'billingschedule', 'creditnote',
        'order', 'orderitem', 'asset', 'contract'
    };

    private static final Set<String> SETUP_OBJECTS = new Set<String>{
        'permissionset', 'permissionsetassignment', 'permissionsetgroup',
        'authsession', 'loginhistory', 'setupaudittrail',
        'namedcredential', 'externalcredential'
    };

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (permSet.objectPermissions == null) return findings;

        for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
            if (op.object_x == null) continue;
            String objLower = op.object_x.toLowerCase();

            if (PII_OBJECTS.contains(objLower)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Compliance')
                    .withSeverity('High')
                    .withWeight(6)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('Access to "' + op.object_x + '" — this object typically contains personally identifiable information (PII)')
                    .withRemediation('Ensure this access is justified by business need. Document the data classification and review with your DPO/compliance team.')
                    .withPurifyAction('FLAG')
                );
            } else if (FINANCIAL_OBJECTS.contains(objLower)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Compliance')
                    .withSeverity('High')
                    .withWeight(6)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('Access to "' + op.object_x + '" — this object typically contains financial data')
                    .withRemediation('Verify SOX/compliance requirements. Ensure proper audit trails are in place for this object.')
                    .withPurifyAction('FLAG')
                );
            } else if (SETUP_OBJECTS.contains(objLower)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('High')
                    .withWeight(7)
                    .withItem('objectPermission', op.object_x)
                    .withDescription('Access to "' + op.object_x + '" — this is a setup/security object that controls org configuration')
                    .withRemediation('Restrict this access to admin-only permission sets. Regular users should not have access to security configuration objects.')
                    .withPurifyAction('FLAG')
                );
            }
        }

        return findings;
    }
}
