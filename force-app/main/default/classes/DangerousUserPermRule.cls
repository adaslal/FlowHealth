/**
 * PS-001: Dangerous User Permissions
 *
 * Flags high-risk system permissions that are commonly over-provisioned:
 *   - ModifyAllData, ViewAllData (god-mode access)
 *   - AuthorApex, ManageUsers, ManageRoles
 *   - CustomizeApplication, ModifyMetadata
 *   - ViewSetup, AssignPermissionSets
 *
 * These should only exist in carefully controlled admin permission sets.
 * Each dangerous permission found is marked for REMOVAL during purification.
 */
public class DangerousUserPermRule implements PermSetRule {

    private static final String RULE_ID = 'PS-001';
    private static final String RULE_NAME = 'Dangerous User Permissions';

    // Permissions grouped by risk tier
    private static final Map<String, String> CRITICAL_PERMS = new Map<String, String>{
        'ModifyAllData' => 'Grants unrestricted write access to ALL data in the org',
        'ViewAllData' => 'Grants unrestricted read access to ALL data in the org',
        'AuthorApex' => 'Allows writing and deploying Apex code — admin/developer only',
        'ManageUsers' => 'Can create, deactivate, and modify all users'
    };

    private static final Map<String, String> HIGH_PERMS = new Map<String, String>{
        'CustomizeApplication' => 'Can modify page layouts, custom fields, and app configuration',
        'ModifyMetadata' => 'Can deploy metadata changes — admin only',
        'ManageRoles' => 'Can modify the role hierarchy and sharing rules',
        'AssignPermissionSets' => 'Can assign any permission set to any user',
        'ManageInternalUsers' => 'Can manage all internal user accounts',
        'ManagePasswordPolicies' => 'Can change org-wide password policies',
        'ManageSandboxes' => 'Can create, refresh, and delete sandboxes',
        'ManageDataIntegrations' => 'Can manage data integration settings',
        'InstallPackaging' => 'Can install AppExchange packages'
    };

    public List<PermSetFinding> evaluate(PermSetMetadata.PermissionSetDefinition permSet) {
        List<PermSetFinding> findings = new List<PermSetFinding>();

        if (permSet.userPermissions == null) return findings;

        for (PermSetMetadata.UserPermission up : permSet.userPermissions) {
            if (up.enabled != true) continue;

            if (CRITICAL_PERMS.containsKey(up.name)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('Critical')
                    .withWeight(10)
                    .withItem('userPermission', up.name)
                    .withDescription(CRITICAL_PERMS.get(up.name))
                    .withRemediation('Remove this permission unless this is a dedicated System Admin permission set. Use more granular object/field permissions instead.')
                    .withPurifyAction('REMOVE')
                );
            } else if (HIGH_PERMS.containsKey(up.name)) {
                findings.add(new PermSetFinding()
                    .withRule(RULE_ID, RULE_NAME)
                    .withCategory('Security')
                    .withSeverity('High')
                    .withWeight(7)
                    .withItem('userPermission', up.name)
                    .withDescription(HIGH_PERMS.get(up.name))
                    .withRemediation('Review whether this permission is necessary. Consider creating a separate admin-only permission set for these capabilities.')
                    .withPurifyAction('FLAG')
                );
            }
        }

        return findings;
    }
}
