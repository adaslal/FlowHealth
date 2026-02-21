# Sprint 6C: Logic Hashing — Semantic Meaning Layer for Flow Comparison

## Concept

Every flow element has two categories of attributes:
- **Functional** (business logic): what the element *does* — object types, filter conditions, assignment values, decision rules, formula expressions
- **Cosmetic** (layout/routing): where the element *sits* — locationX, locationY, connector targets, faultConnector targets

A **Logic Signature** is a deterministic string built from ONLY the functional attributes of an element. When comparing versions, if two elements have the same name but different Logic Signatures, the change is **functional**. If the Logic Signatures match but other attributes differ, the change is **cosmetic** (e.g., the admin just moved nodes around on the canvas or rerouted connectors).

---

## Files to Create

### 1. `classes/FlowLogicSignature.cls` + meta.xml (NEW)

Static utility class with one public method per element/resource type. Each method returns a deterministic string signature.

**Signature rules per element type:**

| Element Type | Functional Attributes (included in signature) |
|---|---|
| **ActionCall** | label, actionName, actionType, inputParameters(name+value), outputParameters(name+assignTo), storeOutputAutomatically, flowTransactionModel |
| **Assignment** | label, assignmentItems(assignTo+operator+value) |
| **Decision** | label, rules(name+label+conditionLogic+conditions(leftRef+operator+rightValue)), defaultConnectorLabel |
| **Loop** | label, collectionReference, iterationOrder, assignNextValueToReference |
| **RecordCreate** | label, object_x, inputAssignments(field+value), inputReference, assignRecordIdToReference, storeOutputAutomatically |
| **RecordUpdate** | label, object_x, inputAssignments(field+value), inputReference, filters(field+operator+value), filterLogic |
| **RecordDelete** | label, object_x, filters(field+operator+value), filterLogic, inputReference |
| **RecordLookup** | label, object_x, filters(field+operator+value), filterLogic, getFirstRecordOnly, sortField, sortOrder, outputAssignments(field+assignTo), storeOutputAutomatically |
| **Screen** | label, fields(name+fieldType+fieldText+dataType+isRequired+defaultValue, recursively) |
| **Subflow** | label, flowName, inputAssignments(name+value), outputAssignments(name+assignTo) |
| **Wait** | label, waitEvents(name+label+eventType+conditionLogic+conditions) |
| **Start** | object_x, triggerType, recordTriggerType, filters(field+operator+value), filterLogic |
| **Variable** | name, dataType, isCollection, isInput, isOutput, objectType, defaultValue |
| **Formula** | name, dataType, expression |
| **Constant** | name, dataType, value |
| **TextTemplate** | name, text, isViewedAsPlainText |
| **Choice** | name, choiceText, dataType, value |

**ALWAYS ignored:** locationX, locationY, connector, faultConnector, defaultConnector, nextValueConnector, noMoreValuesConnector, scheduledConnector

**Key design decisions:**
- Signatures are built by concatenating field values with `|` delimiters and `~` between list items
- Null values serialize as empty string
- FlowValue serializes as: stringValue or numberValue or booleanValue or elementReference
- Lists are sorted by a stable key (e.g., field name, rule name) before concatenation to ensure order-independent comparison

---

## Files to Modify

### 2. `classes/FlowDiffResult.cls` (MODIFY)

Add to **ChangeEntry**:
```apex
@AuraEnabled public Boolean isCosmetic;          // true if Logic Signature unchanged
@AuraEnabled public String oldLogicSignature;     // for debugging/display
@AuraEnabled public String newLogicSignature;     // for debugging/display
```

Add builder method:
```apex
public ChangeEntry withSemantics(Boolean isCosmetic, String oldSig, String newSig)
```

Add to **DiffSummary**:
```apex
@AuraEnabled public Integer functionalChanges;
@AuraEnabled public Integer cosmeticChanges;
```

Update `buildSummary()` to count functional vs cosmetic.

### 3. `classes/FlowDiffService.cls` (MODIFY)

For every `compareXxx` method that detects "Modified" elements:
1. Compute `oldSignature = FlowLogicSignature.forXxx(oldElement)`
2. Compute `newSignature = FlowLogicSignature.forXxx(newElement)`
3. Set `isCosmetic = (oldSignature == newSignature)`
4. Attach signatures to the ChangeEntry via `.withSemantics(isCosmetic, oldSig, newSig)`

**Methods to update:**
- `compareBaseElement()` — generic elements (actionCalls, assignments, waits, recordCreates, recordUpdates, recordDeletes)
- `compareDecisions()` — specialized
- `compareLoops()` — specialized
- `compareRecordLookups()` — specialized
- `compareScreens()` — specialized
- `compareSubflows()` — specialized
- `compareVariables()` — resources
- `compareFormulas()` — resources
- `compareConstants()` — resources
- `compareTextTemplates()` — resources
- `compareChoices()` — resources
- `compareStart()` — start element
- `compareConfigField()` — configuration (always functional, never cosmetic)

### 4. `lwc/flowHealthApp/flowHealthApp.js` (MODIFY)

**New state:**
```javascript
@track hideCosmeticChanges = false;
```

**New handler:**
```javascript
handleToggleHideCosmetic() — toggles hideCosmeticChanges and re-filters displayed changes
```

**Modify `enrichDiffResult()`:**
- Add `isCosmetic` flag passthrough to enriched changes
- Add `cosmeticBadgeClass` for cosmetic indicators
- Compute `filteredGroupedChanges` that respects the toggle
- Add semantic summary: `functionalChanges` and `cosmeticChanges` counts

**New getters:**
```javascript
get displayedGroupedChanges()  — returns filtered or full changes based on toggle
get semanticSummaryText()      — "X functional, Y cosmetic changes"
```

### 5. `lwc/flowHealthApp/flowHealthApp.html` (MODIFY)

**Add toggle** (between summary stats and changes list):
```html
<div class="slds-grid slds-grid_align-center slds-m-bottom_small">
    <lightning-input
        type="toggle"
        label="Hide Cosmetic Changes"
        message-toggle-active="Showing functional changes only"
        message-toggle-inactive="Showing all changes"
        checked={hideCosmeticChanges}
        onchange={handleToggleHideCosmetic}>
    </lightning-input>
</div>
```

**Add semantic summary bar** (new row showing functional vs cosmetic):
- Two-pill summary: "🔧 X Functional" (blue) + "🎨 Y Cosmetic" (gray)

**Update change rows:**
- Cosmetic changes get a subtle gray "Cosmetic" badge and reduced opacity when visible
- Replace `{compareDiffResult.groupedChanges}` → `{displayedGroupedChanges}`
- Each change row gets a small "Cosmetic" or "Functional" pill

### 6. `lwc/flowHealthApp/flowHealthApp.css` (MODIFY)

- `.cosmetic-change-row` — reduced opacity (0.6), subtle left-border
- `.semantic-badge-functional` — blue pill
- `.semantic-badge-cosmetic` — gray pill
- `.semantic-summary-bar` — flex row with pills

---

## Execution Order

1. Create `FlowLogicSignature.cls` + meta.xml
2. Modify `FlowDiffResult.cls` — add isCosmetic, signatures, summary counts
3. Modify `FlowDiffService.cls` — integrate signature computation into all compare methods
4. Modify LWC JS — toggle state, enrichment, filtering
5. Modify LWC HTML — toggle, semantic summary, cosmetic badges
6. Modify LWC CSS — cosmetic styling

---

## What This Enables (Premium Value)

- **"Did anything ACTUALLY change?"** — Admin moves 15 elements on the canvas → 0 functional changes detected
- **"Is this version safe to deploy?"** — Toggle hides cosmetic noise, showing only business logic mutations
- **Version comparison confidence** — Logic Signatures serve as a fingerprint; identical signatures = identical behavior
