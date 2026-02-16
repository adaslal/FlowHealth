/**
 * UnusedVariableRule (DES-004) - Design
 *
 * Detects variables that are declared but never referenced anywhere in the flow.
 * Unused variables:
 * - Clutter the flow and make it harder to maintain
 * - Suggest incomplete refactoring or abandoned development
 * - Can confuse other admins/developers trying to understand the flow
 * - Add unnecessary memory overhead at runtime
 *
 * Detection strategy:
 * - Collects all declared variable names
 * - Scans every element reference, assignment target, filter value,
 *   formula expression, loop collection, input/output parameter, etc.
 * - Reports any variable that is never referenced
 *
 * NOTE: Input/Output variables are excluded since they may be referenced
 * externally by calling flows, processes, or Apex invocations.
 */
public class UnusedVariableRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        if (flow.variables == null || flow.variables.isEmpty()) return findings;

        // Step 1: Collect all variable names (excluding Input/Output vars)
        Map<String, FlowMetadata.FlowVariable> variableMap = new Map<String, FlowMetadata.FlowVariable>();
        for (FlowMetadata.FlowVariable v : flow.variables) {
            // Skip input/output variables — they're referenced externally
            if (v.isInput == true || v.isOutput == true) continue;
            if (v.name != null) {
                variableMap.put(v.name, v);
            }
        }

        if (variableMap.isEmpty()) return findings;

        // Step 2: Collect all references used across the flow
        Set<String> referencedNames = new Set<String>();

        // Check loop collection references
        if (flow.loops != null) {
            for (FlowMetadata.FlowLoop lp : flow.loops) {
                addReference(referencedNames, lp.collectionReference);
                addReference(referencedNames, lp.assignNextValueToReference);
            }
        }

        // Check assignment targets and values
        if (flow.assignments != null) {
            for (FlowMetadata.FlowAssignment assign : flow.assignments) {
                if (assign.assignmentItems != null) {
                    for (FlowMetadata.FlowAssignmentItem item : assign.assignmentItems) {
                        addReference(referencedNames, item.assignToReference);
                        addValueReferences(referencedNames, item.value);
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
                                addReference(referencedNames, cond.leftValueReference);
                                addValueReferences(referencedNames, cond.rightValue);
                            }
                        }
                    }
                }
            }
        }

        // Check record create input assignments and references
        if (flow.recordCreates != null) {
            for (FlowMetadata.FlowRecordCreate rc : flow.recordCreates) {
                addReference(referencedNames, rc.inputReference);
                addReference(referencedNames, rc.assignRecordIdToReference);
                if (rc.inputAssignments != null) {
                    for (FlowMetadata.FlowInputAssignment ia : rc.inputAssignments) {
                        addValueReferences(referencedNames, ia.value);
                    }
                }
            }
        }

        // Check record update
        if (flow.recordUpdates != null) {
            for (FlowMetadata.FlowRecordUpdate ru : flow.recordUpdates) {
                addReference(referencedNames, ru.inputReference);
                if (ru.inputAssignments != null) {
                    for (FlowMetadata.FlowInputAssignment ia : ru.inputAssignments) {
                        addValueReferences(referencedNames, ia.value);
                    }
                }
                if (ru.filters != null) {
                    for (FlowMetadata.FlowRecordFilter f : ru.filters) {
                        addValueReferences(referencedNames, f.value);
                    }
                }
            }
        }

        // Check record delete
        if (flow.recordDeletes != null) {
            for (FlowMetadata.FlowRecordDelete rd : flow.recordDeletes) {
                addReference(referencedNames, rd.inputReference);
                if (rd.filters != null) {
                    for (FlowMetadata.FlowRecordFilter f : rd.filters) {
                        addValueReferences(referencedNames, f.value);
                    }
                }
            }
        }

        // Check record lookups
        if (flow.recordLookups != null) {
            for (FlowMetadata.FlowRecordLookup rl : flow.recordLookups) {
                addReference(referencedNames, rl.outputReference);
                if (rl.filters != null) {
                    for (FlowMetadata.FlowRecordFilter f : rl.filters) {
                        addValueReferences(referencedNames, f.value);
                    }
                }
                if (rl.outputAssignments != null) {
                    for (FlowMetadata.FlowOutputAssignment oa : rl.outputAssignments) {
                        addReference(referencedNames, oa.assignToReference);
                    }
                }
            }
        }

        // Check subflow input/output assignments
        if (flow.subflows != null) {
            for (FlowMetadata.FlowSubflow sf : flow.subflows) {
                if (sf.inputAssignments != null) {
                    for (FlowMetadata.FlowInputParameter ip : sf.inputAssignments) {
                        addValueReferences(referencedNames, ip.value);
                    }
                }
                if (sf.outputAssignments != null) {
                    for (FlowMetadata.FlowOutputParameter op : sf.outputAssignments) {
                        addReference(referencedNames, op.assignToReference);
                    }
                }
            }
        }

        // Check action call input/output parameters
        if (flow.actionCalls != null) {
            for (FlowMetadata.FlowActionCall ac : flow.actionCalls) {
                if (ac.inputParameters != null) {
                    for (FlowMetadata.FlowInputParameter ip : ac.inputParameters) {
                        addValueReferences(referencedNames, ip.value);
                    }
                }
                if (ac.outputParameters != null) {
                    for (FlowMetadata.FlowOutputParameter op : ac.outputParameters) {
                        addReference(referencedNames, op.assignToReference);
                    }
                }
            }
        }

        // Check screen field default values (basic check)
        if (flow.screens != null) {
            for (FlowMetadata.FlowScreen scr : flow.screens) {
                if (scr.fields != null) {
                    for (FlowMetadata.FlowScreenField sf : scr.fields) {
                        addReference(referencedNames, sf.defaultValue);
                    }
                }
            }
        }

        // Check formula expressions for variable references
        if (flow.formulas != null) {
            for (FlowMetadata.FlowFormula formula : flow.formulas) {
                if (formula.expression != null) {
                    // Check if any variable name appears in the expression
                    for (String varName : variableMap.keySet()) {
                        if (formula.expression.contains(varName)) {
                            referencedNames.add(varName);
                        }
                    }
                }
            }
        }

        // Check text template text for variable merge fields
        if (flow.textTemplates != null) {
            for (FlowMetadata.FlowTextTemplate tt : flow.textTemplates) {
                if (tt.text != null) {
                    for (String varName : variableMap.keySet()) {
                        if (tt.text.contains(varName)) {
                            referencedNames.add(varName);
                        }
                    }
                }
            }
        }

        // Step 3: Report unreferenced variables
        for (String varName : variableMap.keySet()) {
            if (!referencedNames.contains(varName)) {
                FlowMetadata.FlowVariable v = variableMap.get(varName);
                String dataType = v.dataType != null ? v.dataType : 'Unknown';

                findings.add(
                    new FlowFinding('DES-004', 'Unused Variable', 'Design', 'Low')
                        .withElement(varName, 'Variable (' + dataType + ')')
                        .withDescription(
                            'Variable "' + varName + '" (type: ' + dataType +
                            ') is declared but never referenced in any flow element. ' +
                            'Unused variables add clutter and suggest incomplete refactoring.'
                        )
                        .withRemediation(
                            'Remove unused variable "' + varName + '" from the flow to keep it clean. ' +
                            'If the variable is needed for future work, add a comment or description explaining its purpose.'
                        )
                );
            }
        }

        return findings;
    }

    private void addReference(Set<String> refs, String reference) {
        if (reference != null && reference.length() > 0) {
            // Handle dot notation (e.g., "myVar.Name" -> "myVar")
            String baseName = reference.contains('.') ? reference.substringBefore('.') : reference;
            refs.add(baseName);
        }
    }

    private void addValueReferences(Set<String> refs, FlowMetadata.FlowValue val) {
        if (val != null && val.elementReference != null) {
            addReference(refs, val.elementReference);
        }
    }
}
