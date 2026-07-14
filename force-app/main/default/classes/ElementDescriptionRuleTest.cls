/**
 * Tests for ElementDescriptionRule (DES-005).
 */
@IsTest
private class ElementDescriptionRuleTest {

    private static FlowMetadata.FlowDefinition buildFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Flow';
        flow.description = 'A test flow with a proper description.';
        flow.processType = 'AutoLaunchedFlow';
        return flow;
    }

    @IsTest
    static void flagsUndescribedHighConsequenceElements() {
        FlowMetadata.FlowDefinition flow = buildFlow();

        // Get Records with NO description → should be flagged
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Account';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        // Decision with NO description → should be flagged
        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'Check_Account_Availability';
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        Test.startTest();
        List<FlowFinding> findings = new ElementDescriptionRule()
            .evaluate(flow, new FlowAnalysisContext(flow));
        Test.stopTest();

        System.assertEquals(2, findings.size(), 'Both undescribed elements should be flagged');
        for (FlowFinding f : findings) {
            System.assertEquals('DES-005', f.ruleId);
            System.assertEquals('Low', f.severity);
            System.assertEquals('Design', f.category);
            System.assertNotEquals(null, f.elementName);
        }
    }

    @IsTest
    static void skipsDescribedElementsAndLowRiskTypes() {
        FlowMetadata.FlowDefinition flow = buildFlow();

        // Get Records WITH a description → should NOT be flagged
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Account';
        lookup.description = 'Fetches the parent Account to check its availability status.';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        // Assignment with NO description → not a high-consequence type, ignored
        FlowMetadata.FlowAssignment assignment = new FlowMetadata.FlowAssignment();
        assignment.name = 'Set_Status';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assignment };

        Test.startTest();
        List<FlowFinding> findings = new ElementDescriptionRule()
            .evaluate(flow, new FlowAnalysisContext(flow));
        Test.stopTest();

        System.assertEquals(0, findings.size(),
            'Described elements and low-risk element types should not be flagged');
    }

    @IsTest
    static void handlesNullElementLists() {
        FlowMetadata.FlowDefinition flow = buildFlow();
        // All element lists left null

        Test.startTest();
        List<FlowFinding> findings = new ElementDescriptionRule()
            .evaluate(flow, new FlowAnalysisContext(flow));
        Test.stopTest();

        System.assertEquals(0, findings.size(), 'Null element lists should produce no findings');
    }
}
