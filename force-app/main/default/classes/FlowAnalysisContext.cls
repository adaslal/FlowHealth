/**
 * FlowAnalysisContext - Pre-computed analysis data for flow health rules.
 *
 * Built once per flow analysis, this context provides O(1) lookups
 * for common questions rules need to answer, like "is this element
 * inside a loop?" — without each rule needing its own graph traversal.
 *
 * The engine constructs this before running any rules. Rules receive
 * it as a parameter alongside the flow definition.
 */
public class FlowAnalysisContext {

    /** Map of element name -> FlowElement for quick lookup */
    public Map<String, FlowMetadata.FlowElement> elementMap { get; private set; }

    /** Map of loop name -> set of element names inside that loop's body */
    public Map<String, Set<String>> loopBodies { get; private set; }

    /** Flat set of all element names that are inside any loop */
    private Set<String> allElementsInsideLoops;

    /**
     * Construct a new context by analyzing a flow definition.
     * Pre-computes element map and loop body membership.
     */
    public FlowAnalysisContext(FlowMetadata.FlowDefinition flow) {
        this.elementMap = flow.getElementMap();
        this.loopBodies = new Map<String, Set<String>>();
        this.allElementsInsideLoops = new Set<String>();
        computeLoopBodies(flow);
    }

    /**
     * Returns true if the named element is inside any loop.
     * Used by DmlInLoopRule, SoqlInLoopRule, SubflowInLoopRule.
     */
    public Boolean isInsideLoop(String elementName) {
        return allElementsInsideLoops.contains(elementName);
    }

    /**
     * Returns the names of all loops that contain the given element.
     * Useful for generating descriptive finding messages.
     */
    public List<String> getContainingLoops(String elementName) {
        List<String> result = new List<String>();
        for (String loopName : loopBodies.keySet()) {
            if (loopBodies.get(loopName).contains(elementName)) {
                result.add(loopName);
            }
        }
        return result;
    }

    /**
     * Returns the element immediately after a connector, or null.
     * Convenience method for rules that inspect element sequencing.
     */
    public FlowMetadata.FlowElement getNextElement(FlowMetadata.FlowConnector conn) {
        if (conn == null || conn.targetReference == null) {
            return null;
        }
        return elementMap.get(conn.targetReference);
    }

    // =========================================================================
    // Private: Loop body computation via BFS
    // =========================================================================

    private void computeLoopBodies(FlowMetadata.FlowDefinition flow) {
        if (flow.loops == null || flow.loops.isEmpty()) {
            return;
        }
        for (FlowMetadata.FlowLoop flowLoop : flow.loops) {
            Set<String> body = traverseLoopBody(flowLoop);
            loopBodies.put(flowLoop.name, body);
            allElementsInsideLoops.addAll(body);
        }
    }

    /**
     * BFS traversal starting from a loop's internal path.
     * Collects all elements reachable from inside the loop body,
     * stopping when we cycle back to the loop element itself
     * or hit an already-visited node (prevents infinite traversal).
     */
    private Set<String> traverseLoopBody(FlowMetadata.FlowLoop flowLoop) {
        Set<String> visited = new Set<String>();
        List<String> queue = new List<String>();

        // Start from the first element inside the loop
        if (flowLoop.nextValueConnector != null &&
            flowLoop.nextValueConnector.targetReference != null) {
            queue.add(flowLoop.nextValueConnector.targetReference);
        }

        while (!queue.isEmpty()) {
            String current = queue.remove(0);

            // Skip nulls, already-visited, or if we've looped back to the loop element
            if (current == null || visited.contains(current) || current == flowLoop.name) {
                continue;
            }

            visited.add(current);

            FlowMetadata.FlowElement el = elementMap.get(current);
            if (el == null) {
                continue;
            }

            // Follow standard connectors (available on all FlowElement subclasses)
            enqueueConnector(el.connector, queue);
            enqueueConnector(el.faultConnector, queue);

            // Follow type-specific connectors
            if (el instanceof FlowMetadata.FlowDecision) {
                FlowMetadata.FlowDecision dec = (FlowMetadata.FlowDecision) el;
                enqueueConnector(dec.defaultConnector, queue);
                if (dec.rules != null) {
                    for (FlowMetadata.FlowRule r : dec.rules) {
                        enqueueConnector(r.connector, queue);
                    }
                }
            } else if (el instanceof FlowMetadata.FlowLoop) {
                FlowMetadata.FlowLoop innerLoop = (FlowMetadata.FlowLoop) el;
                enqueueConnector(innerLoop.nextValueConnector, queue);
                enqueueConnector(innerLoop.noMoreValuesConnector, queue);
            } else if (el instanceof FlowMetadata.FlowWait) {
                FlowMetadata.FlowWait w = (FlowMetadata.FlowWait) el;
                enqueueConnector(w.defaultConnector, queue);
                if (w.waitEvents != null) {
                    for (FlowMetadata.FlowWaitEvent evt : w.waitEvents) {
                        enqueueConnector(evt.connector, queue);
                    }
                }
            }
        }

        return visited;
    }

    private void enqueueConnector(FlowMetadata.FlowConnector conn, List<String> queue) {
        if (conn != null && conn.targetReference != null) {
            queue.add(conn.targetReference);
        }
    }
}
