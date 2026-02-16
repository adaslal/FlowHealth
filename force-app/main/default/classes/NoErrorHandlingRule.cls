/**
 * ERR-002: No Error Handling
 *
 * Detects flows that have ZERO fault paths across all elements.
 * If no element in the flow has a fault connector, the flow has
 * absolutely no error handling — any runtime failure will crash
 * the entire transaction with no recovery path.
 *
 * This is a flow-level check (not per-element like ERR-001).
 * It fires only when the situation is dire: literally zero
 * fault connectors in the entire flow.
 *
 * REMEDIATION: At minimum, add fault paths to all DML operations.
 * Ideally, implement a consistent error handling pattern:
 * fault -> capture error -> notify -> graceful exit.
 */
public class NoErrorHandlingRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        // Count elements that SHOULD have fault paths
        Integer faultableCount = 0;
        faultableCount += safeSize(flow.recordCreates);
        faultableCount += safeSize(flow.recordUpdates);
        faultableCount += safeSize(flow.recordDeletes);
        faultableCount += safeSize(flow.recordLookups);
        faultableCount += safeSize(flow.actionCalls);

        // Count how many actually have fault paths
        Integer hasFaultCount = 0;
        for (FlowMetadata.FlowElement el : flow.getAllElements()) {
            if (el.faultConnector != null) {
                hasFaultCount++;
            }
        }

        // Only fire if there are faultable elements but zero fault paths
        if (faultableCount > 0 && hasFaultCount == 0) {
            findings.add(
                new FlowFinding('ERR-002', 'No Error Handling', 'Error Handling', 'Critical')
                    .withDescription(
                        'This flow has ' + faultableCount + ' data operation elements but ' +
                        'ZERO fault paths. Any runtime error will crash the entire flow ' +
                        'with no recovery option.'
                    )
                    .withRemediation(
                        'Add fault connectors to your DML and action elements. At minimum, ' +
                        'capture {!$Flow.FaultMessage} in an Assignment and route to an ' +
                        'error screen (Screen Flow) or email alert (Record-Triggered Flow).'
                    )
            );
        }

        return findings;
    }

    private Integer safeSize(List<Object> items) {
        return items != null ? items.size() : 0;
    }
}
