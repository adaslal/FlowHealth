/**
 * FlowDiffServiceTest - Comprehensive unit tests for FlowDiffService.compare()
 *
 * APPROACH: Build FlowMetadata objects programmatically to test all comparison paths:
 * - Configuration changes (processType, apiVersion, triggerType, etc.)
 * - Element additions, removals, and modifications
 * - Cosmetic vs. functional changes
 * - Resource changes (variables, formulas, constants)
 * - Health score deltas
 * - Risk assessments
 *
 * HELPER: buildSimpleFlow() creates a baseline flow for modification in each test.
 */
@IsTest
private class FlowDiffServiceTest {

    // =========================================================================
    // HELPER: Build baseline flow for testing
    // =========================================================================

    /**
     * Builds a simple baseline flow with:
     * - 1 decision with 1 rule
     * - 1 assignment
     * - 1 record update (Account)
     * - 1 variable
     *
     * This serves as a starting point for each test.
     */
    private static FlowMetadata.FlowDefinition buildSimpleFlow() {
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Flow';
        flow.description = 'A simple test flow';
        flow.processType = 'AutoLaunchedFlow';
        flow.apiVersion = '62.0';
        flow.runInMode = 'SystemModeWithSharing';
        flow.triggerType = 'RecordAfterSave';

        // Decision with 1 rule
        FlowMetadata.FlowDecision decision = new FlowMetadata.FlowDecision();
        decision.name = 'Check_Status';
        decision.label = 'Check Status';
        decision.description = 'Check if active';
        decision.defaultConnector = new FlowMetadata.FlowConnector();
        decision.defaultConnector.targetReference = 'Set_Values';
        decision.defaultConnectorLabel = 'Default';

        FlowMetadata.FlowRule rule = new FlowMetadata.FlowRule();
        rule.name = 'IsActive';
        rule.label = 'Is Active';
        rule.conditionLogic = 'and';
        FlowMetadata.FlowCondition condition = new FlowMetadata.FlowCondition();
        condition.leftValueReference = 'Status__c';
        condition.operator = 'EqualTo';
        condition.rightValue = new FlowMetadata.FlowValue();
        condition.rightValue.stringValue = 'Active';
        rule.conditions = new List<FlowMetadata.FlowCondition>{ condition };
        rule.connector = new FlowMetadata.FlowConnector();
        rule.connector.targetReference = 'Update_Record';

        decision.rules = new List<FlowMetadata.FlowRule>{ rule };
        flow.decisions = new List<FlowMetadata.FlowDecision>{ decision };

        // Assignment
        FlowMetadata.FlowAssignment assignment = new FlowMetadata.FlowAssignment();
        assignment.name = 'Set_Values';
        assignment.label = 'Set Values';
        assignment.description = 'Set some values';
        FlowMetadata.FlowAssignmentItem item = new FlowMetadata.FlowAssignmentItem();
        item.assignToReference = 'var_Counter';
        item.operator = 'Assign';
        item.value = new FlowMetadata.FlowValue();
        item.value.numberValue = 0;
        assignment.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>{ item };
        assignment.connector = new FlowMetadata.FlowConnector();
        assignment.connector.targetReference = 'Update_Record';
        flow.assignments = new List<FlowMetadata.FlowAssignment>{ assignment };

        // Record Update
        FlowMetadata.FlowRecordUpdate recordUpdate = new FlowMetadata.FlowRecordUpdate();
        recordUpdate.name = 'Update_Record';
        recordUpdate.label = 'Update Record';
        recordUpdate.description = 'Update the record';
        recordUpdate.object_x = 'Account';
        FlowMetadata.FlowInputAssignment inputAssign = new FlowMetadata.FlowInputAssignment();
        inputAssign.field = 'Name';
        inputAssign.value = new FlowMetadata.FlowValue();
        inputAssign.value.stringValue = 'Updated';
        recordUpdate.inputAssignments = new List<FlowMetadata.FlowInputAssignment>{ inputAssign };
        flow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ recordUpdate };

        // Variable
        FlowMetadata.FlowVariable variable = new FlowMetadata.FlowVariable();
        variable.name = 'var_Counter';
        variable.description = 'A counter variable';
        variable.dataType = 'Number';
        variable.isCollection = false;
        variable.isInput = false;
        variable.isOutput = false;
        flow.variables = new List<FlowMetadata.FlowVariable>{ variable };

        return flow;
    }

    // =========================================================================
    // TEST 1: Identical flows
    // =========================================================================

    @IsTest
    static void testCompare_IdenticalFlows() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assertEquals(0, result.changes.size(),
            'Identical flows should have 0 changes');
        System.assertEquals(0, result.summary.totalChanges,
            'Summary should show 0 changes');
    }

    // =========================================================================
    // TEST 2: Added elements
    // =========================================================================

    @IsTest
    static void testCompare_AddedDecision() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add a new decision
        FlowMetadata.FlowDecision newDecision = new FlowMetadata.FlowDecision();
        newDecision.name = 'New_Check';
        newDecision.label = 'New Check';
        newDecision.description = 'A new decision';
        newDecision.defaultConnector = new FlowMetadata.FlowConnector();
        newDecision.defaultConnector.targetReference = 'Done';
        newDecision.rules = new List<FlowMetadata.FlowRule>();
        newFlow.decisions.add(newDecision);

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundAdded = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Added' && change.itemName == 'New_Check') {
                foundAdded = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals('Medium', change.riskLevel);
            }
        }
        System.assert(foundAdded, 'Should detect added decision');
    }

    // =========================================================================
    // TEST 3: Removed elements
    // =========================================================================

    @IsTest
    static void testCompare_RemovedAssignment() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Remove the assignment
        newFlow.assignments = new List<FlowMetadata.FlowAssignment>();

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundRemoved = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Removed' && change.itemName == 'Set_Values') {
                foundRemoved = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals('High', change.riskLevel);
            }
        }
        System.assert(foundRemoved, 'Should detect removed assignment');
    }

    // =========================================================================
    // TEST 4: Modified decision (rule count change)
    // =========================================================================

    @IsTest
    static void testCompare_ModifiedDecision_RuleCountChange() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add a second rule to the decision
        FlowMetadata.FlowRule rule2 = new FlowMetadata.FlowRule();
        rule2.name = 'IsInactive';
        rule2.label = 'Is Inactive';
        rule2.conditionLogic = 'and';
        FlowMetadata.FlowCondition condition2 = new FlowMetadata.FlowCondition();
        condition2.leftValueReference = 'Status__c';
        condition2.operator = 'EqualTo';
        condition2.rightValue = new FlowMetadata.FlowValue();
        condition2.rightValue.stringValue = 'Inactive';
        rule2.conditions = new List<FlowMetadata.FlowCondition>{ condition2 };
        rule2.connector = new FlowMetadata.FlowConnector();
        rule2.connector.targetReference = 'Update_Record';

        newFlow.decisions[0].rules.add(rule2);

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'Check_Status') {
                foundModified = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals('High', change.riskLevel);
                System.assertEquals(false, change.isCosmetic,
                    'Rule count change should be functional, not cosmetic');
            }
        }
        System.assert(foundModified, 'Should detect modified decision with rule count change');
    }

    // =========================================================================
    // TEST 5: Cosmetic-only change (locationX/locationY)
    // =========================================================================

    @IsTest
    static void testCompare_CosmeticChange_LocationOnly() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change only locationX on the assignment (cosmetic)
        newFlow.assignments[0].locationX = '500';
        newFlow.assignments[0].locationY = '600';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        // Should have no changes because logic signature doesn't change
        System.assertEquals(0, result.changes.size(),
            'Location-only change should not be detected (cosmetic)');
    }

    // =========================================================================
    // TEST 6: Configuration change (apiVersion)
    // =========================================================================

    @IsTest
    static void testCompare_ConfigurationChange_ApiVersion() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        newFlow.apiVersion = '61.0';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundConfig = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemType == 'config' &&
                change.itemName == 'apiVersion') {
                foundConfig = true;
                System.assertEquals('Configuration', change.category);
                System.assertEquals('Medium', change.riskLevel);
                System.assertEquals('62.0', change.oldValue);
                System.assertEquals('61.0', change.newValue);
            }
        }
        System.assert(foundConfig, 'Should detect API version change');
    }

    // =========================================================================
    // TEST 7: Modified loop (collectionReference change)
    // =========================================================================

    @IsTest
    static void testCompare_ModifiedLoop_CollectionChange() {
        FlowMetadata.FlowDefinition oldFlow = new FlowMetadata.FlowDefinition();
        oldFlow.label = 'Loop Test Flow';
        oldFlow.description = 'Test';
        oldFlow.processType = 'AutoLaunchedFlow';
        oldFlow.apiVersion = '62.0';

        FlowMetadata.FlowLoop oldLoop = new FlowMetadata.FlowLoop();
        oldLoop.name = 'Loop_Items';
        oldLoop.label = 'Loop Items';
        oldLoop.description = 'Loop through items';
        oldLoop.collectionReference = 'var_OldCollection';
        oldLoop.iterationOrder = 'Ascending';
        oldLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        oldLoop.nextValueConnector.targetReference = 'Done';
        oldLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        oldLoop.noMoreValuesConnector.targetReference = 'End';
        oldFlow.loops = new List<FlowMetadata.FlowLoop>{ oldLoop };

        FlowMetadata.FlowDefinition newFlow = new FlowMetadata.FlowDefinition();
        newFlow.label = 'Loop Test Flow';
        newFlow.description = 'Test';
        newFlow.processType = 'AutoLaunchedFlow';
        newFlow.apiVersion = '62.0';

        FlowMetadata.FlowLoop newLoop = new FlowMetadata.FlowLoop();
        newLoop.name = 'Loop_Items';
        newLoop.label = 'Loop Items';
        newLoop.description = 'Loop through items';
        newLoop.collectionReference = 'var_NewCollection';
        newLoop.iterationOrder = 'Ascending';
        newLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        newLoop.nextValueConnector.targetReference = 'Done';
        newLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        newLoop.noMoreValuesConnector.targetReference = 'End';
        newFlow.loops = new List<FlowMetadata.FlowLoop>{ newLoop };

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'Loop_Items') {
                foundModified = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals(false, change.isCosmetic,
                    'Collection change is functional');
                System.assertEquals('Medium', change.riskLevel);
            }
        }
        System.assert(foundModified, 'Should detect loop collection change');
    }

    // =========================================================================
    // TEST 8: Modified record lookup (object change)
    // =========================================================================

    @IsTest
    static void testCompare_ModifiedRecordLookup_ObjectChange() {
        FlowMetadata.FlowDefinition oldFlow = new FlowMetadata.FlowDefinition();
        oldFlow.label = 'Lookup Test';
        oldFlow.description = 'Test';
        oldFlow.processType = 'AutoLaunchedFlow';
        oldFlow.apiVersion = '62.0';

        FlowMetadata.FlowRecordLookup oldLookup = new FlowMetadata.FlowRecordLookup();
        oldLookup.name = 'Get_Record';
        oldLookup.label = 'Get Record';
        oldLookup.description = 'Get a record';
        oldLookup.object_x = 'Account';
        oldLookup.getFirstRecordOnly = true;
        oldFlow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ oldLookup };

        FlowMetadata.FlowDefinition newFlow = new FlowMetadata.FlowDefinition();
        newFlow.label = 'Lookup Test';
        newFlow.description = 'Test';
        newFlow.processType = 'AutoLaunchedFlow';
        newFlow.apiVersion = '62.0';

        FlowMetadata.FlowRecordLookup newLookup = new FlowMetadata.FlowRecordLookup();
        newLookup.name = 'Get_Record';
        newLookup.label = 'Get Record';
        newLookup.description = 'Get a record';
        newLookup.object_x = 'Contact';
        newLookup.getFirstRecordOnly = true;
        newFlow.recordLookups = new List<FlowMetadata.FlowRecordLookup>{ newLookup };

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'Get_Record') {
                foundModified = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals(false, change.isCosmetic);
                System.assertEquals('High', change.riskLevel);
            }
        }
        System.assert(foundModified, 'Should detect record lookup object change');
    }

    // =========================================================================
    // TEST 9: Added/removed variables
    // =========================================================================

    @IsTest
    static void testCompare_AddedVariable() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add a new variable
        FlowMetadata.FlowVariable newVar = new FlowMetadata.FlowVariable();
        newVar.name = 'var_NewVar';
        newVar.description = 'A new variable';
        newVar.dataType = 'String';
        newVar.isCollection = false;
        newVar.isInput = false;
        newVar.isOutput = false;
        newFlow.variables.add(newVar);

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundAdded = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Added' && change.itemName == 'var_NewVar') {
                foundAdded = true;
                System.assertEquals('Resources', change.category);
                System.assertEquals('Low', change.riskLevel);
            }
        }
        System.assert(foundAdded, 'Should detect added variable');
    }

    @IsTest
    static void testCompare_RemovedVariable() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Remove all variables
        newFlow.variables = new List<FlowMetadata.FlowVariable>();

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundRemoved = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Removed' && change.itemName == 'var_Counter') {
                foundRemoved = true;
                System.assertEquals('Resources', change.category);
                System.assertEquals('Medium', change.riskLevel);
            }
        }
        System.assert(foundRemoved, 'Should detect removed variable');
    }

    // =========================================================================
    // TEST 10: Modified variable (dataType change)
    // =========================================================================

    @IsTest
    static void testCompare_ModifiedVariable_DataTypeChange() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change the dataType of the variable
        newFlow.variables[0].dataType = 'String';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'var_Counter') {
                foundModified = true;
                System.assertEquals('Resources', change.category);
                System.assertEquals(false, change.isCosmetic,
                    'DataType change is functional');
                System.assertEquals('High', change.riskLevel);
            }
        }
        System.assert(foundModified, 'Should detect variable dataType change');
    }

    // =========================================================================
    // TEST 11: Score delta (old has issues, new is clean)
    // =========================================================================

    @IsTest
    static void testCompare_ScoreDelta_Improvement() {
        // Old flow with DML in loop
        FlowMetadata.FlowDefinition oldFlow = new FlowMetadata.FlowDefinition();
        oldFlow.label = 'DML In Loop';
        oldFlow.description = 'Has DML in loop';
        oldFlow.processType = 'AutoLaunchedFlow';
        oldFlow.apiVersion = '62.0';

        FlowMetadata.FlowLoop oldLoop = new FlowMetadata.FlowLoop();
        oldLoop.name = 'Loop_Items';
        oldLoop.label = 'Loop Items';
        oldLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        oldLoop.nextValueConnector.targetReference = 'Update_Record';
        oldLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        oldLoop.noMoreValuesConnector.targetReference = 'End';
        oldFlow.loops = new List<FlowMetadata.FlowLoop>{ oldLoop };

        FlowMetadata.FlowRecordUpdate oldUpdate = new FlowMetadata.FlowRecordUpdate();
        oldUpdate.name = 'Update_Record';
        oldUpdate.label = 'Update Record';
        oldUpdate.object_x = 'Account';
        oldUpdate.connector = new FlowMetadata.FlowConnector();
        oldUpdate.connector.targetReference = 'Loop_Items';
        oldFlow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ oldUpdate };

        // New flow (clean)
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assertNotEquals(null, result.oldScore, 'Old score should be set');
        System.assertNotEquals(null, result.newScore, 'New score should be set');
        System.assertNotEquals(null, result.scoreDelta, 'Score delta should be set');
        System.assertEquals(true, result.isImprovement,
            'Should show improvement (new score > old score)');
    }

    // =========================================================================
    // TEST 12: DiffSummary counts
    // =========================================================================

    @IsTest
    static void testCompare_DiffSummary_Counts() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add a decision
        FlowMetadata.FlowDecision newDec = new FlowMetadata.FlowDecision();
        newDec.name = 'New_Decision';
        newDec.label = 'New Decision';
        newDec.defaultConnector = new FlowMetadata.FlowConnector();
        newDec.defaultConnector.targetReference = 'Done';
        newDec.rules = new List<FlowMetadata.FlowRule>();
        newFlow.decisions.add(newDec);

        // Remove an assignment
        newFlow.assignments = new List<FlowMetadata.FlowAssignment>();

        // Modify a variable
        newFlow.variables[0].dataType = 'String';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assertNotEquals(null, result.summary, 'Summary should exist');
        System.assertEquals(3, result.summary.totalChanges,
            'Should have 1 added + 1 removed + 1 modified = 3 changes');
        System.assertEquals(1, result.summary.added, 'Should have 1 added');
        System.assertEquals(1, result.summary.removed, 'Should have 1 removed');
        System.assertEquals(1, result.summary.modified, 'Should have 1 modified');
    }

    // =========================================================================
    // TEST 13: DiffSummary functional vs cosmetic
    // =========================================================================

    @IsTest
    static void testCompare_DiffSummary_FunctionalVsCosmeticCounts() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Make a functional change (change decision label)
        newFlow.decisions[0].label = 'Updated Label';

        // Add a new variable (functional)
        FlowMetadata.FlowVariable newVar = new FlowMetadata.FlowVariable();
        newVar.name = 'var_New';
        newVar.dataType = 'String';
        newVar.isCollection = false;
        newVar.isInput = false;
        newVar.isOutput = false;
        newFlow.variables.add(newVar);

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assertNotEquals(null, result.summary.functionalChanges,
            'Functional changes count should exist');
        System.assertNotEquals(null, result.summary.cosmeticChanges,
            'Cosmetic changes count should exist');
        System.assert(result.summary.functionalChanges > 0,
            'Should have functional changes');
    }

    // =========================================================================
    // TEST 14: Start element changes (trigger type)
    // =========================================================================

    @IsTest
    static void testCompare_StartElement_TriggerTypeChange() {
        FlowMetadata.FlowDefinition oldFlow = new FlowMetadata.FlowDefinition();
        oldFlow.label = 'Start Test';
        oldFlow.description = 'Test';
        oldFlow.processType = 'RecordTriggeredFlow';
        oldFlow.apiVersion = '62.0';

        FlowMetadata.FlowStart oldStart = new FlowMetadata.FlowStart();
        oldStart.object_x = 'Account';
        oldStart.triggerType = 'RecordAfterSave';
        oldStart.recordTriggerType = 'Create';
        oldStart.connector = new FlowMetadata.FlowConnector();
        oldStart.connector.targetReference = 'Done';
        oldFlow.start = oldStart;

        FlowMetadata.FlowDefinition newFlow = new FlowMetadata.FlowDefinition();
        newFlow.label = 'Start Test';
        newFlow.description = 'Test';
        newFlow.processType = 'RecordTriggeredFlow';
        newFlow.apiVersion = '62.0';

        FlowMetadata.FlowStart newStart = new FlowMetadata.FlowStart();
        newStart.object_x = 'Account';
        newStart.triggerType = 'RecordBeforeSave';
        newStart.recordTriggerType = 'Create';
        newStart.connector = new FlowMetadata.FlowConnector();
        newStart.connector.targetReference = 'Done';
        newFlow.start = newStart;

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundCritical = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.itemName == 'start' && change.changeType == 'Modified') {
                foundCritical = true;
                System.assertEquals('Critical', change.riskLevel,
                    'Start element change should be Critical risk');
            }
        }
        System.assert(foundCritical, 'Should detect start element trigger type change');
    }

    // =========================================================================
    // TEST 15: Formula change (expression)
    // =========================================================================

    @IsTest
    static void testCompare_ModifiedFormula_ExpressionChange() {
        FlowMetadata.FlowDefinition oldFlow = new FlowMetadata.FlowDefinition();
        oldFlow.label = 'Formula Test';
        oldFlow.description = 'Test';
        oldFlow.processType = 'AutoLaunchedFlow';
        oldFlow.apiVersion = '62.0';

        FlowMetadata.FlowFormula oldFormula = new FlowMetadata.FlowFormula();
        oldFormula.name = 'calc_Total';
        oldFormula.description = 'Calculate total';
        oldFormula.dataType = 'Number';
        oldFormula.expression = 'Price__c * Quantity__c';
        oldFlow.formulas = new List<FlowMetadata.FlowFormula>{ oldFormula };

        FlowMetadata.FlowDefinition newFlow = new FlowMetadata.FlowDefinition();
        newFlow.label = 'Formula Test';
        newFlow.description = 'Test';
        newFlow.processType = 'AutoLaunchedFlow';
        newFlow.apiVersion = '62.0';

        FlowMetadata.FlowFormula newFormula = new FlowMetadata.FlowFormula();
        newFormula.name = 'calc_Total';
        newFormula.description = 'Calculate total';
        newFormula.dataType = 'Number';
        newFormula.expression = 'Price__c * Quantity__c * (1 - Discount__c)';
        newFlow.formulas = new List<FlowMetadata.FlowFormula>{ newFormula };

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'calc_Total') {
                foundModified = true;
                System.assertEquals('Resources', change.category);
                System.assertEquals(false, change.isCosmetic,
                    'Formula expression change is functional');
                System.assertEquals('Medium', change.riskLevel);
            }
        }
        System.assert(foundModified, 'Should detect formula expression change');
    }

    // =========================================================================
    // TEST 16: Configuration change (processType) - High risk
    // =========================================================================

    @IsTest
    static void testCompare_ConfigurationChange_ProcessType() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        newFlow.processType = 'Flow';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundConfig = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'processType') {
                foundConfig = true;
                System.assertEquals('Configuration', change.category);
                System.assertEquals('High', change.riskLevel,
                    'ProcessType change should be High risk');
            }
        }
        System.assert(foundConfig, 'Should detect process type change');
    }

    // =========================================================================
    // TEST 17: Configuration change (triggerType) - High risk
    // =========================================================================

    @IsTest
    static void testCompare_ConfigurationChange_TriggerType() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        newFlow.triggerType = 'Scheduled';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundConfig = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'triggerType') {
                foundConfig = true;
                System.assertEquals('Configuration', change.category);
                System.assertEquals('High', change.riskLevel,
                    'TriggerType change should be High risk');
            }
        }
        System.assert(foundConfig, 'Should detect trigger type change');
    }

    // =========================================================================
    // TEST 18: Multiple changes (mixed add/remove/modify)
    // =========================================================================

    @IsTest
    static void testCompare_MultipleChanges() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change API version
        newFlow.apiVersion = '61.0';

        // Add new decision
        FlowMetadata.FlowDecision newDec = new FlowMetadata.FlowDecision();
        newDec.name = 'New_Decision';
        newDec.label = 'New Decision';
        newDec.defaultConnector = new FlowMetadata.FlowConnector();
        newDec.defaultConnector.targetReference = 'Done';
        newDec.rules = new List<FlowMetadata.FlowRule>();
        newFlow.decisions.add(newDec);

        // Remove assignment
        newFlow.assignments = new List<FlowMetadata.FlowAssignment>();

        // Modify variable
        newFlow.variables[0].description = 'Updated description';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assert(result.changes.size() >= 3, 'Should have at least 3 changes');
        System.assertNotEquals(null, result.summary);
        System.assert(result.summary.totalChanges >= 3);
    }

    // =========================================================================
    // TEST 19: Record update object change
    // =========================================================================

    @IsTest
    static void testCompare_RecordUpdate_ObjectChange() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change the object being updated
        newFlow.recordUpdates[0].object_x = 'Contact';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'Update_Record') {
                foundModified = true;
                System.assertEquals('Elements', change.category);
                System.assertEquals(false, change.isCosmetic);
            }
        }
        System.assert(foundModified, 'Should detect record update object change');
    }

    // =========================================================================
    // TEST 20: Assignment modification (assignment items change)
    // =========================================================================

    @IsTest
    static void testCompare_Assignment_ItemChange() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add another assignment item
        FlowMetadata.FlowAssignmentItem item2 = new FlowMetadata.FlowAssignmentItem();
        item2.assignToReference = 'var_Status';
        item2.operator = 'Assign';
        item2.value = new FlowMetadata.FlowValue();
        item2.value.stringValue = 'Active';
        newFlow.assignments[0].assignmentItems.add(item2);

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'Set_Values') {
                foundModified = true;
                System.assertEquals(false, change.isCosmetic,
                    'Assignment item change is functional');
            }
        }
        System.assert(foundModified, 'Should detect assignment modification');
    }

    // =========================================================================
    // TEST 21: Connector change (rerouting) - cosmetic
    // =========================================================================

    @IsTest
    static void testCompare_ConnectorChange_Cosmetic() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change where the assignment connector points (cosmetic without logic change)
        newFlow.assignments[0].connector.targetReference = 'Different_Target';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        // A connector-only change should be flagged as cosmetic
        Boolean foundCosmetic = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.itemName == 'Set_Values' && change.isCosmetic == true) {
                foundCosmetic = true;
                System.assertEquals('Info', change.riskLevel);
            }
        }
        System.assert(foundCosmetic, 'Connector-only change should be cosmetic');
    }

    // =========================================================================
    // TEST 22: Variable isInput/isOutput change
    // =========================================================================

    @IsTest
    static void testCompare_Variable_InputOutputChange() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Change variable to be an input
        newFlow.variables[0].isInput = true;

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundModified = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'var_Counter') {
                foundModified = true;
                System.assertEquals(false, change.isCosmetic,
                    'Variable accessibility change is functional');
                System.assertEquals('High', change.riskLevel);
            }
        }
        System.assert(foundModified, 'Should detect variable input/output change');
    }

    // =========================================================================
    // TEST 23: Added actionCall element
    // =========================================================================

    @IsTest
    static void testCompare_AddedActionCall() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        // Add an action call
        FlowMetadata.FlowActionCall action = new FlowMetadata.FlowActionCall();
        action.name = 'Send_Email';
        action.label = 'Send Email';
        action.description = 'Send notification email';
        action.actionName = 'chatterPost';
        action.actionType = 'chatterPost';
        newFlow.actionCalls = new List<FlowMetadata.FlowActionCall>{ action };

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundAdded = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Added' && change.itemName == 'Send_Email') {
                foundAdded = true;
                System.assertEquals('Elements', change.category);
            }
        }
        System.assert(foundAdded, 'Should detect added action call');
    }

    // =========================================================================
    // TEST 24: Configuration change (runInMode)
    // =========================================================================

    @IsTest
    static void testCompare_ConfigurationChange_RunInMode() {
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();
        FlowMetadata.FlowDefinition newFlow = buildSimpleFlow();

        newFlow.runInMode = 'SystemModeWithoutSharing';

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        Boolean foundConfig = false;
        for (FlowDiffResult.ChangeEntry change : result.changes) {
            if (change.changeType == 'Modified' && change.itemName == 'runInMode') {
                foundConfig = true;
                System.assertEquals('Configuration', change.category);
                System.assertEquals('High', change.riskLevel,
                    'RunInMode change should be High risk');
            }
        }
        System.assert(foundConfig, 'Should detect run in mode change');
    }

    // =========================================================================
    // TEST 25: Regression detection
    // =========================================================================

    @IsTest
    static void testCompare_ScoreDelta_Regression() {
        // Clean flow
        FlowMetadata.FlowDefinition oldFlow = buildSimpleFlow();

        // New flow with DML in loop (introduces issues)
        FlowMetadata.FlowDefinition newFlow = new FlowMetadata.FlowDefinition();
        newFlow.label = 'Problematic Flow';
        newFlow.description = 'Has issues';
        newFlow.processType = 'AutoLaunchedFlow';
        newFlow.apiVersion = '62.0';

        FlowMetadata.FlowLoop newLoop = new FlowMetadata.FlowLoop();
        newLoop.name = 'Loop_Items';
        newLoop.label = 'Loop Items';
        newLoop.nextValueConnector = new FlowMetadata.FlowConnector();
        newLoop.nextValueConnector.targetReference = 'Update_Record';
        newLoop.noMoreValuesConnector = new FlowMetadata.FlowConnector();
        newLoop.noMoreValuesConnector.targetReference = 'End';
        newFlow.loops = new List<FlowMetadata.FlowLoop>{ newLoop };

        FlowMetadata.FlowRecordUpdate newUpdate = new FlowMetadata.FlowRecordUpdate();
        newUpdate.name = 'Update_Record';
        newUpdate.label = 'Update Record';
        newUpdate.object_x = 'Account';
        newUpdate.connector = new FlowMetadata.FlowConnector();
        newUpdate.connector.targetReference = 'Loop_Items';
        newFlow.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>{ newUpdate };

        FlowDiffService differ = new FlowDiffService();
        FlowDiffResult result = differ.compare(oldFlow, newFlow);

        System.assertEquals(true, result.isRegression,
            'Should show regression (new score < old score)');
        System.assertEquals(false, result.isImprovement);
    }
}
