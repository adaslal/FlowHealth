/**
 * PERF-005: Excessive Elements
 *
 * Detects flows with an unusually high number of elements.
 * Large flows are harder to maintain, debug, and test. They also
 * increase the risk of hitting CPU timeout limits and make
 * version comparison nearly impossible.
 *
 * Thresholds:
 * - 50+ elements:  Medium (consider refactoring)
 * - 100+ elements: High (should refactor into subflows)
 *
 * REMEDIATION: Break the flow into smaller, focused subflows.
 * Each subflow should handle a single responsibility (e.g.,
 * validation, data enrichment, notification).
 */
public class ExcessiveElementsRule implements FlowRule {

    private static final Integer MEDIUM_THRESHOLD = 50;
    private static final Integer HIGH_THRESHOLD = 100;

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        Integer totalElements = flow.getAllElements().size();

        if (totalElements >= HIGH_THRESHOLD) {
            findings.add(
                new FlowFinding('PERF-005', 'Excessive Elements', 'Performance', 'High')
                    .withDescription(
                        'This flow contains ' + totalElements + ' elements (threshold: ' +
                        HIGH_THRESHOLD + '). Flows this large are very difficult to maintain ' +
                        'and debug, and risk CPU timeout exceptions.'
                    )
                    .withRemediation(
                        'Break this flow into smaller subflows, each handling a single ' +
                        'responsibility. Use a main orchestrator flow to call subflows ' +
                        'in sequence. Aim for fewer than ' + MEDIUM_THRESHOLD +
                        ' elements per flow.'
                    )
            );
        } else if (totalElements >= MEDIUM_THRESHOLD) {
            findings.add(
                new FlowFinding('PERF-005', 'Excessive Elements', 'Performance', 'Medium')
                    .withDescription(
                        'This flow contains ' + totalElements + ' elements (threshold: ' +
                        MEDIUM_THRESHOLD + '). Consider refactoring into subflows for ' +
                        'better maintainability.'
                    )
                    .withRemediation(
                        'Consider splitting this flow into focused subflows. Each subflow ' +
                        'should handle one logical responsibility. This improves readability ' +
                        'and makes testing easier.'
                    )
            );
        }

        return findings;
    }
}
