@IsTest(SeeAllData=false)
public with sharing class FlowSnapshotServiceTest {

    /**
     * Helper method to build an AnalysisResult with given score and grade
     */
    private static FlowAnalysisService.AnalysisResult buildAnalysisResult(
        Integer score,
        String grade
    ) {
        FlowAnalysisService.AnalysisResult result = new FlowAnalysisService.AnalysisResult();
        result.score = score;
        result.grade = grade;
        result.gradeLabel = grade + ' Grade';
        result.gradeColor = '#FF0000';
        result.findings = new List<FlowFinding>();
        result.totalFindings = 5;
        result.findingsByCategory = new Map<String, List<FlowFinding>>();
        result.findingsBySeverity = new Map<String, Integer>{
            'Critical' => 1,
            'High' => 2,
            'Medium' => 1,
            'Low' => 1
        };
        result.categoryScores = new Map<String, Integer>{
            'Performance' => 80,
            'Best Practices' => 75
        };
        return result;
    }

    /**
     * Test 1: Save snapshot with basic fields
     */
    @IsTest
    static void testSaveSnapshotBasic() {
        FlowAnalysisService.AnalysisResult result = buildAnalysisResult(85, 'A');

        Test.startTest();
        FlowSnapshotService.saveSnapshot(
            'TestFlow',
            'Test Flow Label',
            'AutoLaunchedFlow',
            result,
            'Single'
        );
        Test.stopTest();

        Flow_Health_Snapshot__c snapshot = [
            SELECT Flow_Developer_Name__c, Flow_Label__c, Score__c, Grade__c,
                   Process_Type__c, Scan_Type__c
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = 'TestFlow'
            LIMIT 1
        ];

        Assert.isNotNull(snapshot, 'Snapshot should be inserted');
        Assert.areEqual('TestFlow', snapshot.Flow_Developer_Name__c);
        Assert.areEqual('Test Flow Label', snapshot.Flow_Label__c);
        Assert.areEqual(85, snapshot.Score__c);
        Assert.areEqual('A', snapshot.Grade__c);
        Assert.areEqual('AutoLaunchedFlow', snapshot.Process_Type__c);
        Assert.areEqual('Single', snapshot.Scan_Type__c);
    }

    /**
     * Test 2: Verify severity counts are saved correctly
     */
    @IsTest
    static void testSaveSnapshotWithSeverityCounts() {
        FlowAnalysisService.AnalysisResult result = buildAnalysisResult(75, 'B');

        Test.startTest();
        FlowSnapshotService.saveSnapshot(
            'SeverityTestFlow',
            'Severity Test Flow',
            'Flow',
            result,
            'Single'
        );
        Test.stopTest();

        Flow_Health_Snapshot__c snapshot = [
            SELECT Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = 'SeverityTestFlow'
            LIMIT 1
        ];

        Assert.areEqual(1, snapshot.Critical_Count__c, 'Critical count should be 1');
        Assert.areEqual(2, snapshot.High_Count__c, 'High count should be 2');
        Assert.areEqual(1, snapshot.Medium_Count__c, 'Medium count should be 1');
        Assert.areEqual(1, snapshot.Low_Count__c, 'Low count should be 1');
    }

    /**
     * Test 3: Verify Findings_JSON__c is serialized correctly
     */
    @IsTest
    static void testSaveSnapshotWithFindings() {
        FlowAnalysisService.AnalysisResult result = buildAnalysisResult(80, 'A');

        Test.startTest();
        FlowSnapshotService.saveSnapshot(
            'FindingsTestFlow',
            'Findings Test Flow',
            'Flow',
            result,
            'Single'
        );
        Test.stopTest();

        Flow_Health_Snapshot__c snapshot = [
            SELECT Findings_JSON__c, Total_Findings__c
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = 'FindingsTestFlow'
            LIMIT 1
        ];

        Assert.isNotNull(snapshot.Findings_JSON__c, 'Findings JSON should be populated');
        Assert.areEqual(5, snapshot.Total_Findings__c, 'Total findings should be 5');
    }

    /**
     * Test 4: Null findingsBySeverity → counts default to 0
     */
    @IsTest
    static void testSaveSnapshotNullSeverityMap() {
        FlowAnalysisService.AnalysisResult result = buildAnalysisResult(70, 'C');
        result.findingsBySeverity = null;

        Test.startTest();
        FlowSnapshotService.saveSnapshot(
            'NullSeverityFlow',
            'Null Severity Flow',
            'Flow',
            result,
            'Single'
        );
        Test.stopTest();

        Flow_Health_Snapshot__c snapshot = [
            SELECT Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = 'NullSeverityFlow'
            LIMIT 1
        ];

        Assert.areEqual(0, snapshot.Critical_Count__c, 'Critical count should default to 0');
        Assert.areEqual(0, snapshot.High_Count__c, 'High count should default to 0');
        Assert.areEqual(0, snapshot.Medium_Count__c, 'Medium count should default to 0');
        Assert.areEqual(0, snapshot.Low_Count__c, 'Low count should default to 0');
    }

    /**
     * Test 5: getFlowHistory returns records ordered newest first with limit
     */
    @IsTest
    static void testGetFlowHistoryReturnsRecords() {
        String flowDevName = 'HistoryTestFlow';

        // Insert 3 snapshots
        List<Flow_Health_Snapshot__c> snapshots = new List<Flow_Health_Snapshot__c>();
        for (Integer i = 0; i < 3; i++) {
            snapshots.add(new Flow_Health_Snapshot__c(
                Flow_Developer_Name__c = flowDevName,
                Flow_Label__c = 'History Test Flow ' + i,
                Score__c = 80 + i,
                Grade__c = 'A',
                Process_Type__c = 'Flow',
                Scan_Type__c = 'Single'
            ));
        }
        insert snapshots;

        Test.startTest();
        List<Flow_Health_Snapshot__c> result = FlowSnapshotService.getFlowHistory(flowDevName, 2);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return 2 records');
        // Verify newest first (highest score)
        Assert.areEqual(82, result[0].Score__c, 'First record should be newest (score 82)');
        Assert.areEqual(81, result[1].Score__c, 'Second record should be older (score 81)');
    }

    /**
     * Test 6: getFlowHistory with null maxRecords defaults to 10
     */
    @IsTest
    static void testGetFlowHistoryDefaultMaxRecords() {
        String flowDevName = 'DefaultMaxFlow';

        // Insert 15 snapshots
        List<Flow_Health_Snapshot__c> snapshots = new List<Flow_Health_Snapshot__c>();
        for (Integer i = 0; i < 15; i++) {
            snapshots.add(new Flow_Health_Snapshot__c(
                Flow_Developer_Name__c = flowDevName,
                Flow_Label__c = 'Default Max Flow',
                Score__c = 70 + i,
                Grade__c = 'B',
                Process_Type__c = 'Flow',
                Scan_Type__c = 'Single'
            ));
        }
        insert snapshots;

        Test.startTest();
        List<Flow_Health_Snapshot__c> result = FlowSnapshotService.getFlowHistory(flowDevName, null);
        Test.stopTest();

        Assert.areEqual(10, result.size(), 'Should default to 10 records');
    }

    /**
     * Test 7: getFlowHistory with 0 maxRecords defaults to 10
     */
    @IsTest
    static void testGetFlowHistoryZeroMaxRecords() {
        String flowDevName = 'ZeroMaxFlow';

        // Insert 12 snapshots
        List<Flow_Health_Snapshot__c> snapshots = new List<Flow_Health_Snapshot__c>();
        for (Integer i = 0; i < 12; i++) {
            snapshots.add(new Flow_Health_Snapshot__c(
                Flow_Developer_Name__c = flowDevName,
                Flow_Label__c = 'Zero Max Flow',
                Score__c = 60 + i,
                Grade__c = 'C',
                Process_Type__c = 'Flow',
                Scan_Type__c = 'Single'
            ));
        }
        insert snapshots;

        Test.startTest();
        List<Flow_Health_Snapshot__c> result = FlowSnapshotService.getFlowHistory(flowDevName, 0);
        Test.stopTest();

        Assert.areEqual(10, result.size(), 'Should default to 10 records when 0 is passed');
    }

    /**
     * Test 8: getFlowHistory returns empty list when no records exist
     */
    @IsTest
    static void testGetFlowHistoryNoRecords() {
        String flowDevName = 'NonExistentFlow';

        Test.startTest();
        List<Flow_Health_Snapshot__c> result = FlowSnapshotService.getFlowHistory(flowDevName, 10);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty list');
    }

    /**
     * Test 9: getFlowTrendSummary with one snapshot → isFirstScan=true, hasHistory=true
     */
    @IsTest
    static void testGetFlowTrendSummaryFirstScan() {
        String flowDevName = 'FirstScanFlow';

        Flow_Health_Snapshot__c snapshot = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'First Scan Flow',
            Score__c = 85,
            Grade__c = 'A',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot;

        Test.startTest();
        FlowSnapshotService.TrendSummary summary = FlowSnapshotService.getFlowTrendSummary(flowDevName);
        Test.stopTest();

        Assert.isTrue(summary.hasHistory, 'Should have history');
        Assert.isTrue(summary.isFirstScan, 'Should be first scan');
        Assert.areEqual(85, summary.currentScore);
        Assert.areEqual('A', summary.currentGrade);
    }

    /**
     * Test 10: getFlowTrendSummary with 2 snapshots where newer > older → improving
     */
    @IsTest
    static void testGetFlowTrendSummaryImproving() {
        String flowDevName = 'ImprovingFlow';

        // First snapshot (older, lower score)
        Flow_Health_Snapshot__c snapshot1 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Improving Flow',
            Score__c = 70,
            Grade__c = 'C',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot1;

        // Second snapshot (newer, higher score)
        Flow_Health_Snapshot__c snapshot2 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Improving Flow',
            Score__c = 85,
            Grade__c = 'A',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot2;

        Test.startTest();
        FlowSnapshotService.TrendSummary summary = FlowSnapshotService.getFlowTrendSummary(flowDevName);
        Test.stopTest();

        Assert.isTrue(summary.hasHistory, 'Should have history');
        Assert.isFalse(summary.isFirstScan, 'Should not be first scan');
        Assert.areEqual(85, summary.currentScore);
        Assert.areEqual('A', summary.currentGrade);
        Assert.areEqual(70, summary.previousScore);
        Assert.areEqual('C', summary.previousGrade);
        Assert.areEqual(15, summary.scoreDelta);
        Assert.areEqual('improving', summary.direction);
    }

    /**
     * Test 11: getFlowTrendSummary with 2 snapshots where newer < older → declining
     */
    @IsTest
    static void testGetFlowTrendSummaryDeclining() {
        String flowDevName = 'DecliningFlow';

        // First snapshot (older, higher score)
        Flow_Health_Snapshot__c snapshot1 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Declining Flow',
            Score__c = 90,
            Grade__c = 'A',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot1;

        // Second snapshot (newer, lower score)
        Flow_Health_Snapshot__c snapshot2 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Declining Flow',
            Score__c = 65,
            Grade__c = 'D',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot2;

        Test.startTest();
        FlowSnapshotService.TrendSummary summary = FlowSnapshotService.getFlowTrendSummary(flowDevName);
        Test.stopTest();

        Assert.isTrue(summary.hasHistory, 'Should have history');
        Assert.isFalse(summary.isFirstScan, 'Should not be first scan');
        Assert.areEqual(65, summary.currentScore);
        Assert.areEqual('D', summary.currentGrade);
        Assert.areEqual(90, summary.previousScore);
        Assert.areEqual('A', summary.previousGrade);
        Assert.areEqual(-25, summary.scoreDelta);
        Assert.areEqual('declining', summary.direction);
    }

    /**
     * Test 12: getFlowTrendSummary with 2 snapshots with same score → stable
     */
    @IsTest
    static void testGetFlowTrendSummaryStable() {
        String flowDevName = 'StableFlow';

        // First snapshot
        Flow_Health_Snapshot__c snapshot1 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Stable Flow',
            Score__c = 80,
            Grade__c = 'A',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot1;

        // Second snapshot with same score
        Flow_Health_Snapshot__c snapshot2 = new Flow_Health_Snapshot__c(
            Flow_Developer_Name__c = flowDevName,
            Flow_Label__c = 'Stable Flow',
            Score__c = 80,
            Grade__c = 'A',
            Process_Type__c = 'Flow',
            Scan_Type__c = 'Single'
        );
        insert snapshot2;

        Test.startTest();
        FlowSnapshotService.TrendSummary summary = FlowSnapshotService.getFlowTrendSummary(flowDevName);
        Test.stopTest();

        Assert.isTrue(summary.hasHistory, 'Should have history');
        Assert.isFalse(summary.isFirstScan, 'Should not be first scan');
        Assert.areEqual(80, summary.currentScore);
        Assert.areEqual('A', summary.currentGrade);
        Assert.areEqual(80, summary.previousScore);
        Assert.areEqual('A', summary.previousGrade);
        Assert.areEqual(0, summary.scoreDelta);
        Assert.areEqual('stable', summary.direction);
    }

    /**
     * Test 13: getFlowTrendSummary with no history → hasHistory=false, isFirstScan=true
     */
    @IsTest
    static void testGetFlowTrendSummaryNoHistory() {
        String flowDevName = 'NoHistoryFlow';

        Test.startTest();
        FlowSnapshotService.TrendSummary summary = FlowSnapshotService.getFlowTrendSummary(flowDevName);
        Test.stopTest();

        Assert.isFalse(summary.hasHistory, 'Should not have history');
        Assert.isTrue(summary.isFirstScan, 'Should be first scan');
        Assert.isNull(summary.currentScore);
        Assert.isNull(summary.currentGrade);
    }

    /**
     * Test 14: getOrgTrendData aggregate query
     */
    @IsTest
    static void testGetOrgTrendData() {
        // Insert snapshots with different dates (using CreatedDate would require time travel in test)
        // This test primarily verifies the method doesn't throw exceptions
        List<Flow_Health_Snapshot__c> snapshots = new List<Flow_Health_Snapshot__c>();
        for (Integer i = 0; i < 5; i++) {
            snapshots.add(new Flow_Health_Snapshot__c(
                Flow_Developer_Name__c = 'OrgTrendFlow' + i,
                Flow_Label__c = 'Org Trend Flow',
                Score__c = 75 + i,
                Grade__c = 'B',
                Process_Type__c = 'Flow',
                Scan_Type__c = 'Single'
            ));
        }
        insert snapshots;

        Test.startTest();
        List<FlowSnapshotService.OrgTrendPoint> trendData = FlowSnapshotService.getOrgTrendData(30);
        Test.stopTest();

        // Verify method returns a list (actual data depends on implementation)
        Assert.isNotNull(trendData, 'Should return trend data list');
    }
}
