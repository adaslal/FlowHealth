/**
 * PermSetPatchServiceTest - Unit tests for PermSetPatchService.
 *
 * TESTING STRATEGY:
 * PermSetPatchService.generatePatch() merges source permission set XML into
 * a destination permission set XML using "destination-based merging" —
 * never removing permissions that exist in destination but not in source.
 *
 * Test cases cover:
 * 1. Basic merge scenarios (add, modify, preserve)
 * 2. Null/blank input validation
 * 3. Empty source and destination
 * 4. Multiple permission types together
 * 5. PatchResult structure and counts
 */
@IsTest
private class PermSetPatchServiceTest {

    // =========================================================================
    // TEST: Basic merge — source has permission not in destination
    // =========================================================================

    @IsTest
    static void testGeneratePatch_BasicMerge_AddPermission() {
        // Destination has Account permission (create, read only)
        String destXml = buildPermSetXml('Destination PermSet',
            'Account|false|true|false|false|false|false'  // allowCreate=F, allowRead=T, rest=F
        );

        // Source has Account (full CRUD) + Contact (read only)
        String srcXml = buildPermSetXml('Source PermSet',
            'Account|true|true|true|true|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Verify source Contact permission was ADDED to destination
        System.assertEquals(2, result.patchedPermCount, 'Should have 2 object permissions in patched');
        System.assertEquals(1, result.addedCount, 'Should have added 1 permission');
        System.assertEquals(0, result.modifiedCount, 'Should not have modified any permissions');

        // Verify action list
        System.assertEquals(1, result.actionsApplied.size(), 'Should have 1 action');
        PermSetPatchService.PatchAction addedAction = result.actionsApplied[0];
        System.assertEquals('ADDED', addedAction.actionType, 'Should be ADDED action');
        System.assertEquals('objectPermission', addedAction.itemType, 'Should be objectPermission');
        System.assertEquals('Contact', addedAction.itemName, 'Should be Contact object');
    }

    // =========================================================================
    // TEST: No-op merge — source and destination identical
    // =========================================================================

    @IsTest
    static void testGeneratePatch_NoOpMerge() {
        // Same permissions in both source and destination
        String destXml = buildPermSetXml('Test PermSet',
            'Account|true|true|false|false|false|false'
        );
        String srcXml = buildPermSetXml('Test PermSet',
            'Account|true|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // No changes should be applied
        System.assertEquals(1, result.patchedPermCount, 'Should have 1 permission');
        System.assertEquals(0, result.addedCount, 'Should have added 0 permissions');
        System.assertEquals(0, result.modifiedCount, 'Should have modified 0 permissions');
        System.assertEquals(0, result.actionsApplied.size(), 'Should have 0 actions');

        // Patched XML should match destination (no changes)
        System.assertEquals(result.destinationXml, result.patchedXml, 'Patched XML should match destination');
    }

    // =========================================================================
    // TEST: Elevated permissions — source has higher access
    // =========================================================================

    @IsTest
    static void testGeneratePatch_ElevatedPermissions_ObjectLevel() {
        // Destination: Account with read-only
        String destXml = buildPermSetXml('Destination PermSet',
            'Account|false|true|false|false|false|false'
        );

        // Source: Account with full CRUD
        String srcXml = buildPermSetXml('Source PermSet',
            'Account|true|true|true|true|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Account permission should be MODIFIED (elevated)
        System.assertEquals(0, result.addedCount, 'Should have added 0 permissions');
        System.assertEquals(1, result.modifiedCount, 'Should have modified 1 permission');
        System.assertEquals(1, result.actionsApplied.size(), 'Should have 1 action');

        PermSetPatchService.PatchAction modifiedAction = result.actionsApplied[0];
        System.assertEquals('MODIFIED', modifiedAction.actionType, 'Should be MODIFIED action');
        System.assertEquals('objectPermission', modifiedAction.itemType, 'Should be objectPermission');
        System.assert(modifiedAction.detail.contains('Elevated'), 'Detail should mention elevation');
        System.assert(modifiedAction.detail.contains('allowCreate'), 'Detail should list changed fields');
    }

    @IsTest
    static void testGeneratePatch_ElevatedPermissions_FieldLevel() {
        // Destination: Account.Name is readable only
        String destXml = buildPermSetWithFieldPerms('Destination PermSet',
            'Account.Name|true|false'  // readable=T, editable=F
        );

        // Source: Account.Name is readable and editable
        String srcXml = buildPermSetWithFieldPerms('Source PermSet',
            'Account.Name|true|true'   // readable=T, editable=T
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Field permission should be MODIFIED
        System.assertEquals(0, result.addedCount, 'Should have added 0 permissions');
        System.assertEquals(1, result.modifiedCount, 'Should have modified 1 permission');

        PermSetPatchService.PatchAction action = result.actionsApplied[0];
        System.assertEquals('MODIFIED', action.actionType, 'Should be MODIFIED');
        System.assertEquals('fieldPermission', action.itemType, 'Should be fieldPermission');
        System.assert(action.detail.contains('editable'), 'Detail should mention editable');
    }

    // =========================================================================
    // TEST: Destination-only permissions preserved (never removed)
    // =========================================================================

    @IsTest
    static void testGeneratePatch_DestinationOnlyPermissionsPreserved() {
        // Destination has Account + Contact permissions
        String destXml = buildPermSetXml('Destination PermSet',
            'Account|true|true|false|false|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        // Source has only Account (no Contact)
        String srcXml = buildPermSetXml('Source PermSet',
            'Account|true|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Patched should still have both Account and Contact (Contact never removed)
        System.assertEquals(2, result.patchedPermCount, 'Should preserve destination Contact permission');
        System.assertEquals(0, result.addedCount, 'Should not add anything');
        System.assertEquals(0, result.modifiedCount, 'Should not modify anything');

        // Verify Contact is still in the patched XML
        System.assert(result.patchedXml.contains('<object>Contact</object>'), 'Contact permission should be preserved');
    }

    // =========================================================================
    // TEST: Multiple permission types together
    // =========================================================================

    @IsTest
    static void testGeneratePatch_MultiplePermissionTypes() {
        // Destination: 1 object perm + 1 field perm + 1 user perm
        String destXml = buildMixedPermSetXml('Destination PermSet',
            'Account|true|true|false|false|false|false',    // objectPermission
            'Account.Industry|false|true',                   // fieldPermission
            'ApiEnabled|false'                               // userPermission
        );

        // Source: same Account + different field + same API perm + new tab
        String srcXml = buildMixedPermSetXmlWithTab('Source PermSet',
            'Account|true|true|true|true|false|false',      // elevate Account to full CRUD
            'Account.Industry|true|true',                    // elevate field to editable
            'ApiEnabled|true',                               // enable API
            'Accounts|DefaultOn'                             // add tab
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Should have:
        // - 1 object perm (Account, modified)
        // - 1 field perm (Account.Industry, modified)
        // - 1 user perm (ApiEnabled, modified)
        // - 1 tab setting (Accounts, added)
        System.assertEquals(1, result.addedCount, 'Should have 1 added (tab)');
        System.assertEquals(3, result.modifiedCount, 'Should have 3 modified (Account obj, field, user perm)');
        System.assertEquals(4, result.actionsApplied.size(), 'Should have 4 total actions');

        // Verify at least one modification per type
        Boolean hasObjectModified = false;
        Boolean hasFieldModified = false;
        Boolean hasUserModified = false;
        Boolean hasTabAdded = false;

        for (PermSetPatchService.PatchAction action : result.actionsApplied) {
            if (action.itemType == 'objectPermission' && action.actionType == 'MODIFIED') {
                hasObjectModified = true;
            } else if (action.itemType == 'fieldPermission' && action.actionType == 'MODIFIED') {
                hasFieldModified = true;
            } else if (action.itemType == 'userPermission' && action.actionType == 'MODIFIED') {
                hasUserModified = true;
            } else if (action.itemType == 'tabSetting' && action.actionType == 'ADDED') {
                hasTabAdded = true;
            }
        }

        System.assert(hasObjectModified, 'Should have object permission modified');
        System.assert(hasFieldModified, 'Should have field permission modified');
        System.assert(hasUserModified, 'Should have user permission modified');
        System.assert(hasTabAdded, 'Should have tab setting added');
    }

    // =========================================================================
    // TEST: Null/blank input validation
    // =========================================================================

    @IsTest
    static void testGeneratePatch_BlankDestinationThrows() {
        String srcXml = buildPermSetXml('Source', 'Account|true|true|false|false|false|false');

        Test.startTest();
        try {
            PermSetPatchService.generatePatch('', srcXml);
            System.assert(false, 'Should have thrown exception for blank destination');
        } catch (FlowMetadataService.FlowHealthException e) {
            System.assert(e.getMessage().contains('blank') || e.getMessage().contains('cannot'),
                'Error should mention blank input. Got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGeneratePatch_NullDestinationThrows() {
        String srcXml = buildPermSetXml('Source', 'Account|true|true|false|false|false|false');

        Test.startTest();
        try {
            PermSetPatchService.generatePatch(null, srcXml);
            System.assert(false, 'Should have thrown exception for null destination');
        } catch (Exception e) {
            // Expected behavior — null destination should fail
            System.assert(true, 'Null destination should throw');
        }
        Test.stopTest();
    }

    // =========================================================================
    // TEST: Empty source — destination preserved intact
    // =========================================================================

    @IsTest
    static void testGeneratePatch_EmptySourcePreservesDest() {
        // Destination with permissions
        String destXml = buildPermSetXml('Destination PermSet',
            'Account|true|true|false|false|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        // Source with minimal metadata, no permissions
        String srcXml = buildMinimalPermSetXml('Source PermSet');

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Destination permissions should be preserved
        System.assertEquals(2, result.patchedPermCount, 'Should preserve all destination permissions');
        System.assertEquals(0, result.addedCount, 'Should add nothing');
        System.assertEquals(0, result.modifiedCount, 'Should modify nothing');
        System.assertEquals(0, result.actionsApplied.size(), 'Should have no actions');
    }

    // =========================================================================
    // TEST: PatchResult structure — verify counts and structure
    // =========================================================================

    @IsTest
    static void testGeneratePatch_PatchResultStructure() {
        String destXml = buildPermSetXml('Dest',
            'Account|true|true|false|false|false|false'
        );
        String srcXml = buildPermSetXml('Source',
            'Account|true|true|true|true|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Verify all PatchResult fields are populated
        System.assertNotEquals(null, result.destinationXml, 'destinationXml should not be null');
        System.assertNotEquals(null, result.sourceXml, 'sourceXml should not be null');
        System.assertNotEquals(null, result.patchedXml, 'patchedXml should not be null');
        System.assertNotEquals(null, result.actionsApplied, 'actionsApplied should not be null');

        // Verify counts
        System.assertNotEquals(null, result.destinationPermCount, 'destinationPermCount should not be null');
        System.assertNotEquals(null, result.sourcePermCount, 'sourcePermCount should not be null');
        System.assertNotEquals(null, result.patchedPermCount, 'patchedPermCount should not be null');
        System.assertNotEquals(null, result.addedCount, 'addedCount should not be null');
        System.assertNotEquals(null, result.modifiedCount, 'modifiedCount should not be null');
        System.assertNotEquals(null, result.preservedCount, 'preservedCount should not be null');

        // Verify counts are consistent
        Integer expectedPreserved = result.patchedPermCount - result.addedCount - result.modifiedCount;
        System.assertEquals(expectedPreserved, result.preservedCount, 'Preserved count should be patchedPermCount - added - modified');

        // Destination had 1, Source had 2, Patched should have 2 (Account modified, Contact added)
        System.assertEquals(1, result.destinationPermCount, 'Destination should have 1 permission');
        System.assertEquals(2, result.sourcePermCount, 'Source should have 2 permissions');
        System.assertEquals(2, result.patchedPermCount, 'Patched should have 2 permissions');
    }

    @IsTest
    static void testGeneratePatch_PatchActionStructure() {
        String destXml = buildPermSetXml('Dest',
            'Account|false|true|false|false|false|false'
        );
        String srcXml = buildPermSetXml('Source',
            'Account|true|true|false|false|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Verify PatchAction structure
        System.assertEquals(2, result.actionsApplied.size(), 'Should have 2 actions');

        for (PermSetPatchService.PatchAction action : result.actionsApplied) {
            System.assertNotEquals(null, action.actionType, 'actionType should not be null');
            System.assertNotEquals(null, action.itemType, 'itemType should not be null');
            System.assertNotEquals(null, action.itemName, 'itemName should not be null');
            System.assertNotEquals(null, action.detail, 'detail should not be null');

            // Verify actionType is one of the expected values
            System.assert(
                action.actionType == 'ADDED' || action.actionType == 'MODIFIED' || action.actionType == 'PRESERVED',
                'actionType should be ADDED, MODIFIED, or PRESERVED. Got: ' + action.actionType
            );

            // Verify itemType is one of the expected permission types
            System.assert(
                action.itemType == 'objectPermission' || action.itemType == 'fieldPermission' ||
                action.itemType == 'userPermission' || action.itemType == 'tabSetting' ||
                action.itemType == 'classAccess' || action.itemType == 'pageAccess',
                'itemType should be a recognized permission type. Got: ' + action.itemType
            );
        }
    }

    // =========================================================================
    // TEST: Complex scenario — verify patchedXml is valid and properly formed
    // =========================================================================

    @IsTest
    static void testGeneratePatch_PatchedXmlIsValid() {
        String destXml = buildPermSetXml('Destination PermSet',
            'Account|true|true|false|false|false|false'
        );
        String srcXml = buildPermSetXml('Source PermSet',
            'Account|true|true|true|true|false|false,' +
            'Contact|false|true|false|false|false|false'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Verify patched XML is well-formed XML
        System.assert(result.patchedXml.startsWith('<?xml'), 'Patched XML should start with XML declaration');
        System.assert(result.patchedXml.contains('<PermissionSet'), 'Patched XML should contain PermissionSet root');
        System.assert(result.patchedXml.contains('</PermissionSet>'), 'Patched XML should close PermissionSet root');

        // Verify it can be parsed back (sanity check)
        try {
            PermSetMetadata.PermissionSetDefinition parsed = PermSetXmlParser.parse(result.patchedXml);
            System.assertNotEquals(null, parsed, 'Patched XML should be parseable');
            System.assertEquals(2, parsed.objectPermissions.size(), 'Parsed patched XML should have 2 object permissions');
        } catch (Exception e) {
            System.assert(false, 'Patched XML should be valid and parseable. Error: ' + e.getMessage());
        }
    }

    // =========================================================================
    // TEST: Never remove destination-only permissions across all types
    // =========================================================================

    @IsTest
    static void testGeneratePatch_NeverRemovesDestinationPermissions_AllTypes() {
        // Build destination with multiple permission types that are NOT in source
        String destXml = buildComplexPermSetXml('Dest',
            'objectPerms:Account|true|true|false|false|false|false;Contact|false|true|false|false|false|false',
            'fieldPerms:Account.Name|true|false;Contact.Email|true|true',
            'userPerms:ApiEnabled|true;ViewSetup|false',
            'classAccess:TestClass|true',
            'pageAccess:TestPage|false'
        );

        // Source has only Account + Account.Name (minimal)
        String srcXml = buildComplexPermSetXml('Source',
            'objectPerms:Account|true|true|false|false|false|false',
            'fieldPerms:Account.Name|true|false',
            'userPerms:',
            'classAccess:',
            'pageAccess:'
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Verify destination-only permissions are preserved in patched
        System.assert(result.patchedXml.contains('Contact'), 'Contact object permission should be preserved');
        System.assert(result.patchedXml.contains('Contact.Email'), 'Contact.Email field permission should be preserved');
        System.assert(result.patchedXml.contains('ViewSetup'), 'ViewSetup user permission should be preserved');
        System.assert(result.patchedXml.contains('TestClass'), 'TestClass access should be preserved');
        System.assert(result.patchedXml.contains('TestPage'), 'TestPage access should be preserved');
    }

    // =========================================================================
    // TEST: Source elevation never downgrades destination
    // =========================================================================

    @IsTest
    static void testGeneratePatch_SourceElevationNeverDowngrades() {
        // Destination has full access to Account
        String destXml = buildPermSetXml('Dest',
            'Account|true|true|true|true|true|true'  // all true
        );

        // Source has only read access
        String srcXml = buildPermSetXml('Source',
            'Account|false|true|false|false|false|false'  // read-only
        );

        Test.startTest();
        PermSetPatchService.PatchResult result = PermSetPatchService.generatePatch(destXml, srcXml);
        Test.stopTest();

        // Account should NOT be downgraded (still have full access)
        System.assertEquals(0, result.modifiedCount, 'Should not modify (source is less permissive)');

        // Verify all permission flags remain true in patched
        PermSetMetadata.PermissionSetDefinition parsed = PermSetXmlParser.parse(result.patchedXml);
        PermSetMetadata.ObjectPermission accountPerm = parsed.objectPermissions[0];
        System.assertEquals(true, accountPerm.allowCreate, 'allowCreate should remain true');
        System.assertEquals(true, accountPerm.allowRead, 'allowRead should remain true');
        System.assertEquals(true, accountPerm.allowEdit, 'allowEdit should remain true');
        System.assertEquals(true, accountPerm.allowDelete, 'allowDelete should remain true');
    }

    // =========================================================================
    // TEST DATA BUILDERS
    // =========================================================================

    /**
     * Builds a minimal permission set XML with only label.
     */
    private static String buildMinimalPermSetXml(String label) {
        return '<?xml version="1.0" encoding="UTF-8"?>'
            + '<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '    <label>' + label + '</label>'
            + '</PermissionSet>';
    }

    /**
     * Builds a permission set XML with object permissions.
     * @param label Permission set label
     * @param objectPerms Pipe-delimited: ObjectName|allowCreate|allowRead|allowEdit|allowDelete|viewAll|modifyAll,...
     */
    private static String buildPermSetXml(String label, String objectPerms) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');
        lines.add('    <label>' + label + '</label>');

        // Parse and add object permissions
        List<String> objList = objectPerms.split(',');
        for (String obj : objList) {
            if (String.isBlank(obj)) continue;

            List<String> parts = obj.split('\\|');
            if (parts.size() == 7) {
                String objectName = parts[0];
                String allowCreate = parts[1];
                String allowRead = parts[2];
                String allowEdit = parts[3];
                String allowDelete = parts[4];
                String viewAll = parts[5];
                String modifyAll = parts[6];

                lines.add('    <objectPermissions>');
                lines.add('        <allowCreate>' + allowCreate + '</allowCreate>');
                lines.add('        <allowDelete>' + allowDelete + '</allowDelete>');
                lines.add('        <allowEdit>' + allowEdit + '</allowEdit>');
                lines.add('        <allowRead>' + allowRead + '</allowRead>');
                lines.add('        <modifyAllRecords>' + modifyAll + '</modifyAllRecords>');
                lines.add('        <object>' + objectName + '</object>');
                lines.add('        <viewAllRecords>' + viewAll + '</viewAllRecords>');
                lines.add('    </objectPermissions>');
            }
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }

    /**
     * Builds a permission set XML with field permissions.
     * @param label Permission set label
     * @param fieldPerms Pipe-delimited: Field.Name|readable|editable,...
     */
    private static String buildPermSetWithFieldPerms(String label, String fieldPerms) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');
        lines.add('    <label>' + label + '</label>');

        // Parse and add field permissions
        List<String> fieldList = fieldPerms.split(',');
        for (String field : fieldList) {
            if (String.isBlank(field)) continue;

            List<String> parts = field.split('\\|');
            if (parts.size() == 3) {
                String fieldName = parts[0];
                String readable = parts[1];
                String editable = parts[2];

                lines.add('    <fieldPermissions>');
                lines.add('        <editable>' + editable + '</editable>');
                lines.add('        <field>' + fieldName + '</field>');
                lines.add('        <readable>' + readable + '</readable>');
                lines.add('    </fieldPermissions>');
            }
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }

    /**
     * Builds a permission set XML with mixed permission types.
     */
    private static String buildMixedPermSetXml(String label, String objectPerms, String fieldPerms, String userPerms) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');
        lines.add('    <label>' + label + '</label>');

        // Add object permission
        if (String.isNotBlank(objectPerms)) {
            List<String> objParts = objectPerms.split('\\|');
            if (objParts.size() == 7) {
                lines.add('    <objectPermissions>');
                lines.add('        <allowCreate>' + objParts[1] + '</allowCreate>');
                lines.add('        <allowDelete>' + objParts[4] + '</allowDelete>');
                lines.add('        <allowEdit>' + objParts[3] + '</allowEdit>');
                lines.add('        <allowRead>' + objParts[2] + '</allowRead>');
                lines.add('        <modifyAllRecords>' + objParts[6] + '</modifyAllRecords>');
                lines.add('        <object>' + objParts[0] + '</object>');
                lines.add('        <viewAllRecords>' + objParts[5] + '</viewAllRecords>');
                lines.add('    </objectPermissions>');
            }
        }

        // Add field permission
        if (String.isNotBlank(fieldPerms)) {
            List<String> fieldParts = fieldPerms.split('\\|');
            if (fieldParts.size() == 3) {
                lines.add('    <fieldPermissions>');
                lines.add('        <editable>' + fieldParts[2] + '</editable>');
                lines.add('        <field>' + fieldParts[0] + '</field>');
                lines.add('        <readable>' + fieldParts[1] + '</readable>');
                lines.add('    </fieldPermissions>');
            }
        }

        // Add user permission
        if (String.isNotBlank(userPerms)) {
            List<String> userParts = userPerms.split('\\|');
            if (userParts.size() == 2) {
                lines.add('    <userPermissions>');
                lines.add('        <enabled>' + userParts[1] + '</enabled>');
                lines.add('        <name>' + userParts[0] + '</name>');
                lines.add('    </userPermissions>');
            }
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }

    /**
     * Builds a permission set XML with mixed permission types including tab settings.
     */
    private static String buildMixedPermSetXmlWithTab(String label, String objectPerms, String fieldPerms, String userPerms, String tabSetting) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');
        lines.add('    <label>' + label + '</label>');

        // Add object permission
        if (String.isNotBlank(objectPerms)) {
            List<String> objParts = objectPerms.split('\\|');
            if (objParts.size() == 7) {
                lines.add('    <objectPermissions>');
                lines.add('        <allowCreate>' + objParts[1] + '</allowCreate>');
                lines.add('        <allowDelete>' + objParts[4] + '</allowDelete>');
                lines.add('        <allowEdit>' + objParts[3] + '</allowEdit>');
                lines.add('        <allowRead>' + objParts[2] + '</allowRead>');
                lines.add('        <modifyAllRecords>' + objParts[6] + '</modifyAllRecords>');
                lines.add('        <object>' + objParts[0] + '</object>');
                lines.add('        <viewAllRecords>' + objParts[5] + '</viewAllRecords>');
                lines.add('    </objectPermissions>');
            }
        }

        // Add field permission
        if (String.isNotBlank(fieldPerms)) {
            List<String> fieldParts = fieldPerms.split('\\|');
            if (fieldParts.size() == 3) {
                lines.add('    <fieldPermissions>');
                lines.add('        <editable>' + fieldParts[2] + '</editable>');
                lines.add('        <field>' + fieldParts[0] + '</field>');
                lines.add('        <readable>' + fieldParts[1] + '</readable>');
                lines.add('    </fieldPermissions>');
            }
        }

        // Add user permission
        if (String.isNotBlank(userPerms)) {
            List<String> userParts = userPerms.split('\\|');
            if (userParts.size() == 2) {
                lines.add('    <userPermissions>');
                lines.add('        <enabled>' + userParts[1] + '</enabled>');
                lines.add('        <name>' + userParts[0] + '</name>');
                lines.add('    </userPermissions>');
            }
        }

        // Add tab setting
        if (String.isNotBlank(tabSetting)) {
            List<String> tabParts = tabSetting.split('\\|');
            if (tabParts.size() == 2) {
                lines.add('    <tabSettings>');
                lines.add('        <tab>' + tabParts[0] + '</tab>');
                lines.add('        <visibility>' + tabParts[1] + '</visibility>');
                lines.add('    </tabSettings>');
            }
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }

    /**
     * Builds a complex permission set with multiple permission types.
     * Format: type:details;type:details,...
     */
    private static String buildComplexPermSetXml(String label, String objectPerms, String fieldPerms, String userPerms, String classAccess, String pageAccess) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');
        lines.add('    <label>' + label + '</label>');

        // Add object permissions
        if (objectPerms.startsWith('objectPerms:')) {
            String objData = objectPerms.substring(12);
            if (String.isNotBlank(objData)) {
                List<String> objList = objData.split(';');
                for (String obj : objList) {
                    if (String.isBlank(obj)) continue;
                    List<String> parts = obj.split('\\|');
                    if (parts.size() == 7) {
                        lines.add('    <objectPermissions>');
                        lines.add('        <allowCreate>' + parts[1] + '</allowCreate>');
                        lines.add('        <allowDelete>' + parts[4] + '</allowDelete>');
                        lines.add('        <allowEdit>' + parts[3] + '</allowEdit>');
                        lines.add('        <allowRead>' + parts[2] + '</allowRead>');
                        lines.add('        <modifyAllRecords>' + parts[6] + '</modifyAllRecords>');
                        lines.add('        <object>' + parts[0] + '</object>');
                        lines.add('        <viewAllRecords>' + parts[5] + '</viewAllRecords>');
                        lines.add('    </objectPermissions>');
                    }
                }
            }
        }

        // Add field permissions
        if (fieldPerms.startsWith('fieldPerms:')) {
            String fieldData = fieldPerms.substring(11);
            if (String.isNotBlank(fieldData)) {
                List<String> fieldList = fieldData.split(';');
                for (String field : fieldList) {
                    if (String.isBlank(field)) continue;
                    List<String> parts = field.split('\\|');
                    if (parts.size() == 3) {
                        lines.add('    <fieldPermissions>');
                        lines.add('        <editable>' + parts[2] + '</editable>');
                        lines.add('        <field>' + parts[0] + '</field>');
                        lines.add('        <readable>' + parts[1] + '</readable>');
                        lines.add('    </fieldPermissions>');
                    }
                }
            }
        }

        // Add user permissions
        if (userPerms.startsWith('userPerms:')) {
            String userData = userPerms.substring(10);
            if (String.isNotBlank(userData)) {
                List<String> userList = userData.split(';');
                for (String user : userList) {
                    if (String.isBlank(user)) continue;
                    List<String> parts = user.split('\\|');
                    if (parts.size() == 2) {
                        lines.add('    <userPermissions>');
                        lines.add('        <enabled>' + parts[1] + '</enabled>');
                        lines.add('        <name>' + parts[0] + '</name>');
                        lines.add('    </userPermissions>');
                    }
                }
            }
        }

        // Add class accesses
        if (classAccess.startsWith('classAccess:')) {
            String classData = classAccess.substring(12);
            if (String.isNotBlank(classData)) {
                List<String> classList = classData.split(';');
                for (String cls : classList) {
                    if (String.isBlank(cls)) continue;
                    List<String> parts = cls.split('\\|');
                    if (parts.size() == 2) {
                        lines.add('    <classAccesses>');
                        lines.add('        <apexClass>' + parts[0] + '</apexClass>');
                        lines.add('        <enabled>' + parts[1] + '</enabled>');
                        lines.add('    </classAccesses>');
                    }
                }
            }
        }

        // Add page accesses
        if (pageAccess.startsWith('pageAccess:')) {
            String pageData = pageAccess.substring(11);
            if (String.isNotBlank(pageData)) {
                List<String> pageList = pageData.split(';');
                for (String page : pageList) {
                    if (String.isBlank(page)) continue;
                    List<String> parts = page.split('\\|');
                    if (parts.size() == 2) {
                        lines.add('    <pageAccesses>');
                        lines.add('        <apexPage>' + parts[0] + '</apexPage>');
                        lines.add('        <enabled>' + parts[1] + '</enabled>');
                        lines.add('    </pageAccesses>');
                    }
                }
            }
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }
}
