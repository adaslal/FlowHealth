/**
 * FlowDiffService - Structured diff engine for comparing two flow versions.
 *
 * ALGORITHM:
 * 1. Compare configuration fields (processType, apiVersion, triggerType, runInMode, etc.)
 * 2. Compare elements by name (added/removed/modified for each element type)
 * 3. Compare resources by name (variables, formulas, constants, textTemplates, choices)
 * 4. Run health analysis on both versions to compute score delta
 * 5. Assign risk levels to each change based on impact
 *
 * USAGE:
 *   FlowDiffService differ = new FlowDiffService();
 *   FlowDiffResult result = differ.compare(oldFlow, newFlow);
 *
 * The result contains a flat list of ChangeEntry objects plus summary statistics
 * and health score deltas. The LWC can group/filter/sort as needed.
 */
public class FlowDiffService {

    // =========================================================================
    // Public API
    // =========================================================================

    /**
     * Compare two flow definitions and produce a structured diff.
     * Also runs health analysis on both versions to show score impact.
     *
     * @param oldFlow  The previous version of the flow
     * @param newFlow  The current/newer version of the flow
     * @return FlowDiffResult with all changes, scores, and summary
     */
    public FlowDiffResult compare(
        FlowMetadata.FlowDefinition oldFlow,
        FlowMetadata.FlowDefinition newFlow
    ) {
        FlowDiffResult result = new FlowDiffResult();

        // 1. Compare configuration
        compareConfiguration(oldFlow, newFlow, result);

        // 2. Compare elements (by type)
        compareElementList('actionCalls', 'Action Call',
            oldFlow.actionCalls, newFlow.actionCalls, result);
        compareElementList('assignments', 'Assignment',
            oldFlow.assignments, newFlow.assignments, result);
        compareDecisions(oldFlow.decisions, newFlow.decisions, result);
        compareLoops(oldFlow.loops, newFlow.loops, result);
        compareElementList('recordCreates', 'Record Create',
            oldFlow.recordCreates, newFlow.recordCreates, result);
        compareElementList('recordUpdates', 'Record Update',
            oldFlow.recordUpdates, newFlow.recordUpdates, result);
        compareElementList('recordDeletes', 'Record Delete',
            oldFlow.recordDeletes, newFlow.recordDeletes, result);
        compareRecordLookups(oldFlow.recordLookups, newFlow.recordLookups, result);
        compareScreens(oldFlow.screens, newFlow.screens, result);
        compareSubflows(oldFlow.subflows, newFlow.subflows, result);
        compareElementList('waits', 'Wait',
            oldFlow.waits, newFlow.waits, result);

        // 3. Compare resources
        compareVariables(oldFlow.variables, newFlow.variables, result);
        compareFormulas(oldFlow.formulas, newFlow.formulas, result);
        compareConstants(oldFlow.constants, newFlow.constants, result);
        compareTextTemplates(oldFlow.textTemplates, newFlow.textTemplates, result);
        compareChoices(oldFlow.choices, newFlow.choices, result);

        // 4. Compare start element
        compareStart(oldFlow.start, newFlow.start, result);

        // 5. Run health analysis on both to get score delta
        FlowAnalysisService.AnalysisResult oldAnalysis =
            FlowAnalysisService.analyzeFlowDefinition(oldFlow);
        FlowAnalysisService.AnalysisResult newAnalysis =
            FlowAnalysisService.analyzeFlowDefinition(newFlow);
        result.setScores(oldAnalysis, newAnalysis);

        // 6. Build summary
        result.buildSummary();

        return result;
    }

    // =========================================================================
    // Configuration comparison
    // =========================================================================

    private void compareConfiguration(
        FlowMetadata.FlowDefinition oldFlow,
        FlowMetadata.FlowDefinition newFlow,
        FlowDiffResult result
    ) {
        compareConfigField('processType', 'Process Type',
            oldFlow.processType, newFlow.processType, 'High',
            'Changing process type can fundamentally alter flow behavior', result);

        compareConfigField('apiVersion', 'API Version',
            oldFlow.apiVersion, newFlow.apiVersion, 'Medium',
            'API version changes may affect platform behavior', result);

        compareConfigField('triggerType', 'Trigger Type',
            oldFlow.triggerType, newFlow.triggerType, 'High',
            'Trigger type changes affect when the flow executes', result);

        compareConfigField('runInMode', 'Run Mode',
            oldFlow.runInMode, newFlow.runInMode, 'High',
            'Run mode changes affect security context and data access', result);

        compareConfigField('description', 'Description',
            oldFlow.description, newFlow.description, 'Info',
            'Documentation change only', result);

        compareConfigField('label', 'Label',
            oldFlow.label, newFlow.label, 'Low',
            'Display label changed', result);
    }

    private void compareConfigField(
        String fieldName, String fieldLabel,
        String oldVal, String newVal,
        String riskLevel, String riskReason,
        FlowDiffResult result
    ) {
        String oldSafe = oldVal != null ? oldVal : '';
        String newSafe = newVal != null ? newVal : '';
        if (oldSafe != newSafe) {
            // Configuration changes are always functional (never cosmetic)
            result.changes.add(
                new FlowDiffResult.ChangeEntry('Modified', 'Configuration')
                    .withItem('config', fieldName, fieldLabel)
                    .withDescription(fieldLabel + ' changed from "' + oldSafe + '" to "' + newSafe + '"')
                    .withValues(oldSafe, newSafe)
                    .withRisk(riskLevel, riskReason)
                    .withSemantics(false, oldSafe, newSafe)
            );
        }
    }

    // =========================================================================
    // Generic element list comparison (for simple element types)
    // =========================================================================

    private void compareElementList(
        String typeName, String typeLabel,
        List<FlowMetadata.FlowElement> oldList,
        List<FlowMetadata.FlowElement> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowElement> oldMap = buildElementMap(oldList);
        Map<String, FlowMetadata.FlowElement> newMap = buildElementMap(newList);

        // Added elements
        for (String name : newMap.keySet()) {
            if (!oldMap.containsKey(name)) {
                FlowMetadata.FlowElement el = newMap.get(name);
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Added', 'Elements')
                        .withItem(typeName, name, el.label)
                        .withDescription(typeLabel + ' "' + name + '" was added')
                        .withRisk('Medium', 'New element added to the flow')
                );
            }
        }

        // Removed elements
        for (String name : oldMap.keySet()) {
            if (!newMap.containsKey(name)) {
                FlowMetadata.FlowElement el = oldMap.get(name);
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Removed', 'Elements')
                        .withItem(typeName, name, el.label)
                        .withDescription(typeLabel + ' "' + name + '" was removed')
                        .withRisk('High', 'Removing elements may break downstream references')
                );
            }
        }

        // Modified elements (basic: label, description, connector changes)
        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowElement oldEl = oldMap.get(name);
                FlowMetadata.FlowElement newEl = newMap.get(name);
                compareBaseElement(typeName, typeLabel, oldEl, newEl, result);
            }
        }
    }

    private void compareBaseElement(
        String typeName, String typeLabel,
        FlowMetadata.FlowElement oldEl,
        FlowMetadata.FlowElement newEl,
        FlowDiffResult result
    ) {
        List<String> changes = new List<String>();

        if (strChanged(oldEl.label, newEl.label)) {
            changes.add('label changed');
        }
        if (strChanged(oldEl.description, newEl.description)) {
            changes.add('description updated');
        }
        if (connectorChanged(oldEl.connector, newEl.connector)) {
            changes.add('connector target changed');
        }
        if (connectorChanged(oldEl.faultConnector, newEl.faultConnector)) {
            changes.add('fault connector changed');
        }

        if (!changes.isEmpty()) {
            // Compute logic signatures to determine if change is cosmetic
            String oldSig = computeElementSignature(typeName, oldEl);
            String newSig = computeElementSignature(typeName, newEl);
            Boolean isCosmetic = (oldSig == newSig);

            result.changes.add(
                new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                    .withItem(typeName, newEl.name, newEl.label)
                    .withDescription(typeLabel + ' "' + newEl.name + '": '
                        + String.join(changes, ', '))
                    .withRisk(isCosmetic ? 'Info' : 'Medium',
                        isCosmetic ? 'Cosmetic change only (layout/connector)' : 'Element configuration changed')
                    .withSemantics(isCosmetic, oldSig, newSig)
            );
        }
    }

    /**
     * Dispatches to the correct signature method based on element type.
     * Used by compareBaseElement for generic elements (actionCalls, assignments, etc.)
     * that go through the generic compareElementList pipeline.
     */
    private String computeElementSignature(String typeName, FlowMetadata.FlowElement el) {
        // For generic elements routed through compareBaseElement, use the base signature.
        // Specialized types (decisions, loops, etc.) have their own compare methods
        // that call FlowLogicSignature directly.
        return FlowLogicSignature.forElement(el);
    }

    // =========================================================================
    // Specialized element comparisons (types with extra fields)
    // =========================================================================

    private void compareDecisions(
        List<FlowMetadata.FlowDecision> oldList,
        List<FlowMetadata.FlowDecision> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowDecision> oldMap = buildDecisionMap(oldList);
        Map<String, FlowMetadata.FlowDecision> newMap = buildDecisionMap(newList);

        addedRemovedElement('decisions', 'Decision', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowDecision oldDec = oldMap.get(name);
                FlowMetadata.FlowDecision newDec = newMap.get(name);
                List<String> changes = new List<String>();

                Integer oldRuleCount = oldDec.rules != null ? oldDec.rules.size() : 0;
                Integer newRuleCount = newDec.rules != null ? newDec.rules.size() : 0;
                if (oldRuleCount != newRuleCount) {
                    changes.add('outcomes changed from ' + oldRuleCount + ' to ' + newRuleCount);
                }
                if (strChanged(oldDec.label, newDec.label)) {
                    changes.add('label changed');
                }
                if (connectorChanged(oldDec.defaultConnector, newDec.defaultConnector)) {
                    changes.add('default path changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forDecision(oldDec);
                    String newSig = FlowLogicSignature.forDecision(newDec);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                            .withItem('decisions', name, newDec.label)
                            .withDescription('Decision "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'High',
                                isCosmetic ? 'Cosmetic change only (connector routing)' : 'Decision logic changes affect branching')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareLoops(
        List<FlowMetadata.FlowLoop> oldList,
        List<FlowMetadata.FlowLoop> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowLoop> oldMap = buildLoopMap(oldList);
        Map<String, FlowMetadata.FlowLoop> newMap = buildLoopMap(newList);

        addedRemovedElement('loops', 'Loop', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowLoop oldLoop = oldMap.get(name);
                FlowMetadata.FlowLoop newLoop = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldLoop.collectionReference, newLoop.collectionReference)) {
                    changes.add('collection changed from "' + safe(oldLoop.collectionReference)
                        + '" to "' + safe(newLoop.collectionReference) + '"');
                }
                if (strChanged(oldLoop.iterationOrder, newLoop.iterationOrder)) {
                    changes.add('iteration order changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forLoop(oldLoop);
                    String newSig = FlowLogicSignature.forLoop(newLoop);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                            .withItem('loops', name, newLoop.label)
                            .withDescription('Loop "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'Medium',
                                isCosmetic ? 'Cosmetic change only' : 'Loop configuration changed')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareRecordLookups(
        List<FlowMetadata.FlowRecordLookup> oldList,
        List<FlowMetadata.FlowRecordLookup> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowRecordLookup> oldMap = buildRecordLookupMap(oldList);
        Map<String, FlowMetadata.FlowRecordLookup> newMap = buildRecordLookupMap(newList);

        addedRemovedElement('recordLookups', 'Record Lookup', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowRecordLookup oldLookup = oldMap.get(name);
                FlowMetadata.FlowRecordLookup newLookup = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldLookup.object_x, newLookup.object_x)) {
                    changes.add('object changed from "' + safe(oldLookup.object_x)
                        + '" to "' + safe(newLookup.object_x) + '"');
                }
                if (oldLookup.getFirstRecordOnly != newLookup.getFirstRecordOnly) {
                    changes.add('getFirstRecordOnly changed');
                }
                Integer oldFilterCount = oldLookup.filters != null ? oldLookup.filters.size() : 0;
                Integer newFilterCount = newLookup.filters != null ? newLookup.filters.size() : 0;
                if (oldFilterCount != newFilterCount) {
                    changes.add('filter count changed from ' + oldFilterCount + ' to ' + newFilterCount);
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forRecordLookup(oldLookup);
                    String newSig = FlowLogicSignature.forRecordLookup(newLookup);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                            .withItem('recordLookups', name, newLookup.label)
                            .withDescription('Record Lookup "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'High',
                                isCosmetic ? 'Cosmetic change only' : 'Query changes affect data retrieval')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareScreens(
        List<FlowMetadata.FlowScreen> oldList,
        List<FlowMetadata.FlowScreen> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowScreen> oldMap = buildScreenMap(oldList);
        Map<String, FlowMetadata.FlowScreen> newMap = buildScreenMap(newList);

        addedRemovedElement('screens', 'Screen', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowScreen oldScreen = oldMap.get(name);
                FlowMetadata.FlowScreen newScreen = newMap.get(name);
                List<String> changes = new List<String>();

                Integer oldFieldCount = oldScreen.fields != null ? oldScreen.fields.size() : 0;
                Integer newFieldCount = newScreen.fields != null ? newScreen.fields.size() : 0;
                if (oldFieldCount != newFieldCount) {
                    changes.add('field count changed from ' + oldFieldCount + ' to ' + newFieldCount);
                }
                if (strChanged(oldScreen.label, newScreen.label)) {
                    changes.add('label changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forScreen(oldScreen);
                    String newSig = FlowLogicSignature.forScreen(newScreen);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                            .withItem('screens', name, newScreen.label)
                            .withDescription('Screen "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'Medium',
                                isCosmetic ? 'Cosmetic change only' : 'Screen UI changed')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareSubflows(
        List<FlowMetadata.FlowSubflow> oldList,
        List<FlowMetadata.FlowSubflow> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowSubflow> oldMap = buildSubflowMap(oldList);
        Map<String, FlowMetadata.FlowSubflow> newMap = buildSubflowMap(newList);

        addedRemovedElement('subflows', 'Subflow', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowSubflow oldSf = oldMap.get(name);
                FlowMetadata.FlowSubflow newSf = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldSf.flowName, newSf.flowName)) {
                    changes.add('referenced flow changed from "' + safe(oldSf.flowName)
                        + '" to "' + safe(newSf.flowName) + '"');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forSubflow(oldSf);
                    String newSig = FlowLogicSignature.forSubflow(newSf);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Elements')
                            .withItem('subflows', name, newSf.label)
                            .withDescription('Subflow "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'High',
                                isCosmetic ? 'Cosmetic change only' : 'Subflow reference changes affect downstream flows')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    // =========================================================================
    // Start element comparison
    // =========================================================================

    private void compareStart(
        FlowMetadata.FlowStart oldStart,
        FlowMetadata.FlowStart newStart,
        FlowDiffResult result
    ) {
        if (oldStart == null && newStart == null) return;
        if (oldStart == null || newStart == null) {
            result.changes.add(
                new FlowDiffResult.ChangeEntry('Modified', 'Configuration')
                    .withItem('start', 'start', 'Start Element')
                    .withDescription('Start element was ' + (newStart != null ? 'added' : 'removed'))
                    .withRisk('Critical', 'Start element defines the flow entry point')
            );
            return;
        }

        List<String> changes = new List<String>();

        if (strChanged(oldStart.object_x, newStart.object_x)) {
            changes.add('trigger object changed from "' + safe(oldStart.object_x)
                + '" to "' + safe(newStart.object_x) + '"');
        }
        if (strChanged(oldStart.triggerType, newStart.triggerType)) {
            changes.add('trigger type changed');
        }
        if (strChanged(oldStart.recordTriggerType, newStart.recordTriggerType)) {
            changes.add('record trigger type changed from "' + safe(oldStart.recordTriggerType)
                + '" to "' + safe(newStart.recordTriggerType) + '"');
        }
        if (connectorChanged(oldStart.connector, newStart.connector)) {
            changes.add('start connector changed');
        }

        Integer oldFilterCount = oldStart.filters != null ? oldStart.filters.size() : 0;
        Integer newFilterCount = newStart.filters != null ? newStart.filters.size() : 0;
        if (oldFilterCount != newFilterCount) {
            changes.add('entry filter count changed from ' + oldFilterCount + ' to ' + newFilterCount);
        }

        if (!changes.isEmpty()) {
            String oldSig = FlowLogicSignature.forStart(oldStart);
            String newSig = FlowLogicSignature.forStart(newStart);
            Boolean isCosmetic = (oldSig == newSig);

            result.changes.add(
                new FlowDiffResult.ChangeEntry('Modified', 'Configuration')
                    .withItem('start', 'start', 'Start Element')
                    .withDescription('Start element: ' + String.join(changes, ', '))
                    .withRisk(isCosmetic ? 'Info' : 'Critical',
                        isCosmetic ? 'Cosmetic change only (connector routing)' : 'Start element changes affect when/how the flow triggers')
                    .withSemantics(isCosmetic, oldSig, newSig)
            );
        }
    }

    // =========================================================================
    // Resource comparisons
    // =========================================================================

    private void compareVariables(
        List<FlowMetadata.FlowVariable> oldList,
        List<FlowMetadata.FlowVariable> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowVariable> oldMap = buildVarMap(oldList);
        Map<String, FlowMetadata.FlowVariable> newMap = buildVarMap(newList);

        for (String name : newMap.keySet()) {
            if (!oldMap.containsKey(name)) {
                FlowMetadata.FlowVariable v = newMap.get(name);
                String detail = 'Variable "' + name + '" added (type: ' + safe(v.dataType) + ')';
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Added', 'Resources')
                        .withItem('variable', name, name)
                        .withDescription(detail)
                        .withRisk('Low', 'New variable added')
                );
            }
        }

        for (String name : oldMap.keySet()) {
            if (!newMap.containsKey(name)) {
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Removed', 'Resources')
                        .withItem('variable', name, name)
                        .withDescription('Variable "' + name + '" was removed')
                        .withRisk('Medium', 'Removing variables may break element references')
                );
            }
        }

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowVariable oldVar = oldMap.get(name);
                FlowMetadata.FlowVariable newVar = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldVar.dataType, newVar.dataType)) {
                    changes.add('type changed from "' + safe(oldVar.dataType)
                        + '" to "' + safe(newVar.dataType) + '"');
                }
                if (oldVar.isCollection != newVar.isCollection) {
                    changes.add('collection flag changed');
                }
                if (oldVar.isInput != newVar.isInput) {
                    changes.add('input accessibility changed');
                }
                if (oldVar.isOutput != newVar.isOutput) {
                    changes.add('output accessibility changed');
                }
                if (strChanged(oldVar.objectType, newVar.objectType)) {
                    changes.add('object type changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forVariable(oldVar);
                    String newSig = FlowLogicSignature.forVariable(newVar);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Resources')
                            .withItem('variable', name, name)
                            .withDescription('Variable "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'High',
                                isCosmetic ? 'Cosmetic change only' : 'Variable type/accessibility changes can break references')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareFormulas(
        List<FlowMetadata.FlowFormula> oldList,
        List<FlowMetadata.FlowFormula> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowFormula> oldMap = buildFormulaMap(oldList);
        Map<String, FlowMetadata.FlowFormula> newMap = buildFormulaMap(newList);

        addedRemovedResource('formula', 'Formula', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowFormula oldF = oldMap.get(name);
                FlowMetadata.FlowFormula newF = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldF.expression, newF.expression)) {
                    changes.add('expression changed');
                }
                if (strChanged(oldF.dataType, newF.dataType)) {
                    changes.add('data type changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forFormula(oldF);
                    String newSig = FlowLogicSignature.forFormula(newF);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Resources')
                            .withItem('formula', name, name)
                            .withDescription('Formula "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'Medium',
                                isCosmetic ? 'Cosmetic change only' : 'Formula logic changed')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareConstants(
        List<FlowMetadata.FlowConstant> oldList,
        List<FlowMetadata.FlowConstant> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowConstant> oldMap = buildConstantMap(oldList);
        Map<String, FlowMetadata.FlowConstant> newMap = buildConstantMap(newList);

        addedRemovedResource('constant', 'Constant', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowConstant oldC = oldMap.get(name);
                FlowMetadata.FlowConstant newC = newMap.get(name);
                if (strChanged(oldC.dataType, newC.dataType)) {
                    String oldSig = FlowLogicSignature.forConstant(oldC);
                    String newSig = FlowLogicSignature.forConstant(newC);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Resources')
                            .withItem('constant', name, name)
                            .withDescription('Constant "' + name + '": data type changed')
                            .withRisk(isCosmetic ? 'Info' : 'Medium',
                                isCosmetic ? 'Cosmetic change only' : 'Constant type change may affect consumers')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareTextTemplates(
        List<FlowMetadata.FlowTextTemplate> oldList,
        List<FlowMetadata.FlowTextTemplate> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowTextTemplate> oldMap = buildTextTemplateMap(oldList);
        Map<String, FlowMetadata.FlowTextTemplate> newMap = buildTextTemplateMap(newList);

        addedRemovedResource('textTemplate', 'Text Template', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowTextTemplate oldT = oldMap.get(name);
                FlowMetadata.FlowTextTemplate newT = newMap.get(name);
                if (strChanged(oldT.text, newT.text)) {
                    String oldSig = FlowLogicSignature.forTextTemplate(oldT);
                    String newSig = FlowLogicSignature.forTextTemplate(newT);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Resources')
                            .withItem('textTemplate', name, name)
                            .withDescription('Text Template "' + name + '": content changed')
                            .withRisk('Low', 'Template text updated')
                            .withSemantics(false, oldSig, newSig)
                    );
                }
            }
        }
    }

    private void compareChoices(
        List<FlowMetadata.FlowChoice> oldList,
        List<FlowMetadata.FlowChoice> newList,
        FlowDiffResult result
    ) {
        Map<String, FlowMetadata.FlowChoice> oldMap = buildChoiceMap(oldList);
        Map<String, FlowMetadata.FlowChoice> newMap = buildChoiceMap(newList);

        addedRemovedResource('choice', 'Choice', oldMap.keySet(), newMap.keySet(), result);

        for (String name : newMap.keySet()) {
            if (oldMap.containsKey(name)) {
                FlowMetadata.FlowChoice oldCh = oldMap.get(name);
                FlowMetadata.FlowChoice newCh = newMap.get(name);
                List<String> changes = new List<String>();

                if (strChanged(oldCh.choiceText, newCh.choiceText)) {
                    changes.add('choice text changed');
                }
                if (strChanged(oldCh.dataType, newCh.dataType)) {
                    changes.add('data type changed');
                }

                if (!changes.isEmpty()) {
                    String oldSig = FlowLogicSignature.forChoice(oldCh);
                    String newSig = FlowLogicSignature.forChoice(newCh);
                    Boolean isCosmetic = (oldSig == newSig);

                    result.changes.add(
                        new FlowDiffResult.ChangeEntry('Modified', 'Resources')
                            .withItem('choice', name, name)
                            .withDescription('Choice "' + name + '": '
                                + String.join(changes, ', '))
                            .withRisk(isCosmetic ? 'Info' : 'Low',
                                isCosmetic ? 'Cosmetic change only' : 'Choice option changed')
                            .withSemantics(isCosmetic, oldSig, newSig)
                    );
                }
            }
        }
    }

    // =========================================================================
    // Added/Removed detection helpers (use Set<String> to avoid wildcard generics)
    // =========================================================================

    /**
     * Detects added/removed elements using key sets.
     * Used by specialized element comparisons (decisions, loops, etc.)
     */
    private void addedRemovedElement(
        String typeName, String typeLabel,
        Set<String> oldKeys, Set<String> newKeys,
        FlowDiffResult result
    ) {
        for (String name : newKeys) {
            if (!oldKeys.contains(name)) {
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Added', 'Elements')
                        .withItem(typeName, name, name)
                        .withDescription(typeLabel + ' "' + name + '" was added')
                        .withRisk('Medium', 'New ' + typeLabel.toLowerCase() + ' added')
                );
            }
        }
        for (String name : oldKeys) {
            if (!newKeys.contains(name)) {
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Removed', 'Elements')
                        .withItem(typeName, name, name)
                        .withDescription(typeLabel + ' "' + name + '" was removed')
                        .withRisk('High', 'Removing elements may break downstream references')
                );
            }
        }
    }

    /**
     * Detects added/removed resources using key sets.
     */
    private void addedRemovedResource(
        String typeName, String typeLabel,
        Set<String> oldKeys, Set<String> newKeys,
        FlowDiffResult result
    ) {
        for (String name : newKeys) {
            if (!oldKeys.contains(name)) {
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Added', 'Resources')
                        .withItem(typeName, name, name)
                        .withDescription(typeLabel + ' "' + name + '" was added')
                        .withRisk('Low', 'New ' + typeLabel.toLowerCase() + ' added')
                );
            }
        }
        for (String name : oldKeys) {
            if (!newKeys.contains(name)) {
                result.changes.add(
                    new FlowDiffResult.ChangeEntry('Removed', 'Resources')
                        .withItem(typeName, name, name)
                        .withDescription(typeLabel + ' "' + name + '" was removed')
                        .withRisk('Medium', 'Removing resources may break element references')
                );
            }
        }
    }

    // =========================================================================
    // Map builders (uniquely named to avoid Apex overload resolution issues)
    // =========================================================================

    private Map<String, FlowMetadata.FlowElement> buildElementMap(
        List<FlowMetadata.FlowElement> elements
    ) {
        Map<String, FlowMetadata.FlowElement> m = new Map<String, FlowMetadata.FlowElement>();
        if (elements != null) {
            for (FlowMetadata.FlowElement el : elements) {
                if (el.name != null) {
                    m.put(el.name, el);
                }
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowDecision> buildDecisionMap(
        List<FlowMetadata.FlowDecision> items
    ) {
        Map<String, FlowMetadata.FlowDecision> m = new Map<String, FlowMetadata.FlowDecision>();
        if (items != null) {
            for (FlowMetadata.FlowDecision item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowLoop> buildLoopMap(
        List<FlowMetadata.FlowLoop> items
    ) {
        Map<String, FlowMetadata.FlowLoop> m = new Map<String, FlowMetadata.FlowLoop>();
        if (items != null) {
            for (FlowMetadata.FlowLoop item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowRecordLookup> buildRecordLookupMap(
        List<FlowMetadata.FlowRecordLookup> items
    ) {
        Map<String, FlowMetadata.FlowRecordLookup> m = new Map<String, FlowMetadata.FlowRecordLookup>();
        if (items != null) {
            for (FlowMetadata.FlowRecordLookup item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowScreen> buildScreenMap(
        List<FlowMetadata.FlowScreen> items
    ) {
        Map<String, FlowMetadata.FlowScreen> m = new Map<String, FlowMetadata.FlowScreen>();
        if (items != null) {
            for (FlowMetadata.FlowScreen item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowSubflow> buildSubflowMap(
        List<FlowMetadata.FlowSubflow> items
    ) {
        Map<String, FlowMetadata.FlowSubflow> m = new Map<String, FlowMetadata.FlowSubflow>();
        if (items != null) {
            for (FlowMetadata.FlowSubflow item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowVariable> buildVarMap(
        List<FlowMetadata.FlowVariable> items
    ) {
        Map<String, FlowMetadata.FlowVariable> m = new Map<String, FlowMetadata.FlowVariable>();
        if (items != null) {
            for (FlowMetadata.FlowVariable item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowFormula> buildFormulaMap(
        List<FlowMetadata.FlowFormula> items
    ) {
        Map<String, FlowMetadata.FlowFormula> m = new Map<String, FlowMetadata.FlowFormula>();
        if (items != null) {
            for (FlowMetadata.FlowFormula item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowConstant> buildConstantMap(
        List<FlowMetadata.FlowConstant> items
    ) {
        Map<String, FlowMetadata.FlowConstant> m = new Map<String, FlowMetadata.FlowConstant>();
        if (items != null) {
            for (FlowMetadata.FlowConstant item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowTextTemplate> buildTextTemplateMap(
        List<FlowMetadata.FlowTextTemplate> items
    ) {
        Map<String, FlowMetadata.FlowTextTemplate> m = new Map<String, FlowMetadata.FlowTextTemplate>();
        if (items != null) {
            for (FlowMetadata.FlowTextTemplate item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    private Map<String, FlowMetadata.FlowChoice> buildChoiceMap(
        List<FlowMetadata.FlowChoice> items
    ) {
        Map<String, FlowMetadata.FlowChoice> m = new Map<String, FlowMetadata.FlowChoice>();
        if (items != null) {
            for (FlowMetadata.FlowChoice item : items) {
                if (item.name != null) m.put(item.name, item);
            }
        }
        return m;
    }

    // =========================================================================
    // Utility helpers
    // =========================================================================

    private Boolean strChanged(String a, String b) {
        String sa = a != null ? a : '';
        String sb = b != null ? b : '';
        return sa != sb;
    }

    private Boolean connectorChanged(
        FlowMetadata.FlowConnector a,
        FlowMetadata.FlowConnector b
    ) {
        String aTarget = (a != null && a.targetReference != null) ? a.targetReference : '';
        String bTarget = (b != null && b.targetReference != null) ? b.targetReference : '';
        return aTarget != bTarget;
    }

    private String safe(String val) {
        return val != null ? val : '';
    }
}
