/**
 * FlowRuleConfigService - Manages reading and updating Flow Health rule
 * configurations via the Metadata API.
 *
 * Sprint 4: Custom Rule Configuration
 *
 * Custom Metadata records (Flow_Health_Rule__mdt) can't be updated via
 * standard DML. Instead, we use Metadata.Operations.enqueueDeployment()
 * to submit an async metadata deployment.
 *
 * The deployment callback (FlowRuleDeployCallback) handles success/failure.
 */
public with sharing class FlowRuleConfigService {

    /**
     * Deploys modified rule configurations to Custom Metadata.
     *
     * @param rulesJson  JSON array of objects with:
     *   - developerName (String): DeveloperName of the rule record
     *   - severity (String): New severity value
     *   - weight (Decimal): New weight value
     *   - maxDeduction (Decimal): New max deduction value
     *   - isActive (Boolean): New active state
     * @return The deployment job ID for status tracking
     */
    public static String deployRuleChanges(String rulesJson) {
        List<RuleChangeRequest> changes =
            (List<RuleChangeRequest>) JSON.deserialize(rulesJson, List<RuleChangeRequest>.class);

        if (changes == null || changes.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('No rule changes provided.');
            ex.setMessage('No rule changes provided.');
            throw ex;
        }

        Metadata.DeployContainer container = new Metadata.DeployContainer();

        for (RuleChangeRequest change : changes) {
            Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
            cmd.fullName = 'Flow_Health_Rule.' + change.developerName;
            cmd.label = change.label;

            // Severity
            Metadata.CustomMetadataValue severityVal = new Metadata.CustomMetadataValue();
            severityVal.field = 'Severity__c';
            severityVal.value = change.severity;
            cmd.values.add(severityVal);

            // Weight
            Metadata.CustomMetadataValue weightVal = new Metadata.CustomMetadataValue();
            weightVal.field = 'Weight__c';
            weightVal.value = change.weight;
            cmd.values.add(weightVal);

            // Max Deduction
            Metadata.CustomMetadataValue maxDeductionVal = new Metadata.CustomMetadataValue();
            maxDeductionVal.field = 'Max_Deduction__c';
            maxDeductionVal.value = change.maxDeduction;
            cmd.values.add(maxDeductionVal);

            // Is Active
            Metadata.CustomMetadataValue isActiveVal = new Metadata.CustomMetadataValue();
            isActiveVal.field = 'Is_Active__c';
            isActiveVal.value = change.isActive;
            cmd.values.add(isActiveVal);

            container.addMetadata(cmd);
        }

        // Enqueue the deployment with our callback handler
        Id jobId = Metadata.Operations.enqueueDeployment(
            container,
            new FlowRuleDeployCallback()
        );

        return String.valueOf(jobId);
    }

    /**
     * Checks the REAL status of an async metadata deployment by querying
     * DeployRequest via the Tooling API (same Named Credential the rest of
     * the app already requires).
     *
     * @param jobId  The deployment job ID from enqueueDeployment
     * @return 'Pending' | 'InProgress' | 'Succeeded' | 'Failed' | 'Unknown'
     *         'Unknown' means the status could not be confirmed (e.g. the
     *         Named Credential is unavailable) — the LWC shows a neutral
     *         "submitted, verify in Setup" message instead of a fake success.
     */
    public static String checkDeploymentStatus(String jobId) {
        if (String.isBlank(jobId)) return 'Unknown';
        try {
            String query = 'SELECT Id, Status FROM DeployRequest '
                         + 'WHERE Id = \'' + String.escapeSingleQuotes(jobId) + '\'';
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:FlowHealth_SelfOrg/services/data/v62.0/tooling/query'
                + '?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(15000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) return 'Unknown';

            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) body.get('records');
            if (records == null || records.isEmpty()) return 'Unknown';

            String status = (String) ((Map<String, Object>) records[0]).get('Status');
            if (status == 'Succeeded') return 'Succeeded';
            if (status == 'Failed' || status == 'Canceled' || status == 'Canceling') return 'Failed';
            if (status == 'Pending') return 'Pending';
            if (status == 'InProgress' || status == 'SucceededPartial') return 'InProgress';
            return 'Unknown';
        } catch (Exception e) {
            // Named Credential missing/misconfigured — never fake a success
            return 'Unknown';
        }
    }

    // =========================================================================
    // INNER CLASSES
    // =========================================================================

    /**
     * Deserialization target for rule change requests from the LWC.
     */
    public class RuleChangeRequest {
        public String developerName;
        public String label;
        public String severity;
        public Decimal weight;
        public Decimal maxDeduction;
        public Boolean isActive;
    }
}
