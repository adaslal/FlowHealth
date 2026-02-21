/**
 * PermSetRuleEngine - Orchestrates all PermSet Purifier rules.
 *
 * Similar to FlowRuleEngine but for permission set analysis.
 * Runs all registered rules against a PermissionSetDefinition and
 * returns an AnalysisResult with findings and summary statistics.
 *
 * RULE REGISTRY:
 *   PS-001: Dangerous User Permissions (Modify All, View All, AuthorApex, etc.)
 *   PS-002: Overly Broad Object Permissions (unnecessary Delete/ModifyAll)
 *   PS-003: Field Permissions Without Object Access
 *   PS-004: Disabled Permission Entries (enabled=false clutter)
 *   PS-005: Excessive Permission Count (bloated perm set)
 *   PS-006: Missing Description
 *   PS-007: Sensitive Data Object Access (financial, PII objects)
 *   PS-008: Read-Only Fields With Edit Access
 */
public class PermSetRuleEngine {

    // =========================================================================
    // Analysis Result
    // =========================================================================

    public class AnalysisResult {
        @AuraEnabled public List<PermSetFinding> findings;
        @AuraEnabled public Integer totalFindings;
        @AuraEnabled public Map<String, Integer> findingsBySeverity;
        @AuraEnabled public Map<String, Integer> findingsByCategory;
        @AuraEnabled public Integer permissionCount;
        @AuraEnabled public Integer removableCount;    // Items that can be purified

        public AnalysisResult() {
            this.findings = new List<PermSetFinding>();
            this.findingsBySeverity = new Map<String, Integer>();
            this.findingsByCategory = new Map<String, Integer>();
        }
    }

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Analyze a permission set using all registered rules.
     *
     * @param permSet  The parsed permission set definition
     * @return AnalysisResult with all findings and statistics
     */
    public static AnalysisResult analyze(PermSetMetadata.PermissionSetDefinition permSet) {
        AnalysisResult result = new AnalysisResult();

        // Build the rule list
        List<PermSetRule> rules = getRules();

        // Run each rule
        for (PermSetRule rule : rules) {
            try {
                List<PermSetFinding> ruleFindings = rule.evaluate(permSet);
                if (ruleFindings != null) {
                    result.findings.addAll(ruleFindings);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    'PermSetRuleEngine: Rule failed: ' + e.getMessage());
            }
        }

        // Build statistics
        result.totalFindings = result.findings.size();
        result.permissionCount = permSet.getTotalPermissionCount();

        Integer removable = 0;
        for (PermSetFinding f : result.findings) {
            // Severity counts
            String sev = f.severity != null ? f.severity : 'Medium';
            if (!result.findingsBySeverity.containsKey(sev)) {
                result.findingsBySeverity.put(sev, 0);
            }
            result.findingsBySeverity.put(sev, result.findingsBySeverity.get(sev) + 1);

            // Category counts
            String cat = f.category != null ? f.category : 'Other';
            if (!result.findingsByCategory.containsKey(cat)) {
                result.findingsByCategory.put(cat, 0);
            }
            result.findingsByCategory.put(cat, result.findingsByCategory.get(cat) + 1);

            // Count removable items
            if (f.purifyAction == 'REMOVE' || f.purifyAction == 'DOWNGRADE') {
                removable++;
            }
        }
        result.removableCount = removable;

        return result;
    }

    // =========================================================================
    // Rule Registry
    // =========================================================================

    private static List<PermSetRule> getRules() {
        return new List<PermSetRule>{
            new DangerousUserPermRule(),       // PS-001
            new OverlyBroadObjectPermRule(),   // PS-002
            new OrphanedFieldPermRule(),       // PS-003
            new DisabledEntryRule(),           // PS-004
            new ExcessivePermCountRule(),      // PS-005
            new MissingPermSetDescRule(),      // PS-006
            new SensitiveObjectAccessRule(),   // PS-007
            new EditOnReadOnlyFieldRule()      // PS-008
        };
    }
}
