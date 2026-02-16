/**
 * PERF-001: DML Inside Loop
 *
 * Detects Create/Update/Delete Records elements that execute inside
 * a Loop element. Each iteration consumes a DML statement against
 * the governor limit (150 per transaction). A loop over 150+ records
 * will hit the limit and throw a runtime exception.
 *
 * REMEDIATION: Collect records in a collection variable inside the
 * loop, then perform a single bulk DML operation after the loop.
 */
public class DmlInLoopRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        for (FlowMetadata.FlowElement dml : flow.getDmlElements()) {
            if (ctx.isInsideLoop(dml.name)) {
                String elementType = getElementType(dml);
                List<String> loops = ctx.getContainingLoops(dml.name);
                String loopNames = String.join(loops, ', ');
                String displayName = dml.label != null ? dml.label : dml.name;

                findings.add(
                    new FlowFinding('PERF-001', 'DML Inside Loop', 'Performance', 'Critical')
                        .withElement(dml.name, elementType)
                        .withDescription(
                            elementType + ' element "' + displayName +
                            '" is inside loop "' + loopNames +
                            '". Each iteration consumes a DML statement (limit: 150/transaction).'
                        )
                        .withRemediation(
                            'Collect records in a collection variable inside the loop, ' +
                            'then perform a single bulk DML operation after the loop exits.'
                        )
                );
            }
        }

        return findings;
    }

    private String getElementType(FlowMetadata.FlowElement el) {
        if (el instanceof FlowMetadata.FlowRecordCreate) return 'Create Records';
        if (el instanceof FlowMetadata.FlowRecordUpdate) return 'Update Records';
        if (el instanceof FlowMetadata.FlowRecordDelete) return 'Delete Records';
        return 'DML';
    }
}
