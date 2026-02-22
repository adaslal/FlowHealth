/**
 * CustomRuleEvaluatorTest - Unit tests for the CustomRuleEvaluator class.
 *
 * Tests all five rule types:
 * 1. Element Count Threshold - flags if element count exceeds threshold
 * 2. Element Name Pattern - flags elements matching a regex pattern
 * 3. Flow Property Check - flags if flow property doesn't match expected value
 * 4. Element In Loop Check - flags elements inside loops
 * 5. Missing Fault Path Check - flags elements without fault connectors
 *
 * APPROACH: Uses CustomRuleEvaluator.testRule() with in-memory (unsaved)
 * Flow_Health_Custom_Rule__c objects. This avoids needing database inserts
 * and allows thorough testing of each rule type.
 */
@IsTest
private class CustomRuleEvaluatorTest {

    // =========================================================================
    // HELPER: Build test rules and flows
    // =========================================================================

    /**
     * Creates a minimal clean flow with a few elements.
     */
    private static FlowMetadata.FlowDefinition buildCleanFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Flow';
        flow.description = 'A well-designed test flow';
        flow.processType = 'AutoLaunchedFlow';
        flow.runInMode = 'SystemModeWithSharing';
        flow.apiVersion = '62.0';

        // Add a few elements
        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'Check_Status';
        decision.label = 'Check Status';
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        FlowMetadata.FlowAssignment assignment = new FlowMetadata.FlowAssignment();
        assignment.name = 'Set_Values';
        assignment.label = 'Set Values';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assignment };

        return flow;
    }

    /**
     * Creates a flow with many record lookups (for threshold tests).
     */
    private static FlowMetadata.FlowDefinition buildFlowWithManyLookupsCount(Integer count) {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>();

        for (Integer i = 0; i < count; i++) {
            FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
            lookup.name = 'Lookup_' + i;
            lookup.label = 'Lookup ' + i;
            lookup.object_x = 'Account';
            flow.recordLookups.add(lookup);
        }

        return flow;
    }

    /**
     * Creates a flow with elements matching a specific name pattern.
     */
    private static FlowMetadata.FlowDefinition buildFlowWithNamedElements(
        List<String> elementNames
    ) {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.decisions = new List<FlowMetadata.FlowDecision>();

        for (String name : elementNames) {
            FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
            decision.name = name;
            decision.label = name;
            flow.decisions.add(decision);
        }

        return flow;
    }

    /**
     * Creates a flow with a loop containing an element.
     */
    private static FlowMetadata.FlowDefinition buildFlowWithElementInLoop() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Loop Test Flow';
        flow.processType = 'AutoLaunchedFlow';

        // Create a loop
        FlowMetadata.FlowLoop loopElement = new FlowMetadata.FlowLoop();
        loopElement.name = 'Loop_Accounts';
        loopElement.label = 'Loop Through Accounts';
        loopElement.collectionReference = 'var_Accounts';

        // Element inside loop
        FlowMetadata.FlowScreen screenInLoop = new FlowMetadata.FlowScreen();
        screenInLoop.name = 'Display_Account';
        screenInLoop.label = 'Display Account';

        // Connect loop to screen
        loopElement.nextValueConnector = new FlowMetadata.FlowConnector();
        loopElement.nextValueConnector.targetReference = 'Display_Account';

        loopElement.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        loopElement.noMoreValuesConnector.targetReference = 'Done';

        // Terminal element
        FlowMetadata.FlowAssignment done = new FlowMetadata.FlowAssignment();
        done.name = 'Done';
        done.label = 'Done';

        flow.loops = new List<FlowMetadata.FlowLoop>{ loopElement };
        flow.screens = new List<FlowMetadata.FlowScreen>{ screenInLoop };
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ done };

        return flow;
    }

    /**
     * Creates a flow with elements that have/lack fault connectors.
     */
    private static FlowMetadata.FlowDefinition buildFlowWithFaultConnectors(
        Boolean hasFaultConnector
    ) {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.actionCalls = new List<FlowMetadata.FlowActionCall>();

        FlowMetadata.FlowActionCall actionCall = new FlowMetadata.FlowActionCall();
        actionCall.name = 'Call_Action';
        actionCall.label = 'Call Action';
        actionCall.actionName = 'apex_action';

        if (hasFaultConnector) {
            actionCall.faultConnector = new FlowMetadata.FlowConnector();
            actionCall.faultConnector.targetReference = 'Handle_Error';
        }

        flow.actionCalls.add(actionCall);

        // Add error handler if needed
        if (hasFaultConnector) {
            FlowMetadata.FlowAssignment handler = new FlowMetadata.FlowAssignment();
            handler.name = 'Handle_Error';
            handler.label = 'Handle Error';
            flow.assignments = new List<FlowMetadata.FlowAssignment>{ handler };
        }

        return flow;
    }

    // =========================================================================
    // TEST: Element Count Threshold Rule Type
    // =========================================================================

    /**
     * Test 1: Element Count Threshold - exceeds threshold → finding generated
     */
    @IsTest
    static void testElementCountThresholdExceedsThreshold() {
        // Build a flow with 12 record lookups
        FlowMetadata.FlowDefinition flow = buildFlowWithManyLookupsCount(12);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        // Create rule: flag if more than 10 lookups
        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-001';
        rule.Name = 'Too Many Lookups';
        rule.Rule_Type__c = 'Element Count Threshold';
        rule.Target_Element_Type__c = 'Record Lookups';
        rule.Threshold_Value__c = 10;
        rule.Category__c = 'Performance';
        rule.Severity__c = 'High';
        rule.Description__c = 'Too many record lookups in a single flow';
        rule.Remediation__c = 'Reduce the number of lookups';
        rule.Weight__c = 10;

        // Evaluate
        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        // Assert: should find 1 violation
        Assert.areEqual(1, findings.size(), 'Expected 1 finding for exceeding threshold');
        Assert.areEqual('RULE-001', findings[0].ruleId, 'Rule ID should match');
        Assert.isTrue(
            findings[0].description.contains('12'),
            'Description should contain count'
        );
    }

    /**
     * Test 2: Element Count Threshold - below threshold → no finding
     */
    @IsTest
    static void testElementCountThresholdBelowThreshold() {
        // Build flow with 5 record lookups
        FlowMetadata.FlowDefinition flow = buildFlowWithManyLookupsCount(5);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-002';
        rule.Name = 'Too Many Lookups';
        rule.Rule_Type__c = 'Element Count Threshold';
        rule.Target_Element_Type__c = 'Record Lookups';
        rule.Threshold_Value__c = 10;
        rule.Category__c = 'Performance';
        rule.Severity__c = 'High';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when below threshold');
    }

    /**
     * Test 3: Element Count Threshold - null threshold → no finding
     */
    @IsTest
    static void testElementCountThresholdNullThreshold() {
        FlowMetadata.FlowDefinition flow = buildFlowWithManyLookupsCount(15);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-003';
        rule.Name = 'Invalid Rule';
        rule.Rule_Type__c = 'Element Count Threshold';
        rule.Target_Element_Type__c = 'Record Lookups';
        rule.Threshold_Value__c = null; // No threshold
        rule.Category__c = 'Performance';
        rule.Severity__c = 'High';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when threshold is null');
    }

    /**
     * Test 4: Element Count Threshold - Record Creates
     */
    @IsTest
    static void testElementCountThresholdRecordCreates() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>();

        for (Integer i = 0; i < 3; i++) {
            FlowMetadata.FlowRecordCreate create = new FlowMetadata.FlowRecordCreate();
            create.name = 'Create_' + i;
            create.object_x = 'Account';
            flow.recordCreates.add(create);
        }

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-004';
        rule.Name = 'Too Many Creates';
        rule.Rule_Type__c = 'Element Count Threshold';
        rule.Target_Element_Type__c = 'Record Creates';
        rule.Threshold_Value__c = 2; // Threshold is 2
        rule.Category__c = 'Performance';
        rule.Severity__c = 'Medium';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected 1 finding for 3 creates > 2 threshold');
    }

    /**
     * Test 5: Element Count Threshold - Loops
     */
    @IsTest
    static void testElementCountThresholdLoops() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.loops = new List<FlowMetadata.FlowLoop>();

        for (Integer i = 0; i < 4; i++) {
            FlowMetadata.FlowLoop loopEl = new FlowMetadata.FlowLoop();
            loopEl.name = 'Loop_' + i;
            loopEl.collectionReference = 'var_' + i;
            flow.loops.add(loopEl);
        }

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-005';
        rule.Name = 'Too Many Loops';
        rule.Rule_Type__c = 'Element Count Threshold';
        rule.Target_Element_Type__c = 'Loops';
        rule.Threshold_Value__c = 3;
        rule.Category__c = 'Complexity';
        rule.Severity__c = 'Medium';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding for 4 loops > 3 threshold');
    }

    // =========================================================================
    // TEST: Element Name Pattern Rule Type
    // =========================================================================

    /**
     * Test 6: Element Name Pattern - matching elements found
     */
    @IsTest
    static void testElementNamePatternMatchesFound() {
        List<String> elementNames = new List<String>{
            'myRule_CheckStatus',
            'myRule_ProcessData',
            'regularDecision'
        };
        FlowMetadata.FlowDefinition flow = buildFlowWithNamedElements(elementNames);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-006';
        rule.Name = 'Auto-Generated Names';
        rule.Rule_Type__c = 'Element Name Pattern';
        rule.Target_Element_Type__c = 'Decisions';
        rule.Name_Pattern__c = '^myRule_.*';
        rule.Category__c = 'Naming';
        rule.Severity__c = 'Low';
        rule.Description__c = 'Elements using auto-generated names';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(2, findings.size(), 'Expected 2 matches for myRule_ pattern');
    }

    /**
     * Test 7: Element Name Pattern - no matches → no finding
     */
    @IsTest
    static void testElementNamePatternNoMatches() {
        List<String> elementNames = new List<String>{
            'Check_Status',
            'Process_Data',
            'Handle_Error'
        };
        FlowMetadata.FlowDefinition flow = buildFlowWithNamedElements(elementNames);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-007';
        rule.Name = 'Bad Names';
        rule.Rule_Type__c = 'Element Name Pattern';
        rule.Target_Element_Type__c = 'Decisions';
        rule.Name_Pattern__c = '^myRule_.*';
        rule.Category__c = 'Naming';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when pattern does not match');
    }

    /**
     * Test 8: Element Name Pattern - blank pattern → no finding
     */
    @IsTest
    static void testElementNamePatternBlankPattern() {
        List<String> elementNames = new List<String>{ 'Check_Status', 'Process_Data' };
        FlowMetadata.FlowDefinition flow = buildFlowWithNamedElements(elementNames);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-008';
        rule.Name = 'Empty Pattern Rule';
        rule.Rule_Type__c = 'Element Name Pattern';
        rule.Target_Element_Type__c = 'Decisions';
        rule.Name_Pattern__c = ''; // Blank pattern
        rule.Category__c = 'Naming';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when pattern is blank');
    }

    /**
     * Test 9: Element Name Pattern - invalid regex → no finding (gracefully handled)
     */
    @IsTest
    static void testElementNamePatternInvalidRegex() {
        List<String> elementNames = new List<String>{ 'Check_Status', 'Process_Data' };
        FlowMetadata.FlowDefinition flow = buildFlowWithNamedElements(elementNames);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-009';
        rule.Name = 'Invalid Regex Rule';
        rule.Rule_Type__c = 'Element Name Pattern';
        rule.Target_Element_Type__c = 'Decisions';
        rule.Name_Pattern__c = '[invalid(regex'; // Invalid regex
        rule.Category__c = 'Naming';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        // Should not throw exception, should return empty list
        Assert.areEqual(0, findings.size(), 'Expected no findings for invalid regex');
    }

    // =========================================================================
    // TEST: Flow Property Check Rule Type
    // =========================================================================

    /**
     * Test 10: Flow Property Check - Process Type mismatch
     */
    @IsTest
    static void testFlowPropertyCheckProcessTypeMismatch() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.processType = 'Flow'; // Screen flow
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-010';
        rule.Name = 'Must Be Auto-Launched';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = 'Process Type';
        rule.Expected_Value__c = 'AutoLaunchedFlow';
        rule.Category__c = 'Design';
        rule.Severity__c = 'Medium';
        rule.Description__c = 'Only auto-launched flows allowed';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding for Process Type mismatch');
    }

    /**
     * Test 11: Flow Property Check - Process Type matches → no finding
     */
    @IsTest
    static void testFlowPropertyCheckProcessTypeMatches() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.processType = 'AutoLaunchedFlow';
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-011';
        rule.Name = 'Process Type Check';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = 'Process Type';
        rule.Expected_Value__c = 'AutoLaunchedFlow';
        rule.Category__c = 'Design';
        rule.Severity__c = 'Medium';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when Process Type matches');
    }

    /**
     * Test 12: Flow Property Check - Run Mode check
     */
    @IsTest
    static void testFlowPropertyCheckRunMode() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.runInMode = 'DefaultMode'; // Not secure
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-012';
        rule.Name = 'Secure Run Mode';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = 'Run Mode';
        rule.Expected_Value__c = 'SystemModeWithSharing';
        rule.Category__c = 'Security';
        rule.Severity__c = 'High';
        rule.Description__c = 'Flows must run with sharing';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding for Run Mode mismatch');
    }

    /**
     * Test 13: Flow Property Check - Has Description (blank description → finding)
     */
    @IsTest
    static void testFlowPropertyCheckHasDescriptionBlank() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.description = ''; // Blank description
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-013';
        rule.Name = 'Description Required';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = 'Has Description';
        rule.Category__c = 'Documentation';
        rule.Severity__c = 'Low';
        rule.Description__c = 'All flows must have descriptions';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding when description is blank');
    }

    /**
     * Test 14: Flow Property Check - Has Description (with description → no finding)
     */
    @IsTest
    static void testFlowPropertyCheckHasDescriptionPresent() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.description = 'This flow processes accounts';
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-014';
        rule.Name = 'Description Required';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = 'Has Description';
        rule.Category__c = 'Documentation';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when description present');
    }

    /**
     * Test 15: Flow Property Check - blank property → no finding
     */
    @IsTest
    static void testFlowPropertyCheckBlankProperty() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-015';
        rule.Name = 'Bad Rule';
        rule.Rule_Type__c = 'Flow Property Check';
        rule.Flow_Property__c = ''; // Blank property
        rule.Expected_Value__c = 'SomeValue';
        rule.Category__c = 'Design';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when property is blank');
    }

    // =========================================================================
    // TEST: Element In Loop Check Rule Type
    // =========================================================================

    /**
     * Test 16: Element In Loop Check - element inside loop → finding
     */
    @IsTest
    static void testElementInLoopCheckInsideLoop() {
        FlowMetadata.FlowDefinition flow = buildFlowWithElementInLoop();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-016';
        rule.Name = 'Screen In Loop';
        rule.Rule_Type__c = 'Element In Loop Check';
        rule.Target_Element_Type__c = 'Screens';
        rule.Category__c = 'UX';
        rule.Severity__c = 'Medium';
        rule.Description__c = 'Screens should not be inside loops';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding for screen inside loop');
        Assert.areEqual(
            'Display_Account',
            findings[0].elementName,
            'Should identify screen element'
        );
    }

    /**
     * Test 17: Element In Loop Check - element outside loop → no finding
     */
    @IsTest
    static void testElementInLoopCheckOutsideLoop() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        flow.screens = new List<FlowMetadata.FlowScreen>();

        FlowMetadata.FlowScreen screen = new FlowMetadata.FlowScreen();
        screen.name = 'Display_Info';
        screen.label = 'Display Info';
        flow.screens.add(screen);

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-017';
        rule.Name = 'Screen In Loop';
        rule.Rule_Type__c = 'Element In Loop Check';
        rule.Target_Element_Type__c = 'Screens';
        rule.Category__c = 'UX';
        rule.Severity__c = 'Medium';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when screen is outside loop');
    }

    // =========================================================================
    // TEST: Missing Fault Path Check Rule Type
    // =========================================================================

    /**
     * Test 18: Missing Fault Path Check - element without fault connector → finding
     */
    @IsTest
    static void testMissingFaultPathCheckNoFaultConnector() {
        FlowMetadata.FlowDefinition flow = buildFlowWithFaultConnectors(false);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-018';
        rule.Name = 'Missing Fault Handling';
        rule.Rule_Type__c = 'Missing Fault Path Check';
        rule.Target_Element_Type__c = 'Action Calls';
        rule.Category__c = 'Error Handling';
        rule.Severity__c = 'High';
        rule.Description__c = 'Action calls must have fault paths';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(1, findings.size(), 'Expected finding for missing fault path');
        Assert.areEqual(
            'Call_Action',
            findings[0].elementName,
            'Should identify action call element'
        );
    }

    /**
     * Test 19: Missing Fault Path Check - element with fault connector → no finding
     */
    @IsTest
    static void testMissingFaultPathCheckWithFaultConnector() {
        FlowMetadata.FlowDefinition flow = buildFlowWithFaultConnectors(true);
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-019';
        rule.Name = 'Missing Fault Handling';
        rule.Rule_Type__c = 'Missing Fault Path Check';
        rule.Target_Element_Type__c = 'Action Calls';
        rule.Category__c = 'Error Handling';
        rule.Severity__c = 'High';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings when fault path present');
    }

    // =========================================================================
    // TEST: Unknown Rule Type and Cache Clear
    // =========================================================================

    /**
     * Test 20: Unknown rule type → no finding
     */
    @IsTest
    static void testUnknownRuleType() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        Flow_Health_Custom_Rule__c rule = new Flow_Health_Custom_Rule__c();
        rule.Rule_Id__c = 'RULE-020';
        rule.Name = 'Unknown Rule';
        rule.Rule_Type__c = 'NonExistent Rule Type';
        rule.Category__c = 'Design';
        rule.Severity__c = 'Low';

        List<FlowFinding> findings = CustomRuleEvaluator.testRule(rule, flow, ctx);

        Assert.areEqual(0, findings.size(), 'Expected no findings for unknown rule type');
    }

    /**
     * Test 21: clearCache test
     */
    @IsTest
    static void testClearCache() {
        // This test simply verifies that clearCache() can be called without error
        CustomRuleEvaluator.clearCache();
        // If we got here without exception, the test passes
        Assert.isTrue(true, 'clearCache() executed successfully');
    }
}
