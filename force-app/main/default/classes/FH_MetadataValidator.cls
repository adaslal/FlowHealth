/**
 * FH_MetadataValidator — Pre-deployment Metadata Dependency Validator.
 *
 * Compares Source (Dev) and Destination (Prod/UAT) Permission Set XML files
 * to surface "orphaned references" — metadata (objects, fields, classes, pages,
 * tabs, record types) that exist in the Source but are absent from the
 * Destination.  These orphans cause deployment failures.
 *
 * Design:
 *   - Pure XML comparison (no Schema.getGlobalDescribe overhead).
 *   - Strategy-ready: extractReferences() can be extended for Profiles,
 *     Custom Labels, etc.
 *   - Fully stateless / testable — no DML, no SOQL.
 *
 * Usage from LWC (via FlowHealthController):
 *   FH_MetadataValidator.ValidationReport report =
 *       FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
 *
 * @since  Sprint 8 — Metadata Dependency Validator
 */
public with sharing class FH_MetadataValidator {

    // =========================================================================
    // PUBLIC RESULT WRAPPERS
    // =========================================================================

    /**
     * The validation report returned to the LWC.
     */
    public class ValidationReport {
        @AuraEnabled public Boolean isSafeToDeploy;
        @AuraEnabled public List<MissingDependency> missingObjects;
        @AuraEnabled public List<MissingDependency> missingFields;
        @AuraEnabled public List<MissingDependency> missingClasses;
        @AuraEnabled public List<MissingDependency> missingPages;
        @AuraEnabled public List<MissingDependency> missingTabs;
        @AuraEnabled public List<MissingDependency> missingRecordTypes;
        @AuraEnabled public List<MissingDependency> missingCustomPermissions;
        @AuraEnabled public List<MissingDependency> missingApplications;
        @AuraEnabled public Integer totalMissingCount;
        @AuraEnabled public String summaryMessage;
    }

    /**
     * A single missing dependency with enough context for the UI.
     * Implements Comparable so Lists can be sorted by dependencyType → name.
     * Handles managed-package namespaces (e.g. pse__) gracefully.
     */
    public class MissingDependency implements Comparable {
        @AuraEnabled public String name;           // e.g. 'Product_Display_Group__c'
        @AuraEnabled public String dependencyType; // e.g. 'CustomObject', 'CustomField'
        @AuraEnabled public String parentObject;   // For fields: the parent object name
        @AuraEnabled public String xmlContext;      // e.g. 'objectPermissions', 'fieldPermissions'

        public MissingDependency(String name, String dependencyType, String parentObject, String xmlContext) {
            this.name = name;
            this.dependencyType = dependencyType;
            this.parentObject = parentObject;
            this.xmlContext = xmlContext;
        }

        /**
         * Sort by dependencyType (alphabetical), then by name (alphabetical).
         * Null-safe for all fields.
         */
        public Integer compareTo(Object other) {
            if (other == null) return 1;
            MissingDependency that = (MissingDependency) other;

            // Primary sort: dependencyType
            String thisType = this.dependencyType != null ? this.dependencyType : '';
            String thatType = that.dependencyType != null ? that.dependencyType : '';
            Integer typeCompare = thisType.compareTo(thatType);
            if (typeCompare != 0) return typeCompare;

            // Secondary sort: name (handles namespaces like pse__ naturally)
            String thisName = this.name != null ? this.name : '';
            String thatName = that.name != null ? that.name : '';
            return thisName.compareTo(thatName);
        }
    }

    // =========================================================================
    // INTERNAL REFERENCE SET
    // =========================================================================

    /**
     * All metadata API names referenced inside a single Permission Set XML.
     */
    private class MetadataReferences {
        Set<String> objects       = new Set<String>();
        Set<String> fields        = new Set<String>();   // Object.Field format
        Set<String> classes       = new Set<String>();
        Set<String> pages         = new Set<String>();
        Set<String> tabs          = new Set<String>();
        Set<String> recordTypes   = new Set<String>();   // Object.RecordType format
        Set<String> customPerms   = new Set<String>();
        Set<String> applications  = new Set<String>();
    }

    // =========================================================================
    // PUBLIC ENTRY POINT
    // =========================================================================

    /**
     * Compare Source and Destination PermissionSet XMLs.
     * Returns a report of every dependency in Source that is absent from
     * Destination (i.e. items that would cause a deployment failure).
     *
     * @param sourceXml      The Dev / Source Org permission set XML
     * @param destinationXml The Prod / UAT Destination Org permission set XML
     * @return ValidationReport
     */
    public static ValidationReport validatePermSetDependencies(
        String sourceXml, String destinationXml
    ) {
        if (String.isBlank(sourceXml)) {
            throw new FlowMetadataService.FlowHealthException(
                'Source Permission Set XML is required for validation.'
            );
        }
        if (String.isBlank(destinationXml)) {
            throw new FlowMetadataService.FlowHealthException(
                'Destination Permission Set XML is required for validation.'
            );
        }

        MetadataReferences srcRefs  = extractReferences(sourceXml);
        MetadataReferences destRefs = extractReferences(destinationXml);

        return buildReport(srcRefs, destRefs);
    }

    // =========================================================================
    // XML REFERENCE EXTRACTION
    // =========================================================================

    /**
     * Parse a PermissionSet XML string and collect every metadata reference.
     */
    private static MetadataReferences extractReferences(String xmlContent) {
        MetadataReferences refs = new MetadataReferences();

        Dom.Document doc = new Dom.Document();
        doc.load(xmlContent);
        Dom.XmlNode root = doc.getRootElement();
        if (root == null) {
            return refs;
        }

        String ns = root.getNamespace();

        for (Dom.XmlNode child : root.getChildElements()) {
            String nodeName = child.getName();

            // objectPermissions → <object>
            if (nodeName == 'objectPermissions') {
                String objName = getChildText(child, 'object', ns);
                if (String.isNotBlank(objName)) {
                    refs.objects.add(objName);
                }
            }
            // fieldPermissions → <field> (Object.Field)
            else if (nodeName == 'fieldPermissions') {
                String fieldRef = getChildText(child, 'field', ns);
                if (String.isNotBlank(fieldRef)) {
                    refs.fields.add(fieldRef);
                    // Also track the parent object implicitly
                    if (fieldRef.contains('.')) {
                        refs.objects.add(fieldRef.substringBefore('.'));
                    }
                }
            }
            // classAccesses → <apexClass>
            else if (nodeName == 'classAccesses') {
                String className = getChildText(child, 'apexClass', ns);
                if (String.isNotBlank(className)) {
                    refs.classes.add(className);
                }
            }
            // pageAccesses → <apexPage>
            else if (nodeName == 'pageAccesses') {
                String pageName = getChildText(child, 'apexPage', ns);
                if (String.isNotBlank(pageName)) {
                    refs.pages.add(pageName);
                }
            }
            // tabSettings / tabVisibilities → <tab>
            else if (nodeName == 'tabSettings' || nodeName == 'tabVisibilities') {
                String tabName = getChildText(child, 'tab', ns);
                if (String.isNotBlank(tabName)) {
                    refs.tabs.add(tabName);
                }
            }
            // recordTypeVisibilities → <recordType> (Object.RecordType)
            else if (nodeName == 'recordTypeVisibilities') {
                String rtRef = getChildText(child, 'recordType', ns);
                if (String.isNotBlank(rtRef)) {
                    refs.recordTypes.add(rtRef);
                }
            }
            // customPermissions → <name>
            else if (nodeName == 'customPermissions') {
                String cpName = getChildText(child, 'name', ns);
                if (String.isNotBlank(cpName)) {
                    refs.customPerms.add(cpName);
                }
            }
            // applicationVisibilities → <application>
            else if (nodeName == 'applicationVisibilities') {
                String appName = getChildText(child, 'application', ns);
                if (String.isNotBlank(appName)) {
                    refs.applications.add(appName);
                }
            }
        }

        return refs;
    }

    // =========================================================================
    // DELTA COMPARISON & REPORT BUILDER
    // =========================================================================

    /**
     * Compare Source references against Destination references.
     * Anything in Source but NOT in Destination is flagged as missing.
     */
    private static ValidationReport buildReport(
        MetadataReferences src, MetadataReferences dest
    ) {
        ValidationReport report = new ValidationReport();

        report.missingObjects          = findMissingSimple(src.objects,      dest.objects,      'CustomObject', 'objectPermissions');
        report.missingFields           = findMissingFields(src.fields,       dest.fields);
        report.missingClasses          = findMissingSimple(src.classes,      dest.classes,      'ApexClass',    'classAccesses');
        report.missingPages            = findMissingSimple(src.pages,        dest.pages,        'ApexPage',     'pageAccesses');
        report.missingTabs             = findMissingSimple(src.tabs,         dest.tabs,         'Tab',          'tabSettings');
        report.missingRecordTypes      = findMissingRecordTypes(src.recordTypes, dest.recordTypes);
        report.missingCustomPermissions = findMissingSimple(src.customPerms, dest.customPerms,  'CustomPermission', 'customPermissions');
        report.missingApplications     = findMissingSimple(src.applications, dest.applications, 'Application',  'applicationVisibilities');

        // Tally totals
        Integer total = 0;
        total += report.missingObjects.size();
        total += report.missingFields.size();
        total += report.missingClasses.size();
        total += report.missingPages.size();
        total += report.missingTabs.size();
        total += report.missingRecordTypes.size();
        total += report.missingCustomPermissions.size();
        total += report.missingApplications.size();
        report.totalMissingCount = total;

        report.isSafeToDeploy = (total == 0);
        report.summaryMessage = total == 0
            ? 'Successfully validated. All Source dependencies exist in the Destination. Please proceed with Generate Patch.'
            : total + ' missing ' + (total == 1 ? 'dependency' : 'dependencies') + ' found. These exist in Source but not in Destination and will cause deployment failures.';

        return report;
    }

    /**
     * Simple set-diff for single-name references (objects, classes, pages, tabs, etc.)
     */
    private static List<MissingDependency> findMissingSimple(
        Set<String> srcSet, Set<String> destSet, String depType, String xmlCtx
    ) {
        List<MissingDependency> missing = new List<MissingDependency>();
        for (String item : srcSet) {
            if (!destSet.contains(item)) {
                missing.add(new MissingDependency(item, depType, null, xmlCtx));
            }
        }
        missing.sort();
        return missing;
    }

    /**
     * Field-specific diff: handles Object.Field format, reports parent object.
     */
    private static List<MissingDependency> findMissingFields(
        Set<String> srcFields, Set<String> destFields
    ) {
        List<MissingDependency> missing = new List<MissingDependency>();
        for (String fieldRef : srcFields) {
            if (!destFields.contains(fieldRef)) {
                String parentObj = fieldRef.contains('.')
                    ? fieldRef.substringBefore('.')
                    : null;
                String fieldName = fieldRef.contains('.')
                    ? fieldRef.substringAfter('.')
                    : fieldRef;
                missing.add(new MissingDependency(
                    fieldRef, 'CustomField', parentObj, 'fieldPermissions'
                ));
            }
        }
        missing.sort();
        return missing;
    }

    /**
     * RecordType-specific diff: handles Object.RecordType format.
     */
    private static List<MissingDependency> findMissingRecordTypes(
        Set<String> srcRTs, Set<String> destRTs
    ) {
        List<MissingDependency> missing = new List<MissingDependency>();
        for (String rtRef : srcRTs) {
            if (!destRTs.contains(rtRef)) {
                String parentObj = rtRef.contains('.')
                    ? rtRef.substringBefore('.')
                    : null;
                missing.add(new MissingDependency(
                    rtRef, 'RecordType', parentObj, 'recordTypeVisibilities'
                ));
            }
        }
        missing.sort();
        return missing;
    }

    // =========================================================================
    // XML HELPER
    // =========================================================================

    /**
     * Safely get child element text content.
     */
    private static String getChildText(Dom.XmlNode parent, String childName, String ns) {
        Dom.XmlNode child = parent.getChildElement(childName, ns);
        return child != null ? child.getText() : null;
    }
}
