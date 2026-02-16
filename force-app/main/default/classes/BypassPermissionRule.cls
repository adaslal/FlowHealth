/**
 * BypassPermissionRule (SEC-002) - Security
 *
 * Detects flows running in System Mode Without Sharing, which bypasses:
 * - Object-level security (CRUD permissions)
 * - Field-level security (FLS)
 * - Record-level security (sharing rules, OWD)
 *
 * While System Mode is sometimes necessary, it should be used intentionally.
 * Flows that bypass sharing without clear justification create security risks:
 * - Users may see or modify data they shouldn't have access to
 * - Compliance violations (HIPAA, SOX, GDPR)
 * - Data leakage across organizational boundaries
 *
 * This rule also checks for record-triggered flows that run in System Mode
 * Without Sharing but don't need to (e.g., flows that only update the triggering record).
 */
public class BypassPermissionRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        // Check 1: System Mode Without Sharing
        if (flow.runInMode != null && flow.runInMode == 'SystemModeWithoutSharing') {
            String flowLabel = flow.label != null ? flow.label : 'This flow';
            String processType = flow.processType != null ? flow.processType : 'Unknown';

            String severity = 'Medium';
            String description;

            // Screen flows in System Mode Without Sharing are higher risk
            // because they're user-facing and could expose restricted data
            if (processType == 'Flow') {
                severity = 'High';
                description = 'Screen flow "' + flowLabel + '" runs in System Mode Without Sharing. ' +
                    'This bypasses all record-level security, meaning users could view or modify data ' +
                    'they are restricted from accessing via sharing rules and org-wide defaults. ' +
                    'This is especially risky for user-facing screen flows.';
            } else {
                description = flowLabel + ' runs in System Mode Without Sharing. ' +
                    'All CRUD, FLS, and sharing rules are bypassed. Ensure this is intentional ' +
                    'and that the flow does not expose or modify data outside the user\'s access level.';
            }

            findings.add(
                new FlowFinding('SEC-002', 'System Mode Without Sharing', 'Security', severity)
                    .withDescription(description)
                    .withRemediation(
                        'Switch to "System Mode With Sharing" unless you specifically need to bypass sharing rules. ' +
                        'If System Mode Without Sharing is required, document the reason in the flow description ' +
                        'and ensure the flow does not expose restricted data to end users.'
                    )
            );
        }

        // Check 2: Record-triggered flows in Default Mode (User Context)
        // that perform DML — may fail unexpectedly if the running user lacks CRUD
        if (flow.processType != null && flow.processType == 'RecordTriggeredFlow' &&
            (flow.runInMode == null || flow.runInMode == 'DefaultMode')) {

            // Count DML elements that could fail due to insufficient permissions
            Integer dmlCount = 0;
            if (flow.recordCreates != null) dmlCount += flow.recordCreates.size();
            if (flow.recordUpdates != null) dmlCount += flow.recordUpdates.size();
            if (flow.recordDeletes != null) dmlCount += flow.recordDeletes.size();

            if (dmlCount > 0) {
                String flowLabel = flow.label != null ? flow.label : 'This flow';
                findings.add(
                    new FlowFinding('SEC-002', 'User Context DML Risk', 'Security', 'Low')
                        .withDescription(
                            'Record-triggered flow "' + flowLabel + '" runs in User Context (Default Mode) ' +
                            'with ' + dmlCount + ' DML operation(s). If the running user lacks CRUD permissions ' +
                            'on the target objects, these operations will fail silently or throw errors.'
                        )
                        .withRemediation(
                            'Consider switching to System Mode With Sharing if this flow needs to perform DML ' +
                            'regardless of the running user\'s permissions. Alternatively, ensure all users who ' +
                            'trigger this flow have the necessary CRUD permissions via permission sets.'
                        )
                );
            }
        }

        return findings;
    }
}
