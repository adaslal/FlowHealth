/**
 * PS-003: Field Permissions Without Object Access
 *
 * Detects field permissions that reference objects not in the objectPermissions
 * list. These "orphaned" field permissions are dead weight — they grant nothing
 * because the user has no object-level access.
 *
 * This is one of the most common sources of permission set bloat.
 */
public class OrphanedFieldPermRule implements PermSetRule {

    private static final String RULE_ID = 'PS-003';
    private static final String RULE_NAME = 'Field Permissions Without Object Access';

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (permSet.fieldPermissions == null || permSet.fieldPermissions.isEmpty()) {
            return findings;
        }

        // Build set of objects that have object-level permissions
        Set<String> objectsWithAccess = new Set<String>();
        if (permSet.objectPermissions != null) {
            for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
                if (op.object_x != null) {
                    objectsWithAccess.add(op.object_x.toLowerCase());
                }
            }
        }

        // Check each field permission
        for (PermSetMetadata.FieldPermission fp : permSet.fieldPermissions) {
            String objName = fp.getObjectName();
            if (objName == null) continue;

            if (!objectsWithAccess.contains(objName.toLowerCase())) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Hygiene')
                    .withSeverity('Medium')
                    .withWeight(3)
                    .withItem('fieldPermission', fp.field)
                    .withDescription('Field permission for "' + fp.field + '" but no object permission exists for "' + objName + '". This field permission has no effect.')
                    .withRemediation('Remove this field permission (it does nothing without object access), or add object-level permissions for "' + objName + '" if needed.')
                    .withPurifyAction('REMOVE')
                );
            }
        }

        return findings;
    }
}
