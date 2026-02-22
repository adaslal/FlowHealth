/**
 * FlowLogicSignatureTest - Unit tests for FlowLogicSignature deterministic logic signature generation.
 *
 * APPROACH: Build FlowMetadata objects programmatically rather than parsing JSON.
 * Each test verifies that:
 * 1. Two identical elements produce the same signature
 * 2. Changing a functional attribute produces a different signature
 * 3. Changing cosmetic attributes (locationX, locationY, connectors) does NOT change signature
 * 4. Null inputs are handled gracefully (return empty string)
 *
 * SIGNATURE DESIGN PRINCIPLE:
 * A Logic Signature captures ONLY business-logic attributes, ignoring cosmetic/layout attributes.
 * When signatures match, differences are purely cosmetic.
 * When signatures differ, the element's behavior has changed.
 */
@IsTest
private class FlowLogicSignatureTest {

    // =========================================================================
    // HELPER: Build FlowValue objects
    // =========================================================================

    private static FlowMetadata.FlowValue buildStringValue(String val) {
        FlowMetadata.FlowValue v = new FlowMetadata.FlowValue();
        v.stringValue = val;
        return v;
    }

    private static FlowMetadata.FlowValue buildNumberValue(Decimal val) {
        FlowMetadata.FlowValue v = new FlowMetadata.FlowValue();
        v.numberValue = val;
        return v;
    }

    private static FlowMetadata.FlowValue buildBooleanValue(Boolean val) {
        FlowMetadata.FlowValue v = new FlowMetadata.FlowValue();
        v.booleanValue = val;
        return v;
    }

    private static FlowMetadata.FlowValue buildElementReference(String ref) {
        FlowMetadata.FlowValue v = new FlowMetadata.FlowValue();
        v.elementReference = ref;
        return v;
    }

    // =========================================================================
    // TEST: forDecision - Same logic, different cosmetics = same signature
    // =========================================================================

    @IsTest
    static void testDecision_SameLogicDifferentLocation() {
        // Build two identical decisions with different locations
        FlowMetadata.FlowDecision d1 = new FlowMetadata.FlowDecision();
        d1.name = 'Check_Status';
        d1.label = 'Check Status';
        d1.description = 'Checks account status';
        d1.locationX = '100';
        d1.locationY = '200';
        d1.defaultConnectorLabel = 'Default Path';
        d1.rules = new List<FlowMetadata.FlowRule>();
        FlowMetadata.FlowRule rule = new FlowMetadata.FlowRule();
        rule.name = 'Rule_1';
        rule.label = 'Active';
        rule.conditionLogic = 'and';
        rule.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond = new FlowMetadata.FlowCondition();
        cond.leftValueReference = 'record.Status';
        cond.operator = 'EqualTo';
        cond.rightValue = buildStringValue('Active');
        rule.conditions.add(cond);
        d1.rules.add(rule);

        FlowMetadata.FlowDecision d2 = new FlowMetadata.FlowDecision();
        d2.name = 'Check_Status';
        d2.label = 'Check Status';
        d2.description = 'Checks account status';
        d2.locationX = '300';  // Different location
        d2.locationY = '400';  // Different location
        d2.defaultConnectorLabel = 'Default Path';
        d2.rules = new List<FlowMetadata.FlowRule>();
        FlowMetadata.FlowRule rule2 = new FlowMetadata.FlowRule();
        rule2.name = 'Rule_1';
        rule2.label = 'Active';
        rule2.conditionLogic = 'and';
        rule2.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond2 = new FlowMetadata.FlowCondition();
        cond2.leftValueReference = 'record.Status';
        cond2.operator = 'EqualTo';
        cond2.rightValue = buildStringValue('Active');
        rule2.conditions.add(cond2);
        d2.rules.add(rule2);

        String sig1 = FlowLogicSignature.forDecision(d1);
        String sig2 = FlowLogicSignature.forDecision(d2);

        System.assertEquals(sig1, sig2, 'Same logic with different locations should have same signature');
        System.assertNotEquals('', sig1, 'Signature should not be empty');
    }

    // =========================================================================
    // TEST: forDecision - Changing condition produces different signature
    // =========================================================================

    @IsTest
    static void testDecision_DifferentConditionProducesDifferentSignature() {
        FlowMetadata.FlowDecision d1 = new FlowMetadata.FlowDecision();
        d1.label = 'Check Status';
        d1.rules = new List<FlowMetadata.FlowRule>();
        FlowMetadata.FlowRule rule1 = new FlowMetadata.FlowRule();
        rule1.name = 'Rule_Active';
        rule1.label = 'Active';
        rule1.conditionLogic = 'and';
        rule1.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond1 = new FlowMetadata.FlowCondition();
        cond1.leftValueReference = 'record.Status';
        cond1.operator = 'EqualTo';
        cond1.rightValue = buildStringValue('Active');
        rule1.conditions.add(cond1);
        d1.rules.add(rule1);

        FlowMetadata.FlowDecision d2 = new FlowMetadata.FlowDecision();
        d2.label = 'Check Status';
        d2.rules = new List<FlowMetadata.FlowRule>();
        FlowMetadata.FlowRule rule2 = new FlowMetadata.FlowRule();
        rule2.name = 'Rule_Active';
        rule2.label = 'Active';
        rule2.conditionLogic = 'and';
        rule2.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond2 = new FlowMetadata.FlowCondition();
        cond2.leftValueReference = 'record.Status';
        cond2.operator = 'EqualTo';
        cond2.rightValue = buildStringValue('Inactive');  // Different value
        rule2.conditions.add(cond2);
        d2.rules.add(rule2);

        String sig1 = FlowLogicSignature.forDecision(d1);
        String sig2 = FlowLogicSignature.forDecision(d2);

        System.assertNotEquals(sig1, sig2, 'Different conditions should produce different signatures');
    }

    // =========================================================================
    // TEST: forRecordLookup - Same filters = same sig, different object = different sig
    // =========================================================================

    @IsTest
    static void testRecordLookup_SameFiltersProduceSameSignature() {
        FlowMetadata.FlowRecordLookup lookup1 = new FlowMetadata.FlowRecordLookup();
        lookup1.label = 'Get Accounts';
        lookup1.object_x = 'Account';
        lookup1.getFirstRecordOnly = false;
        lookup1.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter1 = new FlowMetadata.FlowRecordFilter();
        filter1.field = 'Status';
        filter1.operator = 'EqualTo';
        filter1.value = buildStringValue('Active');
        lookup1.filters.add(filter1);
        lookup1.sortField = 'Name';
        lookup1.sortOrder = 'Asc';

        FlowMetadata.FlowRecordLookup lookup2 = new FlowMetadata.FlowRecordLookup();
        lookup2.label = 'Get Accounts';
        lookup2.object_x = 'Account';
        lookup2.getFirstRecordOnly = false;
        lookup2.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter2 = new FlowMetadata.FlowRecordFilter();
        filter2.field = 'Status';
        filter2.operator = 'EqualTo';
        filter2.value = buildStringValue('Active');
        lookup2.filters.add(filter2);
        lookup2.sortField = 'Name';
        lookup2.sortOrder = 'Asc';

        String sig1 = FlowLogicSignature.forRecordLookup(lookup1);
        String sig2 = FlowLogicSignature.forRecordLookup(lookup2);

        System.assertEquals(sig1, sig2, 'Same filters and object should produce same signature');
    }

    @IsTest
    static void testRecordLookup_DifferentObjectProducesDifferentSignature() {
        FlowMetadata.FlowRecordLookup lookup1 = new FlowMetadata.FlowRecordLookup();
        lookup1.label = 'Get Records';
        lookup1.object_x = 'Account';
        lookup1.getFirstRecordOnly = true;

        FlowMetadata.FlowRecordLookup lookup2 = new FlowMetadata.FlowRecordLookup();
        lookup2.label = 'Get Records';
        lookup2.object_x = 'Contact';  // Different object
        lookup2.getFirstRecordOnly = true;

        String sig1 = FlowLogicSignature.forRecordLookup(lookup1);
        String sig2 = FlowLogicSignature.forRecordLookup(lookup2);

        System.assertNotEquals(sig1, sig2, 'Different objects should produce different signatures');
    }

    // =========================================================================
    // TEST: forRecordCreate - Same object/inputAssignments = same sig
    // =========================================================================

    @IsTest
    static void testRecordCreate_SameInputAssignmentsProduceSameSignature() {
        FlowMetadata.FlowRecordCreate rc1 = new FlowMetadata.FlowRecordCreate();
        rc1.label = 'Create Account';
        rc1.object_x = 'Account';
        rc1.inputAssignments = new List<FlowMetadata.FlowInputAssignment>();
        FlowMetadata.FlowInputAssignment assign1 = new FlowMetadata.FlowInputAssignment();
        assign1.field = 'Name';
        assign1.value = buildElementReference('var_AccountName');
        rc1.inputAssignments.add(assign1);

        FlowMetadata.FlowRecordCreate rc2 = new FlowMetadata.FlowRecordCreate();
        rc2.label = 'Create Account';
        rc2.object_x = 'Account';
        rc2.inputAssignments = new List<FlowMetadata.FlowInputAssignment>();
        FlowMetadata.FlowInputAssignment assign2 = new FlowMetadata.FlowInputAssignment();
        assign2.field = 'Name';
        assign2.value = buildElementReference('var_AccountName');
        rc2.inputAssignments.add(assign2);

        String sig1 = FlowLogicSignature.forRecordCreate(rc1);
        String sig2 = FlowLogicSignature.forRecordCreate(rc2);

        System.assertEquals(sig1, sig2, 'Same object and input assignments should produce same signature');
    }

    // =========================================================================
    // TEST: forLoop - Same collectionReference = same sig, different = different
    // =========================================================================

    @IsTest
    static void testLoop_SameCollectionProducesSameSignature() {
        FlowMetadata.FlowLoop loop1 = new FlowMetadata.FlowLoop();
        loop1.label = 'Loop Accounts';
        loop1.collectionReference = 'var_Accounts';
        loop1.iterationOrder = 'Asc';
        loop1.assignNextValueToReference = 'var_CurrentAccount';

        FlowMetadata.FlowLoop loop2 = new FlowMetadata.FlowLoop();
        loop2.label = 'Loop Accounts';
        loop2.collectionReference = 'var_Accounts';
        loop2.iterationOrder = 'Asc';
        loop2.assignNextValueToReference = 'var_CurrentAccount';

        String sig1 = FlowLogicSignature.forLoop(loop1);
        String sig2 = FlowLogicSignature.forLoop(loop2);

        System.assertEquals(sig1, sig2, 'Same collection and iteration order should produce same signature');
    }

    @IsTest
    static void testLoop_DifferentCollectionProducesDifferentSignature() {
        FlowMetadata.FlowLoop loop1 = new FlowMetadata.FlowLoop();
        loop1.label = 'Loop Records';
        loop1.collectionReference = 'var_Accounts';
        loop1.iterationOrder = 'Asc';

        FlowMetadata.FlowLoop loop2 = new FlowMetadata.FlowLoop();
        loop2.label = 'Loop Records';
        loop2.collectionReference = 'var_Contacts';  // Different collection
        loop2.iterationOrder = 'Asc';

        String sig1 = FlowLogicSignature.forLoop(loop1);
        String sig2 = FlowLogicSignature.forLoop(loop2);

        System.assertNotEquals(sig1, sig2, 'Different collections should produce different signatures');
    }

    // =========================================================================
    // TEST: forScreen - Same fields = same sig
    // =========================================================================

    @IsTest
    static void testScreen_SameFieldsProduceSameSignature() {
        FlowMetadata.FlowScreen screen1 = new FlowMetadata.FlowScreen();
        screen1.label = 'Confirmation Screen';
        screen1.allowBack = true;
        screen1.allowFinish = true;
        screen1.allowPause = false;
        screen1.showHeader = true;
        screen1.showFooter = true;
        screen1.fields = new List<FlowMetadata.FlowScreenField>();
        FlowMetadata.FlowScreenField field1 = new FlowMetadata.FlowScreenField();
        field1.name = 'field_Message';
        field1.fieldType = 'DisplayText';
        field1.fieldText = 'Are you sure?';
        field1.dataType = 'String';
        field1.isRequired = false;
        screen1.fields.add(field1);

        FlowMetadata.FlowScreen screen2 = new FlowMetadata.FlowScreen();
        screen2.label = 'Confirmation Screen';
        screen2.allowBack = true;
        screen2.allowFinish = true;
        screen2.allowPause = false;
        screen2.showHeader = true;
        screen2.showFooter = true;
        screen2.fields = new List<FlowMetadata.FlowScreenField>();
        FlowMetadata.FlowScreenField field2 = new FlowMetadata.FlowScreenField();
        field2.name = 'field_Message';
        field2.fieldType = 'DisplayText';
        field2.fieldText = 'Are you sure?';
        field2.dataType = 'String';
        field2.isRequired = false;
        screen2.fields.add(field2);

        String sig1 = FlowLogicSignature.forScreen(screen1);
        String sig2 = FlowLogicSignature.forScreen(screen2);

        System.assertEquals(sig1, sig2, 'Same screen fields should produce same signature');
    }

    // =========================================================================
    // TEST: forSubflow - Same flowName = same sig, different = different
    // =========================================================================

    @IsTest
    static void testSubflow_SameFlowNameProducesSameSignature() {
        FlowMetadata.FlowSubflow sf1 = new FlowMetadata.FlowSubflow();
        sf1.label = 'Call Validation';
        sf1.flowName = 'ValidateAccount';
        sf1.inputAssignments = new List<FlowMetadata.FlowInputParameter>();
        FlowMetadata.FlowInputParameter param1 = new FlowMetadata.FlowInputParameter();
        param1.name = 'recordId';
        param1.value = buildElementReference('record.Id');
        sf1.inputAssignments.add(param1);

        FlowMetadata.FlowSubflow sf2 = new FlowMetadata.FlowSubflow();
        sf2.label = 'Call Validation';
        sf2.flowName = 'ValidateAccount';
        sf2.inputAssignments = new List<FlowMetadata.FlowInputParameter>();
        FlowMetadata.FlowInputParameter param2 = new FlowMetadata.FlowInputParameter();
        param2.name = 'recordId';
        param2.value = buildElementReference('record.Id');
        sf2.inputAssignments.add(param2);

        String sig1 = FlowLogicSignature.forSubflow(sf1);
        String sig2 = FlowLogicSignature.forSubflow(sf2);

        System.assertEquals(sig1, sig2, 'Same flow name and inputs should produce same signature');
    }

    @IsTest
    static void testSubflow_DifferentFlowNameProducesDifferentSignature() {
        FlowMetadata.FlowSubflow sf1 = new FlowMetadata.FlowSubflow();
        sf1.label = 'Call Subflow';
        sf1.flowName = 'FlowA';

        FlowMetadata.FlowSubflow sf2 = new FlowMetadata.FlowSubflow();
        sf2.label = 'Call Subflow';
        sf2.flowName = 'FlowB';  // Different flow

        String sig1 = FlowLogicSignature.forSubflow(sf1);
        String sig2 = FlowLogicSignature.forSubflow(sf2);

        System.assertNotEquals(sig1, sig2, 'Different flow names should produce different signatures');
    }

    // =========================================================================
    // TEST: forVariable - Same type/collection/input/output = same sig
    // =========================================================================

    @IsTest
    static void testVariable_SameConfigurationProducesSameSignature() {
        FlowMetadata.FlowVariable var1 = new FlowMetadata.FlowVariable();
        var1.name = 'var_Status';
        var1.dataType = 'String';
        var1.isCollection = false;
        var1.isInput = false;
        var1.isOutput = false;
        var1.objectType = null;
        var1.defaultValue = buildStringValue('Active');

        FlowMetadata.FlowVariable var2 = new FlowMetadata.FlowVariable();
        var2.name = 'var_Status';
        var2.dataType = 'String';
        var2.isCollection = false;
        var2.isInput = false;
        var2.isOutput = false;
        var2.objectType = null;
        var2.defaultValue = buildStringValue('Active');

        String sig1 = FlowLogicSignature.forVariable(var1);
        String sig2 = FlowLogicSignature.forVariable(var2);

        System.assertEquals(sig1, sig2, 'Same variable configuration should produce same signature');
    }

    // =========================================================================
    // TEST: forFormula - Same expression = same sig, different = different
    // =========================================================================

    @IsTest
    static void testFormula_SameExpressionProducesSameSignature() {
        FlowMetadata.FlowFormula f1 = new FlowMetadata.FlowFormula();
        f1.name = 'formula_IsActive';
        f1.dataType = 'Boolean';
        f1.expression = '{!record.Status} = "Active"';

        FlowMetadata.FlowFormula f2 = new FlowMetadata.FlowFormula();
        f2.name = 'formula_IsActive';
        f2.dataType = 'Boolean';
        f2.expression = '{!record.Status} = "Active"';

        String sig1 = FlowLogicSignature.forFormula(f1);
        String sig2 = FlowLogicSignature.forFormula(f2);

        System.assertEquals(sig1, sig2, 'Same expression should produce same signature');
    }

    @IsTest
    static void testFormula_DifferentExpressionProducesDifferentSignature() {
        FlowMetadata.FlowFormula f1 = new FlowMetadata.FlowFormula();
        f1.name = 'formula_Check';
        f1.dataType = 'Boolean';
        f1.expression = '{!record.Status} = "Active"';

        FlowMetadata.FlowFormula f2 = new FlowMetadata.FlowFormula();
        f2.name = 'formula_Check';
        f2.dataType = 'Boolean';
        f2.expression = '{!record.Status} = "Inactive"';  // Different expression

        String sig1 = FlowLogicSignature.forFormula(f1);
        String sig2 = FlowLogicSignature.forFormula(f2);

        System.assertNotEquals(sig1, sig2, 'Different expressions should produce different signatures');
    }

    // =========================================================================
    // TEST: forStart - Same trigger config = same sig, different triggerType = different
    // =========================================================================

    @IsTest
    static void testStart_SameTriggerConfigProducesSameSignature() {
        FlowMetadata.FlowStart start1 = new FlowMetadata.FlowStart();
        start1.object_x = 'Account';
        start1.triggerType = 'RecordAfterSave';
        start1.recordTriggerType = 'CreateAndUpdate';
        start1.filters = null;
        start1.filterLogic = null;

        FlowMetadata.FlowStart start2 = new FlowMetadata.FlowStart();
        start2.object_x = 'Account';
        start2.triggerType = 'RecordAfterSave';
        start2.recordTriggerType = 'CreateAndUpdate';
        start2.filters = null;
        start2.filterLogic = null;

        String sig1 = FlowLogicSignature.forStart(start1);
        String sig2 = FlowLogicSignature.forStart(start2);

        System.assertEquals(sig1, sig2, 'Same trigger configuration should produce same signature');
    }

    @IsTest
    static void testStart_DifferentTriggerTypeProducesDifferentSignature() {
        FlowMetadata.FlowStart start1 = new FlowMetadata.FlowStart();
        start1.object_x = 'Account';
        start1.triggerType = 'RecordAfterSave';
        start1.recordTriggerType = 'Create';

        FlowMetadata.FlowStart start2 = new FlowMetadata.FlowStart();
        start2.object_x = 'Account';
        start2.triggerType = 'RecordBeforeSave';  // Different trigger
        start2.recordTriggerType = 'Create';

        String sig1 = FlowLogicSignature.forStart(start1);
        String sig2 = FlowLogicSignature.forStart(start2);

        System.assertNotEquals(sig1, sig2, 'Different trigger types should produce different signatures');
    }

    // =========================================================================
    // TEST: forActionCall - Same actionName/params = same sig
    // =========================================================================

    @IsTest
    static void testActionCall_SameConfigurationProducesSameSignature() {
        FlowMetadata.FlowActionCall action1 = new FlowMetadata.FlowActionCall();
        action1.label = 'Send Email';
        action1.actionName = 'emailAlert';
        action1.actionType = 'emailAlert';
        action1.storeOutputAutomatically = false;
        action1.flowTransactionModel = 'Automatic';
        action1.inputParameters = new List<FlowMetadata.FlowInputParameter>();
        FlowMetadata.FlowInputParameter param1 = new FlowMetadata.FlowInputParameter();
        param1.name = 'to';
        param1.value = buildElementReference('record.Email');
        action1.inputParameters.add(param1);

        FlowMetadata.FlowActionCall action2 = new FlowMetadata.FlowActionCall();
        action2.label = 'Send Email';
        action2.actionName = 'emailAlert';
        action2.actionType = 'emailAlert';
        action2.storeOutputAutomatically = false;
        action2.flowTransactionModel = 'Automatic';
        action2.inputParameters = new List<FlowMetadata.FlowInputParameter>();
        FlowMetadata.FlowInputParameter param2 = new FlowMetadata.FlowInputParameter();
        param2.name = 'to';
        param2.value = buildElementReference('record.Email');
        action2.inputParameters.add(param2);

        String sig1 = FlowLogicSignature.forActionCall(action1);
        String sig2 = FlowLogicSignature.forActionCall(action2);

        System.assertEquals(sig1, sig2, 'Same action configuration should produce same signature');
    }

    // =========================================================================
    // TEST: forAssignment - Same items = same sig
    // =========================================================================

    @IsTest
    static void testAssignment_SameItemsProduceSameSignature() {
        FlowMetadata.FlowAssignment assign1 = new FlowMetadata.FlowAssignment();
        assign1.label = 'Set Status';
        assign1.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>();
        FlowMetadata.FlowAssignmentItem item1 = new FlowMetadata.FlowAssignmentItem();
        item1.assignToReference = 'var_Status';
        item1.operator = 'Assign';
        item1.value = buildStringValue('Active');
        assign1.assignmentItems.add(item1);

        FlowMetadata.FlowAssignment assign2 = new FlowMetadata.FlowAssignment();
        assign2.label = 'Set Status';
        assign2.assignmentItems = new List<FlowMetadata.FlowAssignmentItem>();
        FlowMetadata.FlowAssignmentItem item2 = new FlowMetadata.FlowAssignmentItem();
        item2.assignToReference = 'var_Status';
        item2.operator = 'Assign';
        item2.value = buildStringValue('Active');
        assign2.assignmentItems.add(item2);

        String sig1 = FlowLogicSignature.forAssignment(assign1);
        String sig2 = FlowLogicSignature.forAssignment(assign2);

        System.assertEquals(sig1, sig2, 'Same assignment items should produce same signature');
    }

    // =========================================================================
    // TEST: forWait - Same events = same sig
    // =========================================================================

    @IsTest
    static void testWait_SameEventsProduceSameSignature() {
        FlowMetadata.FlowWait wait1 = new FlowMetadata.FlowWait();
        wait1.label = 'Wait for Approval';
        wait1.defaultConnectorLabel = 'Continue';
        wait1.waitEvents = new List<FlowMetadata.FlowWaitEvent>();
        FlowMetadata.FlowWaitEvent event1 = new FlowMetadata.FlowWaitEvent();
        event1.name = 'Approved';
        event1.label = 'Approved';
        event1.eventType = 'alm:FlowRecordTriggeredEvent';
        event1.conditionLogic = 'and';
        event1.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond1 = new FlowMetadata.FlowCondition();
        cond1.leftValueReference = 'record.ApprovalStatus';
        cond1.operator = 'EqualTo';
        cond1.rightValue = buildStringValue('Approved');
        event1.conditions.add(cond1);
        wait1.waitEvents.add(event1);

        FlowMetadata.FlowWait wait2 = new FlowMetadata.FlowWait();
        wait2.label = 'Wait for Approval';
        wait2.defaultConnectorLabel = 'Continue';
        wait2.waitEvents = new List<FlowMetadata.FlowWaitEvent>();
        FlowMetadata.FlowWaitEvent event2 = new FlowMetadata.FlowWaitEvent();
        event2.name = 'Approved';
        event2.label = 'Approved';
        event2.eventType = 'alm:FlowRecordTriggeredEvent';
        event2.conditionLogic = 'and';
        event2.conditions = new List<FlowMetadata.FlowCondition>();
        FlowMetadata.FlowCondition cond2 = new FlowMetadata.FlowCondition();
        cond2.leftValueReference = 'record.ApprovalStatus';
        cond2.operator = 'EqualTo';
        cond2.rightValue = buildStringValue('Approved');
        event2.conditions.add(cond2);
        wait2.waitEvents.add(event2);

        String sig1 = FlowLogicSignature.forWait(wait1);
        String sig2 = FlowLogicSignature.forWait(wait2);

        System.assertEquals(sig1, sig2, 'Same wait events should produce same signature');
    }

    // =========================================================================
    // TEST: forConstant - Basic test
    // =========================================================================

    @IsTest
    static void testConstant_BasicTest() {
        FlowMetadata.FlowConstant const1 = new FlowMetadata.FlowConstant();
        const1.name = 'const_MaxRetries';
        const1.dataType = 'Number';
        const1.value = buildNumberValue(5);

        String sig1 = FlowLogicSignature.forConstant(const1);

        System.assertNotEquals('', sig1, 'Constant signature should not be empty');
        System.assertNotEquals(null, sig1, 'Constant signature should not be null');
    }

    // =========================================================================
    // TEST: forTextTemplate - Basic test
    // =========================================================================

    @IsTest
    static void testTextTemplate_BasicTest() {
        FlowMetadata.FlowTextTemplate tt1 = new FlowMetadata.FlowTextTemplate();
        tt1.name = 'template_Message';
        tt1.text = 'Hello {!var_Name}';
        tt1.isViewedAsPlainText = true;

        String sig1 = FlowLogicSignature.forTextTemplate(tt1);

        System.assertNotEquals('', sig1, 'TextTemplate signature should not be empty');
    }

    // =========================================================================
    // TEST: forChoice - Basic test
    // =========================================================================

    @IsTest
    static void testChoice_BasicTest() {
        FlowMetadata.FlowChoice choice1 = new FlowMetadata.FlowChoice();
        choice1.name = 'choice_Active';
        choice1.choiceText = 'Active';
        choice1.dataType = 'String';
        choice1.value = buildStringValue('Active');

        String sig1 = FlowLogicSignature.forChoice(choice1);

        System.assertNotEquals('', sig1, 'Choice signature should not be empty');
    }

    // =========================================================================
    // TEST: forElement - Base element test
    // =========================================================================

    @IsTest
    static void testElement_BasicTest() {
        FlowMetadata.FlowElement el = new FlowMetadata.FlowElement();
        el.name = 'My_Element';
        el.label = 'My Element';
        el.description = 'This is a test element';
        el.locationX = '100';
        el.locationY = '200';

        String sig = FlowLogicSignature.forElement(el);

        System.assertNotEquals('', sig, 'Element signature should not be empty');
        System.assert(sig.contains('My Element'), 'Signature should include label');
        System.assert(sig.contains('This is a test element'), 'Signature should include description');
    }

    // =========================================================================
    // TEST: Null handling - All methods handle null gracefully
    // =========================================================================

    @IsTest
    static void testNullHandling_AllMethods() {
        System.assertEquals('', FlowLogicSignature.forElement(null), 'forElement(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forDecision(null), 'forDecision(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forRecordLookup(null), 'forRecordLookup(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forRecordCreate(null), 'forRecordCreate(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forRecordUpdate(null), 'forRecordUpdate(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forRecordDelete(null), 'forRecordDelete(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forLoop(null), 'forLoop(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forScreen(null), 'forScreen(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forSubflow(null), 'forSubflow(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forWait(null), 'forWait(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forStart(null), 'forStart(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forActionCall(null), 'forActionCall(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forAssignment(null), 'forAssignment(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forVariable(null), 'forVariable(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forFormula(null), 'forFormula(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forConstant(null), 'forConstant(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forTextTemplate(null), 'forTextTemplate(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forChoice(null), 'forChoice(null) should return empty string');
        System.assertEquals('', FlowLogicSignature.forConfiguration(null), 'forConfiguration(null) should return empty string');
    }

    // =========================================================================
    // TEST: forConfiguration - Flow-level signature test
    // =========================================================================

    @IsTest
    static void testConfiguration_BasicTest() {
        FlowMetadata.FlowDefinition flow1 = new FlowMetadata.FlowDefinition();
        flow1.processType = 'AutoLaunchedFlow';
        flow1.apiVersion = '62.0';
        flow1.triggerType = 'None';
        flow1.runInMode = 'SystemModeWithSharing';
        flow1.description = 'Test flow';
        flow1.label = 'Test Flow';

        String sig1 = FlowLogicSignature.forConfiguration(flow1);

        System.assertNotEquals('', sig1, 'Configuration signature should not be empty');
        System.assert(sig1.contains('AutoLaunchedFlow'), 'Signature should include processType');
        System.assert(sig1.contains('62.0'), 'Signature should include apiVersion');
    }

    // =========================================================================
    // TEST: forRecordUpdate - Basic test to ensure it exists
    // =========================================================================

    @IsTest
    static void testRecordUpdate_BasicTest() {
        FlowMetadata.FlowRecordUpdate ru1 = new FlowMetadata.FlowRecordUpdate();
        ru1.label = 'Update Account';
        ru1.object_x = 'Account';
        ru1.inputAssignments = new List<FlowMetadata.FlowInputAssignment>();
        FlowMetadata.FlowInputAssignment assign = new FlowMetadata.FlowInputAssignment();
        assign.field = 'Status';
        assign.value = buildStringValue('Updated');
        ru1.inputAssignments.add(assign);
        ru1.filters = new List<FlowMetadata.FlowRecordFilter>();

        String sig1 = FlowLogicSignature.forRecordUpdate(ru1);

        System.assertNotEquals('', sig1, 'RecordUpdate signature should not be empty');
    }

    // =========================================================================
    // TEST: forRecordDelete - Basic test to ensure it exists
    // =========================================================================

    @IsTest
    static void testRecordDelete_BasicTest() {
        FlowMetadata.FlowRecordDelete rd1 = new FlowMetadata.FlowRecordDelete();
        rd1.label = 'Delete Account';
        rd1.object_x = 'Account';
        rd1.filters = new List<FlowMetadata.FlowRecordFilter>();
        FlowMetadata.FlowRecordFilter filter = new FlowMetadata.FlowRecordFilter();
        filter.field = 'Status';
        filter.operator = 'EqualTo';
        filter.value = buildStringValue('Inactive');
        rd1.filters.add(filter);

        String sig1 = FlowLogicSignature.forRecordDelete(rd1);

        System.assertNotEquals('', sig1, 'RecordDelete signature should not be empty');
    }

    // =========================================================================
    // TEST: Integration - Multiple elements with the same signature
    // =========================================================================

    @IsTest
    static void testIntegration_MultipleElementsSignature() {
        // Create a minimal flow definition
        FlowMetadata.FlowDefinition flow = new FlowMetadata.FlowDefinition();
        flow.label = 'Test Flow';
        flow.description = 'Test';
        flow.processType = 'AutoLaunchedFlow';
        flow.apiVersion = '62.0';

        // Create two identical decisions
        FlowMetadata.FlowDecision d1 = new FlowMetadata.FlowDecision();
        d1.name = 'Decision_1';
        d1.label = 'Check Status';
        d1.rules = new List<FlowMetadata.FlowRule>();

        FlowMetadata.FlowDecision d2 = new FlowMetadata.FlowDecision();
        d2.name = 'Decision_2';
        d2.label = 'Check Status';
        d2.rules = new List<FlowMetadata.FlowRule>();

        String sig1 = FlowLogicSignature.forDecision(d1);
        String sig2 = FlowLogicSignature.forDecision(d2);

        System.assertEquals(sig1, sig2, 'Two decisions with identical logic should have same signature');
    }

    // =========================================================================
    // TEST: Screen fields order preservation
    // =========================================================================

    @IsTest
    static void testScreen_FieldOrderPreserved() {
        FlowMetadata.FlowScreen screen = new FlowMetadata.FlowScreen();
        screen.label = 'Multi-Field Screen';
        screen.fields = new List<FlowMetadata.FlowScreenField>();

        FlowMetadata.FlowScreenField field1 = new FlowMetadata.FlowScreenField();
        field1.name = 'field1';
        field1.fieldType = 'DisplayText';
        field1.fieldText = 'First';
        screen.fields.add(field1);

        FlowMetadata.FlowScreenField field2 = new FlowMetadata.FlowScreenField();
        field2.name = 'field2';
        field2.fieldType = 'DisplayText';
        field2.fieldText = 'Second';
        screen.fields.add(field2);

        String sig = FlowLogicSignature.forScreen(screen);

        System.assertNotEquals('', sig, 'Screen with multiple fields should produce signature');
        // Screen fields are order-dependent (layout matters)
        System.assert(sig.contains('field1'), 'Signature should include first field');
        System.assert(sig.contains('field2'), 'Signature should include second field');
    }

    // =========================================================================
    // TEST: Decision rules order-independence
    // =========================================================================

    @IsTest
    static void testDecision_RulesOrderIndependent() {
        FlowMetadata.FlowDecision d1 = new FlowMetadata.FlowDecision();
        d1.label = 'Multi-Rule Decision';
        d1.rules = new List<FlowMetadata.FlowRule>();

        FlowMetadata.FlowRule r1 = new FlowMetadata.FlowRule();
        r1.name = 'RuleA';
        r1.label = 'Rule A';
        r1.conditions = new List<FlowMetadata.FlowCondition>();
        d1.rules.add(r1);

        FlowMetadata.FlowRule r2 = new FlowMetadata.FlowRule();
        r2.name = 'RuleB';
        r2.label = 'Rule B';
        r2.conditions = new List<FlowMetadata.FlowCondition>();
        d1.rules.add(r2);

        FlowMetadata.FlowDecision d2 = new FlowMetadata.FlowDecision();
        d2.label = 'Multi-Rule Decision';
        d2.rules = new List<FlowMetadata.FlowRule>();

        FlowMetadata.FlowRule r3 = new FlowMetadata.FlowRule();
        r3.name = 'RuleB';
        r3.label = 'Rule B';
        r3.conditions = new List<FlowMetadata.FlowCondition>();
        d2.rules.add(r3);

        FlowMetadata.FlowRule r4 = new FlowMetadata.FlowRule();
        r4.name = 'RuleA';
        r4.label = 'Rule A';
        r4.conditions = new List<FlowMetadata.FlowCondition>();
        d2.rules.add(r4);

        String sig1 = FlowLogicSignature.forDecision(d1);
        String sig2 = FlowLogicSignature.forDecision(d2);

        System.assertEquals(sig1, sig2, 'Decision rules are sorted, so order should not matter');
    }

    // =========================================================================
    // TEST: Complex nested screen fields
    // =========================================================================

    @IsTest
    static void testScreen_NestedFields() {
        FlowMetadata.FlowScreen screen = new FlowMetadata.FlowScreen();
        screen.label = 'Nested Field Screen';
        screen.fields = new List<FlowMetadata.FlowScreenField>();

        FlowMetadata.FlowScreenField parentField = new FlowMetadata.FlowScreenField();
        parentField.name = 'section1';
        parentField.fieldType = 'RegionContainer';
        parentField.fields = new List<FlowMetadata.FlowScreenField>();

        FlowMetadata.FlowScreenField childField = new FlowMetadata.FlowScreenField();
        childField.name = 'field1';
        childField.fieldType = 'InputField';
        childField.fieldText = 'Name';
        parentField.fields.add(childField);

        screen.fields.add(parentField);

        String sig = FlowLogicSignature.forScreen(screen);

        System.assertNotEquals('', sig, 'Nested screen fields should produce signature');
    }
}
