/**
 * FlowRuleDeployCallback - Handles the result of async metadata deployments
 * for Flow Health rule configuration changes.
 *
 * Sprint 4: Custom Rule Configuration
 *
 * Implements Metadata.DeployCallback to receive notification when
 * the metadata deployment (enqueued by FlowRuleConfigService) completes.
 */
public class FlowRuleDeployCallback implements Metadata.DeployCallback {

    /**
     * Called by the platform when the metadata deployment finishes.
     *
     * @param context  The deployment result with status and details
     * @param result   The metadata deploy result
     */
    public void handleResult(
        Metadata.DeployResult result,
        Metadata.DeployCallbackContext context
    ) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug(LoggingLevel.INFO,
                'FlowRuleDeployCallback: Rule configuration deployment succeeded. ' +
                'Job ID: ' + result.id);
        } else {
            String errorMsg = 'FlowRuleDeployCallback: Rule configuration deployment failed. ' +
                'Job ID: ' + result.id + ', Status: ' + result.status;

            if (result.errorMessage != null) {
                errorMsg += ', Error: ' + result.errorMessage;
            }

            System.debug(LoggingLevel.ERROR, errorMsg);
        }
    }
}
