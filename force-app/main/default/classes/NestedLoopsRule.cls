/**
 * PERF-003: Nested Loops
 *
 * Detects Loop elements that are inside other Loop elements.
 * Nested loops multiply the iteration count: an outer loop of 100
 * items with an inner loop of 50 items means 5,000 iterations.
 * Combined with any DML/SOQL inside the inner loop, this quickly
 * exhausts governor limits.
 *
 * Even without DML/SOQL, deeply nested loops cause CPU timeout
 * exceptions in complex flows.
 *
 * REMEDIATION: Flatten the logic using collection operations,
 * or restructure using a single loop with assignment-based lookups.
 */
public class NestedLoopsRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        if (flow.loops == null || flow.loops.isEmpty()) {
            return findings;
        }

        for (FlowMetadata.FlowLoop flowLoop : flow.loops) {
            if (ctx.isInsideLoop(flowLoop.name)) {
                List<String> outerLoops = ctx.getContainingLoops(flowLoop.name);
                String displayName = flowLoop.label != null ? flowLoop.label : flowLoop.name;

                findings.add(
                    new FlowFinding('PERF-003', 'Nested Loops', 'Performance', 'High')
                        .withElement(flowLoop.name, 'Loop')
                        .withDescription(
                            'Loop "' + displayName + '" is nested inside loop "' +
                            String.join(outerLoops, ', ') +
                            '". Nested loops multiply iterations exponentially and ' +
                            'risk CPU timeout exceptions.'
                        )
                        .withRemediation(
                            'Restructure to avoid nested loops. Consider using collection ' +
                            'variables with Assignment elements to build data structures ' +
                            'that can be processed in a single loop.'
                        )
                );
            }
        }

        return findings;
    }
}
