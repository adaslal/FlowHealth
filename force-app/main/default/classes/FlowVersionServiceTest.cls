@IsTest
public class FlowVersionServiceTest {

    @IsTest
    static void testGetVersionsSuccess() {
        VersionListMock mockResponse = new VersionListMock(200, 2);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        List<FlowVersionService.FlowVersionInfo> versions = FlowVersionService.getVersions('TestFlow');

        Assert.areEqual(2, versions.size(), 'Should return 2 versions');
        Assert.areEqual('3011x00000ABC', versions.get(0).id, 'First version ID should match');
        Assert.areEqual(2, versions.get(0).versionNumber, 'Version number should be 2');
        Assert.areEqual('My Flow', versions.get(0).masterLabel, 'Master label should match');
        Assert.areEqual('Active', versions.get(0).status, 'Status should be Active');
        Assert.areEqual('AutoLaunchedFlow', versions.get(0).processType, 'Process type should match');
    }

    @IsTest
    static void testGetVersionsBlankNameThrowsException() {
        VersionListMock mockResponse = new VersionListMock(200, 0);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.getVersions('');
            Assert.fail('Should throw exception for blank flow name');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('blank'), 'Exception message should mention blank');
        }
    }

    @IsTest
    static void testGetVersionsEmptyResult() {
        VersionListMock mockResponse = new VersionListMock(200, 0);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        List<FlowVersionService.FlowVersionInfo> versions = FlowVersionService.getVersions('NonexistentFlow');

        Assert.areEqual(0, versions.size(), 'Should return empty list for no results');
    }

    @IsTest
    static void testGetVersionMetadataSuccess() {
        VersionMetadataMock mockResponse = new VersionMetadataMock(200);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        FlowMetadata.FlowDefinition flowDef = FlowVersionService.getVersionMetadata('3011x00000ABC');

        Assert.isNotNull(flowDef, 'Should return flow definition');
        Assert.areEqual('My Flow', flowDef.label, 'Flow label should match');
        Assert.areEqual('AutoLaunchedFlow', flowDef.processType, 'Process type should match');
        Assert.areEqual('62.0', flowDef.apiVersion, 'API version should be 62.0');
    }

    @IsTest
    static void testGetVersionMetadataBlankIdThrowsException() {
        VersionMetadataMock mockResponse = new VersionMetadataMock(200);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.getVersionMetadata('');
            Assert.fail('Should throw exception for blank version ID');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('blank'), 'Exception message should mention blank');
        }
    }

    @IsTest
    static void testGetVersionMetadataNotFound() {
        VersionListMock mockResponse = new VersionListMock(200, 0);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.getVersionMetadata('3011x00000NOTFOUND');
            Assert.fail('Should throw exception when version not found');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('not found') || e.getMessage().containsIgnoreCase('no records'),
                'Exception message should indicate not found');
        }
    }

    @IsTest
    static void testGetVersionMetadataApiError() {
        ErrorMock mockResponse = new ErrorMock(400, 'Bad Request');
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.getVersionMetadata('3011x00000ABC');
            Assert.fail('Should throw exception for API error');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('error') || e.getMessage().containsIgnoreCase('failed'),
                'Exception message should indicate error');
        }
    }

    @IsTest
    static void testCompareDefinitionsSuccess() {
        FlowMetadata.FlowDefinition oldFlow = createTestFlowDefinition('Old Flow', 'v1');
        FlowMetadata.FlowDefinition newFlow = createTestFlowDefinition('New Flow', 'v2');

        FlowDiffResult diffResult = FlowVersionService.compareDefinitions(oldFlow, newFlow);

        Assert.isNotNull(diffResult, 'Should return diff result');
        Assert.isNotNull(diffResult.changes, 'Changes list should be set');
    }

    @IsTest
    static void testCompareDefinitionsIdentical() {
        FlowMetadata.FlowDefinition flow = createTestFlowDefinition('Test Flow', 'v1');

        FlowDiffResult diffResult = FlowVersionService.compareDefinitions(flow, flow);

        Assert.isNotNull(diffResult, 'Should return diff result');
        Assert.areEqual(0, diffResult.changes.size(), 'Identical flows should have 0 changes');
    }

    @IsTest
    static void testCompareDefinitionsWithChanges() {
        FlowMetadata.FlowDefinition oldFlow = createTestFlowDefinition('Test Flow', 'v1');
        FlowMetadata.FlowDefinition newFlow = createTestFlowDefinition('Test Flow Modified', 'v2');

        FlowDiffResult diffResult = FlowVersionService.compareDefinitions(oldFlow, newFlow);

        Assert.isNotNull(diffResult, 'Should return diff result');
        Assert.isTrue(diffResult.changes.size() > 0, 'Different flows should have changes');
    }

    @IsTest
    static void testGetVersionsParseVersionNumber() {
        VersionListMock mockResponse = new VersionListMock(200, 1);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        List<FlowVersionService.FlowVersionInfo> versions = FlowVersionService.getVersions('TestFlow');

        Assert.areEqual(1, versions.size(), 'Should parse one version');
        Assert.isNotNull(versions.get(0).versionNumber, 'Version number should not be null');
        Assert.areEqual(2, versions.get(0).versionNumber, 'Version number should be parsed as Integer');
    }

    @IsTest
    static void testGetVersionsParseLastModifiedBy() {
        VersionListMock mockResponse = new VersionListMock(200, 1);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        List<FlowVersionService.FlowVersionInfo> versions = FlowVersionService.getVersions('TestFlow');

        Assert.areEqual(1, versions.size(), 'Should parse one version');
        Assert.areEqual('Admin User', versions.get(0).lastModifiedByName, 'LastModifiedByName should be parsed correctly');
    }

    @IsTest
    static void testGetVersionsParseDisplayLabel() {
        VersionListMock mockResponse = new VersionListMock(200, 1);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        List<FlowVersionService.FlowVersionInfo> versions = FlowVersionService.getVersions('TestFlow');

        Assert.areEqual(1, versions.size(), 'Should parse one version');
        Assert.isNotNull(versions.get(0).displayLabel, 'Display label should not be null');
        // Display label format: "vN — Status (by Name)"
        Assert.isTrue(versions.get(0).displayLabel.contains('v2'), 'Display label should contain version number');
        Assert.isTrue(versions.get(0).displayLabel.contains('Active'), 'Display label should contain status');
        Assert.isTrue(versions.get(0).displayLabel.contains('Admin User'), 'Display label should contain modified by name');
    }

    @IsTest
    static void testCompareVersionsBlankOldId() {
        VersionMetadataMock mockResponse = new VersionMetadataMock(200);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.compareVersions('', '3011x00000ABC');
            Assert.fail('Should throw exception for blank old version ID');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('blank'), 'Exception message should mention blank');
        }
    }

    @IsTest
    static void testCompareVersionsBlankNewId() {
        VersionMetadataMock mockResponse = new VersionMetadataMock(200);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        try {
            FlowVersionService.compareVersions('3011x00000ABC', '');
            Assert.fail('Should throw exception for blank new version ID');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isTrue(e.getMessage().containsIgnoreCase('blank'), 'Exception message should mention blank');
        }
    }

    // Helper method to create test FlowDefinition objects
    private static FlowMetadata.FlowDefinition createTestFlowDefinition(String label, String description) {
        FlowMetadata.FlowDefinition flowDef = new FlowMetadata.FlowDefinition();
        flowDef.label = label;
        flowDef.apiVersion = '62.0';
        flowDef.processType = 'AutoLaunchedFlow';
        flowDef.description = description;
        flowDef.decisions = new List<FlowMetadata.FlowDecision>();
        flowDef.assignments = new List<FlowMetadata.FlowAssignment>();
        flowDef.recordCreates = new List<FlowMetadata.FlowRecordCreate>();
        flowDef.recordUpdates = new List<FlowMetadata.FlowRecordUpdate>();
        flowDef.recordDeletes = new List<FlowMetadata.FlowRecordDelete>();
        flowDef.recordLookups = new List<FlowMetadata.FlowRecordLookup>();
        flowDef.loops = new List<FlowMetadata.FlowLoop>();
        flowDef.screens = new List<FlowMetadata.FlowScreen>();
        flowDef.actionCalls = new List<FlowMetadata.FlowActionCall>();
        flowDef.subflows = new List<FlowMetadata.FlowSubflow>();
        flowDef.variables = new List<FlowMetadata.FlowVariable>();
        flowDef.formulas = new List<FlowMetadata.FlowFormula>();
        flowDef.constants = new List<FlowMetadata.FlowConstant>();
        flowDef.textTemplates = new List<FlowMetadata.FlowTextTemplate>();
        flowDef.choices = new List<FlowMetadata.FlowChoice>();
        return flowDef;
    }

    // Mock class for version list responses
    private class VersionListMock implements HttpCalloutMock {
        private Integer statusCode;
        private Integer recordCount;

        VersionListMock(Integer statusCode, Integer recordCount) {
            this.statusCode = statusCode;
            this.recordCount = recordCount;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setStatus(statusCode == 200 ? 'OK' : 'ERROR');

            if (statusCode == 200) {
                response.setBody(generateVersionListJson(recordCount));
            } else {
                response.setBody('{"error": "Request failed"}');
            }

            return response;
        }

        private String generateVersionListJson(Integer count) {
            List<String> records = new List<String>();

            for (Integer i = 0; i < count; i++) {
                String record = '{"Id":"3011x00000ABC","VersionNumber":2,"Status":"Active","MasterLabel":"My Flow","ProcessType":"AutoLaunchedFlow","Description":"Test","LastModifiedDate":"2024-01-15T10:30:00.000+0000","LastModifiedBy":{"Name":"Admin User"}}';
                records.add(record);
            }

            String recordsJson = '[' + String.join(records, ',') + ']';
            return '{"size":' + count + ',"totalSize":' + count + ',"done":true,"records":' + recordsJson + '}';
        }
    }

    // Mock class for metadata responses
    private class VersionMetadataMock implements HttpCalloutMock {
        private Integer statusCode;

        VersionMetadataMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setStatus(statusCode == 200 ? 'OK' : 'ERROR');

            if (statusCode == 200) {
                response.setBody(generateMetadataJson());
            } else {
                response.setBody('{"error": "Request failed"}');
            }

            return response;
        }

        private String generateMetadataJson() {
            String metadataJson = '{"processType":"AutoLaunchedFlow","label":"My Flow","apiVersion":"62.0","decisions":[],"assignments":[],"recordCreates":[],"recordUpdates":[],"recordDeletes":[],"recordLookups":[],"loops":[],"screens":[],"actionCalls":[],"subflows":[],"variables":[],"formulas":[],"constants":[],"textTemplates":[],"choices":[]}';
            String record = '{"Id":"3011x00000ABC","FullName":"My_Flow-2","MasterLabel":"My Flow","Status":"Active","Metadata":' + metadataJson + '}';
            return '{"size":1,"totalSize":1,"done":true,"records":[' + record + ']}';
        }
    }

    // Mock class for error responses
    private class ErrorMock implements HttpCalloutMock {
        private Integer statusCode;
        private String statusMessage;

        ErrorMock(Integer statusCode, String statusMessage) {
            this.statusCode = statusCode;
            this.statusMessage = statusMessage;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setStatus(statusMessage);
            response.setBody('{"error":{"message":"API Error occurred"}}');
            return response;
        }
    }
}
