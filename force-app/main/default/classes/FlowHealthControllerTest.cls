/**
 * FlowHealthControllerTest - Unit tests for FlowHealthController and FlowMetadataService.
 *
 * TESTING STRATEGY:
 * Since FlowMetadataService makes HTTP callouts to the Tooling API, we use
 * HttpCalloutMock to simulate the API response. This lets us:
 * 1. Test without a real Salesforce org connection
 * 2. Control exactly what data comes back (including edge cases)
 * 3. Test error handling with various HTTP status codes
 *
 * The mock response JSON below is a realistic example of what the Tooling API
 * returns. It includes common flow elements: decisions, loops, record operations,
 * and actions — enough to exercise our deserialization and counting logic.
 */
@IsTest
private class FlowHealthControllerTest {

    // =========================================================================
    // MOCK: Successful Tooling API response
    // =========================================================================

    /**
     * Simulates a successful Tooling API response with a realistic flow.
     * This flow has:
     * - 1 decision (with 1 rule)
     * - 1 loop
     * - 1 recordLookup (SOQL)
     * - 1 recordCreate (DML)
     * - 1 recordUpdate (DML)
     * - 1 actionCall
     * - 2 assignments
     * - 2 variables
     * - 1 formula
     */
    private class MockToolingSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getSuccessResponseBody());
            return res;
        }
    }

    /**
     * Simulates a Tooling API response for the flow list (no Metadata field).
     */
    private class MockToolingFlowList implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            // Check if this is a flow list query (no Metadata field) or detail query
            String endpoint = req.getEndpoint();
            if (endpoint.contains('MasterLabel') && !endpoint.contains('Metadata')) {
                res.setBody(getFlowListResponseBody());
            } else {
                res.setBody(getSuccessResponseBody());
            }
            return res;
        }
    }

    /**
     * Simulates a Tooling API error (e.g., auth failure).
     */
    private class MockToolingError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"message": "Session expired or invalid", "errorCode": "INVALID_SESSION_ID"}');
            return res;
        }
    }

    /**
     * Simulates a successful response with no records (flow not found).
     */
    private class MockToolingEmpty implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"size": 0, "records": []}');
            return res;
        }
    }

    // =========================================================================
    // TESTS: getFlowDetail()
    // =========================================================================

    @IsTest
    static void testGetFlowDetail_Success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingSuccess());

        Test.startTest();
        FlowHealthController.FlowDetailResult result =
            FlowHealthController.getFlowDetail('Update_Account_Status');
        Test.stopTest();

        // Verify flow properties
        System.assertEquals('Update_Account_Status', result.developerName, 'Developer name should match');
        System.assertEquals('Update Account Status', result.label, 'Label should match');
        System.assertEquals('RecordTriggeredFlow', result.processType, 'Process type should match');
        System.assertEquals('RecordAfterSave', result.triggerType, 'Trigger type should match');
        System.assertNotEquals(null, result.description, 'Description should not be null');

        // Verify element counts
        System.assertEquals(1, result.elementCounts.get('decisions'), 'Should have 1 decision');
        System.assertEquals(1, result.elementCounts.get('loops'), 'Should have 1 loop');
        System.assertEquals(1, result.elementCounts.get('recordCreates'), 'Should have 1 record create');
        System.assertEquals(1, result.elementCounts.get('recordUpdates'), 'Should have 1 record update');
        System.assertEquals(1, result.elementCounts.get('recordLookups'), 'Should have 1 record lookup');
        System.assertEquals(1, result.elementCounts.get('actionCalls'), 'Should have 1 action call');
        System.assertEquals(2, result.elementCounts.get('assignments'), 'Should have 2 assignments');

        // Verify total
        System.assert(result.totalElements > 0, 'Total elements should be greater than 0');
    }

    @IsTest
    static void testGetFlowDetail_FlowNotFound() {
        Test.setMock(HttpCalloutMock.class, new MockToolingEmpty());

        Test.startTest();
        try {
            FlowHealthController.getFlowDetail('Nonexistent_Flow');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('No active flow found') ||
                e.getMessage().contains('Nonexistent_Flow'),
                'Error should mention the missing flow. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetFlowDetail_ApiError() {
        Test.setMock(HttpCalloutMock.class, new MockToolingError());

        Test.startTest();
        try {
            FlowHealthController.getFlowDetail('Any_Flow');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('401') || e.getMessage().contains('error') || e.getMessage().length() > 0,
                'Should contain error info. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetFlowDetail_BlankName() {
        Test.setMock(HttpCalloutMock.class, new MockToolingSuccess());

        Test.startTest();
        try {
            FlowHealthController.getFlowDetail('');
            System.assert(false, 'Should have thrown an exception for blank name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().length() > 0, 'Should have an error message');
        }
        Test.stopTest();
    }

    // =========================================================================
    // TESTS: getFlowList()
    // =========================================================================

    @IsTest
    static void testGetFlowList_Success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingFlowList());

        Test.startTest();
        List<FlowMetadataService.FlowInfo> flows = FlowHealthController.getFlowList();
        Test.stopTest();

        System.assertNotEquals(null, flows, 'Flow list should not be null');
        System.assert(flows.size() > 0, 'Should have at least one flow');
        System.assertNotEquals(null, flows[0].masterLabel, 'First flow should have a label');
        System.assertNotEquals(null, flows[0].developerName, 'First flow should have a developer name');
    }

    @IsTest
    static void testGetFlowList_ApiError() {
        Test.setMock(HttpCalloutMock.class, new MockToolingError());

        Test.startTest();
        try {
            FlowHealthController.getFlowList();
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().length() > 0, 'Should have an error message');
        }
        Test.stopTest();
    }

    // =========================================================================
    // TESTS: FlowMetadata wrapper deserialization
    // =========================================================================

    @IsTest
    static void testFlowMetadata_Deserialization() {
        // Test that our wrapper classes correctly deserialize the Tooling API JSON
        String responseBody = getSuccessResponseBody();
        // Handle the "object" reserved word
        responseBody = responseBody.replace('"object":', '"object_x":');

        Test.startTest();
        FlowMetadata.ToolingQueryResult result =
            (FlowMetadata.ToolingQueryResult) JSON.deserialize(responseBody, FlowMetadata.ToolingQueryResult.class);
        Test.stopTest();

        // Verify top-level
        System.assertEquals(1, result.size, 'Should have 1 record');
        System.assertNotEquals(null, result.records, 'Records should not be null');

        // Verify flow definition
        FlowMetadata.FlowDefinition flow = result.records[0].Metadata;
        System.assertNotEquals(null, flow, 'Flow definition should not be null');
        System.assertEquals('Update Account Status', flow.label, 'Flow label should match');

        // Verify helper methods
        List<FlowMetadata.FlowElement> allElements = flow.getAllElements();
        System.assert(allElements.size() > 0, 'Should have elements');

        List<FlowMetadata.FlowElement> dmlElements = flow.getDmlElements();
        System.assert(dmlElements.size() > 0, 'Should have DML elements');

        Map<String, FlowMetadata.FlowElement> elementMap = flow.getElementMap();
        System.assert(elementMap.size() > 0, 'Element map should not be empty');
    }

    @IsTest
    static void testFlowMetadata_EmptyLists() {
        // Test that helper methods handle null lists gracefully
        FlowMetadata.FlowDefinition emptyFlow = new FlowMetadata.FlowDefinition();

        Test.startTest();
        List<FlowMetadata.FlowElement> allElements = emptyFlow.getAllElements();
        List<FlowMetadata.FlowElement> dmlElements = emptyFlow.getDmlElements();
        List<FlowMetadata.FlowRecordLookup> soqlElements = emptyFlow.getSoqlElements();
        Map<String, FlowMetadata.FlowElement> elementMap = emptyFlow.getElementMap();
        Test.stopTest();

        System.assertEquals(0, allElements.size(), 'Empty flow should have 0 elements');
        System.assertEquals(0, dmlElements.size(), 'Empty flow should have 0 DML elements');
        System.assertEquals(0, soqlElements.size(), 'Empty flow should have 0 SOQL elements');
        System.assertEquals(0, elementMap.size(), 'Empty flow should have empty element map');
    }

    // =========================================================================
    // TESTS: getFlowMetadataJson (Logic Audit — load from org)
    // =========================================================================

    @IsTest
    static void testGetFlowMetadataJson_Success() {
        Test.setMock(HttpCalloutMock.class, new MockToolingSuccess());

        Test.startTest();
        String json = FlowHealthController.getFlowMetadataJson('Update_Account_Status');
        Test.stopTest();

        System.assert(String.isNotBlank(json), 'Should return raw metadata JSON');
        System.assert(json.contains('"label"'), 'JSON should contain the flow label field');
    }

    @IsTest
    static void testGetFlowMetadataJson_BlankName() {
        Test.startTest();
        try {
            FlowHealthController.getFlowMetadataJson('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('blank'),
                'Error should mention blank: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // =========================================================================
    // TEST DATA: Realistic Tooling API JSON responses
    // =========================================================================

    /**
     * Returns a realistic Tooling API response for a record-triggered flow.
     * This is what the Tooling API actually returns — study this structure
     * to understand how flows are represented as JSON.
     */
    private static String getSuccessResponseBody() {
        return '{'
            + '"size": 1,'
            + '"totalSize": 1,'
            + '"done": true,'
            + '"records": [{'
            + '  "Id": "301xx000000001AAA",'
            + '  "FullName": "Update_Account_Status-1",'
            + '  "MasterLabel": "Update Account Status",'
            + '  "Status": "Active",'
            + '  "Metadata": {'
            + '    "label": "Update Account Status",'
            + '    "description": "Updates account status based on opportunity stage changes",'
            + '    "processType": "RecordTriggeredFlow",'
            + '    "apiVersion": "62.0",'
            + '    "status": "Active",'
            + '    "triggerType": "RecordAfterSave",'
            + '    "runInMode": "SystemModeWithSharing",'
            + '    "start": {'
            + '      "locationX": "50",'
            + '      "locationY": "0",'
            + '      "connector": {"targetReference": "Get_Related_Opps"},'
            + '      "object": "Account",'
            + '      "triggerType": "RecordAfterSave",'
            + '      "recordTriggerType": "Update"'
            + '    },'
            + '    "decisions": [{'
            + '      "name": "Check_Opp_Count",'
            + '      "label": "Check Opportunity Count",'
            + '      "description": "Determines if account has enough closed opportunities",'
            + '      "locationX": "300",'
            + '      "locationY": "200",'
            + '      "defaultConnector": {"targetReference": "Assign_Inactive"},'
            + '      "defaultConnectorLabel": "No Closed Opps",'
            + '      "rules": [{'
            + '        "name": "Has_Closed_Opps",'
            + '        "label": "Has Closed Opportunities",'
            + '        "conditionLogic": "and",'
            + '        "conditions": [{'
            + '          "leftValueReference": "varOppCount",'
            + '          "operator": "GreaterThan",'
            + '          "rightValue": {"numberValue": 0}'
            + '        }],'
            + '        "connector": {"targetReference": "Assign_Active"}'
            + '      }]'
            + '    }],'
            + '    "loops": [{'
            + '      "name": "Loop_Opps",'
            + '      "label": "Loop Through Opportunities",'
            + '      "description": "Iterates through related opportunities",'
            + '      "locationX": "500",'
            + '      "locationY": "200",'
            + '      "collectionReference": "varOppCollection",'
            + '      "iterationOrder": "Asc",'
            + '      "nextValueConnector": {"targetReference": "Assign_Opp_Values"},'
            + '      "noMoreValuesConnector": {"targetReference": "Update_Account"}'
            + '    }],'
            + '    "recordLookups": [{'
            + '      "name": "Get_Related_Opps",'
            + '      "label": "Get Related Opportunities",'
            + '      "description": "Fetches all related opportunities for the account",'
            + '      "locationX": "150",'
            + '      "locationY": "200",'
            + '      "object": "Opportunity",'
            + '      "filters": [{'
            + '        "field": "AccountId",'
            + '        "operator": "EqualTo",'
            + '        "value": {"elementReference": "$Record.Id"}'
            + '      }],'
            + '      "getFirstRecordOnly": false,'
            + '      "storeOutputAutomatically": true,'
            + '      "connector": {"targetReference": "Check_Opp_Count"}'
            + '    }],'
            + '    "recordCreates": [{'
            + '      "name": "Create_Task",'
            + '      "label": "Create Follow-Up Task",'
            + '      "description": "Creates a task for the account owner",'
            + '      "locationX": "700",'
            + '      "locationY": "300",'
            + '      "object": "Task",'
            + '      "inputAssignments": [{'
            + '        "field": "Subject",'
            + '        "value": {"stringValue": "Follow up on account status change"}'
            + '      }],'
            + '      "connector": {"targetReference": "Loop_Opps"},'
            + '      "faultConnector": null'
            + '    }],'
            + '    "recordUpdates": [{'
            + '      "name": "Update_Account",'
            + '      "label": "Update Account Status",'
            + '      "locationX": "700",'
            + '      "locationY": "100",'
            + '      "inputReference": "$Record",'
            + '      "inputAssignments": [{'
            + '        "field": "Status__c",'
            + '        "value": {"elementReference": "varNewStatus"}'
            + '      }],'
            + '      "connector": null,'
            + '      "faultConnector": null'
            + '    }],'
            + '    "actionCalls": [{'
            + '      "name": "Send_Notification",'
            + '      "label": "Send Email Notification",'
            + '      "description": "Notifies the account owner of the status change",'
            + '      "locationX": "900",'
            + '      "locationY": "200",'
            + '      "actionName": "emailSimple",'
            + '      "actionType": "emailSimple",'
            + '      "inputParameters": [{'
            + '        "name": "emailBody",'
            + '        "value": {"stringValue": "Account status has been updated"}'
            + '      }],'
            + '      "connector": null'
            + '    }],'
            + '    "assignments": [{'
            + '      "name": "Assign_Active",'
            + '      "label": "Set Status to Active",'
            + '      "locationX": "400",'
            + '      "locationY": "100",'
            + '      "assignmentItems": [{'
            + '        "assignToReference": "varNewStatus",'
            + '        "operator": "Assign",'
            + '        "value": {"stringValue": "Active"}'
            + '      }],'
            + '      "connector": {"targetReference": "Update_Account"}'
            + '    },{'
            + '      "name": "Assign_Inactive",'
            + '      "label": "Set Status to Inactive",'
            + '      "locationX": "400",'
            + '      "locationY": "300",'
            + '      "assignmentItems": [{'
            + '        "assignToReference": "varNewStatus",'
            + '        "operator": "Assign",'
            + '        "value": {"stringValue": "Inactive"}'
            + '      }],'
            + '      "connector": {"targetReference": "Update_Account"}'
            + '    }],'
            + '    "variables": [{'
            + '      "name": "varNewStatus",'
            + '      "description": "Holds the calculated new status value",'
            + '      "dataType": "String",'
            + '      "isCollection": false,'
            + '      "isInput": false,'
            + '      "isOutput": false'
            + '    },{'
            + '      "name": "varOppCount",'
            + '      "description": "Count of related closed opportunities",'
            + '      "dataType": "Number",'
            + '      "isCollection": false,'
            + '      "isInput": false,'
            + '      "isOutput": false'
            + '    }],'
            + '    "formulas": [{'
            + '      "name": "frmOppCount",'
            + '      "description": "Counts closed opportunities",'
            + '      "dataType": "Number",'
            + '      "expression": "IF(ISBLANK({!varOppCollection}), 0, {!varOppCollection}.size)"'
            + '    }]'
            + '  }'
            + '}]'
            + '}';
    }

    /**
     * Returns a Tooling API response for the flow list query.
     */
    private static String getFlowListResponseBody() {
        return '{'
            + '"size": 2,'
            + '"totalSize": 2,'
            + '"done": true,'
            + '"records": [{'
            + '  "Id": "301xx000000001AAA",'
            + '  "MasterLabel": "Update Account Status",'
            + '  "Status": "Active",'
            + '  "ProcessType": "RecordTriggeredFlow",'
            + '  "Definition": {"DeveloperName": "Update_Account_Status"}'
            + '},{'
            + '  "Id": "301xx000000002BBB",'
            + '  "MasterLabel": "New Case Screen Flow",'
            + '  "Status": "Active",'
            + '  "ProcessType": "Flow",'
            + '  "Definition": {"DeveloperName": "New_Case_Screen_Flow"}'
            + '}]'
            + '}';
    }
}