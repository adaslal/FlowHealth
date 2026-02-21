/**
 * FlowDiffResult - Data model for structured flow version comparisons.
 *
 * When comparing two versions of a flow (old vs new), the FlowDiffService
 * produces a FlowDiffResult containing:
 *   1. A list of individual changes (added/removed/modified elements, resources, config)
 *   2. Health score delta (old score vs new score)
 *   3. Summary statistics (counts by change type and category)
 *   4. Regression flags (did health get worse?)
 *
 * Used by:
 *   - FlowDiffService (producer)
 *   - FlowHealthController (passes to LWC)
 *   - Compare Versions LWC UI (consumer)
 *
 * Design notes:
 *   - All properties are @AuraEnabled for direct LWC consumption
 *   - ChangeEntry uses a builder pattern consistent with FlowFinding
 *   - Categories match the flow structure: Elements, Resources, Configuration
 */
public class FlowDiffResult {

    // =========================================================================
    // Top-level diff result
    // =========================================================================

    /** The full comparison result returned to the LWC. */
    @AuraEnabled public List<ChangeEntry> changes;
    @AuraEnabled public Integer oldScore;
    @AuraEnabled public Integer newScore;
    @AuraEnabled public Integer scoreDelta;          // newScore - oldScore (negative = regression)
    @AuraEnabled public String oldGrade;
    @AuraEnabled public String newGrade;
    @AuraEnabled public Boolean isRegression;         // true if score dropped
    @AuraEnabled public Boolean isImprovement;        // true if score improved
    @AuraEnabled public DiffSummary summary;

    public FlowDiffResult() {
        this.changes = new List<ChangeEntry>();
        this.oldScore = 0;
        this.newScore = 0;
        this.scoreDelta = 0;
        this.isRegression = false;
        this.isImprovement = false;
    }

    /**
     * Populate score fields from two AnalysisResults.
     */
    public void setScores(
        FlowAnalysisService.AnalysisResult oldAnalysis,
        FlowAnalysisService.AnalysisResult newAnalysis
    ) {
        this.oldScore = oldAnalysis != null ? oldAnalysis.score : 0;
        this.newScore = newAnalysis != null ? newAnalysis.score : 0;
        this.scoreDelta = this.newScore - this.oldScore;
        this.oldGrade = oldAnalysis != null ? oldAnalysis.grade : 'N/A';
        this.newGrade = newAnalysis != null ? newAnalysis.grade : 'N/A';
        this.isRegression = this.scoreDelta < 0;
        this.isImprovement = this.scoreDelta > 0;
    }

    /**
     * Build the summary statistics from the changes list.
     * Call this after all changes have been added.
     */
    public void buildSummary() {
        this.summary = new DiffSummary();
        this.summary.totalChanges = this.changes.size();
        this.summary.added = 0;
        this.summary.removed = 0;
        this.summary.modified = 0;
        this.summary.changesByCategory = new Map<String, Integer>();

        for (ChangeEntry c : this.changes) {
            if (c.changeType == 'Added') {
                this.summary.added++;
            } else if (c.changeType == 'Removed') {
                this.summary.removed++;
            } else if (c.changeType == 'Modified') {
                this.summary.modified++;
            }

            String cat = c.category != null ? c.category : 'Other';
            if (!this.summary.changesByCategory.containsKey(cat)) {
                this.summary.changesByCategory.put(cat, 0);
            }
            this.summary.changesByCategory.put(
                cat, this.summary.changesByCategory.get(cat) + 1
            );
        }

        // Derive risk assessment
        this.summary.hasBreakingChanges = false;
        for (ChangeEntry c : this.changes) {
            if (c.riskLevel == 'High' || c.riskLevel == 'Critical') {
                this.summary.hasBreakingChanges = true;
                break;
            }
        }
    }

    // =========================================================================
    // ChangeEntry - a single diff item
    // =========================================================================

    /**
     * Represents one change between old and new versions.
     * Examples:
     *   - "Element 'Get_Account' was removed" (Removed, Elements)
     *   - "Decision 'Check_Status' modified: 2 rules → 3 rules" (Modified, Elements)
     *   - "Variable 'vAccountId' added" (Added, Resources)
     *   - "API Version changed from 58.0 to 62.0" (Modified, Configuration)
     */
    public class ChangeEntry {
        @AuraEnabled public String changeType;        // Added, Removed, Modified
        @AuraEnabled public String category;          // Elements, Resources, Configuration
        @AuraEnabled public String itemType;          // e.g., 'recordCreate', 'variable', 'processType'
        @AuraEnabled public String itemName;          // API name of the item
        @AuraEnabled public String itemLabel;         // Human-readable label
        @AuraEnabled public String description;       // What changed
        @AuraEnabled public String oldValue;          // Previous value (for Modified)
        @AuraEnabled public String newValue;          // New value (for Modified)
        @AuraEnabled public String riskLevel;         // Critical, High, Medium, Low, Info
        @AuraEnabled public String riskReason;        // Why this risk level

        public ChangeEntry(String changeType, String category) {
            this.changeType = changeType;
            this.category = category;
        }

        public ChangeEntry withItem(String itemType, String itemName, String itemLabel) {
            this.itemType = itemType;
            this.itemName = itemName;
            this.itemLabel = itemLabel != null ? itemLabel : itemName;
            return this;
        }

        public ChangeEntry withDescription(String description) {
            this.description = description;
            return this;
        }

        public ChangeEntry withValues(String oldValue, String newValue) {
            this.oldValue = oldValue;
            this.newValue = newValue;
            return this;
        }

        public ChangeEntry withRisk(String riskLevel, String riskReason) {
            this.riskLevel = riskLevel;
            this.riskReason = riskReason;
            return this;
        }
    }

    // =========================================================================
    // DiffSummary - aggregate statistics
    // =========================================================================

    public class DiffSummary {
        @AuraEnabled public Integer totalChanges;
        @AuraEnabled public Integer added;
        @AuraEnabled public Integer removed;
        @AuraEnabled public Integer modified;
        @AuraEnabled public Map<String, Integer> changesByCategory;
        @AuraEnabled public Boolean hasBreakingChanges;
    }
}
