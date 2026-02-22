/**
 * FlowHealthReportControllerTest2 - Test suite for FlowHealthReportController
 *
 * Tests the Visualforce controller that renders Flow Health reports as PDF.
 * Covers snapshot loading, findings deserialization, color mapping, and report generation.
 */
@isTest
private class FlowHealthReportControllerTest2 {

    /**
     * Test 1: Constructor with snapshot ID parameter
     * Verifies that a snapshot is loaded when ?id=snapshotId is provided
     */
    @isTest
    static void testConstructorWithSnapshotId() {
        // Create a test snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 85, 'B', null);
        insert snapshot;

        // Set page parameters with snapshot ID
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);

        // Instantiate controller
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify snapshot was loaded
        System.assertNotEquals(null, ctrl.snapshot, 'Snapshot should be loaded from ID parameter');
        System.assertEquals(snapshot.Id, ctrl.snapshot.Id, 'Loaded snapshot ID should match');
        System.assertEquals('TestFlow', ctrl.snapshot.Name, 'Snapshot name should match');
    }

    /**
     * Test 2: Constructor with flow developer name parameter
     * Verifies that the latest snapshot is loaded when ?flow=devName is provided
     */
    @isTest
    static void testConstructorWithFlowName() {
        // Create multiple snapshots for the same flow
        Flow_Health_Snapshot__c snapshot1 = createTestSnapshot('TestFlow', 'test_flow_dev', 80, 'B', null);
        insert snapshot1;

        // Create a more recent snapshot
        Flow_Health_Snapshot__c snapshot2 = createTestSnapshot('TestFlow', 'test_flow_dev', 90, 'A', null);
        insert snapshot2;

        // Set page parameters with flow developer name
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('flow', 'test_flow_dev');
        Test.setCurrentPage(pageRef);

        // Instantiate controller
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify the most recent snapshot was loaded
        System.assertNotEquals(null, ctrl.snapshot, 'Latest snapshot should be loaded by flow name');
        System.assertEquals(snapshot2.Id, ctrl.snapshot.Id, 'Should load the most recent snapshot');
    }

    /**
     * Test 3: Constructor with no URL parameters
     * Verifies that the controller initializes with default values
     */
    @isTest
    static void testConstructorNoParams() {
        // Set page with no parameters
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        Test.setCurrentPage(pageRef);

        // Instantiate controller
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify default initialization
        System.assertEquals(null, ctrl.snapshot, 'Snapshot should be null when no parameters provided');
        System.assertEquals(0, ctrl.findings.size(), 'Findings list should be empty');
        System.assertEquals(0, ctrl.findingsByCategory.size(), 'Category map should be empty');
        System.assertEquals(0, ctrl.categoryOrder.size(), 'Category order list should be empty');
        System.assertEquals(false, ctrl.hasFindings, 'hasFindings should be false');
    }

    /**
     * Test 4: Constructor with non-existent snapshot ID
     * Verifies graceful handling of invalid IDs
     */
    @isTest
    static void testConstructorWithInvalidId() {
        // Use a non-existent ID
        String invalidId = '001000000000001';

        // Set page parameters with invalid ID
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', invalidId);
        Test.setCurrentPage(pageRef);

        // Instantiate controller
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify null snapshot
        System.assertEquals(null, ctrl.snapshot, 'Snapshot should be null for invalid ID');
        System.assertEquals(false, ctrl.hasFindings, 'hasFindings should remain false');
    }

    /**
     * Test 5: Findings deserialization from JSON
     * Verifies that Findings_JSON__c is correctly deserialized into FindingDisplay objects
     */
    @isTest
    static void testFindingsDeserialization() {
        // Create findings JSON
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('PERF-001', 'DML Inside Loop', 'Performance', 'Critical')
                .withElement('RecordCreate', 'recordCreate')
                .withDescription('Found DML operation inside loop')
                .withRemediation('Move DML outside of loop or use batch processing')
                .withWeight(50),
            new FlowFinding('SEC-002', 'Hardcoded API Key', 'Security', 'High')
                .withDescription('Hardcoded credentials detected')
                .withRemediation('Use custom settings or named credentials')
                .withWeight(30)
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot with findings
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 80, 'B', findingsJson);
        insert snapshot;

        // Load controller with snapshot ID
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify findings were deserialized
        System.assertEquals(2, ctrl.findings.size(), 'Should have 2 findings');
        System.assertEquals('PERF-001', ctrl.findings[0].ruleId, 'First finding ruleId should match');
        System.assertEquals('DML Inside Loop', ctrl.findings[0].ruleName, 'First finding ruleName should match');
        System.assertEquals(true, ctrl.hasFindings, 'hasFindings should be true');
    }

    /**
     * Test 6: Findings grouped by category
     * Verifies that findings are correctly grouped into the findingsByCategory map
     */
    @isTest
    static void testFindingsByCategory() {
        // Create findings with different categories
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('PERF-001', 'DML Inside Loop', 'Performance', 'Critical')
                .withDescription('Performance issue'),
            new FlowFinding('PERF-002', 'Excessive Decisions', 'Performance', 'Medium')
                .withDescription('Another performance issue'),
            new FlowFinding('SEC-001', 'Missing Validation', 'Security', 'High')
                .withDescription('Security issue')
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 75, 'C', findingsJson);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify category grouping
        System.assertEquals(2, ctrl.findingsByCategory.size(), 'Should have 2 categories');
        System.assertEquals(true, ctrl.findingsByCategory.containsKey('Performance'), 'Should contain Performance category');
        System.assertEquals(true, ctrl.findingsByCategory.containsKey('Security'), 'Should contain Security category');
        System.assertEquals(2, ctrl.findingsByCategory.get('Performance').size(), 'Performance should have 2 findings');
        System.assertEquals(1, ctrl.findingsByCategory.get('Security').size(), 'Security should have 1 finding');
    }

    /**
     * Test 7: Category order is maintained
     * Verifies that categories are added to categoryOrder in the order they appear
     */
    @isTest
    static void testCategoryOrder() {
        // Create findings in specific order
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('SEC-001', 'First Security Issue', 'Security', 'High'),
            new FlowFinding('PERF-001', 'First Performance Issue', 'Performance', 'Medium'),
            new FlowFinding('BEST-001', 'First Best Practice Issue', 'Best Practices', 'Low'),
            new FlowFinding('SEC-002', 'Second Security Issue', 'Security', 'Low')
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 70, 'C', findingsJson);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify category order
        System.assertEquals(3, ctrl.categoryOrder.size(), 'Should have 3 categories');
        System.assertEquals('Security', ctrl.categoryOrder[0], 'First category should be Security');
        System.assertEquals('Performance', ctrl.categoryOrder[1], 'Second category should be Performance');
        System.assertEquals('Best Practices', ctrl.categoryOrder[2], 'Third category should be Best Practices');
    }

    /**
     * Test 8: FindingDisplay fields are populated correctly
     * Verifies that all FindingDisplay properties are set from FlowFinding data
     */
    @isTest
    static void testFindingDisplayFields() {
        // Create a detailed finding
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('PERF-001', 'DML Inside Loop', 'Performance', 'Critical')
                .withElement('MyRecordCreate', 'recordCreate')
                .withDescription('DML operation found inside loop')
                .withRemediation('Refactor to use batch processing or move DML outside loop')
                .withWeight(50)
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 60, 'D', findingsJson);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify FindingDisplay fields
        System.assertEquals(1, ctrl.findings.size(), 'Should have 1 finding');
        FlowHealthReportController.FindingDisplay fd = ctrl.findings[0];
        System.assertEquals(1, fd.index, 'Index should be 1');
        System.assertEquals('PERF-001', fd.ruleId, 'RuleId should match');
        System.assertEquals('DML Inside Loop', fd.ruleName, 'RuleName should match');
        System.assertEquals('Performance', fd.category, 'Category should match');
        System.assertEquals('Critical', fd.severity, 'Severity should match');
        System.assertEquals('MyRecordCreate', fd.elementName, 'ElementName should match');
        System.assertEquals('recordCreate', fd.elementType, 'ElementType should match');
        System.assertEquals('DML operation found inside loop', fd.description, 'Description should match');
        System.assertEquals('Refactor to use batch processing or move DML outside loop', fd.remediation, 'Remediation should match');
        System.assertEquals(true, fd.hasElement, 'hasElement should be true when elementName is set');
    }

    /**
     * Test 9: Score color for excellent (>=90)
     * Verifies scoreColorHex is set to '#04844B' for scores >= 90
     */
    @isTest
    static void testScoreColorExcellent() {
        // Create snapshot with score 95 (Excellent)
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 95, 'A', null);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify score color
        System.assertEquals('#04844B', ctrl.scoreColorHex, 'Color for score 95 should be #04844B');
    }

    /**
     * Test 10: Score color for good (>=80)
     * Verifies scoreColorHex is set to '#2E844A' for scores >= 80 and < 90
     */
    @isTest
    static void testScoreColorGood() {
        // Create snapshot with score 85 (Good)
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 85, 'B', null);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify score color
        System.assertEquals('#2E844A', ctrl.scoreColorHex, 'Color for score 85 should be #2E844A');
    }

    /**
     * Test 11: Score color for fair (>=70)
     * Verifies scoreColorHex is set to '#DD7A01' for scores >= 70 and < 80
     */
    @isTest
    static void testScoreColorFair() {
        // Create snapshot with score 72 (Fair)
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 72, 'C', null);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify score color
        System.assertEquals('#DD7A01', ctrl.scoreColorHex, 'Color for score 72 should be #DD7A01');
    }

    /**
     * Test 12: Score color for poor (<70)
     * Verifies scoreColorHex is set to '#C23934' for scores < 60
     */
    @isTest
    static void testScoreColorPoor() {
        // Create snapshot with score 55 (Poor)
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 55, 'D', null);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify score color
        System.assertEquals('#C23934', ctrl.scoreColorHex, 'Color for score 55 should be #C23934');
    }

    /**
     * Test 13: Grade labels are mapped correctly
     * Verifies all grade values map to correct labels: A->Excellent, B->Good, C->Fair, D->Needs Work, else->Critical
     */
    @isTest
    static void testGradeLabels() {
        // Test grade A (Excellent)
        Flow_Health_Snapshot__c snapshotA = createTestSnapshot('FlowA', 'flow_a', 95, 'A', null);
        insert snapshotA;
        PageReference pageRefA = new PageReference('/apex/FlowHealthReport');
        pageRefA.getParameters().put('id', snapshotA.Id);
        Test.setCurrentPage(pageRefA);
        FlowHealthReportController ctrlA = new FlowHealthReportController();
        System.assertEquals('Excellent', ctrlA.gradeLabel, 'Grade A should map to Excellent');

        // Test grade B (Good)
        Flow_Health_Snapshot__c snapshotB = createTestSnapshot('FlowB', 'flow_b', 85, 'B', null);
        insert snapshotB;
        PageReference pageRefB = new PageReference('/apex/FlowHealthReport');
        pageRefB.getParameters().put('id', snapshotB.Id);
        Test.setCurrentPage(pageRefB);
        FlowHealthReportController ctrlB = new FlowHealthReportController();
        System.assertEquals('Good', ctrlB.gradeLabel, 'Grade B should map to Good');

        // Test grade C (Fair)
        Flow_Health_Snapshot__c snapshotC = createTestSnapshot('FlowC', 'flow_c', 75, 'C', null);
        insert snapshotC;
        PageReference pageRefC = new PageReference('/apex/FlowHealthReport');
        pageRefC.getParameters().put('id', snapshotC.Id);
        Test.setCurrentPage(pageRefC);
        FlowHealthReportController ctrlC = new FlowHealthReportController();
        System.assertEquals('Fair', ctrlC.gradeLabel, 'Grade C should map to Fair');

        // Test grade D (Needs Work)
        Flow_Health_Snapshot__c snapshotD = createTestSnapshot('FlowD', 'flow_d', 65, 'D', null);
        insert snapshotD;
        PageReference pageRefD = new PageReference('/apex/FlowHealthReport');
        pageRefD.getParameters().put('id', snapshotD.Id);
        Test.setCurrentPage(pageRefD);
        FlowHealthReportController ctrlD = new FlowHealthReportController();
        System.assertEquals('Needs Work', ctrlD.gradeLabel, 'Grade D should map to Needs Work');

        // Test grade F (Critical)
        Flow_Health_Snapshot__c snapshotF = createTestSnapshot('FlowF', 'flow_f', 45, 'F', null);
        insert snapshotF;
        PageReference pageRefF = new PageReference('/apex/FlowHealthReport');
        pageRefF.getParameters().put('id', snapshotF.Id);
        Test.setCurrentPage(pageRefF);
        FlowHealthReportController ctrlF = new FlowHealthReportController();
        System.assertEquals('Critical', ctrlF.gradeLabel, 'Grade F should map to Critical');
    }

    /**
     * Test 14: Severity colors are applied correctly
     * Verifies that different severity levels map to correct hex colors
     */
    @isTest
    static void testSeverityColors() {
        // Create findings with different severity levels
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('RULE-001', 'Critical Issue', 'Test', 'Critical'),
            new FlowFinding('RULE-002', 'High Issue', 'Test', 'High'),
            new FlowFinding('RULE-003', 'Medium Issue', 'Test', 'Medium'),
            new FlowFinding('RULE-004', 'Low Issue', 'Test', 'Low')
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 70, 'C', findingsJson);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify severity colors
        System.assertEquals('#C23934', ctrl.findings[0].severityColor, 'Critical severity should be #C23934');
        System.assertEquals('#E87400', ctrl.findings[1].severityColor, 'High severity should be #E87400');
        System.assertEquals('#F4BC25', ctrl.findings[2].severityColor, 'Medium severity should be #F4BC25');
        System.assertEquals('#0176D3', ctrl.findings[3].severityColor, 'Low severity should be #0176D3');
    }

    /**
     * Test 15: Findings without element name
     * Verifies that hasElement is false when elementName is blank
     */
    @isTest
    static void testFindingWithoutElement() {
        // Create a finding without element
        List<FlowFinding> testFindings = new List<FlowFinding>{
            new FlowFinding('RULE-001', 'Flow-level issue', 'General', 'Medium')
                .withDescription('This is a flow-wide issue')
                .withRemediation('Review flow design')
        };
        String findingsJson = JSON.serialize(testFindings);

        // Create snapshot
        Flow_Health_Snapshot__c snapshot = createTestSnapshot('TestFlow', 'test_flow_dev', 80, 'B', findingsJson);
        insert snapshot;

        // Load controller
        PageReference pageRef = new PageReference('/apex/FlowHealthReport');
        pageRef.getParameters().put('id', snapshot.Id);
        Test.setCurrentPage(pageRef);
        FlowHealthReportController ctrl = new FlowHealthReportController();

        // Verify hasElement is false
        System.assertEquals(1, ctrl.findings.size(), 'Should have 1 finding');
        System.assertEquals(false, ctrl.findings[0].hasElement, 'hasElement should be false for finding without element');
    }

    /**
     * Helper method to create a test snapshot
     */
    private static Flow_Health_Snapshot__c createTestSnapshot(
        String name,
        String flowDevName,
        Integer score,
        String grade,
        String findingsJson
    ) {
        Flow_Health_Snapshot__c snapshot = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = name + ' Label',
            Score__c = score,
            Grade__c = grade,
            Total_Findings__c = 0,
            Critical_Count__c = 0,
            High_Count__c = 0,
            Medium_Count__c = 0,
            Low_Count__c = 0,
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Health',
            Findings_JSON__c = findingsJson
        );
        return snapshot;
    }
}
