/**
 * ERR-001: Missing Fault Path
 *
 * Detects DML elements (Create/Update/Delete Records), SOQL elements
 * (Get Records), and Action elements (Apex actions, email alerts, etc.)
 * that do not have a fault connector configured.
 *
 * Without a fault path, any runtime error (duplicate rule violation,
 * required field missing, Apex exception, etc.) causes the entire
 * flow to fail with an unhandled fault — showing users a cryptic
 * error message and rolling back all database changes.
 *
 * REMEDIATION: Add a fault connector to each data operation element.
 * Connect it to an Assignment that captures $Flow.FaultMessage,
 * then route to appropriate error handling (screen message, email
 * notification, or custom error logging).
 */
public class MissingFaultPathRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        // Check Create Records
        if (flow.recordCreates != null) {
            for (FlowMetadata.FlowRecordCreate el : flow.recordCreates) {
                checkElement(el, 'Create Records', 'High', findings);
            }
        }

        // Check Update Records
        if (flow.recordUpdates != null) {
            for (FlowMetadata.FlowRecordUpdate el : flow.recordUpdates) {
                checkElement(el, 'Update Records', 'High', findings);
            }
        }

        // Check Delete Records
        if (flow.recordDeletes != null) {
            for (FlowMetadata.FlowRecordDelete el : flow.recordDeletes) {
                checkElement(el, 'Delete Records', 'High', findings);
            }
        }

        // Check Get Records (lower severity — reads are less risky)
        if (flow.recordLookups != null) {
            for (FlowMetadata.FlowRecordLookup el : flow.recordLookups) {
                checkElement(el, 'Get Records', 'Medium', findings);
            }
        }

        // Check Action elements (Apex actions, email alerts, etc.)
        if (flow.actionCalls != null) {
            for (FlowMetadata.FlowActionCall el : flow.actionCalls) {
                checkElement(el, 'Action', 'High', findings);
            }
        }

        return findings;
    }

    private void checkElement(FlowMetadata.FlowElement el, String elementType,
                              String severity, List<FlowFinding> findings) {
        if (el.faultConnector == null) {
            String displayName = el.label != null ? el.label : el.name;

            findings.add(
                new FlowFinding('ERR-001', 'Missing Fault Path', 'Error Handling', severity)
                    .withElement(el.name, elementType)
                    .withDescription(
                        elementType + ' element "' + displayName +
                        '" has no fault path. If this operation fails at runtime, ' +
                        'the entire flow will fail with an unhandled exception.'
                    )
                    .withRemediation(
                        'Add a fault connector to this element. Connect it to an ' +
                        'Assignment that captures {!$Flow.FaultMessage}, then route ' +
                        'to appropriate error handling (screen, email, or logging).'
                    )
            );
        }
    }
}
