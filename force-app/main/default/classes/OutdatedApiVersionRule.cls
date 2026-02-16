/**
 * OutdatedApiVersionRule (DES-003) - Design
 *
 * Detects flows running on outdated Salesforce API versions.
 * Older API versions miss out on:
 * - Performance improvements in the flow engine
 * - New features (e.g., reactive screens, transform elements)
 * - Security patches and bug fixes
 * - Governor limit enhancements
 *
 * Salesforce recommends keeping flows on a recent API version.
 * This rule flags flows that are more than 4 major versions behind current.
 */
public class OutdatedApiVersionRule implements FlowRule {

    // Current Salesforce API version (Spring '25 = 63.0)
    // Update this each release or make configurable via Custom Metadata
    private static final Decimal CURRENT_API_VERSION = 63.0;

    // Threshold: flag if more than this many versions behind
    private static final Integer VERSION_LAG_THRESHOLD = 4;

    // Severely outdated threshold (triggers Critical severity)
    private static final Integer SEVERE_LAG_THRESHOLD = 10;

    public List<FlowFinding> evaluate(FlowMetadata.FlowDefinition flow, FlowAnalysisContext ctx) {
        List<FlowFinding> findings = new List<FlowFinding>();

        if (flow.apiVersion == null) return findings;

        Decimal flowVersion;
        try {
            flowVersion = Decimal.valueOf(flow.apiVersion);
        } catch (Exception e) {
            return findings; // Can't parse version, skip
        }

        Decimal versionsBehind = CURRENT_API_VERSION - flowVersion;

        if (versionsBehind >= VERSION_LAG_THRESHOLD) {
            String severity = versionsBehind >= SEVERE_LAG_THRESHOLD ? 'High' : 'Medium';

            String flowLabel = flow.label != null ? flow.label : 'This flow';

            findings.add(
                new FlowFinding('DES-003', 'Outdated API Version', 'Design', severity)
                    .withDescription(
                        flowLabel + ' is running on API version ' + flow.apiVersion +
                        ', which is ' + versionsBehind.intValue() + ' versions behind the current version (' +
                        CURRENT_API_VERSION.toPlainString() + '). ' +
                        'Outdated versions miss performance improvements, security patches, and new features.'
                    )
                    .withRemediation(
                        'Open this flow in Flow Builder, go to Flow Details, and update the API version to ' +
                        CURRENT_API_VERSION.toPlainString() + '. Test thoroughly after upgrading, as behavior ' +
                        'changes between versions may affect flow logic.'
                    )
            );
        }

        return findings;
    }
}
