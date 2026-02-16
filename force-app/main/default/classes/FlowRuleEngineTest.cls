/**
 * FlowRuleEngineTest - Unit tests for the rule engine, individual rules,
 * score calculator, and analysis service.
 *
 * APPROACH: We build FlowMetadata objects programmatically rather than
 * parsing JSON. This is faster, more readable, and avoids coupling tests
 * to the exact Tooling API JSON structure.
 *
 * Each rule gets at least two tests:
 * 1. A flow that SHOULD trigger the rule (expects findings)
 * 2. A flow that should NOT trigger the rule (expects no findings)
 */
@IsTest
private class FlowRuleEngineTest {

    // =========================================================================
    // HELPER: Build minimal flow definitions for testing
    // =========================================================================

    /**
     * Creates a minimal clean flow with no issues.
     */
    private static FlowMetadata.FlowDefinition buildCleanFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Clean Flow';
        flow.description = 'A well-designed flow for testing';
        flow.processType = 'AutoLaunchedFlow';
        flow.triggerType = 'RecordAfterSave';
        flow.apiVersion = '62.0';
        flow.runInMode = 'SystemModeWithSharing';

        // A simple decision with a proper name
        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'Check_Account_Status';
        decision.label = 'Check Account Status';
        decision.description = 'Checks if account is active';
        decision.defaultConnector = new FlowMetadata.FlowConnector();
        decision.defaultConnector.targetReference = 'Set_Default_Values';
        decision.rules = new List<FlowMetadata.FlowRule>();
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        // An assignment with a proper name
        FlowMetadata.FlowAssignment assignment = new FlowMetadata.FlowAssignment();
        assignment.name = 'Set_Default_Values';
        assignment.label = 'Set Default Values';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assignment };

        return flow;
    }

    /**
     * Creates a flow with DML inside a loop (the most common anti-pattern).
     */
    private static FlowMetadata.FlowDefinition buildDmlInLoopFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'DML In Loop Flow';
        flow.description = 'Flow with DML inside loop for testing';
        flow.processType = 'AutoLaunchedFlow';

        // Loop element
        FlowMetadata.FlowLoop flowLoop = new FlowMetadata.FlowLoop();
        flowLoop.name = 'Loop_Accounts';
        flowLoop.label = 'Loop Through Accounts';
        flowLoop.collectionReference = 'var_Accounts';
        flowLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        flowLoop.nextValueConnector.targetReference = 'Update_Each_Account';
        flowLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        flowLoop.noMoreValuesConnector.targetReference = 'Done';
        flow.loops = new List<FlowMetadata.FlowLoop>{ flowLoop };

        // DML inside the loop (BAD!)
        FlowMetadata.FlowRecordUpdate updateInLoop = new FlowMetadata.FlowRecordUpdate();
        updateInLoop.name = 'Update_Each_Account';
        updateInLoop.label = 'Update Each Account';
        updateInLoop.object_x = 'Account';
        updateInLoop.connector = new FlowMetadata.FlowConnector();
        updateInLoop.connector.targetReference = 'Loop_Accounts';
        // No fault connector (this will also trigger ERR-001)
        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ updateInLoop };

        // Terminal assignment
        FlowMetadata.FlowAssignment done = new FlowMetadata.FlowAssignment();
        done.name = 'Done';
        done.label = 'Done';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ done };

        return flow;
    }

    /**
     * Creates a flow with SOQL inside a loop.
     */
    private static FlowMetadata.FlowDefinition buildSoqlInLoopFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'SOQL In Loop Flow';
        flow.description = 'Flow with SOQL inside loop';
        flow.processType = 'AutoLaunchedFlow';

        FlowMetadata.FlowLoop flowLoop = new FlowMetadata.FlowLoop();
        flowLoop.name = 'Loop_Contacts';
        flowLoop.label = 'Loop Contacts';
        flowLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        flowLoop.nextValueConnector.targetReference = 'Get_Related_Cases';
        flowLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        flowLoop.noMoreValuesConnector.targetReference = 'Done';
        flow.loops = new List<FlowMetadata.FlowLoop>{ flowLoop };

        FlowMetadata.FlowRecordLookup lookupInLoop = new FlowMetadata.FlowRecordLookup();
        lookupInLoop.name = 'Get_Related_Cases';
        lookupInLoop.label = 'Get Related Cases';
        lookupInLoop.object_x = 'Case';
        lookupInLoop.getFirstRecordOnly = false;
        lookupInLoop.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter = new FlowMetadata.FlowRecordFilter();
        filter.field = 'ContactId';
        filter.operator = 'EqualTo';
        lookupInLoop.filters.add(filter);
        lookupInLoop.connector = new FlowMetadata.FlowConnector();
        lookupInLoop.connector.targetReference = 'Loop_Contacts';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookupInLoop };

        FlowMetadata.FlowAssignment done = new FlowMetadata.FlowAssignment();
        done.name = 'Done';
        done.label = 'Done';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ done };

        return flow;
    }

    /**
     * Creates a flow with nested loops.
     */
    private static FlowMetadata.FlowDefinition buildNestedLoopFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Nested Loop Flow';
        flow.description = 'Flow with nested loops';
        flow.processType = 'AutoLaunchedFlow';

        // Outer loop
        FlowMetadata.FlowLoop outerLoop = new FlowMetadata.FlowLoop();
        outerLoop.name = 'Outer_Loop';
        outerLoop.label = 'Outer Loop';
        outerLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        outerLoop.nextValueConnector.targetReference = 'Inner_Loop';
        outerLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        outerLoop.noMoreValuesConnector.targetReference = 'Done';

        // Inner loop (BAD - nested!)
        FlowMetadata.FlowLoop innerLoop = new FlowMetadata.FlowLoop();
        innerLoop.name = 'Inner_Loop';
        innerLoop.label = 'Inner Loop';
        innerLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        innerLoop.nextValueConnector.targetReference = 'Set_Values';
        innerLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        innerLoop.noMoreValuesConnector.targetReference = 'Outer_Loop';

        flow.loops = new List<FlowMetadata.FlowLoop>{ outerLoop, innerLoop };

        FlowMetadata.FlowAssignment setValues = new FlowMetadata.FlowAssignment();
        setValues.name = 'Set_Values';
        setValues.label = 'Set Values';
        setValues.connector = new FlowMetadata.FlowConnector();
        setValues.connector.targetReference = 'Inner_Loop';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ setValues };

        FlowMetadata.FlowAssignment done = new FlowMetadata.FlowAssignment();
        done.name = 'Done';
        done.label = 'Done';
        flow.assignments.add(done);

        return flow;
    }

    // =========================================================================
    // TESTS: FlowAnalysisContext
    // =========================================================================

    @IsTest
    static void testContext_LoopBodyDetection() {
        FlowMetadata.FlowDefinition flow = buildDmlInLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        // The DML element should be detected as inside the loop
        System.assertEquals(true, ctx.isInsideLoop('Update_Each_Account'),
            'DML element should be detected as inside loop');

        // The terminal element should NOT be inside the loop
        System.assertEquals(false, ctx.isInsideLoop('Done'),
            'Terminal element should not be inside loop');

        // Non-existent element should not be inside loop
        System.assertEquals(false, ctx.isInsideLoop('NonExistent'),
            'Non-existent element should not be inside loop');
    }

    @IsTest
    static void testContext_NestedLoopDetection() {
        FlowMetadata.FlowDefinition flow = buildNestedLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        // Inner loop should be detected as inside outer loop
        System.assertEquals(true, ctx.isInsideLoop('Inner_Loop'),
            'Inner loop should be inside outer loop');

        // Assignment inside inner loop should be inside both loops
        System.assertEquals(true, ctx.isInsideLoop('Set_Values'),
            'Element inside inner loop should be flagged');

        // Containing loops for inner loop should include outer
        List<String> containers = ctx.getContainingLoops('Inner_Loop');
        System.assertEquals(1, containers.size(),
            'Inner loop should have one containing loop');
        System.assertEquals('Outer_Loop', containers[0],
            'Outer_Loop should be the containing loop');
    }

    @IsTest
    static void testContext_NoLoops() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        System.assertEquals(false, ctx.isInsideLoop('Check_Account_Status'),
            'No loops means nothing is inside a loop');
        System.assertEquals(0, ctx.loopBodies.size(),
            'Loop bodies map should be empty');
    }

    @IsTest
    static void testContext_GetNextElement() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);

        FlowMetadata.FlowConnector conn = new FlowMetadata.FlowConnector();
        conn.targetReference = 'Set_Default_Values';
        FlowMetadata.FlowElement next = ctx.getNextElement(conn);

        System.assertNotEquals(null, next, 'Should find the next element');
        System.assertEquals('Set_Default_Values', next.name, 'Should match expected element');

        // Null connector
        System.assertEquals(null, ctx.getNextElement(null), 'Null connector should return null');
    }

    // =========================================================================
    // TESTS: Individual Rules
    // =========================================================================

    @IsTest
    static void testDmlInLoopRule_Positive() {
        FlowMetadata.FlowDefinition flow = buildDmlInLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DmlInLoopRule rule = new DmlInLoopRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should find 1 DML-in-loop violation');
        System.assertEquals('PERF-001', findings[0].ruleId);
        System.assertEquals('Update_Each_Account', findings[0].elementName);
        System.assertEquals('Critical', findings[0].severity);
    }

    @IsTest
    static void testDmlInLoopRule_Negative() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DmlInLoopRule rule = new DmlInLoopRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Clean flow should have no DML-in-loop findings');
    }

    @IsTest
    static void testSoqlInLoopRule_Positive() {
        FlowMetadata.FlowDefinition flow = buildSoqlInLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        SoqlInLoopRule rule = new SoqlInLoopRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should find 1 SOQL-in-loop violation');
        System.assertEquals('PERF-002', findings[0].ruleId);
        System.assertEquals('Get_Related_Cases', findings[0].elementName);
    }

    @IsTest
    static void testNestedLoopsRule_Positive() {
        FlowMetadata.FlowDefinition flow = buildNestedLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NestedLoopsRule rule = new NestedLoopsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should find 1 nested loop violation');
        System.assertEquals('PERF-003', findings[0].ruleId);
        System.assertEquals('Inner_Loop', findings[0].elementName);
    }

    @IsTest
    static void testNestedLoopsRule_Negative() {
        // Flow with a single loop (not nested)
        FlowMetadata.FlowDefinition flow = buildDmlInLoopFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NestedLoopsRule rule = new NestedLoopsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Single loop should not trigger nested loops rule');
    }

    @IsTest
    static void testUnboundedGetRecordsRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Get Records with no filters and multiple records
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_All_Accounts';
        lookup.label = 'Get All Accounts';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = false;
        // No filters!
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnboundedGetRecordsRule rule = new UnboundedGetRecordsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should find unbounded get records');
        System.assertEquals('PERF-004', findings[0].ruleId);
    }

    @IsTest
    static void testUnboundedGetRecordsRule_Negative() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Get Records WITH filters — should be fine
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Active_Accounts';
        lookup.label = 'Get Active Accounts';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = false;
        lookup.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter = new FlowMetadata.FlowRecordFilter();
        filter.field = 'IsActive__c';
        filter.operator = 'EqualTo';
        lookup.filters.add(filter);
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnboundedGetRecordsRule rule = new UnboundedGetRecordsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Filtered get records should not trigger');
    }

    @IsTest
    static void testExcessiveElementsRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Add 55 assignment elements
        flow.assignments = new List<FlowMetadata.FlowAssignment>();
        for (Integer i = 0; i < 55; i++) {
            FlowMetadata.FlowAssignment a = new FlowMetadata.FlowAssignment();
            a.name = 'Assignment_' + i;
            a.label = 'Assignment ' + i;
            flow.assignments.add(a);
        }

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        ExcessiveElementsRule rule = new ExcessiveElementsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag 55 elements');
        System.assertEquals('Medium', findings[0].severity, '50-99 should be Medium');
    }

    @IsTest
    static void testExcessiveElementsRule_HighThreshold() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Add 105 assignment elements
        flow.assignments = new List<FlowMetadata.FlowAssignment>();
        for (Integer i = 0; i < 105; i++) {
            FlowMetadata.FlowAssignment a = new FlowMetadata.FlowAssignment();
            a.name = 'Assignment_' + i;
            a.label = 'Assignment ' + i;
            flow.assignments.add(a);
        }

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        ExcessiveElementsRule rule = new ExcessiveElementsRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag 105 elements');
        System.assertEquals('High', findings[0].severity, '100+ should be High');
    }

    @IsTest
    static void testSubflowInLoopRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        FlowMetadata.FlowLoop flowLoop = new FlowMetadata.FlowLoop();
        flowLoop.name = 'Loop_Records';
        flowLoop.label = 'Loop Records';
        flowLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        flowLoop.nextValueConnector.targetReference = 'Call_Subflow';
        flowLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        flowLoop.noMoreValuesConnector.targetReference = 'Done';
        flow.loops = new List<FlowMetadata.FlowLoop>{ flowLoop };

        FlowMetadata.FlowSubflow subflow = new FlowMetadata.FlowSubflow();
        subflow.name = 'Call_Subflow';
        subflow.label = 'Call Validation Subflow';
        subflow.flowName = 'Validate_Record';
        subflow.connector = new FlowMetadata.FlowConnector();
        subflow.connector.targetReference = 'Loop_Records';
        flow.subflows = new List<FlowMetadata.FlowSubflow>{ subflow };

        FlowMetadata.FlowAssignment done = new FlowMetadata.FlowAssignment();
        done.name = 'Done';
        done.label = 'Done';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ done };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        SubflowInLoopRule rule = new SubflowInLoopRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should find subflow in loop');
        System.assertEquals('PERF-006', findings[0].ruleId);
    }

    @IsTest
    static void testMissingFaultPathRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // DML without fault connector
        FlowMetadata.FlowRecordCreate create = new FlowMetadata.FlowRecordCreate();
        create.name = 'Create_Account';
        create.label = 'Create Account';
        create.object_x = 'Account';
        // No faultConnector!
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>{ create };

        // Action without fault connector
        FlowMetadata.FlowActionCall action = new FlowMetadata.FlowActionCall();
        action.name = 'Send_Email';
        action.label = 'Send Email';
        action.actionType = 'emailAlert';
        flow.actionCalls = new List<FlowMetadata.FlowActionCall>{ action };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        MissingFaultPathRule rule = new MissingFaultPathRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(2, findings.size(), 'Should find 2 missing fault paths');
    }

    @IsTest
    static void testMissingFaultPathRule_Negative() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // DML WITH fault connector
        FlowMetadata.FlowRecordCreate create = new FlowMetadata.FlowRecordCreate();
        create.name = 'Create_Account';
        create.label = 'Create Account';
        create.faultConnector = new FlowMetadata.FlowConnector();
        create.faultConnector.targetReference = 'Handle_Error';
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>{ create };

        FlowMetadata.FlowAssignment errorHandler = new FlowMetadata.FlowAssignment();
        errorHandler.name = 'Handle_Error';
        errorHandler.label = 'Handle Error';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ errorHandler };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        MissingFaultPathRule rule = new MissingFaultPathRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Element with fault path should not trigger');
    }

    @IsTest
    static void testNoErrorHandlingRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // DML elements but NO fault paths at all
        FlowMetadata.FlowRecordUpdate recUpdate = new FlowMetadata.FlowRecordUpdate();
        recUpdate.name = 'Update_Account';
        recUpdate.label = 'Update Account';
        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ recUpdate };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NoErrorHandlingRule rule = new NoErrorHandlingRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag flow with zero error handling');
        System.assertEquals('ERR-002', findings[0].ruleId);
        System.assertEquals('Critical', findings[0].severity);
    }

    @IsTest
    static void testNoErrorHandlingRule_Negative() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // DML with at least one fault path
        FlowMetadata.FlowRecordUpdate recUpdate = new FlowMetadata.FlowRecordUpdate();
        recUpdate.name = 'Update_Account';
        recUpdate.label = 'Update Account';
        recUpdate.faultConnector = new FlowMetadata.FlowConnector();
        recUpdate.faultConnector.targetReference = 'Error_Handler';
        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ recUpdate };

        FlowMetadata.FlowAssignment errorHandler = new FlowMetadata.FlowAssignment();
        errorHandler.name = 'Error_Handler';
        errorHandler.label = 'Error Handler';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ errorHandler };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NoErrorHandlingRule rule = new NoErrorHandlingRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Flow with at least one fault path should pass');
    }

    @IsTest
    static void testMissingDescriptionRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Flow';
        // No description!

        // Add element with auto-generated name
        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'myDecision';
        decision.label = 'myDecision';
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        MissingDescriptionRule rule = new MissingDescriptionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(2, findings.size(),
            'Should find missing description AND auto-generated names');
    }

    @IsTest
    static void testMissingDescriptionRule_Negative() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        MissingDescriptionRule rule = new MissingDescriptionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        // Clean flow has description and meaningful names
        System.assertEquals(0, findings.size(),
            'Clean flow should not trigger description rule');
    }

    @IsTest
    static void testNullCheckAfterGetRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Get Records (single) followed by Assignment (not Decision)
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Account';
        lookup.label = 'Get Account';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = true;
        lookup.connector = new FlowMetadata.FlowConnector();
        lookup.connector.targetReference = 'Set_Fields';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowMetadata.FlowAssignment assignment = new FlowMetadata.FlowAssignment();
        assignment.name = 'Set_Fields';
        assignment.label = 'Set Fields';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assignment };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NullCheckAfterGetRule rule = new NullCheckAfterGetRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag missing null check');
        System.assertEquals('DES-002', findings[0].ruleId);
    }

    @IsTest
    static void testNullCheckAfterGetRule_Negative() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Get Records (single) followed by Decision (good!)
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Account';
        lookup.label = 'Get Account';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = true;
        lookup.connector = new FlowMetadata.FlowConnector();
        lookup.connector.targetReference = 'Check_Null';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'Check_Null';
        decision.label = 'Was Account Found?';
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NullCheckAfterGetRule rule = new NullCheckAfterGetRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Get Records followed by Decision should pass');
    }

    @IsTest
    static void testNullCheckAfterGetRule_CollectionSkipped() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Get Records (collection, not single) — should be skipped
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Accounts';
        lookup.label = 'Get Accounts';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = false;
        lookup.connector = new FlowMetadata.FlowConnector();
        lookup.connector.targetReference = 'Loop_Accounts';
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowMetadata.FlowLoop flowLoop = new FlowMetadata.FlowLoop();
        flowLoop.name = 'Loop_Accounts';
        flowLoop.label = 'Loop Accounts';
        flow.loops = new List<FlowMetadata.FlowLoop>{ flowLoop };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        NullCheckAfterGetRule rule = new NullCheckAfterGetRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Collection get records should not trigger null check');
    }

    // =========================================================================
    // TESTS: FlowScoreCalculator
    // =========================================================================

    @IsTest
    static void testScoreCalculator_PerfectScore() {
        FlowScoreCalculator calc = new FlowScoreCalculator();
        FlowScoreCalculator.ScoreResult result = calc.calculate(new List<FlowFinding>());

        System.assertEquals(100, result.score, 'Empty findings should give 100');
        System.assertEquals('A', result.grade);
        System.assertEquals('Excellent', result.gradeLabel);
    }

    @IsTest
    static void testScoreCalculator_NullFindings() {
        FlowScoreCalculator calc = new FlowScoreCalculator();
        FlowScoreCalculator.ScoreResult result = calc.calculate(null);

        System.assertEquals(100, result.score, 'Null findings should give 100');
    }

    @IsTest
    static void testScoreCalculator_WithFindings() {
        List<FlowFinding> findings = new List<FlowFinding>();

        // One critical finding with weight 15
        FlowFinding f1 = new FlowFinding('PERF-001', 'DML In Loop', 'Performance', 'Critical');
        f1.weight = 15;
        findings.add(f1);

        // One medium finding with weight 5
        FlowFinding f2 = new FlowFinding('DES-001', 'Missing Description', 'Design', 'Medium');
        f2.weight = 5;
        findings.add(f2);

        FlowScoreCalculator calc = new FlowScoreCalculator();
        FlowScoreCalculator.ScoreResult result = calc.calculate(findings);

        // Expected: 100 - (15 × 1.0) - (5 × 0.5) = 100 - 15 - 2.5 = 82.5 → 83
        System.assert(result.score > 0 && result.score < 100,
            'Score should be between 0 and 100: ' + result.score);
        System.assertNotEquals(null, result.grade, 'Grade should be assigned');
        System.assertNotEquals(null, result.categoryScores, 'Category scores should exist');
    }

    @IsTest
    static void testScoreCalculator_DiminishingReturns() {
        List<FlowFinding> findings = new List<FlowFinding>();

        // 5 findings of the same rule
        for (Integer i = 0; i < 5; i++) {
            FlowFinding f = new FlowFinding('ERR-001', 'Missing Fault Path', 'Error Handling', 'High');
            f.weight = 8;
            findings.add(f);
        }

        FlowScoreCalculator calc = new FlowScoreCalculator();
        FlowScoreCalculator.ScoreResult result = calc.calculate(findings);

        // Due to diminishing returns, 5 findings should cost LESS than 5 × 8 × 0.75 = 30
        // Each subsequent finding costs less:
        // i=0: 8 × 0.75 × 1.0 = 6.0
        // i=1: 8 × 0.75 × 0.769 = 4.62
        // i=2: 8 × 0.75 × 0.625 = 3.75
        // Total < 30
        System.assert(result.score > 70,
            'Diminishing returns should prevent score from dropping too much: ' + result.score);
    }

    @IsTest
    static void testScoreCalculator_GradeThresholds() {
        FlowScoreCalculator calc = new FlowScoreCalculator();

        // Test grade boundaries by creating findings that produce specific scores
        // This is a basic check that grades are assigned
        List<FlowFinding> manyFindings = new List<FlowFinding>();
        for (Integer i = 0; i < 20; i++) {
            FlowFinding f = new FlowFinding('PERF-001', 'DML In Loop', 'Performance', 'Critical');
            f.weight = 15;
            manyFindings.add(f);
        }

        FlowScoreCalculator.ScoreResult result = calc.calculate(manyFindings);
        System.assert(result.score >= 0, 'Score should not be negative');
        System.assertNotEquals(null, result.gradeColor, 'Grade color should be set');
    }

    // =========================================================================
    // TESTS: FlowFinding builder pattern
    // =========================================================================

    @IsTest
    static void testFlowFinding_Builder() {
        FlowFinding finding = new FlowFinding('TEST-001', 'Test Rule', 'Test', 'High')
            .withElement('My_Element', 'recordUpdate')
            .withDescription('Something is wrong')
            .withRemediation('Fix it')
            .withWeight(10);

        System.assertEquals('TEST-001', finding.ruleId);
        System.assertEquals('Test Rule', finding.ruleName);
        System.assertEquals('Test', finding.category);
        System.assertEquals('High', finding.severity);
        System.assertEquals('My_Element', finding.elementName);
        System.assertEquals('recordUpdate', finding.elementType);
        System.assertEquals('Something is wrong', finding.description);
        System.assertEquals('Fix it', finding.remediation);
        System.assertEquals(10, finding.weight);
    }

    // =========================================================================
    // TESTS: FlowAnalysisService (integration-like, no callout)
    // =========================================================================

    @IsTest
    static void testAnalysisService_CleanFlow() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisService.AnalysisResult result = FlowAnalysisService.analyzeFlowDefinition(flow);

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.score, 'Score should not be null');
        System.assertNotEquals(null, result.grade, 'Grade should not be null');
        System.assertNotEquals(null, result.findings, 'Findings should not be null');
        System.assertNotEquals(null, result.findingsByCategory, 'Category breakdown should exist');
        System.assertNotEquals(null, result.findingsBySeverity, 'Severity breakdown should exist');
    }

    @IsTest
    static void testAnalysisService_ProblematicFlow() {
        FlowMetadata.FlowDefinition flow = buildDmlInLoopFlow();
        FlowAnalysisService.AnalysisResult result = FlowAnalysisService.analyzeFlowDefinition(flow);

        System.assert(result.score < 100,
            'Problematic flow should have score below 100: ' + result.score);
        System.assert(result.totalFindings > 0,
            'Problematic flow should have findings: ' + result.totalFindings);
    }

    // =========================================================================
    // TESTS: FlowHealthController.analyzeFlow (with mock callout)
    // =========================================================================

    @IsTest
    static void testController_AnalyzeFlow_BlankName() {
        Test.startTest();
        try {
            FlowHealthController.analyzeFlow('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'),
                'Error should mention required: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // =========================================================================
    // TESTS: HardcodedIdRule (SEC-001)
    // =========================================================================

    @IsTest
    static void testHardcodedIdRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Assignment with a hardcoded Account ID
        FlowMetadata.FlowAssignment assign = new FlowMetadata.FlowAssignment();
        assign.name = 'Set_Owner';
        assign.label = 'Set Owner';
        assign.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>();
        FlowMetadata.FlowAssignmentItem item = new FlowMetadata.FlowAssignmentItem();
        item.assignToReference = 'var_OwnerId';
        item.value = new FlowMetadata.FlowValue();
        item.value.stringValue = '005000000000001AAA';  // Hardcoded User ID
        assign.assignmentItems.add(item);
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assign };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        HardcodedIdRule rule = new HardcodedIdRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect hardcoded ID in assignment');
        System.assertEquals('SEC-001', findings[0].ruleId);
        System.assertEquals('High', findings[0].severity);
    }

    @IsTest
    static void testHardcodedIdRule_InFormula() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Formula with hardcoded record ID
        FlowMetadata.FlowFormula formula = new FlowMetadata.FlowFormula();
        formula.name = 'formulaOwnerId';
        formula.expression = 'IF(true, "005000000000001AAA", "005000000000002BBB")';
        flow.formulas = new List<FlowMetadata.FlowFormula>{ formula };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        HardcodedIdRule rule = new HardcodedIdRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assert(findings.size() >= 1, 'Should detect hardcoded ID in formula expression');
    }

    @IsTest
    static void testHardcodedIdRule_InRecordFilter() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Record lookup with hardcoded Account ID in filter
        FlowMetadata.FlowRecordLookup lookup = new FlowMetadata.FlowRecordLookup();
        lookup.name = 'Get_Specific_Account';
        lookup.label = 'Get Specific Account';
        lookup.object_x = 'Account';
        lookup.getFirstRecordOnly = true;
        lookup.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter = new FlowMetadata.FlowRecordFilter();
        filter.field = 'Id';
        filter.operator = 'EqualTo';
        filter.value = new FlowMetadata.FlowValue();
        filter.value.stringValue = '001000000000001AAA';  // Hardcoded Account ID
        lookup.filters.add(filter);
        flow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ lookup };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        HardcodedIdRule rule = new HardcodedIdRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect hardcoded ID in record filter');
    }

    @IsTest
    static void testHardcodedIdRule_Negative() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        HardcodedIdRule rule = new HardcodedIdRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Clean flow should have no hardcoded IDs');
    }

    // =========================================================================
    // TESTS: BypassPermissionRule (SEC-002)
    // =========================================================================

    @IsTest
    static void testBypassPermissionRule_SystemModeWithoutSharing() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Risky Flow';
        flow.description = 'Test';
        flow.processType = 'AutoLaunchedFlow';
        flow.runInMode = 'SystemModeWithoutSharing';

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        BypassPermissionRule rule = new BypassPermissionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect System Mode Without Sharing');
        System.assertEquals('SEC-002', findings[0].ruleId);
        System.assertEquals('Medium', findings[0].severity);
    }

    @IsTest
    static void testBypassPermissionRule_ScreenFlowHigherSeverity() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Risky Screen Flow';
        flow.description = 'Test';
        flow.processType = 'Flow';  // Screen flow
        flow.runInMode = 'SystemModeWithoutSharing';

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        BypassPermissionRule rule = new BypassPermissionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect screen flow without sharing');
        System.assertEquals('High', findings[0].severity, 'Screen flows should get higher severity');
    }

    @IsTest
    static void testBypassPermissionRule_UserContextDmlRisk() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'User Context Flow';
        flow.description = 'Test';
        flow.processType = 'RecordTriggeredFlow';
        flow.runInMode = 'DefaultMode';

        // Add DML operations
        FlowMetadata.FlowRecordCreate rc = new FlowMetadata.FlowRecordCreate();
        rc.name = 'Create_Task';
        rc.label = 'Create Task';
        rc.object_x = 'Task';
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>{ rc };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        BypassPermissionRule rule = new BypassPermissionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag DML in user context record-triggered flow');
        System.assertEquals('Low', findings[0].severity);
    }

    @IsTest
    static void testBypassPermissionRule_Negative() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();  // Uses SystemModeWithSharing
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        BypassPermissionRule rule = new BypassPermissionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'System Mode With Sharing should not trigger');
    }

    // =========================================================================
    // TESTS: OutdatedApiVersionRule (DES-003)
    // =========================================================================

    @IsTest
    static void testOutdatedApiVersionRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Old Flow';
        flow.description = 'Test';
        flow.apiVersion = '50.0';  // Many versions behind

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        OutdatedApiVersionRule rule = new OutdatedApiVersionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag outdated API version');
        System.assertEquals('DES-003', findings[0].ruleId);
        System.assertEquals('High', findings[0].severity, 'Severely outdated should be High');
    }

    @IsTest
    static void testOutdatedApiVersionRule_MediumSeverity() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Slightly Old Flow';
        flow.description = 'Test';
        flow.apiVersion = '58.0';  // 5 versions behind (between 4 and 10)

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        OutdatedApiVersionRule rule = new OutdatedApiVersionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should flag slightly outdated API version');
        System.assertEquals('Medium', findings[0].severity, 'Slightly outdated should be Medium');
    }

    @IsTest
    static void testOutdatedApiVersionRule_Negative() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Current Flow';
        flow.description = 'Test';
        flow.apiVersion = '62.0';  // Within threshold

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        OutdatedApiVersionRule rule = new OutdatedApiVersionRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Current API version should not trigger');
    }

    // =========================================================================
    // TESTS: UnusedVariableRule (DES-004)
    // =========================================================================

    @IsTest
    static void testUnusedVariableRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Declare a variable but never reference it
        FlowMetadata.FlowVariable unusedVar = new FlowMetadata.FlowVariable();
        unusedVar.name = 'var_NeverUsed';
        unusedVar.dataType = 'String';
        unusedVar.isInput = false;
        unusedVar.isOutput = false;
        flow.variables = new List<FlowMetadata.FlowVariable>{ unusedVar };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnusedVariableRule rule = new UnusedVariableRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect unused variable');
        System.assertEquals('DES-004', findings[0].ruleId);
        System.assertEquals('var_NeverUsed', findings[0].elementName);
    }

    @IsTest
    static void testUnusedVariableRule_InputOutputExcluded() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Input variable (should be excluded even if unused internally)
        FlowMetadata.FlowVariable inputVar = new FlowMetadata.FlowVariable();
        inputVar.name = 'var_RecordId';
        inputVar.dataType = 'String';
        inputVar.isInput = true;
        inputVar.isOutput = false;

        // Output variable (should be excluded)
        FlowMetadata.FlowVariable outputVar = new FlowMetadata.FlowVariable();
        outputVar.name = 'var_Result';
        outputVar.dataType = 'Boolean';
        outputVar.isInput = false;
        outputVar.isOutput = true;

        flow.variables = new List<FlowMetadata.FlowVariable>{ inputVar, outputVar };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnusedVariableRule rule = new UnusedVariableRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Input/Output variables should not be flagged');
    }

    @IsTest
    static void testUnusedVariableRule_UsedInAssignment() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Variable that IS referenced in an assignment
        FlowMetadata.FlowVariable usedVar = new FlowMetadata.FlowVariable();
        usedVar.name = 'var_Status';
        usedVar.dataType = 'String';
        usedVar.isInput = false;
        usedVar.isOutput = false;
        flow.variables = new List<FlowMetadata.FlowVariable>{ usedVar };

        // Assignment that references the variable
        FlowMetadata.FlowAssignment assign = new FlowMetadata.FlowAssignment();
        assign.name = 'Set_Status';
        assign.label = 'Set Status';
        assign.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>();
        FlowMetadata.FlowAssignmentItem item = new FlowMetadata.FlowAssignmentItem();
        item.assignToReference = 'var_Status';
        item.value = new FlowMetadata.FlowValue();
        item.value.stringValue = 'Active';
        assign.assignmentItems.add(item);
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assign };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnusedVariableRule rule = new UnusedVariableRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Variable used in assignment should not be flagged');
    }

    @IsTest
    static void testUnusedVariableRule_UsedInLoop() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        FlowMetadata.FlowVariable collVar = new FlowMetadata.FlowVariable();
        collVar.name = 'var_Accounts';
        collVar.dataType = 'SObject';
        collVar.isCollection = true;
        collVar.isInput = false;
        collVar.isOutput = false;
        flow.variables = new List<FlowMetadata.FlowVariable>{ collVar };

        FlowMetadata.FlowLoop lp = new FlowMetadata.FlowLoop();
        lp.name = 'Loop_Accounts';
        lp.label = 'Loop Accounts';
        lp.collectionReference = 'var_Accounts';
        flow.loops = new List<FlowMetadata.FlowLoop>{ lp };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        UnusedVariableRule rule = new UnusedVariableRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Variable used as loop collection should not be flagged');
    }

    // =========================================================================
    // TESTS: DuplicateDmlRule (PERF-007)
    // =========================================================================

    @IsTest
    static void testDuplicateDmlRule_Positive() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Two separate Update Account elements
        FlowMetadata.FlowRecordUpdate update1 = new FlowMetadata.FlowRecordUpdate();
        update1.name = 'Update_Account_Status';
        update1.label = 'Update Account Status';
        update1.object_x = 'Account';

        FlowMetadata.FlowRecordUpdate update2 = new FlowMetadata.FlowRecordUpdate();
        update2.name = 'Update_Account_Rating';
        update2.label = 'Update Account Rating';
        update2.object_x = 'Account';

        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ update1, update2 };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DuplicateDmlRule rule = new DuplicateDmlRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect duplicate DML on same object');
        System.assertEquals('PERF-007', findings[0].ruleId);
    }

    @IsTest
    static void testDuplicateDmlRule_DifferentObjects() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // Updates on different objects (should be fine)
        FlowMetadata.FlowRecordUpdate update1 = new FlowMetadata.FlowRecordUpdate();
        update1.name = 'Update_Account';
        update1.label = 'Update Account';
        update1.object_x = 'Account';

        FlowMetadata.FlowRecordUpdate update2 = new FlowMetadata.FlowRecordUpdate();
        update2.name = 'Update_Contact';
        update2.label = 'Update Contact';
        update2.object_x = 'Contact';

        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ update1, update2 };

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DuplicateDmlRule rule = new DuplicateDmlRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'DML on different objects should not trigger');
    }

    @IsTest
    static void testDuplicateDmlRule_MultipleCreates() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.description = 'Test';

        // 4 separate Create Task elements (high severity threshold)
        flow.recordCreates = new List<FlowMetadata.FlowRecordCreate>();
        for (Integer i = 0; i < 4; i++) {
            FlowMetadata.FlowRecordCreate rc = new FlowMetadata.FlowRecordCreate();
            rc.name = 'Create_Task_' + i;
            rc.label = 'Create Task ' + i;
            rc.object_x = 'Task';
            flow.recordCreates.add(rc);
        }

        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DuplicateDmlRule rule = new DuplicateDmlRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);

        System.assertEquals(1, findings.size(), 'Should detect 4 creates on same object');
        System.assertEquals('High', findings[0].severity, '4+ duplicates should be High severity');
    }

    @IsTest
    static void testDuplicateDmlRule_Negative() {
        FlowMetadata.FlowDefinition flow = buildCleanFlow();
        FlowAnalysisContext ctx = new FlowAnalysisContext(flow);
        DuplicateDmlRule rule = new DuplicateDmlRule();

        List<FlowFinding> findings = rule.evaluate(flow, ctx);
        System.assertEquals(0, findings.size(), 'Flow with no DML should not trigger');
    }
}
