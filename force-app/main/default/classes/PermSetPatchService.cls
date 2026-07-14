/**
 * PermSetPatchService - Surgical Merge for Permission Sets.
 *
 * CONCEPT: "Destination-based merging" — prevents destructive overwrites
 * during deployment by reconciling a Source (Dev) perm set with the
 * Destination (Prod/Target) perm set.
 *
 * ALGORITHM:
 *   1. Parse both XMLs into PermissionSetDefinition objects
 *   2. Use Destination as the base (the "truth" from Production)
 *   3. Iterate Source permissions: if new or different, "patch" into Destination
 *   4. Never remove permissions that exist in Destination but not in Source
 *   5. Output a complete merged XML
 *
 * This ensures we never accidentally remove a permission that exists in
 * Production but was missing from the Dev branch.
 */
public class PermSetPatchService {

    // =========================================================================
    // Result classes
    // =========================================================================

    /**
     * Full patch result returned to the LWC.
     */
    public class PatchResult {
        @AuraEnabled public String destinationXml;
        @AuraEnabled public String sourceXml;
        @AuraEnabled public String patchedXml;
        @AuraEnabled public List<PatchAction> actionsApplied;
        @AuraEnabled public Integer destinationPermCount;
        @AuraEnabled public Integer sourcePermCount;
        @AuraEnabled public Integer patchedPermCount;
        @AuraEnabled public Integer addedCount;
        @AuraEnabled public Integer modifiedCount;
        @AuraEnabled public Integer preservedCount;
    }

    /**
     * A single patch action that was applied during reconciliation.
     */
    public class PatchAction {
        @AuraEnabled public String actionType;     // ADDED, MODIFIED, PRESERVED
        @AuraEnabled public String itemType;       // objectPermission, fieldPermission, etc.
        @AuraEnabled public String itemName;       // API name / key
        @AuraEnabled public String detail;         // Human-readable description of what changed
    }

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Generate a patched Permission Set XML by merging Source into Destination.
     *
     * @param destinationXml  The "truth" from the target/production Org
     * @param sourceXml       The new changes from the dev Org
     * @return PatchResult with merged XML and diff details
     */
    public static PatchResult generatePatch(String destinationXml, String sourceXml) {
        PatchResult result = new PatchResult();
        result.destinationXml = destinationXml;
        result.sourceXml = sourceXml;
        result.actionsApplied = new List<PatchAction>();

        // 1. Parse both
        PermSetMetadata.PermissionSetDefinition dest = PermSetXmlParser.parse(destinationXml);
        PermSetMetadata.PermissionSetDefinition src = PermSetXmlParser.parse(sourceXml);

        result.destinationPermCount = dest.getTotalPermissionCount();
        result.sourcePermCount = src.getTotalPermissionCount();

        // 2. Reconcile each permission block using Map-based merging
        Integer added = 0;
        Integer modified = 0;

        // --- Object Permissions ---
        PatchCounts objCounts = mergeObjectPermissions(dest, src, result.actionsApplied);
        added += objCounts.added;
        modified += objCounts.modified;

        // --- Field Permissions ---
        PatchCounts fieldCounts = mergeFieldPermissions(dest, src, result.actionsApplied);
        added += fieldCounts.added;
        modified += fieldCounts.modified;

        // --- User Permissions ---
        PatchCounts userCounts = mergeUserPermissions(dest, src, result.actionsApplied);
        added += userCounts.added;
        modified += userCounts.modified;

        // --- Tab Settings ---
        PatchCounts tabCounts = mergeTabSettings(dest, src, result.actionsApplied);
        added += tabCounts.added;
        modified += tabCounts.modified;

        // --- Class Accesses ---
        PatchCounts classCounts = mergeClassAccesses(dest, src, result.actionsApplied);
        added += classCounts.added;
        modified += classCounts.modified;

        // --- Page Accesses ---
        PatchCounts pageCounts = mergePageAccesses(dest, src, result.actionsApplied);
        added += pageCounts.added;
        modified += pageCounts.modified;

        // --- Record Type Visibilities ---
        PatchCounts rtCounts = mergeRecordTypeVisibilities(dest, src, result.actionsApplied);
        added += rtCounts.added;
        modified += rtCounts.modified;

        // --- Application Visibilities ---
        PatchCounts appCounts = mergeApplicationVisibilities(dest, src, result.actionsApplied);
        added += appCounts.added;
        modified += appCounts.modified;

        // --- Custom Metadata Type Accesses ---
        PatchCounts cmtCounts = mergeCustomMetadataTypeAccesses(dest, src, result.actionsApplied);
        added += cmtCounts.added;
        modified += cmtCounts.modified;

        // --- Custom Setting Accesses ---
        PatchCounts csCounts = mergeCustomSettingAccesses(dest, src, result.actionsApplied);
        added += csCounts.added;
        modified += csCounts.modified;

        // --- Flow Accesses ---
        PatchCounts flowCounts = mergeFlowAccesses(dest, src, result.actionsApplied);
        added += flowCounts.added;
        modified += flowCounts.modified;

        // --- Custom Permissions ---
        PatchCounts cpCounts = mergeCustomPermissions(dest, src, result.actionsApplied);
        added += cpCounts.added;
        modified += cpCounts.modified;

        // 3. Patch top-level metadata from source (label, description) if source has them
        patchTopLevelMetadata(dest, src);

        // 4. Serialize the merged definition
        result.patchedXml = serializeToXml(dest);
        result.patchedPermCount = dest.getTotalPermissionCount();
        result.addedCount = added;
        result.modifiedCount = modified;
        result.preservedCount = result.patchedPermCount - added - modified;

        return result;
    }

    // =========================================================================
    // Helper: PatchCounts
    // =========================================================================

    private class PatchCounts {
        Integer added = 0;
        Integer modified = 0;
    }

    // =========================================================================
    // Top-level metadata patching
    // =========================================================================

    private static void patchTopLevelMetadata(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src
    ) {
        // Only overwrite if source has explicit values
        if (src.label != null) dest.label = src.label;
        if (src.description != null) dest.description = src.description;
        if (src.license != null) dest.license = src.license;
        if (src.hasActivationRequired != null) dest.hasActivationRequired = src.hasActivationRequired;
    }

    // =========================================================================
    // Object Permissions merge
    // =========================================================================

    private static PatchCounts mergeObjectPermissions(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        // Build destination map keyed by object name
        Map<String, PermSetMetadata.ObjectPermission> destMap = new Map<String, PermSetMetadata.ObjectPermission>();
        for (PermSetMetadata.ObjectPermission op : dest.objectPermissions) {
            if (op.object_x != null) destMap.put(op.object_x, op);
        }

        // Merge source into destination
        for (PermSetMetadata.ObjectPermission srcOp : src.objectPermissions) {
            if (srcOp.object_x == null) continue;

            if (!destMap.containsKey(srcOp.object_x)) {
                // NEW: add from source
                dest.objectPermissions.add(srcOp);
                destMap.put(srcOp.object_x, srcOp);
                counts.added++;
                actions.add(buildAction('ADDED', 'objectPermission', srcOp.object_x,
                    'New object permission added from source'));
            } else {
                // EXISTS: patch if source grants more access
                PermSetMetadata.ObjectPermission destOp = destMap.get(srcOp.object_x);
                List<String> changes = new List<String>();

                if (srcOp.allowCreate == true && destOp.allowCreate != true) {
                    destOp.allowCreate = true; changes.add('allowCreate');
                }
                if (srcOp.allowRead == true && destOp.allowRead != true) {
                    destOp.allowRead = true; changes.add('allowRead');
                }
                if (srcOp.allowEdit == true && destOp.allowEdit != true) {
                    destOp.allowEdit = true; changes.add('allowEdit');
                }
                if (srcOp.allowDelete == true && destOp.allowDelete != true) {
                    destOp.allowDelete = true; changes.add('allowDelete');
                }
                if (srcOp.viewAllRecords == true && destOp.viewAllRecords != true) {
                    destOp.viewAllRecords = true; changes.add('viewAllRecords');
                }
                if (srcOp.modifyAllRecords == true && destOp.modifyAllRecords != true) {
                    destOp.modifyAllRecords = true; changes.add('modifyAllRecords');
                }

                if (!changes.isEmpty()) {
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'objectPermission', srcOp.object_x,
                        'Elevated: ' + String.join(changes, ', ')));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Field Permissions merge
    // =========================================================================

    private static PatchCounts mergeFieldPermissions(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.FieldPermission> destMap = new Map<String, PermSetMetadata.FieldPermission>();
        for (PermSetMetadata.FieldPermission fp : dest.fieldPermissions) {
            if (fp.field != null) destMap.put(fp.field, fp);
        }

        for (PermSetMetadata.FieldPermission srcFp : src.fieldPermissions) {
            if (srcFp.field == null) continue;

            if (!destMap.containsKey(srcFp.field)) {
                dest.fieldPermissions.add(srcFp);
                counts.added++;
                actions.add(buildAction('ADDED', 'fieldPermission', srcFp.field,
                    'New field permission added from source'));
            } else {
                PermSetMetadata.FieldPermission destFp = destMap.get(srcFp.field);
                List<String> changes = new List<String>();

                if (srcFp.readable == true && destFp.readable != true) {
                    destFp.readable = true; changes.add('readable');
                }
                if (srcFp.editable == true && destFp.editable != true) {
                    destFp.editable = true; changes.add('editable');
                }

                if (!changes.isEmpty()) {
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'fieldPermission', srcFp.field,
                        'Elevated: ' + String.join(changes, ', ')));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // User Permissions merge
    // =========================================================================

    private static PatchCounts mergeUserPermissions(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.UserPermission> destMap = new Map<String, PermSetMetadata.UserPermission>();
        for (PermSetMetadata.UserPermission up : dest.userPermissions) {
            if (up.name != null) destMap.put(up.name, up);
        }

        for (PermSetMetadata.UserPermission srcUp : src.userPermissions) {
            if (srcUp.name == null) continue;

            if (!destMap.containsKey(srcUp.name)) {
                dest.userPermissions.add(srcUp);
                counts.added++;
                actions.add(buildAction('ADDED', 'userPermission', srcUp.name,
                    'New user permission added from source'));
            } else {
                PermSetMetadata.UserPermission destUp = destMap.get(srcUp.name);
                if (srcUp.enabled == true && destUp.enabled != true) {
                    destUp.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'userPermission', srcUp.name,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Tab Settings merge
    // =========================================================================

    private static PatchCounts mergeTabSettings(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.TabSetting> destMap = new Map<String, PermSetMetadata.TabSetting>();
        for (PermSetMetadata.TabSetting ts : dest.tabSettings) {
            if (ts.tab != null) destMap.put(ts.tab, ts);
        }

        for (PermSetMetadata.TabSetting srcTs : src.tabSettings) {
            if (srcTs.tab == null) continue;

            if (!destMap.containsKey(srcTs.tab)) {
                dest.tabSettings.add(srcTs);
                counts.added++;
                actions.add(buildAction('ADDED', 'tabSetting', srcTs.tab,
                    'New tab setting: ' + srcTs.visibility));
            } else {
                PermSetMetadata.TabSetting destTs = destMap.get(srcTs.tab);
                if (srcTs.visibility != null && srcTs.visibility != destTs.visibility) {
                    destTs.visibility = srcTs.visibility;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'tabSetting', srcTs.tab,
                        'Visibility changed to: ' + srcTs.visibility));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Class Accesses merge
    // =========================================================================

    private static PatchCounts mergeClassAccesses(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.ClassAccess> destMap = new Map<String, PermSetMetadata.ClassAccess>();
        for (PermSetMetadata.ClassAccess ca : dest.classAccesses) {
            if (ca.apexClass != null) destMap.put(ca.apexClass, ca);
        }

        for (PermSetMetadata.ClassAccess srcCa : src.classAccesses) {
            if (srcCa.apexClass == null) continue;

            if (!destMap.containsKey(srcCa.apexClass)) {
                dest.classAccesses.add(srcCa);
                counts.added++;
                actions.add(buildAction('ADDED', 'classAccess', srcCa.apexClass,
                    'New Apex class access added'));
            } else {
                PermSetMetadata.ClassAccess destCa = destMap.get(srcCa.apexClass);
                if (srcCa.enabled == true && destCa.enabled != true) {
                    destCa.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'classAccess', srcCa.apexClass,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Page Accesses merge
    // =========================================================================

    private static PatchCounts mergePageAccesses(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.PageAccess> destMap = new Map<String, PermSetMetadata.PageAccess>();
        for (PermSetMetadata.PageAccess pa : dest.pageAccesses) {
            if (pa.apexPage != null) destMap.put(pa.apexPage, pa);
        }

        for (PermSetMetadata.PageAccess srcPa : src.pageAccesses) {
            if (srcPa.apexPage == null) continue;

            if (!destMap.containsKey(srcPa.apexPage)) {
                dest.pageAccesses.add(srcPa);
                counts.added++;
                actions.add(buildAction('ADDED', 'pageAccess', srcPa.apexPage,
                    'New VF page access added'));
            } else {
                PermSetMetadata.PageAccess destPa = destMap.get(srcPa.apexPage);
                if (srcPa.enabled == true && destPa.enabled != true) {
                    destPa.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'pageAccess', srcPa.apexPage,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Record Type Visibilities merge
    // =========================================================================

    private static PatchCounts mergeRecordTypeVisibilities(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.RecordTypeVisibility> destMap = new Map<String, PermSetMetadata.RecordTypeVisibility>();
        for (PermSetMetadata.RecordTypeVisibility rtv : dest.recordTypeVisibilities) {
            if (rtv.recordType != null) destMap.put(rtv.recordType, rtv);
        }

        for (PermSetMetadata.RecordTypeVisibility srcRtv : src.recordTypeVisibilities) {
            if (srcRtv.recordType == null) continue;

            if (!destMap.containsKey(srcRtv.recordType)) {
                dest.recordTypeVisibilities.add(srcRtv);
                counts.added++;
                actions.add(buildAction('ADDED', 'recordTypeVisibility', srcRtv.recordType,
                    'New record type visibility added'));
            } else {
                PermSetMetadata.RecordTypeVisibility destRtv = destMap.get(srcRtv.recordType);
                if (srcRtv.visible == true && destRtv.visible != true) {
                    destRtv.visible = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'recordTypeVisibility', srcRtv.recordType,
                        'Made visible (was hidden in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Application Visibilities merge
    // =========================================================================

    private static PatchCounts mergeApplicationVisibilities(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.ApplicationVisibility> destMap = new Map<String, PermSetMetadata.ApplicationVisibility>();
        for (PermSetMetadata.ApplicationVisibility av : dest.applicationVisibilities) {
            if (av.application != null) destMap.put(av.application, av);
        }

        for (PermSetMetadata.ApplicationVisibility srcAv : src.applicationVisibilities) {
            if (srcAv.application == null) continue;

            if (!destMap.containsKey(srcAv.application)) {
                dest.applicationVisibilities.add(srcAv);
                counts.added++;
                actions.add(buildAction('ADDED', 'applicationVisibility', srcAv.application,
                    'New application visibility added'));
            } else {
                PermSetMetadata.ApplicationVisibility destAv = destMap.get(srcAv.application);
                if (srcAv.visible == true && destAv.visible != true) {
                    destAv.visible = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'applicationVisibility', srcAv.application,
                        'Made visible (was hidden in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Custom Metadata Type Accesses merge
    // =========================================================================

    private static PatchCounts mergeCustomMetadataTypeAccesses(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.CustomMetadataTypeAccess> destMap = new Map<String, PermSetMetadata.CustomMetadataTypeAccess>();
        for (PermSetMetadata.CustomMetadataTypeAccess cma : dest.customMetadataTypeAccesses) {
            if (cma.name != null) destMap.put(cma.name, cma);
        }

        for (PermSetMetadata.CustomMetadataTypeAccess srcCma : src.customMetadataTypeAccesses) {
            if (srcCma.name == null) continue;

            if (!destMap.containsKey(srcCma.name)) {
                dest.customMetadataTypeAccesses.add(srcCma);
                counts.added++;
                actions.add(buildAction('ADDED', 'customMetadataTypeAccess', srcCma.name,
                    'New custom metadata type access added'));
            } else {
                PermSetMetadata.CustomMetadataTypeAccess destCma = destMap.get(srcCma.name);
                if (srcCma.enabled == true && destCma.enabled != true) {
                    destCma.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'customMetadataTypeAccess', srcCma.name,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Custom Setting Accesses merge
    // =========================================================================

    private static PatchCounts mergeCustomSettingAccesses(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.CustomSettingAccess> destMap = new Map<String, PermSetMetadata.CustomSettingAccess>();
        for (PermSetMetadata.CustomSettingAccess csa : dest.customSettingAccesses) {
            if (csa.name != null) destMap.put(csa.name, csa);
        }

        for (PermSetMetadata.CustomSettingAccess srcCsa : src.customSettingAccesses) {
            if (srcCsa.name == null) continue;

            if (!destMap.containsKey(srcCsa.name)) {
                dest.customSettingAccesses.add(srcCsa);
                counts.added++;
                actions.add(buildAction('ADDED', 'customSettingAccess', srcCsa.name,
                    'New custom setting access added'));
            } else {
                PermSetMetadata.CustomSettingAccess destCsa = destMap.get(srcCsa.name);
                if (srcCsa.enabled == true && destCsa.enabled != true) {
                    destCsa.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'customSettingAccess', srcCsa.name,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Flow Accesses merge
    // =========================================================================

    private static PatchCounts mergeFlowAccesses(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.FlowAccess> destMap = new Map<String, PermSetMetadata.FlowAccess>();
        for (PermSetMetadata.FlowAccess fa : dest.flowAccesses) {
            if (fa.flow != null) destMap.put(fa.flow, fa);
        }

        for (PermSetMetadata.FlowAccess srcFa : src.flowAccesses) {
            if (srcFa.flow == null) continue;

            if (!destMap.containsKey(srcFa.flow)) {
                dest.flowAccesses.add(srcFa);
                counts.added++;
                actions.add(buildAction('ADDED', 'flowAccess', srcFa.flow,
                    'New flow access added'));
            } else {
                PermSetMetadata.FlowAccess destFa = destMap.get(srcFa.flow);
                if (srcFa.enabled == true && destFa.enabled != true) {
                    destFa.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'flowAccess', srcFa.flow,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // Custom Permissions merge
    // =========================================================================

    private static PatchCounts mergeCustomPermissions(
        PermSetMetadata.PermissionSetDefinition dest,
        PermSetMetadata.PermissionSetDefinition src,
        List<PatchAction> actions
    ) {
        PatchCounts counts = new PatchCounts();

        Map<String, PermSetMetadata.CustomPermission> destMap = new Map<String, PermSetMetadata.CustomPermission>();
        for (PermSetMetadata.CustomPermission cp : dest.customPermissions) {
            if (cp.name != null) destMap.put(cp.name, cp);
        }

        for (PermSetMetadata.CustomPermission srcCp : src.customPermissions) {
            if (srcCp.name == null) continue;

            if (!destMap.containsKey(srcCp.name)) {
                dest.customPermissions.add(srcCp);
                counts.added++;
                actions.add(buildAction('ADDED', 'customPermission', srcCp.name,
                    'New custom permission added'));
            } else {
                PermSetMetadata.CustomPermission destCp = destMap.get(srcCp.name);
                if (srcCp.enabled == true && destCp.enabled != true) {
                    destCp.enabled = true;
                    counts.modified++;
                    actions.add(buildAction('MODIFIED', 'customPermission', srcCp.name,
                        'Enabled (was disabled in destination)'));
                }
            }
        }
        return counts;
    }

    // =========================================================================
    // XML Serialization (reuses the same clean output format)
    // =========================================================================

    private static String serializeToXml(PermSetMetadata.PermissionSetDefinition def) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');

        // Top-level fields
        if (def.description != null) {
            lines.add('    <description>' + escapeXml(def.description) + '</description>');
        }
        // Emit only when true: absent means false in Salesforce semantics, and
        // the parser defaults absent → false. Emitting "false" here would make
        // a no-op patch differ textually from its input XML.
        if (def.hasActivationRequired == true) {
            lines.add('    <hasActivationRequired>true</hasActivationRequired>');
        }
        if (def.label != null) {
            lines.add('    <label>' + escapeXml(def.label) + '</label>');
        }
        if (def.license != null) {
            lines.add('    <license>' + escapeXml(def.license) + '</license>');
        }

        // Application visibilities
        for (PermSetMetadata.ApplicationVisibility av : def.applicationVisibilities) {
            lines.add('    <applicationVisibilities>');
            lines.add('        <application>' + escapeXml(av.application) + '</application>');
            if (av.isDefault != null) {
                lines.add('        <default>' + av.isDefault + '</default>');
            }
            lines.add('        <visible>' + (av.visible == true) + '</visible>');
            lines.add('    </applicationVisibilities>');
        }

        // Class accesses
        for (PermSetMetadata.ClassAccess ca : def.classAccesses) {
            lines.add('    <classAccesses>');
            lines.add('        <apexClass>' + escapeXml(ca.apexClass) + '</apexClass>');
            lines.add('        <enabled>' + (ca.enabled == true) + '</enabled>');
            lines.add('    </classAccesses>');
        }

        // Custom metadata type accesses
        for (PermSetMetadata.CustomMetadataTypeAccess cma : def.customMetadataTypeAccesses) {
            lines.add('    <customMetadataTypeAccesses>');
            lines.add('        <name>' + escapeXml(cma.name) + '</name>');
            lines.add('        <enabled>' + (cma.enabled == true) + '</enabled>');
            lines.add('    </customMetadataTypeAccesses>');
        }

        // Custom permissions
        for (PermSetMetadata.CustomPermission cp : def.customPermissions) {
            lines.add('    <customPermissions>');
            lines.add('        <name>' + escapeXml(cp.name) + '</name>');
            lines.add('        <enabled>' + (cp.enabled == true) + '</enabled>');
            lines.add('    </customPermissions>');
        }

        // Custom setting accesses
        for (PermSetMetadata.CustomSettingAccess csa : def.customSettingAccesses) {
            lines.add('    <customSettingAccesses>');
            lines.add('        <name>' + escapeXml(csa.name) + '</name>');
            lines.add('        <enabled>' + (csa.enabled == true) + '</enabled>');
            lines.add('    </customSettingAccesses>');
        }

        // Field permissions
        for (PermSetMetadata.FieldPermission fp : def.fieldPermissions) {
            lines.add('    <fieldPermissions>');
            lines.add('        <editable>' + (fp.editable == true) + '</editable>');
            lines.add('        <field>' + escapeXml(fp.field) + '</field>');
            lines.add('        <readable>' + (fp.readable == true) + '</readable>');
            lines.add('    </fieldPermissions>');
        }

        // Flow accesses
        for (PermSetMetadata.FlowAccess fa : def.flowAccesses) {
            lines.add('    <flowAccesses>');
            lines.add('        <enabled>' + (fa.enabled == true) + '</enabled>');
            lines.add('        <flow>' + escapeXml(fa.flow) + '</flow>');
            lines.add('    </flowAccesses>');
        }

        // Object permissions
        for (PermSetMetadata.ObjectPermission op : def.objectPermissions) {
            lines.add('    <objectPermissions>');
            lines.add('        <allowCreate>' + (op.allowCreate == true) + '</allowCreate>');
            lines.add('        <allowDelete>' + (op.allowDelete == true) + '</allowDelete>');
            lines.add('        <allowEdit>' + (op.allowEdit == true) + '</allowEdit>');
            lines.add('        <allowRead>' + (op.allowRead == true) + '</allowRead>');
            lines.add('        <modifyAllRecords>' + (op.modifyAllRecords == true) + '</modifyAllRecords>');
            lines.add('        <object>' + escapeXml(op.object_x) + '</object>');
            lines.add('        <viewAllRecords>' + (op.viewAllRecords == true) + '</viewAllRecords>');
            lines.add('    </objectPermissions>');
        }

        // Page accesses
        for (PermSetMetadata.PageAccess pa : def.pageAccesses) {
            lines.add('    <pageAccesses>');
            lines.add('        <apexPage>' + escapeXml(pa.apexPage) + '</apexPage>');
            lines.add('        <enabled>' + (pa.enabled == true) + '</enabled>');
            lines.add('    </pageAccesses>');
        }

        // Record type visibilities
        for (PermSetMetadata.RecordTypeVisibility rtv : def.recordTypeVisibilities) {
            lines.add('    <recordTypeVisibilities>');
            if (rtv.personAccountDefault != null) {
                lines.add('        <personAccountDefault>' + rtv.personAccountDefault + '</personAccountDefault>');
            }
            lines.add('        <recordType>' + escapeXml(rtv.recordType) + '</recordType>');
            lines.add('        <visible>' + (rtv.visible == true) + '</visible>');
            lines.add('    </recordTypeVisibilities>');
        }

        // Tab settings
        for (PermSetMetadata.TabSetting ts : def.tabSettings) {
            lines.add('    <tabSettings>');
            lines.add('        <tab>' + escapeXml(ts.tab) + '</tab>');
            lines.add('        <visibility>' + escapeXml(ts.visibility) + '</visibility>');
            lines.add('    </tabSettings>');
        }

        // User permissions
        for (PermSetMetadata.UserPermission up : def.userPermissions) {
            lines.add('    <userPermissions>');
            lines.add('        <enabled>' + (up.enabled == true) + '</enabled>');
            lines.add('        <name>' + escapeXml(up.name) + '</name>');
            lines.add('    </userPermissions>');
        }

        lines.add('</PermissionSet>');
        return String.join(lines, '\n');
    }

    private static String escapeXml(String text) {
        if (text == null) return '';
        return text.replace('&', '&amp;')
                   .replace('<', '&lt;')
                   .replace('>', '&gt;')
                   .replace('"', '&quot;')
                   .replace('\'', '&apos;');
    }

    private static PatchAction buildAction(String actionType, String itemType, String itemName, String detail) {
        PatchAction action = new PatchAction();
        action.actionType = actionType;
        action.itemType = itemType;
        action.itemName = itemName;
        action.detail = detail;
        return action;
    }
}
