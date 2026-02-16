/**
 * PERF-002: SOQL Inside Loop
 *
 * Detects Get Records elements that execute inside a Loop element.
 * Each iteration consumes a SOQL query against the governor limit
 * (100 per transaction). A loop over 100+ records will throw
 * a runtime exception.
 *
 * REMEDIATION: Move the Get Records before the loop and store results
 * in a collection variable. If you need to look up related records,
 * fetch them all at once with a single Get Records using an
 * "In" filter on the collection.
 */
public class SoqlInLoopRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        for (FlowMetadata.FlowRecordLookup lookup : flow.getSoqlElements()) {
            if (ctx.isInsideLoop(lookup.name)) {
                List<String> loops = ctx.getContainingLoops(lookup.name);
                String loopNames = String.join(loops, ', ');
                String displayName = lookup.label != null ? lookup.label : lookup.name;

                findings.add(
                    new FlowFinding('PERF-002', 'SOQL Inside Loop', 'Performance', 'Critical')
                        .withElement(lookup.name, 'Get Records')
                        .withDescription(
                            'Get Records element "' + displayName +
                            '" is inside loop "' + loopNames +
                            '". Each iteration consumes a SOQL query (limit: 100/transaction).'
                        )
                        .withRemediation(
                            'Move the Get Records element before the loop. Fetch all needed ' +
                            'records in a single query, then iterate over the results.'
                        )
                );
            }
        }

        return findings;
    }
}
