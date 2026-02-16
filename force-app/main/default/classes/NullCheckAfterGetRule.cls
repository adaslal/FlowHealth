/**
 * DES-002: Missing Null Check After Get Records
 *
 * Detects Get Records elements configured to return a single record
 * (getFirstRecordOnly = true) where the NEXT element is NOT a
 * Decision that could check whether the record was found.
 *
 * When Get Records returns a single record and no record matches,
 * the output variable is null. If the flow immediately tries to
 * use that variable (in an Assignment, Update, etc.) without
 * checking for null first, it will fail at runtime.
 *
 * REMEDIATION: After every single-record Get Records, add a
 * Decision element that checks "{!recordVariable} Is Null = false"
 * before proceeding to use the record.
 */
public class NullCheckAfterGetRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        if (flow.recordLookups == null) {
            return findings;
        }

        for (FlowMetadata.FlowRecordLookup lookup : flow.recordLookups) {
            // Only check single-record lookups
            if (lookup.getFirstRecordOnly == null || !lookup.getFirstRecordOnly) {
                continue;
            }

            // Check what the next element is
            FlowMetadata.FlowElement nextElement = ctx.getNextElement(lookup.connector);

            if (nextElement == null) {
                // No next element (dead end after get records) - different issue
                continue;
            }

            // If the next element is NOT a Decision, flag it
            if (!(nextElement instanceof FlowMetadata.FlowDecision)) {
                String displayName = lookup.label != null ? lookup.label : lookup.name;
                String nextName = nextElement.label != null ? nextElement.label : nextElement.name;
                String nextType = getElementType(nextElement);

                findings.add(
                    new FlowFinding('DES-002', 'Missing Null Check', 'Design', 'Medium')
                        .withElement(lookup.name, 'Get Records')
                        .withDescription(
                            'Get Records element "' + displayName +
                            '" retrieves a single record but is followed by ' +
                            nextType + ' "' + nextName + '" instead of a null check. ' +
                            'If no record is found, the variable will be null and ' +
                            'downstream elements may fail.'
                        )
                        .withRemediation(
                            'Add a Decision element after this Get Records to check: ' +
                            '"Is the record variable null?" Route the "null" outcome ' +
                            'to an appropriate fallback path before using the variable.'
                        )
                );
            }
        }

        return findings;
    }

    private String getElementType(FlowMetadata.FlowElement el) {
        if (el instanceof FlowMetadata.FlowAssignment) return 'Assignment';
        if (el instanceof FlowMetadata.FlowRecordUpdate) return 'Update Records';
        if (el instanceof FlowMetadata.FlowRecordCreate) return 'Create Records';
        if (el instanceof FlowMetadata.FlowRecordDelete) return 'Delete Records';
        if (el instanceof FlowMetadata.FlowRecordLookup) return 'Get Records';
        if (el instanceof FlowMetadata.FlowLoop) return 'Loop';
        if (el instanceof FlowMetadata.FlowScreen) return 'Screen';
        if (el instanceof FlowMetadata.FlowSubflow) return 'Subflow';
        if (el instanceof FlowMetadata.FlowActionCall) return 'Action';
        return 'Element';
    }
}
