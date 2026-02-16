/**
 * HardcodedIdRule (SEC-001) - Security
 *
 * Detects hardcoded Salesforce record IDs in flow elements.
 * Hardcoded IDs break when migrating between environments (sandbox → production),
 * are fragile to data changes, and represent a significant deployment risk.
 *
 * Detection strategy:
 * - Scans all assignment values, input parameters, record filters, and formula
 *   expressions for strings matching the 15-char or 18-char Salesforce ID pattern.
 * - Uses a regex pattern that matches the standard Salesforce ID format:
 *   [a-zA-Z0-9]{15} or [a-zA-Z0-9]{18} that starts with a valid 3-char key prefix.
 */
public class HardcodedIdRule implements FlowRule {

    // Salesforce IDs are 15 or 18 alphanumeric characters starting with
    // a 3-character key prefix (e.g., 001 for Account, 003 for Contact).
    // We look for standalone ID-shaped strings in flow values.
    private static final Pattern ID_PATTERN = Pattern.compile(
        '(?<![a-zA-Z0-9])([a-zA-Z0-9]{3}[a-zA-Z0-9]{12}([a-zA-Z0-9]{3})?)(?![a-zA-Z0-9])'
    );

    // Known Salesforce key prefixes (first 3 chars) that confirm it's a real ID
    private static final Set<String> COMMON_PREFIXES = new Set<String>{
        '001', '003', '005', '006', '00Q', '00T', '00U', '00e', '00o',
        '500', '701', '801', '01p', '01q', '01I', '01t', '012', '0D5',
        '00D', '0DM', '0Q0', 'a0', 'a1', 'a2', 'a3'
    };

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        // Check assignments
        if (flow.assignments != null) {
            for (FlowMetadata.FlowAssignment assign : flow.assignments) {
                if (assign.assignmentItems != null) {
                    for (FlowMetadata.FlowAssignmentItem item : assign.assignmentItems) {
                        String hardcodedId = extractHardcodedId(item.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(assign.name, 'Assignment', assign.label, hardcodedId));
                        }
                    }
                }
            }
        }

        // Check record create input assignments
        if (flow.recordCreates != null) {
            for (FlowMetadata.FlowRecordCreate rc : flow.recordCreates) {
                if (rc.inputAssignments != null) {
                    for (FlowMetadata.FlowInputAssignment ia : rc.inputAssignments) {
                        String hardcodedId = extractHardcodedId(ia.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(rc.name, 'Create Records', rc.label, hardcodedId));
                        }
                    }
                }
            }
        }

        // Check record update input assignments
        if (flow.recordUpdates != null) {
            for (FlowMetadata.FlowRecordUpdate ru : flow.recordUpdates) {
                if (ru.inputAssignments != null) {
                    for (FlowMetadata.FlowInputAssignment ia : ru.inputAssignments) {
                        String hardcodedId = extractHardcodedId(ia.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(ru.name, 'Update Records', ru.label, hardcodedId));
                        }
                    }
                }
            }
        }

        // Check record lookup filters
        if (flow.recordLookups != null) {
            for (FlowMetadata.FlowRecordLookup rl : flow.recordLookups) {
                if (rl.filters != null) {
                    for (FlowMetadata.FlowRecordFilter filter : rl.filters) {
                        String hardcodedId = extractHardcodedId(filter.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(rl.name, 'Get Records', rl.label, hardcodedId));
                        }
                    }
                }
            }
        }

        // Check record delete filters
        if (flow.recordDeletes != null) {
            for (FlowMetadata.FlowRecordDelete rd : flow.recordDeletes) {
                if (rd.filters != null) {
                    for (FlowMetadata.FlowRecordFilter filter : rd.filters) {
                        String hardcodedId = extractHardcodedId(filter.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(rd.name, 'Delete Records', rd.label, hardcodedId));
                        }
                    }
                }
            }
        }

        // Check decision conditions
        if (flow.decisions != null) {
            for (FlowMetadata.FlowDecision dec : flow.decisions) {
                if (dec.rules != null) {
                    for (FlowMetadata.FlowRule rule : dec.rules) {
                        if (rule.conditions != null) {
                            for (FlowMetadata.FlowCondition cond : rule.conditions) {
                                String hardcodedId = extractHardcodedId(cond.rightValue);
                                if (hardcodedId != null) {
                                    findings.add(buildFinding(dec.name, 'Decision', dec.label, hardcodedId));
                                }
                            }
                        }
                    }
                }
            }
        }

        // Check formula expressions
        if (flow.formulas != null) {
            for (FlowMetadata.FlowFormula formula : flow.formulas) {
                if (formula.expression != null) {
                    String hardcodedId = extractIdFromText(formula.expression);
                    if (hardcodedId != null) {
                        findings.add(
                            new FlowFinding('SEC-001', 'Hardcoded Record ID', 'Security', 'High')
                                .withElement(formula.name, 'Formula')
                                .withDescription(
                                    'Formula "' + formula.name + '" contains hardcoded Salesforce ID "' +
                                    hardcodedId + '". Hardcoded IDs will break during sandbox-to-production deployments.'
                                )
                                .withRemediation(
                                    'Replace hardcoded IDs with dynamic lookups using Get Records elements, ' +
                                    'Custom Labels, Custom Metadata, or Custom Settings for environment portability.'
                                )
                        );
                    }
                }
            }
        }

        // Check action call input parameters
        if (flow.actionCalls != null) {
            for (FlowMetadata.FlowActionCall ac : flow.actionCalls) {
                if (ac.inputParameters != null) {
                    for (FlowMetadata.FlowInputParameter ip : ac.inputParameters) {
                        String hardcodedId = extractHardcodedId(ip.value);
                        if (hardcodedId != null) {
                            findings.add(buildFinding(ac.name, 'Action', ac.label, hardcodedId));
                        }
                    }
                }
            }
        }

        return findings;
    }

    private FlowFinding buildFinding(String elementName, String elementType, String label, String hardcodedId) {
        String displayName = label != null ? label : elementName;
        return new FlowFinding('SEC-001', 'Hardcoded Record ID', 'Security', 'High')
            .withElement(elementName, elementType)
            .withDescription(
                elementType + ' element "' + displayName + '" contains hardcoded Salesforce ID "' +
                hardcodedId + '". This ID will differ between sandbox and production environments.'
            )
            .withRemediation(
                'Replace hardcoded IDs with dynamic lookups using Get Records elements, ' +
                'Custom Labels, Custom Metadata, or Custom Settings for environment portability.'
            );
    }

    private String extractHardcodedId(FlowMetadata.FlowValue val) {
        if (val == null) return null;
        if (val.stringValue != null) {
            return extractIdFromText(val.stringValue);
        }
        return null;
    }

    private String extractIdFromText(String text) {
        if (text == null || text.length() < 15) return null;

        Matcher m = ID_PATTERN.matcher(text);
        while (m.find()) {
            String candidate = m.group(1);
            String prefix = candidate.substring(0, 3);
            // Check if prefix matches known Salesforce key prefixes
            if (COMMON_PREFIXES.contains(prefix) || COMMON_PREFIXES.contains(prefix.substring(0, 2))) {
                return candidate;
            }
        }
        return null;
    }
}
