/**
 * PERF-006: Subflow Inside Loop
 *
 * Detects Subflow (Action) elements that execute inside a Loop.
 * Each subflow invocation runs in the same transaction context and
 * inherits the parent's governor limits. If the subflow performs
 * DML or SOQL operations, those counts multiply by the number of
 * loop iterations — leading to rapid limit exhaustion.
 *
 * Even if the subflow itself is "clean," the overhead of launching
 * it repeatedly adds CPU time per iteration.
 *
 * REMEDIATION: Collect the data needed in a collection variable,
 * then pass the entire collection to a single subflow call after
 * the loop. Design subflows to accept collections and process
 * records in bulk.
 */
public class SubflowInLoopRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        if (flow.subflows == null || flow.subflows.isEmpty()) {
            return findings;
        }

        for (FlowMetadata.FlowSubflow subflow : flow.subflows) {
            if (ctx.isInsideLoop(subflow.name)) {
                List<String> loops = ctx.getContainingLoops(subflow.name);
                String displayName = subflow.label != null ? subflow.label : subflow.name;
                String calledFlow = subflow.flowName != null ? subflow.flowName : 'unknown';

                findings.add(
                    new FlowFinding('PERF-006', 'Subflow Inside Loop', 'Performance', 'High')
                        .withElement(subflow.name, 'Subflow')
                        .withDescription(
                            'Subflow "' + displayName + '" (calls: ' + calledFlow +
                            ') is inside loop "' + String.join(loops, ', ') +
                            '". Each iteration invokes the subflow, multiplying any ' +
                            'DML/SOQL operations within it.'
                        )
                        .withRemediation(
                            'Collect data in a collection variable inside the loop, then ' +
                            'pass the collection to a single subflow call after the loop. ' +
                            'Design the subflow to process records in bulk.'
                        )
                );
            }
        }

        return findings;
    }
}
