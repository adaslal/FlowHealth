/**
 * FlowScoreCalculator - Calculates a 0-100 health score from findings.
 *
 * SCORING ALGORITHM:
 * - Start at 100 (perfect score)
 * - Deduct points for each finding: weight × severity multiplier
 * - Apply diminishing returns: 2nd finding of same rule costs less
 *   than the 1st, 3rd costs less than 2nd, etc.
 * - Cap deductions per rule (Max_Deduction__c from Custom Metadata)
 * - Final score clamped to [0, 100]
 *
 * DIMINISHING RETURNS FORMULA:
 *   deduction = weight × severityMultiplier × (1 / (1 + 0.3 × i))
 *   where i = 0-based index of the finding within its rule group
 *
 * This means: first DML-in-loop = full weight, second = ~77%,
 * third = ~63%, etc. Prevents a single rule from obliterating
 * the score when a flow has many similar violations.
 *
 * GRADE SCALE:
 *   A (90-100): Excellent  |  B (80-89): Good
 *   C (70-79): Fair        |  D (60-69): Needs Work
 *   F (0-59): Critical
 */
public class FlowScoreCalculator {

    private static final Integer BASE_SCORE = 100;
    private static final Decimal DIMINISHING_FACTOR = 0.3;

    // Severity multipliers — Critical findings cost full weight,
    // lower severities cost proportionally less
    private static final Map<String, Decimal> SEVERITY_MULTIPLIERS = new Map<String, Decimal>{
        'Critical' => 1.0,
        'High'     => 0.75,
        'Medium'   => 0.5,
        'Low'      => 0.25
    };

    /**
     * Result object returned to callers.
     */
    public class ScoreResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String grade;
        @AuraEnabled public String gradeLabel;
        @AuraEnabled public String gradeColor;
        @AuraEnabled public Map<String, Integer> categoryScores;
    }

    /**
     * Calculate the health score from a list of findings.
     */
    public ScoreResult calculate(List<FlowFinding> findings) {
        ScoreResult result = new ScoreResult();

        if (findings == null || findings.isEmpty()) {
            result.score = BASE_SCORE;
            result.categoryScores = new Map<String, Integer>();
            assignGrade(result);
            return result;
        }

        // Group findings by ruleId for diminishing returns
        Map<String, List<FlowFinding>> findingsByRule = new Map<String, List<FlowFinding>>();
        for (FlowFinding f : findings) {
            if (!findingsByRule.containsKey(f.ruleId)) {
                findingsByRule.put(f.ruleId, new List<FlowFinding>());
            }
            findingsByRule.get(f.ruleId).add(f);
        }

        // Load max deductions from Custom Metadata
        Map<String, Decimal> maxDeductions = getMaxDeductions();

        // Calculate deductions
        Decimal totalDeduction = 0;
        Map<String, Decimal> categoryDeductions = new Map<String, Decimal>();

        for (String ruleId : findingsByRule.keySet()) {
            List<FlowFinding> ruleFindings = findingsByRule.get(ruleId);
            Decimal ruleDeduction = 0;

            for (Integer i = 0; i < ruleFindings.size(); i++) {
                FlowFinding f = ruleFindings[i];
                Integer weight = f.weight != null ? f.weight : 5;
                Decimal severityMult = SEVERITY_MULTIPLIERS.containsKey(f.severity)
                    ? SEVERITY_MULTIPLIERS.get(f.severity)
                    : 0.5;

                // Diminishing returns per additional finding of same rule
                Decimal diminishing = 1.0 / (1.0 + DIMINISHING_FACTOR * i);
                ruleDeduction += weight * severityMult * diminishing;
            }

            // Apply max deduction cap
            if (maxDeductions.containsKey(ruleId)) {
                ruleDeduction = Math.min(ruleDeduction, maxDeductions.get(ruleId));
            }

            totalDeduction += ruleDeduction;

            // Track deductions by category
            String category = ruleFindings[0].category;
            if (!categoryDeductions.containsKey(category)) {
                categoryDeductions.put(category, 0);
            }
            categoryDeductions.put(category,
                categoryDeductions.get(category) + ruleDeduction);
        }

        // Calculate final score
        result.score = (Integer) Math.max(0,
            Math.min(BASE_SCORE, Math.round(BASE_SCORE - totalDeduction)));

        // Calculate per-category scores (100 minus category deductions)
        result.categoryScores = new Map<String, Integer>();
        for (String category : categoryDeductions.keySet()) {
            Integer catScore = (Integer) Math.max(0,
                Math.round(100 - categoryDeductions.get(category)));
            result.categoryScores.put(category, catScore);
        }

        assignGrade(result);
        return result;
    }

    private void assignGrade(ScoreResult result) {
        if (result.score >= 90) {
            result.grade = 'A';
            result.gradeLabel = 'Excellent';
            result.gradeColor = '#04844B'; // Salesforce success green
        } else if (result.score >= 80) {
            result.grade = 'B';
            result.gradeLabel = 'Good';
            result.gradeColor = '#2E844A';
        } else if (result.score >= 70) {
            result.grade = 'C';
            result.gradeLabel = 'Fair';
            result.gradeColor = '#DD7A01'; // Salesforce warning amber
        } else if (result.score >= 60) {
            result.grade = 'D';
            result.gradeLabel = 'Needs Work';
            result.gradeColor = '#BA5005';
        } else {
            result.grade = 'F';
            result.gradeLabel = 'Critical';
            result.gradeColor = '#C23934'; // Salesforce error red
        }
    }

    private Map<String, Decimal> getMaxDeductions() {
        Map<String, Decimal> maxDed = new Map<String, Decimal>();
        for (Flow_Health_Rule__mdt rule : [
            SELECT Rule_Id__c, Max_Deduction__c
            FROM Flow_Health_Rule__mdt
            WHERE Is_Active__c = true
              AND Max_Deduction__c != null
        ]) {
            maxDed.put(rule.Rule_Id__c, rule.Max_Deduction__c);
        }
        return maxDed;
    }
}
