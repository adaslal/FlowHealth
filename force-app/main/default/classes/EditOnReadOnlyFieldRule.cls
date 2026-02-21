/**
 * PS-008: Edit Access on Commonly Read-Only Fields
 *
 * Flags field permissions that grant edit access where read-only would suffice.
 * Common patterns:
 *   - Edit on formula fields (can't be edited via UI, but permission still exists)
 *   - Edit on system fields (CreatedById, LastModifiedById patterns)
 *   - Edit on Id/Name fields that are typically system-managed
 *
 * Since we can't query field metadata from XML alone, this rule uses
 * naming conventions to flag likely read-only fields.
 */
public class EditOnReadOnlyFieldRule implements PermSetRule {

    private static final String RULE_ID = 'PS-008';
    private static final String RULE_NAME = 'Edit Access on Likely Read-Only Fields';

    // Field name patterns that are typically read-only
    private static final Set<String> READONLY_FIELD_SUFFIXES = new Set<String>{
        'createdbyid', 'createddate', 'lastmodifiedbyid', 'lastmodifieddate',
        'systemmodstamp', 'lastactivitydate', 'lastvieweddate',
        'lastreferenceddate', 'isdeleted', 'masterrecordid'
    };

    // Formula field naming convention patterns
    private static final Set<String> FORMULA_PREFIXES = new Set<String>{
        'formula_', 'calc_', 'computed_'
    };

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (permSet.fieldPermissions == null) return findings;

        for (PermSetMetadata.FieldPermission fp : permSet.fieldPermissions) {
            if (fp.editable != true) continue;

            String fieldName = fp.getFieldName();
            if (fieldName == null) continue;
            String fieldLower = fieldName.toLowerCase();

            // Check system read-only fields
            if (READONLY_FIELD_SUFFIXES.contains(fieldLower)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Hygiene')
                    .withSeverity('Low')
                    .withWeight(2)
                    .withItem('fieldPermission', fp.field)
                    .withDescription('Edit access on "' + fp.field + '" — this is a system field that cannot be edited by users')
                    .withRemediation('Downgrade to read-only access. System fields like CreatedDate, LastModifiedDate, etc. are automatically managed by Salesforce.')
                    .withPurifyAction('DOWNGRADE')
                );
                continue;
            }

            // Check formula field patterns
            for (String prefix : FORMULA_PREFIXES) {
                if (fieldLower.startsWith(prefix)) {
                    findings.add(new PermSetFinding()
                        .withRule(RULE_ID, RULE_NAME)
                        .withCategory('Hygiene')
                        .withSeverity('Low')
                        .withWeight(1)
                        .withItem('fieldPermission', fp.field)
                        .withDescription('Edit access on "' + fp.field + '" — naming convention suggests this is a formula/computed field')
                        .withRemediation('If this is a formula field, downgrade to read-only. Formula fields cannot be edited regardless of permissions.')
                        .withPurifyAction('DOWNGRADE')
                    );
                    break;
                }
            }
        }

        return findings;
    }
}
