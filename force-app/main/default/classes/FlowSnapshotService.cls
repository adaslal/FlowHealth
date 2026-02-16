/**
 * FlowSnapshotService - Manages persistence and retrieval of flow health snapshots.
 *
 * Sprint 4: Historical Trend Tracking
 *
 * This service handles:
 * 1. Saving analysis results as Flow_Health_Snapshot__c records
 * 2. Querying history for a single flow (trend chart)
 * 3. Querying org-wide trend data (bulk dashboard trend)
 * 4. Computing trend summaries (improving/declining/stable)
 */
public with sharing class FlowSnapshotService {

    /**
     * Saves a single analysis result as a snapshot record.
     *
     * @param flowDevName   Flow API name
     * @param flowLabel     Flow display label
     * @param processType   Flow process type (e.g., RecordTriggeredFlow)
     * @param result        The analysis result to persist
     * @param scanType      'Single' or 'Bulk'
     */
    public static void saveSnapshot(
        String flowDevName,
        String flowLabel,
        String processType,
        FlowAnalysisService.AnalysisResult result,
        String scanType
    ) {
        Flow_Health_Snapshot__c snapshot = new Flow_Health_Snapshot__c();
        snapshot.Flow_Developer_Name__c = flowDevName;
        snapshot.Flow_Label__c = flowLabel;
        snapshot.Score__c = result.score;
        snapshot.Grade__c = result.grade;
        snapshot.Total_Findings__c = result.totalFindings;
        snapshot.Process_Type__c = processType;
        snapshot.Scan_Type__c = scanType;

        // Severity counts
        if (result.findingsBySeverity != null) {
            snapshot.Critical_Count__c = result.findingsBySeverity.containsKey('Critical')
                ? result.findingsBySeverity.get('Critical') : 0;
            snapshot.High_Count__c = result.findingsBySeverity.containsKey('High')
                ? result.findingsBySeverity.get('High') : 0;
            snapshot.Medium_Count__c = result.findingsBySeverity.containsKey('Medium')
                ? result.findingsBySeverity.get('Medium') : 0;
            snapshot.Low_Count__c = result.findingsBySeverity.containsKey('Low')
                ? result.findingsBySeverity.get('Low') : 0;
        }

        // Serialize findings for PDF report and historical drill-down
        if (result.findings != null) {
            snapshot.Findings_JSON__c = JSON.serialize(result.findings);
        }

        insert snapshot;
    }

    /**
     * Returns the last N snapshots for a specific flow, newest first.
     * Used for the single-flow trend chart.
     *
     * @param flowDevName  Flow API name
     * @param maxRecords   Max records to return (default 10)
     * @return Ordered list of snapshot records
     */
    public static List<Flow_Health_Snapshot__c> getFlowHistory(String flowDevName, Integer maxRecords) {
        if (maxRecords == null || maxRecords <= 0) {
            maxRecords = 10;
        }
        return [
            SELECT Id, Score__c, Grade__c, Total_Findings__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Scan_Type__c, CreatedDate
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = :flowDevName
            ORDER BY CreatedDate DESC
            LIMIT :maxRecords
        ];
    }

    /**
     * Returns daily average scores across all flows for the last N days.
     * Used for the org-wide trend line on the Bulk Dashboard.
     *
     * @param days  Number of days to look back (default 30)
     * @return List of OrgTrendPoint with date and average score
     */
    public static List<OrgTrendPoint> getOrgTrendData(Integer days) {
        if (days == null || days <= 0) {
            days = 30;
        }
        DateTime cutoff = DateTime.now().addDays(-days);

        // Aggregate: group by calendar date, average score
        List<AggregateResult> aggResults = [
            SELECT DAY_ONLY(CreatedDate) scanDate,
                   AVG(Score__c) avgScore,
                   COUNT(Id) flowCount
            FROM Flow_Health_Snapshot__c
            WHERE CreatedDate >= :cutoff
            GROUP BY DAY_ONLY(CreatedDate)
            ORDER BY DAY_ONLY(CreatedDate) ASC
        ];

        List<OrgTrendPoint> points = new List<OrgTrendPoint>();
        for (AggregateResult ar : aggResults) {
            OrgTrendPoint pt = new OrgTrendPoint();
            pt.scanDate = (Date) ar.get('scanDate');
            pt.avgScore = ((Decimal) ar.get('avgScore')).intValue();
            pt.flowCount = (Integer) ar.get('flowCount');
            points.add(pt);
        }
        return points;
    }

    /**
     * Computes a trend summary for a specific flow: current vs. previous score,
     * delta, and direction (improving / declining / stable).
     *
     * @param flowDevName  Flow API name
     * @return TrendSummary with current, previous, delta, and direction
     */
    public static TrendSummary getFlowTrendSummary(String flowDevName) {
        List<Flow_Health_Snapshot__c> recent = [
            SELECT Score__c, Grade__c, CreatedDate
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = :flowDevName
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];

        TrendSummary summary = new TrendSummary();

        if (recent.isEmpty()) {
            summary.hasHistory = false;
            summary.isFirstScan = true;
            return summary;
        }

        summary.hasHistory = true;
        summary.currentScore = (Integer) recent[0].Score__c;
        summary.currentGrade = recent[0].Grade__c;

        if (recent.size() >= 2) {
            summary.isFirstScan = false;
            summary.previousScore = (Integer) recent[1].Score__c;
            summary.previousGrade = recent[1].Grade__c;
            summary.scoreDelta = summary.currentScore - summary.previousScore;

            if (summary.scoreDelta > 0) {
                summary.direction = 'improving';
            } else if (summary.scoreDelta < 0) {
                summary.direction = 'declining';
            } else {
                summary.direction = 'stable';
            }
        } else {
            summary.isFirstScan = true;
            summary.scoreDelta = 0;
            summary.direction = 'stable';
        }

        return summary;
    }

    // =========================================================================
    // WRAPPER CLASSES
    // =========================================================================

    /**
     * A single point on the org-wide trend line.
     */
    public class OrgTrendPoint {
        @AuraEnabled public Date scanDate;
        @AuraEnabled public Integer avgScore;
        @AuraEnabled public Integer flowCount;
    }

    /**
     * Summary of a flow's score trend compared to its previous analysis.
     */
    public class TrendSummary {
        @AuraEnabled public Boolean hasHistory = false;
        @AuraEnabled public Boolean isFirstScan = true;
        @AuraEnabled public Integer currentScore;
        @AuraEnabled public String currentGrade;
        @AuraEnabled public Integer previousScore;
        @AuraEnabled public String previousGrade;
        @AuraEnabled public Integer scoreDelta = 0;
        @AuraEnabled public String direction = 'stable'; // 'improving', 'declining', 'stable'
    }
}
