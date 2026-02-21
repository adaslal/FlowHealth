/**
 * PS-004: Disabled Permission Entries
 *
 * Detects entries where enabled=false or all booleans are false.
 * These are dead weight — they clutter the XML, make it harder to read,
 * and provide zero value. The purifier removes them.
 *
 * Checks:
 *   - Class accesses with enabled=false
 *   - Page accesses with enabled=false
 *   - Custom metadata type accesses with enabled=false
 *   - Custom setting accesses with enabled=false
 *   - Flow accesses with enabled=false
 *   - User permissions with enabled=false
 *   - Object permissions where all CRUD flags are false
 *   - Field permissions where both readable and editable are false
 */
public class DisabledEntryRule implements PermSetRule {

    private static final String RULE_ID = 'PS-004';
    private static final String RULE_NAME = 'Disabled Permission Entries (Dead Weight)';

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        // Class accesses
        if (permSet.classAccesses != null) {
            for (PermSetMetadata.ClassAccess ca : permSet.classAccesses) {
                if (ca.enabled != true) {
                    findings.add(buildFinding('classAccess', ca.apexClass,
                        'Apex class access for "' + ca.apexClass + '" is disabled'));
                }
            }
        }

        // Page accesses
        if (permSet.pageAccesses != null) {
            for (PermSetMetadata.PageAccess pa : permSet.pageAccesses) {
                if (pa.enabled != true) {
                    findings.add(buildFinding('pageAccess', pa.apexPage,
                        'Visualforce page access for "' + pa.apexPage + '" is disabled'));
                }
            }
        }

        // User permissions with enabled=false
        if (permSet.userPermissions != null) {
            for (PermSetMetadata.UserPermission up : permSet.userPermissions) {
                if (up.enabled != true) {
                    findings.add(buildFinding('userPermission', up.name,
                        'User permission "' + up.name + '" is disabled'));
                }
            }
        }

        // Custom metadata type accesses
        if (permSet.customMetadataTypeAccesses != null) {
            for (PermSetMetadata.CustomMetadataTypeAccess cma : permSet.customMetadataTypeAccesses) {
                if (cma.enabled != true) {
                    findings.add(buildFinding('customMetadataTypeAccess', cma.name,
                        'Custom metadata type access for "' + cma.name + '" is disabled'));
                }
            }
        }

        // Custom setting accesses
        if (permSet.customSettingAccesses != null) {
            for (PermSetMetadata.CustomSettingAccess csa : permSet.customSettingAccesses) {
                if (csa.enabled != true) {
                    findings.add(buildFinding('customSettingAccess', csa.name,
                        'Custom setting access for "' + csa.name + '" is disabled'));
                }
            }
        }

        // Flow accesses
        if (permSet.flowAccesses != null) {
            for (PermSetMetadata.FlowAccess fa : permSet.flowAccesses) {
                if (fa.enabled != true) {
                    findings.add(buildFinding('flowAccess', fa.flow,
                        'Flow access for "' + fa.flow + '" is disabled'));
                }
            }
        }

        // Object permissions where all CRUD is false
        if (permSet.objectPermissions != null) {
            for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
                if (op.allowCreate != true && op.allowRead != true &&
                    op.allowEdit != true && op.allowDelete != true &&
                    op.viewAllRecords != true && op.modifyAllRecords != true) {
                    findings.add(buildFinding('objectPermission', op.object_x,
                        'Object permission for "' + op.object_x + '" has all CRUD flags set to false'));
                }
            }
        }

        // Field permissions where both are false
        if (permSet.fieldPermissions != null) {
            for (PermSetMetadata.FieldPermission fp : permSet.fieldPermissions) {
                if (fp.readable != true && fp.editable != true) {
                    findings.add(buildFinding('fieldPermission', fp.field,
                        'Field permission for "' + fp.field + '" has both readable and editable set to false'));
                }
            }
        }

        return findings;
    }

    private PermSetFinding buildFinding(String itemType, String itemName, String description) {
        return new PermSetFinding()
            .withRule(RULE_ID, RULE_NAME)
            .withCategory('Hygiene')
            .withSeverity('Low')
            .withWeight(2)
            .withItem(itemType, itemName)
            .withDescription(description)
            .withRemediation('Remove this entry — disabled permissions add XML bloat and confusion without granting any access.')
            .withPurifyAction('REMOVE');
    }
}
