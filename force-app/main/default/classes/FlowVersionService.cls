/**
 * FlowVersionService - Fetches all versions of a flow from the Tooling API.
 *
 * The Tooling API stores every saved version of a flow. This service:
 *   1. Lists all versions of a flow (for the version selector dropdown)
 *   2. Fetches the full metadata for a specific version (by Flow record Id)
 *   3. Provides a convenience method to compare any two versions
 *
 * Used by:
 *   - FlowHealthController (new @AuraEnabled methods for Compare Versions UI)
 *   - FlowDiffService (receives two FlowDefinitions to compare)
 *
 * NAMING CONVENTION:
 *   "FlowVersionInfo" = lightweight version record for UI dropdowns
 *   "FlowDefinition"  = full parsed metadata (via FlowMetadata.FlowDefinition)
 */
public with sharing class FlowVersionService {

    private static final String NAMED_CREDENTIAL = 'FlowHealth_SelfOrg';
    private static final String API_VERSION = 'v62.0';

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * List all versions of a flow by its DeveloperName.
     * Returns lightweight version info sorted by version number descending
     * (newest first).
     *
     * @param flowDeveloperName  The DeveloperName of the flow
     * @return List of FlowVersionInfo objects
     */
    public static List<FlowVersionInfo> getVersions(String flowDeveloperName) {
        if (String.isBlank(flowDeveloperName)) {
            throw new FlowMetadataService.FlowHealthException(
                'Flow developer name cannot be blank.'
            );
        }

        // Query all versions (Active, Draft, Obsolete) for this flow definition
        String query = 'SELECT Id, VersionNumber, Status, MasterLabel, '
                     + 'ProcessType, Description, LastModifiedDate, LastModifiedBy.Name '
                     + 'FROM Flow '
                     + 'WHERE Definition.DeveloperName = \''
                     + String.escapeSingleQuotes(flowDeveloperName) + '\' '
                     + 'ORDER BY VersionNumber DESC';

        String responseBody = executeToolingQuery(query);
        return parseVersionList(responseBody);
    }

    /**
     * Fetch the full metadata for a specific flow version by its record Id.
     *
     * @param flowVersionId  The Tooling API Id of the specific Flow version
     * @return FlowMetadata.FlowDefinition  The parsed flow definition
     */
    public static FlowMetadata.FlowDefinition getVersionMetadata(String flowVersionId) {
        if (String.isBlank(flowVersionId)) {
            throw new FlowMetadataService.FlowHealthException(
                'Flow version Id cannot be blank.'
            );
        }

        String query = 'SELECT Id, FullName, MasterLabel, Status, Metadata '
                     + 'FROM Flow '
                     + 'WHERE Id = \'' + String.escapeSingleQuotes(flowVersionId) + '\' '
                     + 'LIMIT 1';

        String responseBody = executeToolingQuery(query);
        return parseVersionMetadata(responseBody, flowVersionId);
    }

    /**
     * Compare two versions of a flow by their Tooling API record Ids.
     * Convenience method that fetches both versions and runs the diff.
     *
     * @param oldVersionId  The Id of the older version
     * @param newVersionId  The Id of the newer version
     * @return FlowDiffResult  The structured diff between the two versions
     */
    public static FlowDiffResult compareVersions(String oldVersionId, String newVersionId) {
        // Fetch both versions (2 callouts)
        FlowMetadata.FlowDefinition oldFlow = getVersionMetadata(oldVersionId);
        FlowMetadata.FlowDefinition newFlow = getVersionMetadata(newVersionId);

        // Run the diff
        FlowDiffService differ = new FlowDiffService();
        return differ.compare(oldFlow, newFlow);
    }

    /**
     * Compare two flow definitions directly (no callout needed).
     * Used for Privacy Mode where XML is uploaded by the user.
     *
     * @param oldFlow  The older version's parsed definition
     * @param newFlow  The newer version's parsed definition
     * @return FlowDiffResult  The structured diff
     */
    public static FlowDiffResult compareDefinitions(
        FlowMetadata.FlowDefinition oldFlow,
        FlowMetadata.FlowDefinition newFlow
    ) {
        FlowDiffService differ = new FlowDiffService();
        return differ.compare(oldFlow, newFlow);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    @TestVisible
    private static String executeToolingQuery(String query) {
        // Delegates to the shared connection layer (zero-setup session mode
        // by default, Named Credential when hardened mode is enabled).
        return FlowMetadataService.toolingGet(
            '/services/data/' + API_VERSION + '/tooling/query'
            + '?q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );
    }

    private static List<FlowVersionInfo> parseVersionList(String responseBody) {
        List<FlowVersionInfo> versions = new List<FlowVersionInfo>();

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> records = (List<Object>) parsed.get('records');

        if (records == null) {
            return versions;
        }

        for (Object rec : records) {
            Map<String, Object> record = (Map<String, Object>) rec;
            FlowVersionInfo info = new FlowVersionInfo();
            info.id = (String) record.get('Id');
            info.masterLabel = (String) record.get('MasterLabel');
            info.status = (String) record.get('Status');
            info.processType = (String) record.get('ProcessType');
            info.description = (String) record.get('Description');

            // Version number comes as a Decimal from JSON
            Object versionObj = record.get('VersionNumber');
            if (versionObj != null) {
                info.versionNumber = Integer.valueOf(String.valueOf(versionObj));
            }

            // Last modified date
            Object dateObj = record.get('LastModifiedDate');
            if (dateObj != null) {
                info.lastModifiedDate = String.valueOf(dateObj);
            }

            // Last modified by name
            Object modByObj = record.get('LastModifiedBy');
            if (modByObj != null) {
                Map<String, Object> modBy = (Map<String, Object>) modByObj;
                info.lastModifiedByName = (String) modBy.get('Name');
            }

            // Build display label
            info.displayLabel = 'v' + info.versionNumber
                + ' — ' + safe(info.status)
                + (String.isNotBlank(info.lastModifiedByName)
                    ? ' (by ' + info.lastModifiedByName + ')'
                    : '');

            versions.add(info);
        }

        return versions;
    }

    private static FlowMetadata.FlowDefinition parseVersionMetadata(
        String responseBody, String versionId
    ) {
        // Same "object" → "object_x" sanitization as FlowMetadataService
        String sanitized = responseBody.replace('"object":', '"object_x":');

        FlowMetadata.ToolingQueryResult result =
            (FlowMetadata.ToolingQueryResult) JSON.deserialize(
                sanitized, FlowMetadata.ToolingQueryResult.class
            );

        if (result == null || result.records == null || result.records.isEmpty()) {
            throw new FlowMetadataService.FlowHealthException(
                'Flow version not found for Id: ' + versionId
            );
        }

        FlowMetadata.FlowDefinition flowDef = result.records[0].Metadata;
        if (flowDef == null) {
            throw new FlowMetadataService.FlowHealthException(
                'Flow version "' + versionId + '" was found but its metadata is empty.'
            );
        }

        return flowDef;
    }

    private static String safe(String val) {
        return val != null ? val : '';
    }

    // =========================================================================
    // Data classes
    // =========================================================================

    /**
     * Lightweight version info for the version selector UI.
     */
    public class FlowVersionInfo {
        @AuraEnabled public String id;
        @AuraEnabled public Integer versionNumber;
        @AuraEnabled public String masterLabel;
        @AuraEnabled public String status;
        @AuraEnabled public String processType;
        @AuraEnabled public String description;
        @AuraEnabled public String lastModifiedDate;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public String displayLabel;    // Pre-formatted for combobox display
    }
}
