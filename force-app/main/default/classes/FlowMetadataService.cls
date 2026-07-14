/**
 * FlowMetadataService - Fetches Flow metadata from the Salesforce Tooling API.
 *
 * WHY TOOLING API?
 * The Metadata API returns XML and requires async retrieval (deploy/retrieve).
 * The Tooling API returns JSON synchronously via a simple SOQL-like query,
 * which is perfect for on-demand analysis from LWC.
 *
 * WHY NAMED CREDENTIAL?
 * In Lightning context, UserInfo.getSessionId() returns 'INVALID_SESSION_ID'.
 * A Named Credential with OAuth handles auth automatically and is also
 * required for AppExchange security review (no hardcoded credentials).
 *
 * SETUP REQUIRED:
 * 1. Create a Connected App in Setup (for OAuth)
 * 2. Create an Auth Provider using that Connected App
 * 3. Create a Named Credential called 'FlowHealth_SelfOrg' pointing to
 *    your org's My Domain URL, using the Auth Provider
 * 4. Add your org's My Domain URL to Remote Site Settings
 *
 * (We'll create a setup guide for this.)
 */
public with sharing class FlowMetadataService {

    // The Named Credential API name - users configure this during setup
    private static final String NAMED_CREDENTIAL = 'FlowHealth_SelfOrg';

    // Tooling API version - pinned to avoid breaking changes
    private static final String API_VERSION = 'v62.0';

    /**
     * Fetches the active version of a Flow by its DeveloperName.
     *
     * @param flowDeveloperName  The API name of the flow (e.g., 'Update_Account_Status')
     * @return FlowMetadata.FlowDefinition  The parsed flow definition
     * @throws FlowHealthException  If the flow is not found or API call fails
     */
    public static FlowMetadata.FlowDefinition getFlowMetadata(String flowDeveloperName) {
        // Validate input
        if (String.isBlank(flowDeveloperName)) {
            throw new FlowHealthException('Flow developer name cannot be blank.');
        }

        // Build the Tooling API query
        // IMPORTANT: We filter on Definition.DeveloperName (not FullName)
        // because FullName isn't filterable in the Tooling API for Flow objects
        String query = 'SELECT Id, FullName, MasterLabel, Status, Metadata '
                     + 'FROM Flow '
                     + 'WHERE Definition.DeveloperName = \'' + String.escapeSingleQuotes(flowDeveloperName) + '\' '
                     + 'AND Status = \'Active\' '
                     + 'LIMIT 1';

        // Make the callout
        String responseBody = executeToolingQuery(query);

        // Parse the response
        return parseFlowResponse(responseBody, flowDeveloperName);
    }

    /**
     * Lists all active flows in the org with basic info (no full metadata).
     * Used by the flow selector dropdown in the UI.
     *
     * @return List of FlowInfo objects with name, label, type, and trigger info
     */
    public static List<FlowInfo> getActiveFlows() {
        String query = 'SELECT Id, MasterLabel, Status, ProcessType, Definition.DeveloperName '
                     + 'FROM Flow '
                     + 'WHERE Status = \'Active\' '
                     + 'ORDER BY MasterLabel ASC';

        String responseBody = executeToolingQuery(query);

        return parseFlowList(responseBody);
    }

    /**
     * Returns the RAW metadata of a flow as a JSON string (the Tooling API's
     * "Metadata" node, untyped and unmodified).
     *
     * Used by the Logic Audit tab: the client-side Sanity Engine converts
     * this JSON to XML-equivalent structure and analyzes it locally, so users
     * can pick an org flow instead of manually exporting .flow-meta.xml.
     *
     * @param flowDeveloperName  The API name of the flow
     * @return String  Raw JSON of the flow's Metadata node
     * @throws FlowHealthException  If the flow is not found or has no metadata
     */
    public static String getFlowMetadataJson(String flowDeveloperName) {
        if (String.isBlank(flowDeveloperName)) {
            throw new FlowHealthException('Flow developer name cannot be blank.');
        }

        String query = 'SELECT Id, FullName, MasterLabel, Status, Metadata '
                     + 'FROM Flow '
                     + 'WHERE Definition.DeveloperName = \'' + String.escapeSingleQuotes(flowDeveloperName) + '\' '
                     + 'AND Status = \'Active\' '
                     + 'LIMIT 1';

        String responseBody = executeToolingQuery(query);

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> records = (List<Object>) parsed.get('records');
        if (records == null || records.isEmpty()) {
            throw new FlowHealthException(
                'No active flow found with developer name: ' + flowDeveloperName + '.'
            );
        }

        Object metadata = ((Map<String, Object>) records[0]).get('Metadata');
        if (metadata == null) {
            throw new FlowHealthException(
                'Flow "' + flowDeveloperName + '" was found but its metadata is empty.'
            );
        }

        return JSON.serialize(metadata);
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /**
     * Executes a Tooling API query using the active connection mode.
     *
     * @param query  The SOQL query string for the Tooling API
     * @return String  The raw JSON response body
     */
    @TestVisible
    private static String executeToolingQuery(String query) {
        return toolingGet(
            '/services/data/' + API_VERSION + '/tooling/query'
            + '?q=' + EncodingUtil.urlEncode(query, 'UTF-8')
        );
    }

    // =========================================================================
    // CONNECTION LAYER — Zero-setup by default, Named Credential optional
    // =========================================================================
    //
    // ZERO-SETUP MODE (default): the app calls its own org's Tooling API at
    // URL.getOrgDomainUrl() — which requires NO Remote Site Setting — using
    // an API-enabled session obtained from the FlowHealthSession Visualforce
    // page. Install → works. Nothing to configure.
    //
    // HARDENED MODE (optional): admins who prefer OAuth can complete the
    // SETUP_GUIDE steps and check "Use Named Credential" in Flow Health
    // Settings. All callouts then route through callout:FlowHealth_SelfOrg.
    // =========================================================================

    /** Per-transaction cache of the API session id. */
    private static String cachedSessionId;

    /**
     * True when the org has opted into Named Credential (hardened) mode.
     */
    public static Boolean useNamedCredential() {
        Flow_Health_Settings__c settings = Flow_Health_Settings__c.getInstance();
        return settings != null && settings.Use_Named_Credential__c == true;
    }

    /**
     * Executes a GET against this org's APIs using the active connection
     * mode. Shared by FlowMetadataService, FlowVersionService, and
     * FlowRuleConfigService so the strategy lives in exactly one place.
     *
     * @param relativePath  Path starting with '/services/...'
     * @return Raw response body
     */
    public static String toolingGet(String relativePath) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);

        if (useNamedCredential()) {
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + relativePath);
        } else {
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + relativePath);
            req.setHeader('Authorization', 'Bearer ' + getApiSessionId());
        }

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new FlowHealthException(
                'Tooling API error (HTTP ' + res.getStatusCode() + '): ' + res.getBody()
            );
        }
        return res.getBody();
    }

    /**
     * Returns an API-enabled session id for same-org calls.
     *
     * In Lightning context UserInfo.getSessionId() is not API-enabled, so we
     * read the session from the FlowHealthSession Visualforce page (VF
     * sessions are API-enabled). This is the established pattern used by
     * admin tools for same-org API access without OAuth setup. The session
     * is only ever used against this org's own domain and is never stored
     * or transmitted anywhere else.
     */
    @TestVisible
    private static String getApiSessionId() {
        if (cachedSessionId != null) {
            return cachedSessionId;
        }
        if (Test.isRunningTest()) {
            // getContent() is not supported in tests; callouts are mocked anyway.
            cachedSessionId = UserInfo.getSessionId();
            return cachedSessionId;
        }
        try {
            String content = Page.FlowHealthSession.getContent().toString();
            Integer startIdx = content.indexOf('FH_SID_START') + 'FH_SID_START'.length();
            Integer endIdx = content.indexOf('FH_SID_END');
            String sid = content.substring(startIdx, endIdx).trim();
            if (String.isBlank(sid)) {
                throw new FlowHealthException('Empty session id.');
            }
            cachedSessionId = sid;
            return cachedSessionId;
        } catch (Exception e) {
            throw new FlowHealthException(
                'Unable to establish the org connection automatically. ' +
                'You can enable hardened mode instead: complete the Named ' +
                'Credential setup in SETUP_GUIDE.md, then check "Use Named ' +
                'Credential" in Setup → Custom Settings → Flow Health Settings. ' +
                '(Detail: ' + e.getMessage() + ')'
            );
        }
    }

    /**
     * Parses the Tooling API response for a single flow's metadata.
     *
     * WHY MANUAL PARSING?
     * The Tooling API returns JSON with a field called "object" (for SObject type).
     * "object" is a reserved word in Apex, so JSON.deserialize() can't map it
     * directly. We handle this by replacing "object" with "object_x" before
     * deserializing — a standard Salesforce pattern for reserved words.
     */
    private static FlowMetadata.FlowDefinition parseFlowResponse(String responseBody, String flowName) {
        // Handle the "object" reserved word issue
        // The Tooling API returns "object": "Account" in recordCreates, etc.
        // Apex can't have a field named "object", so we rename it to "object_x"
        String sanitized = responseBody.replace('"object":', '"object_x":');

        // Deserialize the top-level response
        FlowMetadata.ToolingQueryResult result =
            (FlowMetadata.ToolingQueryResult) JSON.deserialize(
                sanitized, FlowMetadata.ToolingQueryResult.class
            );

        // Validate we got a result
        if (result == null || result.records == null || result.records.isEmpty()) {
            throw new FlowHealthException(
                'No active flow found with developer name: ' + flowName +
                '. Make sure the flow exists and has an active version.'
            );
        }

        // Return the flow definition (the metadata itself)
        FlowMetadata.FlowDefinition flowDef = result.records[0].Metadata;
        if (flowDef == null) {
            throw new FlowHealthException(
                'Flow "' + flowName + '" was found but its metadata is empty. ' +
                'This can happen if the user lacks Tooling API permissions.'
            );
        }

        return flowDef;
    }

    /**
     * Parses the Tooling API response for the flow list (no full metadata).
     */
    private static List<FlowInfo> parseFlowList(String responseBody) {
        List<FlowInfo> flows = new List<FlowInfo>();

        // Use a lightweight parse since we don't need the full Metadata field
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> records = (List<Object>) parsed.get('records');

        if (records == null) {
            return flows;
        }

        // Track seen flow names to deduplicate (Tooling API returns all versions)
        Set<String> seenNames = new Set<String>();

        for (Object rec : records) {
            Map<String, Object> record = (Map<String, Object>) rec;

            // Get DeveloperName from the Definition relationship field
            String devName = null;
            Object defObj = record.get('Definition');
            if (defObj != null) {
                Map<String, Object> definition = (Map<String, Object>) defObj;
                devName = (String) definition.get('DeveloperName');
            }

            // Deduplicate — Tooling API may return multiple versions per flow
            if (devName == null || seenNames.contains(devName)) {
                continue;
            }
            seenNames.add(devName);

            FlowInfo info = new FlowInfo();
            info.id = (String) record.get('Id');
            info.fullName = devName;
            info.developerName = devName;
            info.masterLabel = (String) record.get('MasterLabel');
            info.processType = (String) record.get('ProcessType');
            info.status = (String) record.get('Status');
            flows.add(info);
        }

        return flows;
    }

    // =========================================================================
    // DATA CLASSES
    // =========================================================================

    /**
     * Lightweight flow info for the selector dropdown.
     * Doesn't include full metadata — just enough for display.
     */
    public class FlowInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String fullName;
        @AuraEnabled public String developerName;
        @AuraEnabled public String masterLabel;
        @AuraEnabled public String processType;
        @AuraEnabled public String triggerType;
        @AuraEnabled public String status;
    }

    // =========================================================================
    // CUSTOM EXCEPTION
    // =========================================================================

    public class FlowHealthException extends Exception {}
}