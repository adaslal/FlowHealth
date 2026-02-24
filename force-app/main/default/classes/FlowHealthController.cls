/**
 * FlowHealthController - Single entry point for all LWC ↔ Apex communication.
 *
 * DESIGN PATTERN: Thin Controller
 * This controller delegates all work to service classes. It only handles:
 * 1. @AuraEnabled method declarations (LWC bridge)
 * 2. Error wrapping (catch exceptions, return user-friendly messages)
 *
 * In Sprint 1, we expose:
 * - getFlowList(): Returns all active flows for the dropdown selector
 * - getFlowDetail(): Returns parsed metadata for a single flow
 *
 * Sprint 2 additions:
 * - analyzeFlow(): Runs the full health check and returns scores + findings
 *
 * Sprint 4 additions (Historical Tracking + Export + Rule Config):
 * - analyzeFlow() now accepts scanType and auto-saves a snapshot
 * - getFlowHistory(): Returns past snapshots for trend charts
 * - getOrgTrend(): Returns org-wide daily average scores
 * - getFlowTrendSummary(): Returns trend direction for a single flow
 * - getSnapshotDetail(): Returns a single snapshot with full findings JSON
 * - getAllRuleConfigs(): Returns all rule metadata for the Settings tab
 * - saveRuleChanges(): Updates rule metadata via Metadata API
 * - getDeployStatus(): Checks async metadata deployment status
 */
public with sharing class FlowHealthController {

    /**
     * Returns a list of all active flows in the org.
     * Used by the flowSelector LWC to populate the dropdown.
     *
     * @return List<FlowMetadataService.FlowInfo> - lightweight flow info objects
     */
    @AuraEnabled(cacheable=true)
    public static List<FlowMetadataService.FlowInfo> getFlowList() {
        try {
            return FlowMetadataService.getActiveFlows();
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load flow list. Please check that the Named Credential ' +
                '"FlowHealth_SelfOrg" is configured correctly. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Fetches and returns the full metadata for a single flow.
     * Used in Sprint 1 to display raw metadata; in Sprint 2, this feeds
     * into the rule engine.
     *
     * WHY NOT cacheable=true?
     * This method makes an HTTP callout (Tooling API). Cacheable methods
     * can't make callouts in LWC — they run in a "read-only" context.
     * So we use cacheable=false (the default) and call it imperatively
     * from the LWC instead of with @wire.
     *
     * @param flowDeveloperName  The API name of the flow to analyze
     * @return FlowDetailResult - wrapper with flow info and element counts
     */
    @AuraEnabled
    public static FlowDetailResult getFlowDetail(String flowDeveloperName) {
        try {
            FlowMetadata.FlowDefinition flowDef = FlowMetadataService.getFlowMetadata(flowDeveloperName);
            return buildDetailResult(flowDef, flowDeveloperName);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to analyze flow "' + flowDeveloperName + '". Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 2: FLOW ANALYSIS (Health Score + Findings)
    // =========================================================================

    /**
     * Runs the full health analysis on a flow: fetch metadata, execute all
     * active rules, calculate the health score, and return structured results.
     *
     * WHY NOT cacheable=true?
     * Same reason as getFlowDetail — this makes an HTTP callout to the
     * Tooling API, which isn't allowed in cacheable (read-only) context.
     *
     * @param flowDeveloperName  The API name of the flow to analyze
     * @return FlowAnalysisService.AnalysisResult - score, grade, findings, breakdowns
     */
    @AuraEnabled
    public static FlowAnalysisService.AnalysisResult analyzeFlow(String flowDeveloperName) {
        return analyzeFlowWithSnapshot(flowDeveloperName, 'Single');
    }

    /**
     * Analyze a flow and save a snapshot. The scanType parameter indicates
     * whether this was triggered from a single flow analysis or bulk scan.
     *
     * @param flowDeveloperName  The API name of the flow to analyze
     * @param scanType           'Single' or 'Bulk'
     * @return FlowAnalysisService.AnalysisResult - score, grade, findings, breakdowns
     */
    @AuraEnabled
    public static FlowAnalysisService.AnalysisResult analyzeFlowWithSnapshot(
        String flowDeveloperName, String scanType
    ) {
        try {
            if (String.isBlank(flowDeveloperName)) {
                throw new AuraHandledException('Flow developer name is required.');
            }

            FlowAnalysisService.AnalysisResult result =
                FlowAnalysisService.analyzeFlow(flowDeveloperName);

            // Auto-save snapshot for historical tracking (Sprint 4)
            // Fire-and-forget: don't let snapshot save failure break the analysis
            try {
                // Look up flow label and processType from the flow list
                String flowLabel = flowDeveloperName;
                String processType = '';
                List<FlowMetadataService.FlowInfo> flows = FlowMetadataService.getActiveFlows();
                for (FlowMetadataService.FlowInfo fi : flows) {
                    if (fi.developerName == flowDeveloperName) {
                        flowLabel = fi.masterLabel;
                        processType = fi.processType;
                        break;
                    }
                }
                FlowSnapshotService.saveSnapshot(
                    flowDeveloperName, flowLabel, processType, result,
                    String.isBlank(scanType) ? 'Single' : scanType
                );
            } catch (Exception snapErr) {
                // Log but don't fail — analysis result is still valid
                System.debug(LoggingLevel.WARN,
                    'FlowHealthController: Failed to save snapshot for ' +
                    flowDeveloperName + ': ' + snapErr.getMessage());
            }

            return result;
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to analyze flow "' + flowDeveloperName + '". Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 4: HISTORICAL TREND TRACKING
    // =========================================================================

    /**
     * Returns the last N analysis snapshots for a specific flow.
     * Used by the single-flow trend chart.
     *
     * @param flowDeveloperName  The API name of the flow
     * @return List of snapshot records ordered by date descending
     */
    @AuraEnabled
    public static List<Flow_Health_Snapshot__c> getFlowHistory(String flowDeveloperName) {
        try {
            return FlowSnapshotService.getFlowHistory(flowDeveloperName, 10);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load flow history. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Returns org-wide daily average scores for the last 30 days.
     * Used by the Bulk Dashboard trend line.
     *
     * @return List of OrgTrendPoint (date, avgScore, flowCount)
     */
    @AuraEnabled
    public static List<FlowSnapshotService.OrgTrendPoint> getOrgTrend() {
        try {
            return FlowSnapshotService.getOrgTrendData(30);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load org trend data. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Returns the trend summary (current score, previous score, delta, direction)
     * for a specific flow.
     *
     * @param flowDeveloperName  The API name of the flow
     * @return TrendSummary with direction and delta
     */
    @AuraEnabled
    public static FlowSnapshotService.TrendSummary getFlowTrendSummary(String flowDeveloperName) {
        try {
            return FlowSnapshotService.getFlowTrendSummary(flowDeveloperName);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load trend summary. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Returns a single snapshot record with the full Findings_JSON__c.
     * Used for PDF export — retrieves the most recent snapshot for a flow.
     *
     * @param flowDeveloperName  The API name of the flow
     * @return The most recent snapshot with all fields including Findings_JSON
     */
    @AuraEnabled
    public static Flow_Health_Snapshot__c getSnapshotDetail(String flowDeveloperName) {
        try {
            List<Flow_Health_Snapshot__c> snapshots = [
                SELECT Id, Name, Flow_Developer_Name__c, Flow_Label__c,
                       Score__c, Grade__c, Total_Findings__c,
                       Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                       Process_Type__c, Scan_Type__c, Findings_JSON__c, CreatedDate
                FROM Flow_Health_Snapshot__c
                WHERE Flow_Developer_Name__c = :flowDeveloperName
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return snapshots.isEmpty() ? null : snapshots[0];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load snapshot detail. Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 4: RULE CONFIGURATION
    // =========================================================================

    /**
     * Returns all rule metadata records for the Settings tab.
     *
     * @return List of all Flow_Health_Rule__mdt records
     */
    @AuraEnabled
    public static List<Flow_Health_Rule__mdt> getAllRuleConfigs() {
        try {
            return [
                SELECT DeveloperName, MasterLabel, Rule_Id__c, Category__c,
                       Severity__c, Weight__c, Max_Deduction__c, Is_Active__c,
                       Detection_Class__c, Description__c, Remediation__c
                FROM Flow_Health_Rule__mdt
                ORDER BY Rule_Id__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load rule configurations. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Saves modified rule configurations via the Metadata API.
     * This is an async operation — returns a deployment job ID.
     *
     * @param rulesJson  JSON array of modified rules with fields:
     *                   developerName, severity, weight, maxDeduction, isActive
     * @return The deployment job ID for status tracking
     */
    @AuraEnabled
    public static String saveRuleChanges(String rulesJson) {
        try {
            return FlowRuleConfigService.deployRuleChanges(rulesJson);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to save rule changes. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Checks the status of an async metadata deployment.
     *
     * @param jobId  The deployment job ID from saveRuleChanges
     * @return Status string: 'Pending', 'InProgress', 'Succeeded', 'Failed'
     */
    @AuraEnabled
    public static String getDeployStatus(String jobId) {
        try {
            return FlowRuleConfigService.checkDeploymentStatus(jobId);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to check deployment status. Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 5: CUSTOM RULE MANAGEMENT (User-Defined Rules)
    // =========================================================================

    /**
     * Returns all user-defined custom rules for the Settings > Custom Rules tab.
     *
     * @return List of all Flow_Health_Custom_Rule__c records
     */
    @AuraEnabled
    public static List<Flow_Health_Custom_Rule__c> getCustomRules() {
        try {
            return [
                SELECT Id, Name, Rule_Id__c, Category__c, Severity__c, Weight__c,
                       Is_Active__c, Description__c, Remediation__c,
                       Rule_Type__c, Target_Element_Type__c, Threshold_Value__c,
                       Name_Pattern__c, Flow_Property__c, Expected_Value__c,
                       CreatedDate, LastModifiedDate
                FROM Flow_Health_Custom_Rule__c
                ORDER BY Rule_Id__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load custom rules. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Creates or updates a custom rule.
     * Takes a JSON string to avoid LWC ↔ Apex SObject serialization issues.
     *
     * @param ruleJson  JSON object with all rule fields
     * @return The saved record Id
     */
    @AuraEnabled
    public static String saveCustomRule(String ruleJson) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(ruleJson);

            Flow_Health_Custom_Rule__c rule;

            // Update existing or create new
            String recordId = (String) data.get('id');
            if (String.isNotBlank(recordId)) {
                rule = [SELECT Id FROM Flow_Health_Custom_Rule__c WHERE Id = :recordId LIMIT 1];
            } else {
                rule = new Flow_Health_Custom_Rule__c();
            }

            rule.Name             = (String) data.get('name');
            rule.Rule_Id__c       = (String) data.get('ruleId');
            rule.Category__c      = (String) data.get('category');
            rule.Severity__c      = (String) data.get('severity');
            rule.Description__c   = (String) data.get('description');
            rule.Remediation__c   = (String) data.get('remediation');
            rule.Rule_Type__c     = (String) data.get('ruleType');
            rule.Target_Element_Type__c = (String) data.get('targetElementType');
            rule.Flow_Property__c = (String) data.get('flowProperty');
            rule.Expected_Value__c = (String) data.get('expectedValue');
            rule.Name_Pattern__c  = (String) data.get('namePattern');

            // Number fields
            Object weightVal = data.get('weight');
            rule.Weight__c = weightVal != null ? Decimal.valueOf(String.valueOf(weightVal)) : 5;

            Object thresholdVal = data.get('thresholdValue');
            rule.Threshold_Value__c = thresholdVal != null ? Decimal.valueOf(String.valueOf(thresholdVal)) : null;

            // Boolean
            Object activeVal = data.get('isActive');
            rule.Is_Active__c = activeVal != null ? Boolean.valueOf(String.valueOf(activeVal)) : true;

            upsert rule;

            // Clear the evaluator cache so the next analysis uses the updated rules
            CustomRuleEvaluator.clearCache();

            return rule.Id;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to save custom rule. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Deletes a custom rule by Id.
     *
     * @param ruleId  The Salesforce record Id of the custom rule to delete
     */
    @AuraEnabled
    public static void deleteCustomRule(String ruleId) {
        try {
            if (String.isBlank(ruleId)) {
                throw new AuraHandledException('Rule Id is required for deletion.');
            }
            delete [SELECT Id FROM Flow_Health_Custom_Rule__c WHERE Id = :ruleId LIMIT 1];
            CustomRuleEvaluator.clearCache();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to delete custom rule. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Toggles the active state of a custom rule.
     *
     * @param ruleId   The Salesforce record Id
     * @param isActive The new active state
     */
    @AuraEnabled
    public static void toggleCustomRule(String ruleId, Boolean isActive) {
        try {
            Flow_Health_Custom_Rule__c rule = [
                SELECT Id, Is_Active__c
                FROM Flow_Health_Custom_Rule__c
                WHERE Id = :ruleId LIMIT 1
            ];
            rule.Is_Active__c = isActive;
            update rule;
            CustomRuleEvaluator.clearCache();
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to toggle custom rule. Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 5: TEST CUSTOM RULE (Preview before saving)
    // =========================================================================

    /**
     * Tests a custom rule against a specific flow without saving.
     * Returns the findings so the admin can preview the rule's behavior
     * before committing the rule to the database.
     *
     * @param ruleJson           JSON object with all rule fields
     * @param flowDeveloperName  The flow to test against
     * @return TestRuleResult with findings list and count
     */
    @AuraEnabled
    public static TestRuleResult testCustomRule(String ruleJson, String flowDeveloperName) {
        try {
            if (String.isBlank(ruleJson) || String.isBlank(flowDeveloperName)) {
                throw new AuraHandledException('Rule definition and flow name are required.');
            }

            // Parse rule from JSON into an in-memory record (not saved)
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(ruleJson);
            Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
            rule.Name             = (String) data.get('name');
            rule.Rule_Id__c       = (String) data.get('ruleId');
            rule.Category__c      = (String) data.get('category');
            rule.Severity__c      = (String) data.get('severity');
            rule.Rule_Type__c     = (String) data.get('ruleType');
            rule.Target_Element_Type__c = (String) data.get('targetElementType');
            rule.Flow_Property__c = (String) data.get('flowProperty');
            rule.Expected_Value__c = (String) data.get('expectedValue');
            rule.Name_Pattern__c  = (String) data.get('namePattern');
            rule.Description__c   = (String) data.get('description');
            rule.Remediation__c   = (String) data.get('remediation');

            Object weightVal = data.get('weight');
            rule.Weight__c = weightVal != null ? Decimal.valueOf(String.valueOf(weightVal)) : 5;

            Object thresholdVal = data.get('thresholdValue');
            rule.Threshold_Value__c = thresholdVal != null ? Decimal.valueOf(String.valueOf(thresholdVal)) : null;

            // Fetch flow metadata and build context
            FlowMetadata.FlowDefinition flow = FlowMetadataService.getFlowMetadata(flowDeveloperName);
            FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

            // Test the rule (does NOT save it)
            List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

            TestRuleResult result = new TestRuleResult();
            result.findings = findings;
            result.totalFindings = findings.size();
            result.passed = findings.isEmpty();
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Test rule failed: ' + e.getMessage()
            );
        }
    }

    /**
     * Result wrapper for testCustomRule — returned to the LWC.
     */
    public class TestRuleResult {
        @AuraEnabled public List<FlowFinding> findings;
        @AuraEnabled public Integer totalFindings;
        @AuraEnabled public Boolean passed;
    }

    // =========================================================================
    // SPRINT 6: VERSION COMPARISON
    // =========================================================================

    /**
     * Returns all versions of a flow for the version selector dropdown.
     *
     * @param flowDeveloperName  The DeveloperName of the flow
     * @return List of FlowVersionInfo objects (version number, status, modified by)
     */
    @AuraEnabled
    public static List<FlowVersionService.FlowVersionInfo> getFlowVersions(String flowDeveloperName) {
        try {
            return FlowVersionService.getVersions(flowDeveloperName);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load flow versions. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Compares two flow versions by their Tooling API record Ids.
     * Returns a structured diff with changes, score delta, and risk assessment.
     *
     * @param oldVersionId  The Id of the older version
     * @param newVersionId  The Id of the newer version
     * @return FlowDiffResult with all changes and summary
     */
    @AuraEnabled
    public static FlowDiffResult compareFlowVersions(String oldVersionId, String newVersionId) {
        try {
            return FlowVersionService.compareVersions(oldVersionId, newVersionId);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to compare flow versions. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Compares two flow XML strings (Privacy Mode — no Tooling API callout).
     * Used when users upload XML files directly.
     *
     * @param oldXml  The XML content of the older version
     * @param newXml  The XML content of the newer version
     * @return FlowDiffResult with all changes and summary
     */
    @AuraEnabled
    public static FlowDiffResult compareFlowXml(String oldXml, String newXml) {
        try {
            FlowMetadata.FlowDefinition oldFlow = FlowXmlParser.parse(oldXml);
            FlowMetadata.FlowDefinition newFlow = FlowXmlParser.parse(newXml);
            return FlowVersionService.compareDefinitions(oldFlow, newFlow);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to compare flow XML. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Analyzes a flow from its XML content (Privacy Mode — no Tooling API callout).
     * Used when users upload a flow XML file directly.
     *
     * @param xmlContent  The raw XML content of the flow
     * @return FlowAnalysisService.AnalysisResult - score, grade, findings, breakdowns
     */
    @AuraEnabled
    public static FlowAnalysisService.AnalysisResult analyzeFlowXml(String xmlContent) {
        try {
            FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xmlContent);
            return FlowAnalysisService.analyzeFlowDefinition(flow);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to analyze flow XML. Error: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // SPRINT 7: PERMSET PATCHMASTER
    // =========================================================================

    /**
     * Generates a patched Permission Set XML by merging Source (Dev) into
     * Destination (Prod/Target). Prevents destructive overwrites during deployment.
     *
     * @param destinationXml  The "truth" from the target/production Org
     * @param sourceXml       The new changes from the dev Org
     * @return PermSetPatchService.PatchResult with merged XML and diff details
     */
    @AuraEnabled
    public static PermSetPatchService.PatchResult generatePermSetPatch(
        String destinationXml, String sourceXml
    ) {
        try {
            if (String.isBlank(destinationXml)) {
                throw new AuraHandledException(
                    'Destination (Base) Permission Set XML is required.'
                );
            }
            if (String.isBlank(sourceXml)) {
                throw new AuraHandledException(
                    'Source (Delta) Permission Set XML is required.'
                );
            }
            return PermSetPatchService.generatePatch(destinationXml, sourceXml);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to generate Permission Set patch. Error: ' + e.getMessage()
            );
        }
    }

    /**
     * Sprint 8: Validate Source XML dependencies against Destination XML.
     * Surfaces objects, fields, classes, pages, tabs, etc. that exist in Source
     * but are missing from Destination — preventing deployment failures.
     *
     * @param sourceXml      The Dev / Source Org permission set XML
     * @param destinationXml The Prod / UAT Destination Org permission set XML
     * @return FH_MetadataValidator.ValidationReport
     */
    @AuraEnabled
    public static FH_MetadataValidator.ValidationReport validatePermSetDependencies(
        String sourceXml, String destinationXml
    ) {
        try {
            if (String.isBlank(sourceXml)) {
                throw new AuraHandledException(
                    'Source (Delta) Permission Set XML is required for validation.'
                );
            }
            if (String.isBlank(destinationXml)) {
                throw new AuraHandledException(
                    'Destination (Base) Permission Set XML is required for validation.'
                );
            }
            return FH_MetadataValidator.validatePermSetDependencies(sourceXml, destinationXml);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Validation Error: The engine encountered an issue parsing the metadata structure. '
                + 'Please ensure both XML files are valid Permission Sets. '
                + '(Detail: ' + e.getMessage() + ')'
            );
        }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /**
     * Converts the raw FlowDefinition into a UI-friendly result object
     * with element counts and summary info.
     */
    private static FlowDetailResult buildDetailResult(FlowMetadata.FlowDefinition flowDef, String devName) {
        FlowDetailResult result = new FlowDetailResult();
        result.developerName = devName;
        result.label = flowDef.label;
        result.description = flowDef.description;
        result.processType = flowDef.processType;
        result.triggerType = flowDef.triggerType;
        result.apiVersion = flowDef.apiVersion;
        result.runInMode = flowDef.runInMode;

        // Count elements by type — gives a quick overview of flow complexity
        result.elementCounts = new Map<String, Integer>();
        result.elementCounts.put('actionCalls', safeSize(flowDef.actionCalls));
        result.elementCounts.put('assignments', safeSize(flowDef.assignments));
        result.elementCounts.put('decisions', safeSize(flowDef.decisions));
        result.elementCounts.put('loops', safeSize(flowDef.loops));
        result.elementCounts.put('recordCreates', safeSize(flowDef.recordCreates));
        result.elementCounts.put('recordUpdates', safeSize(flowDef.recordUpdates));
        result.elementCounts.put('recordDeletes', safeSize(flowDef.recordDeletes));
        result.elementCounts.put('recordLookups', safeSize(flowDef.recordLookups));
        result.elementCounts.put('screens', safeSize(flowDef.screens));
        result.elementCounts.put('subflows', safeSize(flowDef.subflows));
        result.elementCounts.put('variables', safeSize(flowDef.variables));
        result.elementCounts.put('formulas', safeSize(flowDef.formulas));

        // Collect element API names by type for the breakdown drill-down
        result.elementNames = new Map<String, List<String>>();
        result.elementNames.put('actionCalls', extractElementNames(flowDef.actionCalls));
        result.elementNames.put('assignments', extractElementNames(flowDef.assignments));
        result.elementNames.put('decisions', extractElementNames(flowDef.decisions));
        result.elementNames.put('loops', extractElementNames(flowDef.loops));
        result.elementNames.put('recordCreates', extractElementNames(flowDef.recordCreates));
        result.elementNames.put('recordUpdates', extractElementNames(flowDef.recordUpdates));
        result.elementNames.put('recordDeletes', extractElementNames(flowDef.recordDeletes));
        result.elementNames.put('recordLookups', extractElementNames(flowDef.recordLookups));
        result.elementNames.put('screens', extractElementNames(flowDef.screens));
        result.elementNames.put('subflows', extractElementNames(flowDef.subflows));
        result.elementNames.put('variables', extractVarNames(flowDef.variables));
        result.elementNames.put('formulas', extractFormulaNames(flowDef.formulas));

        // Total element count (elements only, not variables/formulas)
        result.totalElements = 0;
        for (String key : new List<String>{
            'actionCalls', 'assignments', 'decisions', 'loops',
            'recordCreates', 'recordUpdates', 'recordDeletes',
            'recordLookups', 'screens', 'subflows'
        }) {
            result.totalElements += result.elementCounts.get(key);
        }

        return result;
    }

    /**
     * Null-safe list size helper.
     */
    private static Integer safeSize(List<Object> items) {
        return items != null ? items.size() : 0;
    }

    /**
     * Extracts API names from any list of FlowElement subclasses.
     * Uses List<Object> to avoid Apex's lack of wildcard generics,
     * then casts each item to FlowElement (safe because all element
     * list types extend FlowElement).
     */
    private static List<String> extractElementNames(List<Object> elements) {
        List<String> names = new List<String>();
        if (elements != null) {
            for (Object obj : elements) {
                FlowMetadata.FlowElement el = (FlowMetadata.FlowElement) obj;
                names.add(el.name != null ? el.name : '(unnamed)');
            }
        }
        return names;
    }

    /**
     * Extracts names from FlowVariable list (not a FlowElement subclass).
     */
    private static List<String> extractVarNames(List<FlowMetadata.FlowVariable> vars) {
        List<String> names = new List<String>();
        if (vars != null) {
            for (FlowMetadata.FlowVariable v : vars) {
                names.add(v.name != null ? v.name : '(unnamed)');
            }
        }
        return names;
    }

    /**
     * Extracts names from FlowFormula list (not a FlowElement subclass).
     */
    private static List<String> extractFormulaNames(List<FlowMetadata.FlowFormula> fmls) {
        List<String> names = new List<String>();
        if (fmls != null) {
            for (FlowMetadata.FlowFormula f : fmls) {
                names.add(f.name != null ? f.name : '(unnamed)');
            }
        }
        return names;
    }

    // =========================================================================
    // RESULT WRAPPER
    // =========================================================================

    /**
     * UI-friendly result object returned to the LWC.
     * Contains flow summary info and element counts.
     * For health scores and findings, see FlowAnalysisService.AnalysisResult.
     */
    public class FlowDetailResult {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String processType;
        @AuraEnabled public String triggerType;
        @AuraEnabled public String apiVersion;
        @AuraEnabled public String runInMode;
        @AuraEnabled public Map<String, Integer> elementCounts;
        @AuraEnabled public Map<String, List<String>> elementNames;
        @AuraEnabled public Integer totalElements;
    }
}
