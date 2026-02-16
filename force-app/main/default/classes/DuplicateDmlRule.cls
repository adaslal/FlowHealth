/**
 * DuplicateDmlRule (PERF-007) - Performance
 *
 * Detects multiple DML operations on the same SObject type within a single flow.
 * Each DML operation on the same object could potentially be consolidated into
 * a single operation, reducing governor limit consumption.
 *
 * Examples of what this catches:
 * - Two separate "Update Account" elements that could be merged into one
 * - A "Create Contact" followed by another "Create Contact" in different branches
 *   that could share a single bulk create
 * - Multiple "Delete" operations on the same object scattered across the flow
 *
 * This is especially impactful in record-triggered flows where governor limits
 * are shared across all triggers in the transaction.
 */
public class DuplicateDmlRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        // Track DML operations grouped by SObject type and DML type
        Map<String, List<String>> createsByObject = new Map<String, List<String>>();
        Map<String, List<String>> updatesByObject = new Map<String, List<String>>();
        Map<String, List<String>> deletesByObject = new Map<String, List<String>>();

        // Collect Create Records by object
        if (flow.recordCreates != null) {
            for (FlowMetadata.FlowRecordCreate rc : flow.recordCreates) {
                String objName = rc.object_x != null ? rc.object_x : 'Unknown';
                if (!createsByObject.containsKey(objName)) {
                    createsByObject.put(objName, new List<String>());
                }
                String displayName = rc.label != null ? rc.label : rc.name;
                createsByObject.get(objName).add(displayName);
            }
        }

        // Collect Update Records by object
        if (flow.recordUpdates != null) {
            for (FlowMetadata.FlowRecordUpdate ru : flow.recordUpdates) {
                String objName = ru.object_x != null ? ru.object_x : 'Unknown';
                if (!updatesByObject.containsKey(objName)) {
                    updatesByObject.put(objName, new List<String>());
                }
                String displayName = ru.label != null ? ru.label : ru.name;
                updatesByObject.get(objName).add(displayName);
            }
        }

        // Collect Delete Records by object
        if (flow.recordDeletes != null) {
            for (FlowMetadata.FlowRecordDelete rd : flow.recordDeletes) {
                String objName = rd.object_x != null ? rd.object_x : 'Unknown';
                if (!deletesByObject.containsKey(objName)) {
                    deletesByObject.put(objName, new List<String>());
                }
                String displayName = rd.label != null ? rd.label : rd.name;
                deletesByObject.get(objName).add(displayName);
            }
        }

        // Report duplicates
        reportDuplicates(findings, createsByObject, 'Create Records');
        reportDuplicates(findings, updatesByObject, 'Update Records');
        reportDuplicates(findings, deletesByObject, 'Delete Records');

        return findings;
    }

    private void reportDuplicates(List<FlowFinding> findings, Map<String, List<String>> byObject, String dmlType) {
        for (String objName : byObject.keySet()) {
            List<String> elementNames = byObject.get(objName);
            if (elementNames.size() > 1) {
                String severity = elementNames.size() > 3 ? 'High' : 'Medium';

                findings.add(
                    new FlowFinding('PERF-007', 'Duplicate DML Operations', 'Performance', severity)
                        .withDescription(
                            elementNames.size() + ' separate "' + dmlType + '" operations found for ' +
                            objName + ': ' + String.join(elementNames, ', ') + '. ' +
                            'Each operation consumes a DML statement against the governor limit (150/transaction). ' +
                            'Consolidating these into fewer operations reduces limit consumption.'
                        )
                        .withRemediation(
                            'Merge multiple "' + dmlType + '" operations on ' + objName +
                            ' into a single bulk operation where possible. Use collection variables ' +
                            'to accumulate records, then perform one DML at the end of the flow path. ' +
                            'If the operations are in different decision branches, this may be acceptable.'
                        )
                );
            }
        }
    }
}
