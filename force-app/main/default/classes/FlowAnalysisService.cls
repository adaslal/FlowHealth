/**
 * FlowAnalysisService - Orchestrates the full flow health analysis.
 *
 * PIPELINE:
 * 1. Fetch flow metadata via Tooling API (FlowMetadataService)
 * 2. Run all active rules via the engine (FlowRuleEngine)
 * 3. Calculate the health score (FlowScoreCalculator)
 * 4. Package results into a structured AnalysisResult
 *
 * The controller calls this service; the service coordinates
 * the internal components. This keeps the controller thin
 * and the business logic testable.
 */
public class FlowAnalysisService {

    /**
     * The complete result of a flow health analysis.
     * Returned to the LWC via FlowHealthController.
     */
    public class AnalysisResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String grade;
        @AuraEnabled public String gradeLabel;
        @AuraEnabled public String gradeColor;
        @AuraEnabled public List<FlowFinding> findings;
        @AuraEnabled public Integer totalFindings;
        @AuraEnabled public Map<String, List<FlowFinding>> findingsByCategory;
        @AuraEnabled public Map<String, Integer> findingsBySeverity;
        @AuraEnabled public Map<String, Integer> categoryScores;
    }

    /**
     * Analyze a flow by developer name — full pipeline from API call to score.
     * This method makes an HTTP callout to the Tooling API.
     *
     * @param flowDeveloperName  The DeveloperName of the flow to analyze
     * @return AnalysisResult with score, findings, and breakdowns
     */
    public static AnalysisResult analyzeFlow(String flowDeveloperName) {
        // 1. Fetch flow metadata via Tooling API
        FlowMetadata.FlowDefinition flow =
            FlowMetadataService.getFlowMetadata(flowDeveloperName);

        // 2-4. Analyze the fetched definition
        return analyzeFlowDefinition(flow);
    }

    /**
     * Analyze a pre-fetched flow definition (no callout needed).
     * Useful for testing and for batch analysis scenarios.
     *
     * @param flow  The already-parsed flow definition
     * @return AnalysisResult with score, findings, and breakdowns
     */
    public static AnalysisResult analyzeFlowDefinition(FlowMetadata.FlowDefinition flow) {
        // 2. Run all active rules
        FlowRuleEngine engine = new FlowRuleEngine();
        List<FlowFinding> findings = engine.evaluate(flow);

        // 3. Calculate score
        FlowScoreCalculator calculator = new FlowScoreCalculator();
        FlowScoreCalculator.ScoreResult scoreResult = calculator.calculate(findings);

        // 4. Package results
        AnalysisResult result = new AnalysisResult();
        result.score = scoreResult.score;
        result.grade = scoreResult.grade;
        result.gradeLabel = scoreResult.gradeLabel;
        result.gradeColor = scoreResult.gradeColor;
        result.findings = findings;
        result.totalFindings = findings.size();
        result.findingsByCategory = groupByCategory(findings);
        result.findingsBySeverity = countBySeverity(findings);
        result.categoryScores = scoreResult.categoryScores;

        return result;
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    private static Map<String, List<FlowFinding>> groupByCategory(List<FlowFinding> findings) {
        Map<String, List<FlowFinding>> grouped = new Map<String, List<FlowFinding>>();
        for (FlowFinding f : findings) {
            String cat = f.category != null ? f.category : 'Other';
            if (!grouped.containsKey(cat)) {
                grouped.put(cat, new List<FlowFinding>());
            }
            grouped.get(cat).add(f);
        }
        return grouped;
    }

    private static Map<String, Integer> countBySeverity(List<FlowFinding> findings) {
        Map<String, Integer> counts = new Map<String, Integer>{
            'Critical' => 0,
            'High' => 0,
            'Medium' => 0,
            'Low' => 0
        };
        for (FlowFinding f : findings) {
            String sev = f.severity != null ? f.severity : 'Medium';
            if (counts.containsKey(sev)) {
                counts.put(sev, counts.get(sev) + 1);
            }
        }
        return counts;
    }
}
