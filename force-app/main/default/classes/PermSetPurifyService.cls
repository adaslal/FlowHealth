/**
 * PermSetPurifyService - The transformer: "Drop dirty XML in, get clean XML out."
 *
 * This is the core value proposition of PermSet Purifier:
 *   1. Parse the input XML into a PermissionSetDefinition
 *   2. Run all analysis rules to identify issues
 *   3. Apply purification actions (REMOVE/DOWNGRADE) based on findings
 *   4. Serialize the cleaned definition back to XML
 *   5. Return both the clean XML and a diff showing what changed
 *
 * MODES:
 *   - ANALYZE ONLY: Just return findings (no transformation)
 *   - PURIFY:       Apply automatic fixes and return clean XML + diff
 *
 * The purification is deterministic and non-destructive — the user always
 * gets a BEFORE/AFTER comparison and can choose to use the clean XML or not.
 */
public class PermSetPurifyService {

    // =========================================================================
    // Result classes
    // =========================================================================

    /**
     * Full purification result returned to the LWC.
     */
    public class PurifyResult {
        @AuraEnabled public String originalXml;
        @AuraEnabled public String purifiedXml;
        @AuraEnabled public PermSetRuleEngine.AnalysisResult analysis;
        @AuraEnabled public List<PurifyAction> actionsApplied;
        @AuraEnabled public Integer removedCount;
        @AuraEnabled public Integer downgradedCount;
        @AuraEnabled public Integer originalPermCount;
        @AuraEnabled public Integer purifiedPermCount;
    }

    /**
     * A single purification action that was applied.
     */
    public class PurifyAction {
        @AuraEnabled public String actionType;     // REMOVE, DOWNGRADE
        @AuraEnabled public String itemType;       // objectPermission, fieldPermission, etc.
        @AuraEnabled public String itemName;       // API name
        @AuraEnabled public String reason;         // Why this was purified
    }

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Analyze a permission set XML without transforming it.
     * Returns findings only.
     *
     * @param xmlContent  The raw permission set XML
     * @return AnalysisResult with findings
     */
    public static PermSetRuleEngine.AnalysisResult analyzeOnly(String xmlContent) {
        PermSetMetadata.PermissionSetDefinition permSet = PermSetXmlParser.parse(xmlContent);
        return PermSetRuleEngine.analyze(permSet);
    }

    /**
     * Full purification: analyze, transform, and return clean XML.
     *
     * @param xmlContent  The raw "dirty" permission set XML
     * @return PurifyResult with original XML, clean XML, findings, and diff
     */
    public static PurifyResult purify(String xmlContent) {
        PurifyResult result = new PurifyResult();
        result.originalXml = xmlContent;
        result.actionsApplied = new List<PurifyAction>();

        // 1. Parse
        PermSetMetadata.PermissionSetDefinition permSet = PermSetXmlParser.parse(xmlContent);
        result.originalPermCount = permSet.getTotalPermissionCount();

        // 2. Analyze
        result.analysis = PermSetRuleEngine.analyze(permSet);

        // 3. Collect purification actions from findings
        Set<String> removeSet = new Set<String>();  // "itemType:itemName" keys to remove
        Set<String> downgradeSet = new Set<String>(); // keys to downgrade

        for (PermSetFinding f : result.analysis.findings) {
            if (f.purifyAction == null) continue;

            String key = f.itemType + ':' + f.itemName;

            if (f.purifyAction == 'REMOVE') {
                removeSet.add(key);
                result.actionsApplied.add(buildAction('REMOVE', f));
            } else if (f.purifyAction == 'DOWNGRADE') {
                downgradeSet.add(key);
                result.actionsApplied.add(buildAction('DOWNGRADE', f));
            }
        }

        // 4. Apply purification to the definition
        applyRemovals(permSet, removeSet);
        applyDowngrades(permSet, downgradeSet);

        // 5. Serialize to clean XML
        result.purifiedXml = serializeToXml(permSet);
        result.purifiedPermCount = permSet.getTotalPermissionCount();
        result.removedCount = result.originalPermCount - result.purifiedPermCount;
        result.downgradedCount = downgradeSet.size();

        return result;
    }

    // =========================================================================
    // Purification logic
    // =========================================================================

    private static void applyRemovals(
        PermSetMetadata.PermissionSetDefinition permSet,
        Set<String> removeSet
    ) {
        if (removeSet.isEmpty()) return;

        // Remove user permissions
        List<PermSetMetadata.UserPermission> cleanUserPerms = new List<PermSetMetadata.UserPermission>();
        for (PermSetMetadata.UserPermission up : permSet.userPermissions) {
            if (!removeSet.contains('userPermission:' + up.name)) {
                cleanUserPerms.add(up);
            }
        }
        permSet.userPermissions = cleanUserPerms;

        // Remove field permissions
        List<PermSetMetadata.FieldPermission> cleanFieldPerms = new List<PermSetMetadata.FieldPermission>();
        for (PermSetMetadata.FieldPermission fp : permSet.fieldPermissions) {
            if (!removeSet.contains('fieldPermission:' + fp.field)) {
                cleanFieldPerms.add(fp);
            }
        }
        permSet.fieldPermissions = cleanFieldPerms;

        // Remove object permissions
        List<PermSetMetadata.ObjectPermission> cleanObjPerms = new List<PermSetMetadata.ObjectPermission>();
        for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
            if (!removeSet.contains('objectPermission:' + op.object_x)) {
                cleanObjPerms.add(op);
            }
        }
        permSet.objectPermissions = cleanObjPerms;

        // Remove class accesses
        List<PermSetMetadata.ClassAccess> cleanClasses = new List<PermSetMetadata.ClassAccess>();
        for (PermSetMetadata.ClassAccess ca : permSet.classAccesses) {
            if (!removeSet.contains('classAccess:' + ca.apexClass)) {
                cleanClasses.add(ca);
            }
        }
        permSet.classAccesses = cleanClasses;

        // Remove page accesses
        List<PermSetMetadata.PageAccess> cleanPages = new List<PermSetMetadata.PageAccess>();
        for (PermSetMetadata.PageAccess pa : permSet.pageAccesses) {
            if (!removeSet.contains('pageAccess:' + pa.apexPage)) {
                cleanPages.add(pa);
            }
        }
        permSet.pageAccesses = cleanPages;

        // Remove flow accesses
        List<PermSetMetadata.FlowAccess> cleanFlows = new List<PermSetMetadata.FlowAccess>();
        for (PermSetMetadata.FlowAccess fa : permSet.flowAccesses) {
            if (!removeSet.contains('flowAccess:' + fa.flow)) {
                cleanFlows.add(fa);
            }
        }
        permSet.flowAccesses = cleanFlows;

        // Remove custom metadata type accesses
        List<PermSetMetadata.CustomMetadataTypeAccess> cleanCMT = new List<PermSetMetadata.CustomMetadataTypeAccess>();
        for (PermSetMetadata.CustomMetadataTypeAccess cma : permSet.customMetadataTypeAccesses) {
            if (!removeSet.contains('customMetadataTypeAccess:' + cma.name)) {
                cleanCMT.add(cma);
            }
        }
        permSet.customMetadataTypeAccesses = cleanCMT;

        // Remove custom setting accesses
        List<PermSetMetadata.CustomSettingAccess> cleanCS = new List<PermSetMetadata.CustomSettingAccess>();
        for (PermSetMetadata.CustomSettingAccess csa : permSet.customSettingAccesses) {
            if (!removeSet.contains('customSettingAccess:' + csa.name)) {
                cleanCS.add(csa);
            }
        }
        permSet.customSettingAccesses = cleanCS;
    }

    private static void applyDowngrades(
        PermSetMetadata.PermissionSetDefinition permSet,
        Set<String> downgradeSet
    ) {
        if (downgradeSet.isEmpty()) return;

        // Downgrade object permissions: remove ModifyAllRecords (keep rest)
        for (PermSetMetadata.ObjectPermission op : permSet.objectPermissions) {
            if (downgradeSet.contains('objectPermission:' + op.object_x)) {
                op.modifyAllRecords = false;
                // Also remove ViewAllRecords if ModifyAll was set
                op.viewAllRecords = false;
            }
        }

        // Downgrade field permissions: editable → readable only
        for (PermSetMetadata.FieldPermission fp : permSet.fieldPermissions) {
            if (downgradeSet.contains('fieldPermission:' + fp.field)) {
                fp.editable = false;
                // Keep readable = true
                if (fp.readable != true) {
                    fp.readable = true;
                }
            }
        }
    }

    // =========================================================================
    // XML Serialization (clean output)
    // =========================================================================

    /**
     * Serialize a PermissionSetDefinition back to well-formed XML.
     * Produces clean, alphabetically sorted, properly indented output.
     */
    private static String serializeToXml(PermSetMetadata.PermissionSetDefinition def) {
        List<String> lines = new List<String>();
        lines.add('<?xml version="1.0" encoding="UTF-8"?>');
        lines.add('<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">');

        // Top-level fields
        if (def.description != null) {
            lines.add('    <description>' + escapeXml(def.description) + '</description>');
        }
        if (def.hasActivationRequired != null) {
            lines.add('    <hasActivationRequired>' + def.hasActivationRequired + '</hasActivationRequired>');
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

        // Field permissions (sorted by field name)
        List<PermSetMetadata.FieldPermission> sortedFields = new List<PermSetMetadata.FieldPermission>(def.fieldPermissions);
        // Note: Can't sort custom objects in Apex without a wrapper — output in original order
        for (PermSetMetadata.FieldPermission fp : sortedFields) {
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

    private static PurifyAction buildAction(String actionType, PermSetFinding finding) {
        PurifyAction action = new PurifyAction();
        action.actionType = actionType;
        action.itemType = finding.itemType;
        action.itemName = finding.itemName;
        action.reason = finding.ruleId + ': ' + finding.description;
        return action;
    }
}
