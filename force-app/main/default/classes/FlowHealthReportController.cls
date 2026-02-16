/**
 * FlowHealthReportController - Controller for the FlowHealthReport
 * Visualforce page that renders as PDF.
 *
 * Sprint 4: Report Export
 *
 * The LWC passes a snapshot ID (or flow developer name) as a URL
 * parameter. This controller queries the snapshot and deserializes
 * the findings JSON for display in the PDF template.
 */
public with sharing class FlowHealthReportController {

    public Flow_Health_Snapshot__c snapshot { get; set; }
    public List<FindingDisplay> findings { get; set; }
    public Map<String, List<FindingDisplay>> findingsByCategory { get; set; }
    public List<String> categoryOrder { get; set; }
    public String reportDate { get; set; }
    public String scoreColorHex { get; set; }
    public String gradeLabel { get; set; }
    public Boolean hasFindings { get; set; }

    /**
     * Constructor: loads snapshot data from URL parameters.
     * Accepts either ?id=snapshotId or ?flow=flowDeveloperName
     */
    public FlowHealthReportController() {
        findings = new List<FindingDisplay>();
        findingsByCategory = new Map<String, List<FindingDisplay>>();
        categoryOrder = new List<String>();
        hasFindings = false;

        String snapshotId = ApexPages.currentPage().getParameters().get('id');
        String flowDevName = ApexPages.currentPage().getParameters().get('flow');

        if (String.isNotBlank(snapshotId)) {
            loadById(snapshotId);
        } else if (String.isNotBlank(flowDevName)) {
            loadByFlowName(flowDevName);
        }
    }

    private void loadById(String snapshotId) {
        List<Flow_Health_Snapshot__c> snapshots = [
            SELECT Id, Name, Flow_Developer_Name__c, Flow_Label__c,
                   Score__c, Grade__c, Total_Findings__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Process_Type__c, Scan_Type__c, Findings_JSON__c, CreatedDate
            FROM Flow_Health_Snapshot__c
            WHERE Id = :snapshotId
            LIMIT 1
        ];
        if (!snapshots.isEmpty()) {
            processSnapshot(snapshots[0]);
        }
    }

    private void loadByFlowName(String flowDevName) {
        List<Flow_Health_Snapshot__c> snapshots = [
            SELECT Id, Name, Flow_Developer_Name__c, Flow_Label__c,
                   Score__c, Grade__c, Total_Findings__c,
                   Critical_Count__c, High_Count__c, Medium_Count__c, Low_Count__c,
                   Process_Type__c, Scan_Type__c, Findings_JSON__c, CreatedDate
            FROM Flow_Health_Snapshot__c
            WHERE Flow_Developer_Name__c = :flowDevName
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!snapshots.isEmpty()) {
            processSnapshot(snapshots[0]);
        }
    }

    private void processSnapshot(Flow_Health_Snapshot__c snap) {
        this.snapshot = snap;
        this.reportDate = snap.CreatedDate.format('MMMM d, yyyy \'at\' h:mm a');
        this.scoreColorHex = getScoreColor((Integer) snap.Score__c);
        this.gradeLabel = getGradeLabel(snap.Grade__c);

        // Deserialize findings JSON
        if (String.isNotBlank(snap.Findings_JSON__c)) {
            try {
                List<FlowFinding> rawFindings =
                    (List<FlowFinding>) JSON.deserialize(
                        snap.Findings_JSON__c, List<FlowFinding>.class
                    );

                for (Integer i = 0; i < rawFindings.size(); i++) {
                    FlowFinding f = rawFindings[i];
                    FindingDisplay fd = new FindingDisplay();
                    fd.index = i + 1;
                    fd.ruleId = f.ruleId;
                    fd.ruleName = f.ruleName;
                    fd.category = f.category;
                    fd.severity = f.severity;
                    fd.severityColor = getSeverityColor(f.severity);
                    fd.elementName = f.elementName;
                    fd.elementType = f.elementType;
                    fd.description = f.description;
                    fd.remediation = f.remediation;
                    fd.hasElement = String.isNotBlank(f.elementName);
                    findings.add(fd);

                    // Group by category
                    String cat = String.isNotBlank(f.category) ? f.category : 'Other';
                    if (!findingsByCategory.containsKey(cat)) {
                        findingsByCategory.put(cat, new List<FindingDisplay>());
                        categoryOrder.add(cat);
                    }
                    findingsByCategory.get(cat).add(fd);
                }

                hasFindings = !findings.isEmpty();
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'FlowHealthReportController: Failed to parse findings JSON: ' + e.getMessage());
            }
        }
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private String getScoreColor(Integer score) {
        if (score >= 90) return '#04844B';
        if (score >= 80) return '#2E844A';
        if (score >= 70) return '#DD7A01';
        if (score >= 60) return '#BA5005';
        return '#C23934';
    }

    private String getGradeLabel(String grade) {
        if (grade == 'A') return 'Excellent';
        if (grade == 'B') return 'Good';
        if (grade == 'C') return 'Fair';
        if (grade == 'D') return 'Needs Work';
        return 'Critical';
    }

    private String getSeverityColor(String severity) {
        if (severity == 'Critical') return '#C23934';
        if (severity == 'High') return '#E87400';
        if (severity == 'Medium') return '#F4BC25';
        return '#0176D3';
    }

    // =========================================================================
    // INNER CLASSES
    // =========================================================================

    public class FindingDisplay {
        public Integer index { get; set; }
        public String ruleId { get; set; }
        public String ruleName { get; set; }
        public String category { get; set; }
        public String severity { get; set; }
        public String severityColor { get; set; }
        public String elementName { get; set; }
        public String elementType { get; set; }
        public String description { get; set; }
        public String remediation { get; set; }
        public Boolean hasElement { get; set; }
    }
}
