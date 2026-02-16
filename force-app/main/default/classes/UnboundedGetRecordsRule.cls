/**
 * PERF-004: Unbounded Get Records
 *
 * Detects Get Records elements that retrieve multiple records
 * (getFirstRecordOnly = false) without any filter conditions.
 * Without filters, the query returns ALL records of that object type,
 * potentially millions of rows. This causes:
 * - Heap size limit exceptions (6MB synchronous / 12MB async)
 * - Extremely slow flow execution
 * - CPU timeout exceptions during downstream processing
 *
 * REMEDIATION: Always add filter conditions to limit the result set.
 * If you genuinely need all records, consider using a Batch Apex
 * approach instead of a flow.
 */
public class UnboundedGetRecordsRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        for (FlowMetadata.FlowRecordLookup lookup : flow.getSoqlElements()) {
            // Only flag if retrieving multiple records (collection) with no filters
            Boolean isCollection = lookup.getFirstRecordOnly == null || !lookup.getFirstRecordOnly;
            Boolean hasNoFilters = lookup.filters == null || lookup.filters.isEmpty();

            if (isCollection && hasNoFilters) {
                String displayName = lookup.label != null ? lookup.label : lookup.name;
                String objectName = lookup.object_x != null ? lookup.object_x : 'unknown object';

                findings.add(
                    new FlowFinding('PERF-004', 'Unbounded Get Records', 'Performance', 'High')
                        .withElement(lookup.name, 'Get Records')
                        .withDescription(
                            'Get Records element "' + displayName +
                            '" retrieves all ' + objectName +
                            ' records with no filter conditions. This could return ' +
                            'millions of rows, causing heap or CPU limit exceptions.'
                        )
                        .withRemediation(
                            'Add filter conditions to limit the result set to only the ' +
                            'records you need. Consider filtering by record ownership, ' +
                            'date ranges, or related record IDs.'
                        )
                );
            }
        }

        return findings;
    }
}
