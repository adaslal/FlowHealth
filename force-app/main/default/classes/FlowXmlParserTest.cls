/**
 * FlowXmlParserTest - Unit tests for the Flow XML parser.
 *
 * APPROACH: We test the FlowXmlParser.parse() method by providing raw XML strings
 * and verifying that the parser correctly extracts and populates FlowMetadata objects.
 *
 * Each test case covers:
 * 1. Valid minimal flow XML
 * 2. Flow with record operations (creates, updates, lookups)
 * 3. Flow with variable definitions
 * 4. Empty/minimal XML with just label and processType
 * 5. Null/blank input handling
 * 6. Start element with trigger configuration
 */
@IsTest
private class FlowXmlParserTest {

    // =========================================================================
    // TEST 1: Valid Minimal Flow XML
    // =========================================================================

    @IsTest
    static void testParseValidMinimalFlow() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Test Flow</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <status>Active</status>' +
            '  <description>A minimal test flow</description>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals('Test Flow', flow.label, 'Label should be parsed correctly');
        System.assertEquals('AutoLaunchedFlow', flow.processType, 'ProcessType should be parsed');
        System.assertEquals('Active', flow.status, 'Status should be parsed');
        System.assertEquals('A minimal test flow', flow.description, 'Description should be parsed');
        System.assertEquals('62.0', flow.apiVersion, 'API version should be parsed');
    }

    // =========================================================================
    // TEST 2: Flow with Decision
    // =========================================================================

    @IsTest
    static void testParseFlowWithDecision() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Decision</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <decisions>' +
            '    <name>Check_Status</name>' +
            '    <label>Check Status</label>' +
            '    <description>Checks account status</description>' +
            '    <locationX>100</locationX>' +
            '    <locationY>200</locationY>' +
            '    <defaultConnector>' +
            '      <targetReference>End</targetReference>' +
            '    </defaultConnector>' +
            '    <defaultConnectorLabel>Default</defaultConnectorLabel>' +
            '  </decisions>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.decisions.size(), 'Flow should have 1 decision');
        System.assertEquals('Check_Status', flow.decisions[0].name, 'Decision name should match');
        System.assertEquals('Check Status', flow.decisions[0].label, 'Decision label should match');
        System.assertEquals('Checks account status', flow.decisions[0].description, 'Description should match');
        System.assertEquals('100', flow.decisions[0].locationX, 'LocationX should be parsed');
        System.assertEquals('200', flow.decisions[0].locationY, 'LocationY should be parsed');
        System.assertNotEquals(null, flow.decisions[0].defaultConnector, 'Default connector should exist');
        System.assertEquals('End', flow.decisions[0].defaultConnector.targetReference, 'Target reference should match');
        System.assertEquals('Default', flow.decisions[0].defaultConnectorLabel, 'Default connector label should match');
    }

    // =========================================================================
    // TEST 3: Flow with Assignment
    // =========================================================================

    @IsTest
    static void testParseFlowWithAssignment() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Assignment</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <assignments>' +
            '    <name>Set_Values</name>' +
            '    <label>Set Values</label>' +
            '    <assignmentItems>' +
            '      <assignToReference>var_Status</assignToReference>' +
            '      <operator>Assign</operator>' +
            '      <value>' +
            '        <stringValue>Active</stringValue>' +
            '      </value>' +
            '    </assignmentItems>' +
            '    <connector>' +
            '      <targetReference>Next_Step</targetReference>' +
            '    </connector>' +
            '  </assignments>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.assignments.size(), 'Flow should have 1 assignment');
        System.assertEquals('Set_Values', flow.assignments[0].name, 'Assignment name should match');
        System.assertEquals('Set Values', flow.assignments[0].label, 'Assignment label should match');
        System.assertEquals(1, flow.assignments[0].assignmentItems.size(), 'Should have 1 assignment item');
        System.assertEquals('var_Status', flow.assignments[0].assignmentItems[0].assignToReference, 'AssignToReference should match');
        System.assertEquals('Assign', flow.assignments[0].assignmentItems[0].operator, 'Operator should match');
        System.assertEquals('Active', flow.assignments[0].assignmentItems[0].value.stringValue, 'String value should match');
    }

    // =========================================================================
    // TEST 4: Flow with Record Operations (Create, Update, Lookup)
    // =========================================================================

    @IsTest
    static void testParseFlowWithRecordCreate() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Create</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <recordCreates>' +
            '    <name>Create_Case</name>' +
            '    <label>Create Case</label>' +
            '    <object>Case</object>' +
            '    <inputAssignments>' +
            '      <field>Subject</field>' +
            '      <value>' +
            '        <stringValue>New Case</stringValue>' +
            '      </value>' +
            '    </inputAssignments>' +
            '    <connector>' +
            '      <targetReference>Done</targetReference>' +
            '    </connector>' +
            '  </recordCreates>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.recordCreates.size(), 'Flow should have 1 record create');
        System.assertEquals('Create_Case', flow.recordCreates[0].name, 'Record create name should match');
        System.assertEquals('Create Case', flow.recordCreates[0].label, 'Record create label should match');
        System.assertEquals('Case', flow.recordCreates[0].object_x, 'Object should be Case');
        System.assertEquals(1, flow.recordCreates[0].inputAssignments.size(), 'Should have 1 input assignment');
        System.assertEquals('Subject', flow.recordCreates[0].inputAssignments[0].field, 'Field should be Subject');
    }

    @IsTest
    static void testParseFlowWithRecordUpdate() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Update</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <recordUpdates>' +
            '    <name>Update_Account</name>' +
            '    <label>Update Account</label>' +
            '    <object>Account</object>' +
            '    <inputReference>var_Account</inputReference>' +
            '    <inputAssignments>' +
            '      <field>Status__c</field>' +
            '      <value>' +
            '        <stringValue>Updated</stringValue>' +
            '      </value>' +
            '    </inputAssignments>' +
            '  </recordUpdates>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.recordUpdates.size(), 'Flow should have 1 record update');
        System.assertEquals('Update_Account', flow.recordUpdates[0].name, 'Record update name should match');
        System.assertEquals('Account', flow.recordUpdates[0].object_x, 'Object should be Account');
        System.assertEquals('var_Account', flow.recordUpdates[0].inputReference, 'Input reference should match');
    }

    @IsTest
    static void testParseFlowWithRecordLookup() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Lookup</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <recordLookups>' +
            '    <name>Get_Accounts</name>' +
            '    <label>Get Accounts</label>' +
            '    <object>Account</object>' +
            '    <outputReference>var_Accounts</outputReference>' +
            '    <getFirstRecordOnly>false</getFirstRecordOnly>' +
            '    <filters>' +
            '      <field>Status__c</field>' +
            '      <operator>EqualTo</operator>' +
            '      <value>' +
            '        <stringValue>Active</stringValue>' +
            '      </value>' +
            '    </filters>' +
            '  </recordLookups>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.recordLookups.size(), 'Flow should have 1 record lookup');
        System.assertEquals('Get_Accounts', flow.recordLookups[0].name, 'Record lookup name should match');
        System.assertEquals('Account', flow.recordLookups[0].object_x, 'Object should be Account');
        System.assertEquals('var_Accounts', flow.recordLookups[0].outputReference, 'Output reference should match');
        System.assertEquals(false, flow.recordLookups[0].getFirstRecordOnly, 'Should get multiple records');
        System.assertEquals(1, flow.recordLookups[0].filters.size(), 'Should have 1 filter');
        System.assertEquals('Status__c', flow.recordLookups[0].filters[0].field, 'Filter field should be Status__c');
        System.assertEquals('EqualTo', flow.recordLookups[0].filters[0].operator, 'Filter operator should match');
    }

    @IsTest
    static void testParseFlowWithRecordDelete() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Delete</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <recordDeletes>' +
            '    <name>Delete_Case</name>' +
            '    <label>Delete Case</label>' +
            '    <object>Case</object>' +
            '    <inputReference>var_CaseId</inputReference>' +
            '  </recordDeletes>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.recordDeletes.size(), 'Flow should have 1 record delete');
        System.assertEquals('Delete_Case', flow.recordDeletes[0].name, 'Record delete name should match');
        System.assertEquals('Case', flow.recordDeletes[0].object_x, 'Object should be Case');
        System.assertEquals('var_CaseId', flow.recordDeletes[0].inputReference, 'Input reference should match');
    }

    // =========================================================================
    // TEST 5: Flow with Variables
    // =========================================================================

    @IsTest
    static void testParseFlowWithVariables() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Variables</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <variables>' +
            '    <name>var_Status</name>' +
            '    <dataType>String</dataType>' +
            '    <description>Account status variable</description>' +
            '    <isCollection>false</isCollection>' +
            '    <isInput>false</isInput>' +
            '    <isOutput>true</isOutput>' +
            '  </variables>' +
            '  <variables>' +
            '    <name>var_Accounts</name>' +
            '    <dataType>SObject</dataType>' +
            '    <objectType>Account</objectType>' +
            '    <isCollection>true</isCollection>' +
            '  </variables>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(2, flow.variables.size(), 'Flow should have 2 variables');

        // First variable
        System.assertEquals('var_Status', flow.variables[0].name, 'First variable name should match');
        System.assertEquals('String', flow.variables[0].dataType, 'First variable dataType should match');
        System.assertEquals('Account status variable', flow.variables[0].description, 'Description should match');
        System.assertEquals(false, flow.variables[0].isCollection, 'Should not be a collection');
        System.assertEquals(true, flow.variables[0].isOutput, 'Should be output variable');

        // Second variable
        System.assertEquals('var_Accounts', flow.variables[1].name, 'Second variable name should match');
        System.assertEquals('SObject', flow.variables[1].dataType, 'Second variable dataType should match');
        System.assertEquals('Account', flow.variables[1].objectType, 'ObjectType should be Account');
        System.assertEquals(true, flow.variables[1].isCollection, 'Should be a collection');
    }

    // =========================================================================
    // TEST 6: Flow with Formulas, Constants, and Choices
    // =========================================================================

    @IsTest
    static void testParseFlowWithFormulas() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Formula</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <formulas>' +
            '    <name>formula_Total</name>' +
            '    <dataType>Number</dataType>' +
            '    <description>Calculate total amount</description>' +
            '    <expression>var_Price * var_Quantity</expression>' +
            '  </formulas>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.formulas.size(), 'Flow should have 1 formula');
        System.assertEquals('formula_Total', flow.formulas[0].name, 'Formula name should match');
        System.assertEquals('Number', flow.formulas[0].dataType, 'DataType should be Number');
        System.assertEquals('var_Price * var_Quantity', flow.formulas[0].expression, 'Expression should match');
    }

    @IsTest
    static void testParseFlowWithConstants() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Constant</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <constants>' +
            '    <name>const_MaxRecords</name>' +
            '    <dataType>Number</dataType>' +
            '    <description>Maximum records to process</description>' +
            '    <value>' +
            '      <numberValue>100</numberValue>' +
            '    </value>' +
            '  </constants>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.constants.size(), 'Flow should have 1 constant');
        System.assertEquals('const_MaxRecords', flow.constants[0].name, 'Constant name should match');
        System.assertEquals('Number', flow.constants[0].dataType, 'DataType should be Number');
        System.assertEquals(100, flow.constants[0].value.numberValue, 'Number value should be 100');
    }

    // =========================================================================
    // TEST 7: Flow with Start Element (Trigger Configuration)
    // =========================================================================

    @IsTest
    static void testParseFlowWithStartElement() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Record Triggered Flow</label>' +
            '  <processType>RecordTriggeredFlow</processType>' +
            '  <triggerType>RecordAfterSave</triggerType>' +
            '  <start>' +
            '    <locationX>50</locationX>' +
            '    <locationY>0</locationY>' +
            '    <triggerType>RecordAfterSave</triggerType>' +
            '    <object>Account</object>' +
            '    <recordTriggerType>Create</recordTriggerType>' +
            '    <filters>' +
            '      <field>BillingCountry</field>' +
            '      <operator>EqualTo</operator>' +
            '      <value>' +
            '        <stringValue>USA</stringValue>' +
            '      </value>' +
            '    </filters>' +
            '    <connector>' +
            '      <targetReference>Process_Account</targetReference>' +
            '    </connector>' +
            '  </start>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertNotEquals(null, flow.start, 'Start element should exist');
        System.assertEquals('50', flow.start.locationX, 'LocationX should match');
        System.assertEquals('0', flow.start.locationY, 'LocationY should match');
        System.assertEquals('RecordAfterSave', flow.start.triggerType, 'Start triggerType should match');
        System.assertEquals('Account', flow.start.object_x, 'Object should be Account');
        System.assertEquals('Create', flow.start.recordTriggerType, 'RecordTriggerType should be Create');
        System.assertEquals(1, flow.start.filters.size(), 'Should have 1 filter');
        System.assertEquals('BillingCountry', flow.start.filters[0].field, 'Filter field should match');
        System.assertNotEquals(null, flow.start.connector, 'Connector should exist');
        System.assertEquals('Process_Account', flow.start.connector.targetReference, 'Connector target should match');
    }

    // =========================================================================
    // TEST 8: Empty/Minimal Flow (Just label and processType)
    // =========================================================================

    @IsTest
    static void testParseEmptyFlow() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <label>Minimal Flow</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals('Minimal Flow', flow.label, 'Label should be parsed');
        System.assertEquals('AutoLaunchedFlow', flow.processType, 'ProcessType should be parsed');
        System.assertEquals(null, flow.description, 'Description should be null when not provided');
        System.assertEquals(null, flow.status, 'Status should be null when not provided');
        System.assertEquals(0, flow.decisions.size(), 'Decisions list should be empty');
        System.assertEquals(0, flow.assignments.size(), 'Assignments list should be empty');
        System.assertEquals(0, flow.recordCreates.size(), 'RecordCreates list should be empty');
    }

    // =========================================================================
    // TEST 9: Null Input
    // =========================================================================

    @IsTest
    static void testParseNullInput() {
        try {
            FlowXmlParser.parse(null);
            System.assert(false, 'Should throw exception for null input');
        } catch (FlowMetadataService.FlowHealthException e) {
            System.assert(e.getMessage().contains('blank'),
                'Exception message should mention blank: ' + e.getMessage());
        }
    }

    // =========================================================================
    // TEST 10: Blank Input
    // =========================================================================

    @IsTest
    static void testParseBlankInput() {
        try {
            FlowXmlParser.parse('   ');
            System.assert(false, 'Should throw exception for blank input');
        } catch (FlowMetadataService.FlowHealthException e) {
            System.assert(e.getMessage().contains('blank'),
                'Exception message should mention blank: ' + e.getMessage());
        }
    }

    @IsTest
    static void testParseEmptyString() {
        try {
            FlowXmlParser.parse('');
            System.assert(false, 'Should throw exception for empty string');
        } catch (FlowMetadataService.FlowHealthException e) {
            System.assert(e.getMessage().contains('blank'),
                'Exception message should mention blank: ' + e.getMessage());
        }
    }

    // =========================================================================
    // TEST 11: Invalid XML
    // =========================================================================

    @IsTest
    static void testParseInvalidXml() {
        String invalidXml = '<?xml version="1.0"?><Flow><label>Bad Flow';

        try {
            FlowXmlParser.parse(invalidXml);
            System.assert(false, 'Should throw exception for invalid XML');
        } catch (FlowMetadataService.FlowHealthException e) {
            System.assert(e.getMessage().contains('Failed') || e.getMessage().contains('parse'),
                'Exception should indicate parsing failure: ' + e.getMessage());
        }
    }

    // =========================================================================
    // TEST 12: Flow with Multiple Complex Elements
    // =========================================================================

    @IsTest
    static void testParseComplexFlow() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Complex Flow</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <description>A complex flow with multiple elements</description>' +
            '  <status>Active</status>' +
            '  <variables>' +
            '    <name>var_Counter</name>' +
            '    <dataType>Number</dataType>' +
            '  </variables>' +
            '  <recordLookups>' +
            '    <name>Get_Accounts</name>' +
            '    <label>Get Accounts</label>' +
            '    <object>Account</object>' +
            '    <outputReference>var_Accounts</outputReference>' +
            '    <getFirstRecordOnly>false</getFirstRecordOnly>' +
            '  </recordLookups>' +
            '  <decisions>' +
            '    <name>Decision_1</name>' +
            '    <label>Decision 1</label>' +
            '    <defaultConnector>' +
            '      <targetReference>Assignment_1</targetReference>' +
            '    </defaultConnector>' +
            '  </decisions>' +
            '  <assignments>' +
            '    <name>Assignment_1</name>' +
            '    <label>Assignment 1</label>' +
            '  </assignments>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals('Complex Flow', flow.label, 'Label should match');
        System.assertEquals(1, flow.variables.size(), 'Should have 1 variable');
        System.assertEquals(1, flow.recordLookups.size(), 'Should have 1 lookup');
        System.assertEquals(1, flow.decisions.size(), 'Should have 1 decision');
        System.assertEquals(1, flow.assignments.size(), 'Should have 1 assignment');
    }

    // =========================================================================
    // TEST 13: Flow with Loops
    // =========================================================================

    @IsTest
    static void testParseFlowWithLoop() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Loop</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <loops>' +
            '    <name>Loop_Accounts</name>' +
            '    <label>Loop Through Accounts</label>' +
            '    <collectionReference>var_Accounts</collectionReference>' +
            '    <iterationOrder>Asc</iterationOrder>' +
            '    <nextValueConnector>' +
            '      <targetReference>Process_Account</targetReference>' +
            '    </nextValueConnector>' +
            '    <noMoreValuesConnector>' +
            '      <targetReference>Complete</targetReference>' +
            '    </noMoreValuesConnector>' +
            '    <assignNextValueToReference>var_CurrentAccount</assignNextValueToReference>' +
            '  </loops>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.loops.size(), 'Flow should have 1 loop');
        System.assertEquals('Loop_Accounts', flow.loops[0].name, 'Loop name should match');
        System.assertEquals('var_Accounts', flow.loops[0].collectionReference, 'Collection reference should match');
        System.assertEquals('Asc', flow.loops[0].iterationOrder, 'Iteration order should be Asc');
        System.assertEquals('var_CurrentAccount', flow.loops[0].assignNextValueToReference, 'AssignNextValueToReference should match');
        System.assertNotEquals(null, flow.loops[0].nextValueConnector, 'NextValueConnector should exist');
        System.assertNotEquals(null, flow.loops[0].noMoreValuesConnector, 'NoMoreValuesConnector should exist');
    }

    // =========================================================================
    // TEST 14: Flow with Screens
    // =========================================================================

    @IsTest
    static void testParseFlowWithScreen() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Screen</label>' +
            '  <processType>Flow</processType>' +
            '  <screens>' +
            '    <name>Screen_1</name>' +
            '    <label>User Input Screen</label>' +
            '    <allowBack>true</allowBack>' +
            '    <allowFinish>true</allowFinish>' +
            '    <allowPause>false</allowPause>' +
            '    <showHeader>true</showHeader>' +
            '    <showFooter>true</showFooter>' +
            '  </screens>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.screens.size(), 'Flow should have 1 screen');
        System.assertEquals('Screen_1', flow.screens[0].name, 'Screen name should match');
        System.assertEquals(true, flow.screens[0].allowBack, 'AllowBack should be true');
        System.assertEquals(true, flow.screens[0].allowFinish, 'AllowFinish should be true');
        System.assertEquals(false, flow.screens[0].allowPause, 'AllowPause should be false');
    }

    // =========================================================================
    // TEST 15: Flow with Subflow Call
    // =========================================================================

    @IsTest
    static void testParseFlowWithSubflow() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Subflow</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <subflows>' +
            '    <name>Call_Validation_Subflow</name>' +
            '    <label>Call Validation Subflow</label>' +
            '    <flowName>Validate_Record</flowName>' +
            '    <inputAssignments>' +
            '      <name>var_RecordId</name>' +
            '      <value>' +
            '        <elementReference>var_Id</elementReference>' +
            '      </value>' +
            '    </inputAssignments>' +
            '  </subflows>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.subflows.size(), 'Flow should have 1 subflow');
        System.assertEquals('Call_Validation_Subflow', flow.subflows[0].name, 'Subflow name should match');
        System.assertEquals('Validate_Record', flow.subflows[0].flowName, 'FlowName should match');
        System.assertEquals(1, flow.subflows[0].inputAssignments.size(), 'Should have 1 input assignment');
    }

    // =========================================================================
    // TEST 16: Flow with Action Call
    // =========================================================================

    @IsTest
    static void testParseFlowWithActionCall() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Action</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <actionCalls>' +
            '    <name>Send_Email_Action</name>' +
            '    <label>Send Email</label>' +
            '    <actionName>emailAlert</actionName>' +
            '    <actionType>email</actionType>' +
            '    <storeOutputAutomatically>true</storeOutputAutomatically>' +
            '  </actionCalls>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.actionCalls.size(), 'Flow should have 1 action call');
        System.assertEquals('Send_Email_Action', flow.actionCalls[0].name, 'Action name should match');
        System.assertEquals('emailAlert', flow.actionCalls[0].actionName, 'ActionName should match');
        System.assertEquals('email', flow.actionCalls[0].actionType, 'ActionType should match');
        System.assertEquals(true, flow.actionCalls[0].storeOutputAutomatically, 'StoreOutputAutomatically should be true');
    }

    // =========================================================================
    // TEST 17: Flow with Wait Element
    // =========================================================================

    @IsTest
    static void testParseFlowWithWait() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Wait</label>' +
            '  <processType>RecordTriggeredFlow</processType>' +
            '  <waits>' +
            '    <name>Wait_For_Event</name>' +
            '    <label>Wait For Event</label>' +
            '    <defaultConnector>' +
            '      <targetReference>Done</targetReference>' +
            '    </defaultConnector>' +
            '  </waits>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.waits.size(), 'Flow should have 1 wait');
        System.assertEquals('Wait_For_Event', flow.waits[0].name, 'Wait name should match');
        System.assertNotEquals(null, flow.waits[0].defaultConnector, 'Default connector should exist');
    }

    // =========================================================================
    // TEST 18: All Element Collections Are Initialized
    // =========================================================================

    @IsTest
    static void testParseInitializesAllElementLists() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Test Flow</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertNotEquals(null, flow.decisions, 'Decisions list should be initialized');
        System.assertNotEquals(null, flow.assignments, 'Assignments list should be initialized');
        System.assertNotEquals(null, flow.recordCreates, 'RecordCreates list should be initialized');
        System.assertNotEquals(null, flow.recordUpdates, 'RecordUpdates list should be initialized');
        System.assertNotEquals(null, flow.recordDeletes, 'RecordDeletes list should be initialized');
        System.assertNotEquals(null, flow.recordLookups, 'RecordLookups list should be initialized');
        System.assertNotEquals(null, flow.loops, 'Loops list should be initialized');
        System.assertNotEquals(null, flow.screens, 'Screens list should be initialized');
        System.assertNotEquals(null, flow.subflows, 'Subflows list should be initialized');
        System.assertNotEquals(null, flow.actionCalls, 'ActionCalls list should be initialized');
        System.assertNotEquals(null, flow.waits, 'Waits list should be initialized');
        System.assertNotEquals(null, flow.variables, 'Variables list should be initialized');
        System.assertNotEquals(null, flow.formulas, 'Formulas list should be initialized');
        System.assertNotEquals(null, flow.constants, 'Constants list should be initialized');
        System.assertNotEquals(null, flow.choices, 'Choices list should be initialized');
    }

    // =========================================================================
    // TEST 19: Flow with Text Template
    // =========================================================================

    @IsTest
    static void testParseFlowWithTextTemplate() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Text Template</label>' +
            '  <processType>AutoLaunchedFlow</processType>' +
            '  <textTemplates>' +
            '    <name>template_Email</name>' +
            '    <description>Email template</description>' +
            '    <text>Hello {!var_Name}, your account has been {!var_Status}</text>' +
            '    <isViewedAsPlainText>true</isViewedAsPlainText>' +
            '  </textTemplates>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.textTemplates.size(), 'Flow should have 1 text template');
        System.assertEquals('template_Email', flow.textTemplates[0].name, 'Template name should match');
        System.assertEquals('Email template', flow.textTemplates[0].description, 'Template description should match');
        System.assert(flow.textTemplates[0].text.contains('var_Name'), 'Template text should contain variable reference');
        System.assertEquals(true, flow.textTemplates[0].isViewedAsPlainText, 'IsViewedAsPlainText should be true');
    }

    // =========================================================================
    // TEST 20: Flow with Choices
    // =========================================================================

    @IsTest
    static void testParseFlowWithChoices() {
        String xml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
            '  <apiVersion>62.0</apiVersion>' +
            '  <label>Flow With Choices</label>' +
            '  <processType>Flow</processType>' +
            '  <choices>' +
            '    <name>choice_Yes</name>' +
            '    <choiceText>Yes</choiceText>' +
            '    <dataType>String</dataType>' +
            '    <value>' +
            '      <stringValue>true</stringValue>' +
            '    </value>' +
            '  </choices>' +
            '</Flow>';

        FlowMetadata.FlowDefinition flow = FlowXmlParser.parse(xml);

        System.assertNotEquals(null, flow, 'Parsed flow should not be null');
        System.assertEquals(1, flow.choices.size(), 'Flow should have 1 choice');
        System.assertEquals('choice_Yes', flow.choices[0].name, 'Choice name should match');
        System.assertEquals('Yes', flow.choices[0].choiceText, 'Choice text should match');
        System.assertEquals('String', flow.choices[0].dataType, 'DataType should match');
    }
}
