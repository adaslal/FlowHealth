/**
 * DES-005: Element Missing Description
 *
 * Flags HIGH-CONSEQUENCE elements (Get Records, DML operations,
 * Decisions, Loops) that have no description. These are the elements
 * where intent matters most for maintainability — a future admin needs
 * to know WHY a query filters the way it does, or WHY a decision
 * branches where it does.
 *
 * Deliberately does NOT flag Assignments, Screens, or other low-risk
 * elements — flagging every undescribed element would drown users in noise.
 *
 * SCORING BEHAVIOR (by design):
 * This rule ships with Weight = 0 in its Custom Metadata record, so by
 * default findings are INFORMATIONAL — they appear in the findings list
 * but deduct nothing from the score (deduction = weight × severity
 * multiplier = 0). The Settings tab exposes a checkbox ("Flag missing
 * element descriptions as errors") that flips the weight to 5, making
 * the findings affect the score. FlowRuleEngine always overrides
 * finding weight with the CMDT Weight__c value, which is what makes
 * this toggle work with no engine changes.
 */
public inherited sharing class ElementDescriptionRule implements FlowRule {

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        checkElements(flow.recordLookups, 'recordLookup', 'Get Records', findings);
        checkElements(flow.recordCreates, 'recordCreate', 'Create Records', findings);
        checkElements(flow.recordUpdates, 'recordUpdate', 'Update Records', findings);
        checkElements(flow.recordDeletes, 'recordDelete', 'Delete Records', findings);
        checkElements(flow.decisions,     'decision',     'Decision',       findings);
        checkElements(flow.loops,         'loop',         'Loop',           findings);

        return findings;
    }

    /**
     * Adds a finding for every element in the list with a blank description.
     * Uses List<Object> because Apex lacks wildcard generics; every element
     * list type extends FlowMetadata.FlowElement, so the cast is safe.
     */
    private void checkElements(
        List<Object> elements, String elementType, String typeLabel,
        List<FlowFinding> findings
    ) {
        if (elements == null) return;

        for (Object obj : elements) {
            FlowMetadata.FlowElement el = (FlowMetadata.FlowElement) obj;
            if (String.isBlank(el.description)) {
                findings.add(
                    new FlowFinding('DES-005', 'Element Missing Description', 'Design', 'Low')
                        .withElement(el.name, elementType)
                        .withDescription(
                            typeLabel + ' element "' + (el.name != null ? el.name : '(unnamed)') +
                            '" has no description. Data operations, decisions, and loops are ' +
                            'the elements where documented intent matters most for maintainability.'
                        )
                        .withRemediation(
                            'Add a short description explaining WHY this element exists — e.g. ' +
                            'for a Get Records: what the query fetches and why the filters are ' +
                            'set the way they are; for a Decision: what business condition each ' +
                            'branch represents.'
                        )
                );
            }
        }
    }
}
