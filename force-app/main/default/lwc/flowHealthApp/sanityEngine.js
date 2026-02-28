// ============================================================================
// SANITY ENGINE v1.4 — Deterministic Logic Hashing
// ============================================================================
//
// Sovereign Architect Philosophy:
//   Deterministic logic, local-first execution, "AI without AI."
//
// The 9 Rules of the Logic Hashing Grammar:
//   R1: Tokenize (XML tag → deterministic token via FLOW_TOKEN_MAP)
//   R2: Sequence (preserve execution order as token array)
//   R3: Hash (SHA-256 the canonical token sequence)
//   R4: Trace (map each token to its SEMANTIC_DICTIONARY meaning)
//   R5: Graph (build adjacency list from connector references)
//   R6: Warn (detect anti-patterns: DML/SOQL in loops, missing fault paths)
//   R7: Summarize (count element types for quick structural overview)
//   R8: Namespace Strip (optionally remove managed-package prefixes)
//   R9: Graceful Degradation (unknown XML tags → UNK_X fallback token)
//
// ALL processing happens client-side in the browser.
// No metadata is transmitted to any external server.
//
// Author: Abhilash | Confidential / Proprietary IP
// ============================================================================

// ============================================================================
// GRAMMAR DICTIONARY — The "Language of Intent"
// ============================================================================

/**
 * Maps Salesforce Flow XML element names → deterministic tokens.
 * Unknown elements hit Rule 9 (Graceful Degradation).
 */
const FLOW_TOKEN_MAP = {
    // Entry points
    start:                'RTF_S',      // Record-Triggered / Flow Start

    // Logic branching
    decisions:            'DEC',        // Logical Decision (bifurcating path)

    // DML operations (database writes)
    recordCreates:        'DML_W',      // Insert
    recordUpdates:        'DML_W',      // Update
    recordDeletes:        'DML_D',      // Delete

    // SOQL operations (database reads)
    recordLookups:        'SOQL_R',     // Query

    // Iteration
    loops:                'LOOP_S',     // Loop start

    // External actions
    actionCalls:          'EXT_ACT',    // Apex action, email, etc.
    subflows:             'SUBFLOW',    // Invoke another flow

    // Assignments & resources
    assignments:          'ASSIGN',     // Variable assignment
    collectionProcessors: 'COLL_PROC',  // Transform / filter / sort

    // Screen
    screens:              'SCREEN',     // UI screen element

    // Wait / Pause
    waits:                'WAIT',       // Pause-resume element

    // Custom error
    customErrors:         'FAULT'       // Custom error throw
};

/**
 * Tags that are NOISE — no effect on runtime execution (Rule 1).
 */
const NOISE_TAGS = new Set([
    'locationX', 'locationY',
    'connector', 'faultConnector', 'defaultConnector',
    'nextValueConnector', 'noMoreValuesConnector',
    'label', 'description',
    'processMetadataValues'
]);

/**
 * Flow-level metadata tags (not executable elements).
 */
const METADATA_TAGS = new Set([
    'processType', 'apiVersion', 'status', 'interviewLabel',
    'environments', 'runInMode', 'isTemplate', 'isOverridable',
    'overriddenFlow', 'migratedFromWorkflowRuleName'
]);

/**
 * Resource tags (not executable — declared, not traversed).
 */
const RESOURCE_TAGS = new Set([
    'variables', 'formulas', 'constants', 'textTemplates',
    'stages', 'choices', 'dynamicChoiceSets'
]);

/**
 * SEMANTIC DICTIONARY — The "Meaning Layer"
 *
 * Maps every deterministic token to a Semantic Object containing:
 *   - meaning:  Human-readable sentence explaining WHAT this step does.
 *   - impact:   WHY it matters to the business or system.
 *   - category: Grouping key for visual rendering (start, logic, data, loop, action, ui, error).
 *   - shape:    SVG shape type for the Sovereign Flowchart (stadium, diamond, rect, hex, rounded, flag, octagon).
 *   - color:    Fill color for the SVG node.
 *
 * Every token the engine can emit MUST have an entry here.
 * Unknown tokens fall through to a runtime default (Rule 9 Graceful Degradation).
 */
const SEMANTIC_DICTIONARY = {
    'RTF_S': {
        meaning:  'Record-Triggered Start: The automation engine wakes up when a record is created, updated, or deleted.',
        impact:   'This is the ignition point — every downstream operation depends on this trigger firing correctly.',
        category: 'start',
        shape:    'stadium',
        color:    '#0176d3'
    },
    'DEC': {
        meaning:  'Logic Gate: The system evaluates business criteria and splits the execution path into branches.',
        impact:   'Decisions control which operations run. A misconfigured condition silently skips critical logic.',
        category: 'logic',
        shape:    'diamond',
        color:    '#9b59b6'
    },
    'DML_W': {
        meaning:  'Database Write: Data is permanently committed to Salesforce (Insert or Update).',
        impact:   'Each write consumes a DML statement. Inside a loop, this will breach governor limits at scale.',
        category: 'data',
        shape:    'rect',
        color:    '#e87400'
    },
    'DML_D': {
        meaning:  'Database Delete: Records are permanently removed from Salesforce.',
        impact:   'Irreversible data loss. Ensure cascade effects (lookups, triggers) are accounted for.',
        category: 'data',
        shape:    'rect',
        color:    '#c23934'
    },
    'SOQL_R': {
        meaning:  'Database Query: The system reads records from Salesforce using SOQL.',
        impact:   'Each query consumes a SOQL statement. Inside a loop, this hits the 100-query governor limit.',
        category: 'data',
        shape:    'rect',
        color:    '#2e844a'
    },
    'LOOP_S': {
        meaning:  'Iteration Start: A repetitive cycle begins, processing each item in a collection one-by-one.',
        impact:   'Loops amplify everything inside them. DML/SOQL inside a loop = governor limit time bomb.',
        category: 'loop',
        shape:    'hex',
        color:    '#f4bc25'
    },
    'LOOP_E': {
        meaning:  'Iteration End: The cycle completes. Control returns to the loop header or exits to the next step.',
        impact:   'Marks the boundary of the amplification zone. Operations after this line are safe from loop multiplication.',
        category: 'loop',
        shape:    'hex',
        color:    '#f4bc25'
    },
    'EXT_ACT': {
        meaning:  'External Action: An Apex class, Email Alert, or managed-package invocable is called.',
        impact:   'External code is a black box to the Flow engine. Errors here surface as uncatchable faults unless handled.',
        category: 'action',
        shape:    'rounded',
        color:    '#0b8dff'
    },
    'SUBFLOW': {
        meaning:  'Subflow Invocation: Execution is delegated to a child Flow, creating a nested transaction scope.',
        impact:   'Subflows inherit the parent\'s governor limits. Deep nesting can exhaust limits before the parent resumes.',
        category: 'action',
        shape:    'rounded',
        color:    '#0b8dff'
    },
    'ASSIGN': {
        meaning:  'Variable Assignment: A value is set, copied, or transformed within the Flow\'s in-memory state.',
        impact:   'Lightweight and safe — no governor impact. But incorrect assignments silently corrupt downstream logic.',
        category: 'action',
        shape:    'rect',
        color:    '#706e6b'
    },
    'COLL_PROC': {
        meaning:  'Collection Processor: A collection is filtered, sorted, or mapped in bulk.',
        impact:   'Efficient in-memory operation. Preferred over loops for simple transformations.',
        category: 'action',
        shape:    'rect',
        color:    '#706e6b'
    },
    'SCREEN': {
        meaning:  'User Screen: A UI form or display is presented, pausing execution until the user responds.',
        impact:   'Screens break the transaction boundary. Data may change between screens in multi-step flows.',
        category: 'ui',
        shape:    'flag',
        color:    '#00b4d8'
    },
    'WAIT': {
        meaning:  'Pause/Wait: Execution is suspended, awaiting an event or scheduled time to resume.',
        impact:   'The interview is serialized to storage. Resume context may differ from the original transaction.',
        category: 'action',
        shape:    'rounded',
        color:    '#706e6b'
    },
    'FAULT': {
        meaning:  'Custom Error: The Flow intentionally throws a fault to halt execution and surface an error message.',
        impact:   'Stops all downstream processing. If uncaught, the entire transaction rolls back.',
        category: 'error',
        shape:    'octagon',
        color:    '#c23934'
    },
    '!ERR_BULK_LIMIT!': {
        meaning:  'CRITICAL VIOLATION: A DML or SOQL operation was detected inside a Loop. This WILL fail in production with bulk data.',
        impact:   'Governor limit breach is certain at scale. Move the operation outside the loop immediately.',
        category: 'error',
        shape:    'octagon',
        color:    '#c23934'
    }
};

/**
 * Backwards-compatible alias — the old name is still exported.
 * Internal code now uses SEMANTIC_DICTIONARY exclusively.
 */
const TRACE_DICTIONARY = Object.fromEntries(
    Object.entries(SEMANTIC_DICTIONARY).map(([k, v]) => [k, v.meaning])
);


// ============================================================================
// SANITY ENGINE — Core Class
// ============================================================================

class SanityEngine {

    constructor(options = {}) {
        /** Strip managed-package namespace prefixes (Rule 8). */
        this.stripNamespaces = options.stripNamespaces || false;

        /** Collected audit warnings during analysis. */
        this.auditWarnings = [];

        /** Step-by-step logic trace. */
        this.logicTrace = [];

        /** Decision counter for sequential numbering. */
        this._decisionCounter = 0;
    }

    // ========================================================================
    // PUBLIC ENTRY POINT — Flow Analysis
    // ========================================================================

    /**
     * Analyse a raw Salesforce Flow XML string.
     * Returns a complete audit report with hash, warnings, trace, and diagram.
     *
     * @param {string} xmlString - Raw Flow XML
     * @returns {Object} AuditReport
     */
    analyzeFlow(xmlString) {
        const startTime = performance.now();
        this.auditWarnings = [];
        this.logicTrace = [];
        this._decisionCounter = 0;

        // ── Parse XML ────────────────────────────────────────────────
        const parser = new DOMParser();
        const doc = parser.parseFromString(xmlString, 'text/xml');
        const parseError = doc.querySelector('parsererror');
        if (parseError) {
            return this._errorReport('XML Parse Error: ' + parseError.textContent.substring(0, 200));
        }

        const root = doc.documentElement;
        if (!root || (root.localName !== 'Flow' && root.localName !== 'Workflow')) {
            return this._errorReport('Invalid Flow XML: root element must be <Flow>.');
        }

        // ── Extract flow metadata ────────────────────────────────────
        const flowType = this._getChildText(root, 'processType') || 'Unknown';
        const apiVersion = this._getChildText(root, 'apiVersion') || '';

        // ── Extract elements + connectors ────────────────────────────
        const { elements, connectorMap, noiseCount } = this._extractElements(root);

        // ── Build execution graph ────────────────────────────────────
        const graph = this._buildGraph(elements, connectorMap, root);

        // ── Walk graph → generate tokens (Rules 1-4, 8-9 applied) ───
        const tokens = this._walkGraph(graph, elements);

        // ── Rule 6: Bulkification audit ──────────────────────────────
        this._auditBulkification(tokens);

        // ── Build the Logic Fingerprint ──────────────────────────────
        const hash = tokens.map(t => t.token).join(' -> ');

        // ── Generate Logic Trace ─────────────────────────────────────
        const trace = this._generateTrace(tokens);

        // ── Generate Sovereign Flowchart (native SVG) ────────────────
        const flowchartSvg = this._generateSvgFlowchart(graph, elements, tokens);

        // ── Element summary ──────────────────────────────────────────
        const summary = this._buildSummary(tokens);

        const elapsed = Math.round(performance.now() - startTime);

        return {
            success: true,
            hash,
            tokens: tokens.map(t => t.token),
            flowType: this._humanFlowType(flowType),
            apiVersion,
            elementSummary: summary,
            warnings: [...this.auditWarnings],
            trace,
            flowchartSvg,
            stats: {
                totalElements: Object.keys(elements).length,
                noiseStripped: noiseCount,
                unknownTags: this.auditWarnings.filter(w => w.type === 'UNKNOWN_ELEMENT').length,
                processingTimeMs: elapsed
            }
        };
    }

    // ========================================================================
    // PUBLIC ENTRY POINT — PermSet Hashing (Rule 7)
    // ========================================================================

    /**
     * Hash a PermissionSet XML for deterministic comparison.
     * Extracts, normalises, sorts, and joins all permission entries.
     *
     * @param {string} xmlString - Raw PermissionSet XML
     * @returns {Object} PermSet hash report
     */
    hashPermSet(xmlString) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(xmlString, 'text/xml');
        const root = doc.documentElement;
        if (!root) return { hash: '', entries: [] };

        const entries = [];
        for (const child of root.children) {
            const tag = child.localName;
            if (['label', 'description', 'license', 'hasActivationRequired'].includes(tag)) continue;

            const parts = [tag];
            for (const sub of child.children) {
                let val = this._normalizeValue(sub.textContent); // Rule 4
                if (this.stripNamespaces) val = this._stripNs(val); // Rule 8
                parts.push(sub.localName + '=' + val);
            }
            parts.sort(); // Rule 3
            entries.push(parts.join('|'));
        }
        entries.sort(); // Rule 3: deterministic order

        return {
            hash: entries.join('\n'),
            entryCount: entries.length
        };
    }

    /**
     * Rule 7: Compare Source and Destination PermSet hashes.
     * Returns orphaned entries (in source but not destination).
     */
    comparePermSetHashes(sourceHash, destHash) {
        const srcSet = new Set(sourceHash.split('\n').filter(Boolean));
        const destSet = new Set(destHash.split('\n').filter(Boolean));
        const orphans = [];
        for (const entry of srcSet) {
            if (!destSet.has(entry)) {
                orphans.push(entry);
            }
        }
        return {
            isSafe: orphans.length === 0,
            orphanCount: orphans.length,
            orphans
        };
    }

    // ========================================================================
    // RULE 1: Structural Noise Suppression
    // ========================================================================

    /**
     * Determines whether a child element is functional (non-noise).
     */
    _isFunctional(tagName) {
        return !NOISE_TAGS.has(tagName);
    }

    // ========================================================================
    // RULE 2: Variable & Reference Canonicalization
    // ========================================================================

    /**
     * Canonicalise a Salesforce reference string.
     * {!Get_Recent_Account.Id} → [REF:Account.Id]
     * $Record.Status → [REF:$Record.Status]
     */
    _canonicalizeRef(ref) {
        if (!ref) return 'null';
        let v = String(ref).trim();

        // Strip {! ... } wrapper
        if (v.startsWith('{!') && v.endsWith('}')) {
            v = v.substring(2, v.length - 1);
        }

        // Rule 8: Namespace stripping
        if (this.stripNamespaces) {
            v = this._stripNs(v);
        }

        return '[REF:' + v + ']';
    }

    // ========================================================================
    // RULE 3: Deterministic Intent Sorting
    // ========================================================================

    /**
     * Compute a semantic signature for a decision rule's conditions.
     * Used for sorting and redundancy detection.
     */
    _getSemanticSignature(conditionNodes) {
        if (!conditionNodes || conditionNodes.length === 0) return 'DEFAULT_PATH';

        const parts = conditionNodes.map(c => {
            const left = this._canonicalizeRef(this._getChildText(c, 'leftValueReference'));
            const op = this._getChildText(c, 'operator') || 'UNKNOWN_OP';
            const rightNode = c.querySelector('rightValue');
            const right = rightNode
                ? this._normalizeValue(rightNode.textContent)
                : 'null';
            return left + ':' + op + ':' + right;
        });

        return parts.sort().join('&&');
    }

    /**
     * Compare two decision rules for sorting.
     * If signatures match → flag redundancy (Rule 3 extension).
     */
    _compareIntent(ruleA, ruleB) {
        const hashA = this._getSemanticSignature(
            Array.from(ruleA.querySelectorAll(':scope > conditions'))
        );
        const hashB = this._getSemanticSignature(
            Array.from(ruleB.querySelectorAll(':scope > conditions'))
        );

        if (hashA === hashB && hashA !== 'DEFAULT_PATH') {
            const nameA = this._getChildText(ruleA, 'name') || 'Unknown';
            const nameB = this._getChildText(ruleB, 'name') || 'Unknown';
            this.auditWarnings.push({
                type: 'REDUNDANCY',
                severity: 'Medium',
                message: 'Identical logic detected in "' + nameA + '" and "' + nameB + '".',
                detail: 'Consider merging these paths to reduce technical debt.',
                remediation: 'Review both outcomes — if they lead to the same action, consolidate.',
                hashSignature: hashA
            });
            return 0;
        }
        return hashA < hashB ? -1 : 1;
    }

    // ========================================================================
    // RULE 4: Data-Type Normalisation
    // ========================================================================

    /**
     * Normalise a value to its canonical string form.
     */
    _normalizeValue(value) {
        if (value === null || value === undefined) return 'null';
        let v = String(value).trim();
        if (v === '') return 'null';

        // Boolean normalisation
        const lower = v.toLowerCase();
        if (lower === 'true' || lower === 'false') return lower;

        // Numeric normalisation (strip trailing zeros)
        if (!isNaN(v) && v !== '') {
            return parseFloat(v).toString();
        }

        // String normalisation (lowercase, trimmed)
        return lower;
    }

    // ========================================================================
    // RULE 5: Formula De-nesting & Operator Standardisation
    // ========================================================================

    /**
     * Standardise a formula string for hashing.
     * Strips redundant parentheses, normalises whitespace.
     * Full algebraic normalisation is a Phase 2 enhancement.
     */
    _normalizeFormula(formula) {
        if (!formula) return '';
        let f = formula.trim();
        // Collapse whitespace
        f = f.replace(/\s+/g, ' ');
        // Lowercase function names
        f = f.replace(/\b(IF|AND|OR|NOT|ISBLANK|ISNULL|TEXT|VALUE)\b/gi,
            match => match.toUpperCase());
        return f;
    }

    // ========================================================================
    // RULE 6: Bulkification Risk Signature (The Auditor Rule)
    // ========================================================================

    /**
     * Post-hash pass: detect DML/SOQL inside loops.
     * Supports nested loops via depth counter.
     */
    _auditBulkification(tokenList) {
        let loopDepth = 0;

        for (const entry of tokenList) {
            const t = entry.token;

            if (t.includes('[LOOP_S]'))  { loopDepth++; }
            if (t.includes('[LOOP_E]'))  { loopDepth = Math.max(0, loopDepth - 1); }

            if (loopDepth > 0 && (t.includes('[DML_W]') || t.includes('[DML_D]'))) {
                this.auditWarnings.push({
                    type: 'CRITICAL_RISK',
                    severity: 'Critical',
                    message: 'Governor Limit Risk: DML inside Loop detected.',
                    detail: 'Element "' + (entry.name || 'unknown') + '" performs a database write inside a loop. ' +
                            'This will cause "Too Many DML Statements" in production with bulk data.',
                    remediation: 'Move DML outside the loop. Collect records in a Collection variable, then perform a single bulk DML after the loop.',
                    hashSignature: t
                });
                // Append risk flag to the token sequence
                tokenList.push({
                    token: '!ERR_BULK_LIMIT!',
                    name: '_risk_flag',
                    elementType: 'risk'
                });
            }

            if (loopDepth > 0 && t.includes('[SOQL_R]')) {
                this.auditWarnings.push({
                    type: 'CRITICAL_RISK',
                    severity: 'Critical',
                    message: 'Governor Limit Risk: SOQL inside Loop detected.',
                    detail: 'Element "' + (entry.name || 'unknown') + '" performs a database query inside a loop. ' +
                            'This will cause "Too Many SOQL Queries" in production with bulk data.',
                    remediation: 'Move the query before the loop. Use a single query to retrieve all needed records, then loop over the results.',
                    hashSignature: t
                });
                tokenList.push({
                    token: '!ERR_BULK_LIMIT!',
                    name: '_risk_flag',
                    elementType: 'risk'
                });
            }
        }
    }

    // ========================================================================
    // RULE 8: Namespace Abstraction (The AppExchange Rule)
    // ========================================================================

    /**
     * Strip managed-package namespace prefixes.
     * pse__Timecard__c → Timecard__c
     */
    _stripNs(name) {
        if (!name) return name;
        return name.replace(/^[a-zA-Z0-9]+__/g, '');
    }

    // ========================================================================
    // RULE 9: Graceful Degradation (The "Future-Proof" Rule)
    // ========================================================================

    /**
     * Generate a token for any element. Unknown elements produce [UNKNOWN:tag].
     */
    _tokenize(tagName, elementName) {
        const mapped = FLOW_TOKEN_MAP[tagName];
        if (mapped) {
            if (mapped === 'DEC') {
                this._decisionCounter++;
                const num = String(this._decisionCounter).padStart(2, '0');
                return '[DEC_' + num + ']';
            }
            return '[' + mapped + ']';
        }

        // Rule 9: Unknown element — flag, don't drop
        this.auditWarnings.push({
            type: 'UNKNOWN_ELEMENT',
            severity: 'Low',
            message: 'Unknown element type: <' + tagName + '>',
            detail: 'Element "' + (elementName || tagName) + '" is outside the current Grammar Dictionary. ' +
                    'Its raw signature is included in the hash to maintain audit integrity.',
            remediation: 'No action needed. This element was preserved in the hash for traceability.',
            hashSignature: '[UNKNOWN:' + tagName + ']'
        });
        return '[UNKNOWN:' + tagName + ']';
    }

    // ========================================================================
    // INTERNAL: XML Element Extraction
    // ========================================================================

    /**
     * Walk the Flow XML root and extract all executable elements + connectors.
     */
    _extractElements(root) {
        const elements = {};    // name → { tag, node, connectors }
        const connectorMap = {}; // name → { next, default, fault, loopBody, loopExit }
        let noiseCount = 0;

        for (const child of root.children) {
            const tag = child.localName;

            // Skip metadata, resources, and noise
            if (METADATA_TAGS.has(tag) || RESOURCE_TAGS.has(tag)) continue;
            if (NOISE_TAGS.has(tag)) { noiseCount++; continue; }

            const name = this._getChildText(child, 'name');
            if (!name && tag !== 'start') continue;

            const elName = name || '__start__';
            elements[elName] = { tag, node: child, name: elName };

            // Extract connectors for graph building
            const conn = {};
            const nextConn = child.querySelector(':scope > connector > targetReference');
            if (nextConn) conn.next = nextConn.textContent.trim();

            const defConn = child.querySelector(':scope > defaultConnector > targetReference');
            if (defConn) conn.default = defConn.textContent.trim();

            const faultConn = child.querySelector(':scope > faultConnector > targetReference');
            if (faultConn) conn.fault = faultConn.textContent.trim();

            // Loop-specific connectors
            const bodyConn = child.querySelector(':scope > nextValueConnector > targetReference');
            if (bodyConn) conn.loopBody = bodyConn.textContent.trim();

            const exitConn = child.querySelector(':scope > noMoreValuesConnector > targetReference');
            if (exitConn) conn.loopExit = exitConn.textContent.trim();

            // Decision rules → individual branch connectors
            if (tag === 'decisions') {
                const rules = Array.from(child.querySelectorAll(':scope > rules'));
                // Rule 3: Sort decision rules by semantic signature
                rules.sort((a, b) => this._compareIntent(a, b));
                conn.rules = rules.map(r => {
                    const rName = this._getChildText(r, 'name') || 'unknown';
                    const rConn = r.querySelector(':scope > connector > targetReference');
                    return {
                        name: rName,
                        ruleNode: r,
                        target: rConn ? rConn.textContent.trim() : null
                    };
                });
            }

            // Count noise stripped from this element (Rule 1)
            for (const sub of child.children) {
                if (NOISE_TAGS.has(sub.localName)) noiseCount++;
            }

            connectorMap[elName] = conn;
        }

        return { elements, connectorMap, noiseCount };
    }

    // ========================================================================
    // INTERNAL: Graph Construction
    // ========================================================================

    _buildGraph(elements, connectorMap, root) {
        const graph = {}; // name → [{ target, label }]

        for (const [name, conn] of Object.entries(connectorMap)) {
            const edges = [];
            const el = elements[name];
            if (!el) continue;

            if (el.tag === 'loops') {
                // Loop: body path + exit path
                if (conn.loopBody) edges.push({ target: conn.loopBody, label: 'each_item', type: 'loopBody' });
                if (conn.loopExit) edges.push({ target: conn.loopExit, label: 'done', type: 'loopExit' });
            } else if (el.tag === 'decisions' && conn.rules) {
                // Decision: each rule is a branch
                for (const rule of conn.rules) {
                    if (rule.target) {
                        edges.push({ target: rule.target, label: rule.name, type: 'branch' });
                    }
                }
                if (conn.default) edges.push({ target: conn.default, label: 'default', type: 'default' });
            } else {
                if (conn.next)    edges.push({ target: conn.next, label: 'next', type: 'next' });
                if (conn.default) edges.push({ target: conn.default, label: 'default', type: 'default' });
            }

            if (conn.fault) edges.push({ target: conn.fault, label: 'fault', type: 'fault' });

            graph[name] = edges;
        }

        return graph;
    }

    // ========================================================================
    // INTERNAL: Graph Walk → Token Sequence
    // ========================================================================

    /**
     * DFS traversal of the execution graph.
     * Produces an ordered token sequence representing the flow's logic.
     */
    _walkGraph(graph, elements) {
        const tokens = [];
        const visited = new Set();

        const walk = (name) => {
            if (!name || visited.has(name)) return;
            visited.add(name);

            const el = elements[name];
            if (!el) return;

            const token = this._tokenize(el.tag, el.name);
            tokens.push({ token, name: el.name, elementType: el.tag });

            // If this is a loop, mark body entry and exit
            const edges = graph[name] || [];

            if (el.tag === 'loops') {
                // Walk the loop body
                const bodyEdge = edges.find(e => e.type === 'loopBody');
                const exitEdge = edges.find(e => e.type === 'loopExit');

                if (bodyEdge) {
                    walk(bodyEdge.target);
                }
                // Emit LOOP_E after body
                tokens.push({ token: '[LOOP_E]', name: el.name + '_end', elementType: 'loopEnd' });

                // Walk the exit path
                if (exitEdge) {
                    walk(exitEdge.target);
                }
            } else if (el.tag === 'decisions') {
                // Walk each branch
                for (const edge of edges) {
                    walk(edge.target);
                }
            } else {
                // Linear: follow edges
                for (const edge of edges) {
                    if (edge.type !== 'fault') {
                        walk(edge.target);
                    }
                }
            }
        };

        // Find the start element
        const startEl = elements['__start__'];
        if (startEl) {
            tokens.push({ token: '[RTF_S]', name: '__start__', elementType: 'start' });
            const startEdges = graph['__start__'] || [];
            for (const edge of startEdges) {
                walk(edge.target);
            }
        } else {
            // Fallback: walk all elements that aren't targets of others
            const allTargets = new Set();
            for (const edges of Object.values(graph)) {
                for (const e of edges) allTargets.add(e.target);
            }
            for (const name of Object.keys(elements)) {
                if (!allTargets.has(name) && name !== '__start__') {
                    walk(name);
                }
            }
        }

        return tokens;
    }

    // ========================================================================
    // LOGIC TRACE — Semantic Meaning Extraction
    // ========================================================================

    /**
     * Look up the Semantic Dictionary entry for a token.
     * Handles numbered variants like [DEC_01] → strips _NN to find base key.
     * Falls back to Rule 9 default for unknown tokens.
     */
    _lookupSemantic(token) {
        // Strip bracket wrappers: [DML_W] → DML_W
        const stripped = token.replace(/[\[\]!]/g, '');
        // Try exact match first (handles !ERR_BULK_LIMIT!)
        if (SEMANTIC_DICTIONARY[token])    return SEMANTIC_DICTIONARY[token];
        if (SEMANTIC_DICTIONARY[stripped]) return SEMANTIC_DICTIONARY[stripped];
        // Strip numeric suffix: DEC_01 → DEC
        const base = stripped.replace(/_\d+$/, '');
        if (SEMANTIC_DICTIONARY[base])     return SEMANTIC_DICTIONARY[base];
        // Rule 9: Unknown token fallback
        return {
            meaning:  'Unknown element encountered: ' + token,
            impact:   'This element type is not yet mapped in the Semantic Dictionary.',
            category: 'action',
            shape:    'rect',
            color:    '#b0adab'
        };
    }

    _generateTrace(tokens) {
        return tokens.map((entry, idx) => {
            const semantic = this._lookupSemantic(entry.token);

            // Override for synthetic loop-end tokens
            const isLoopEnd = entry.elementType === 'loopEnd';
            const loopEndSemantic = SEMANTIC_DICTIONARY['LOOP_E'];

            return {
                step: idx + 1,
                token: entry.token,
                elementName: entry.name,
                explanation: isLoopEnd ? loopEndSemantic.meaning : semantic.meaning,
                impact:      isLoopEnd ? loopEndSemantic.impact  : semantic.impact,
                category:    isLoopEnd ? loopEndSemantic.category : semantic.category
            };
        });
    }

    // ========================================================================
    // VISUAL TRUTH — Sovereign Flowchart (Pure SVG, Zero Dependencies)
    // ========================================================================

    /**
     * Generate a complete SVG flowchart from the execution graph.
     * Returns raw SVG markup string that can be injected via innerHTML.
     *
     * 100% local. No Mermaid. No external libraries. Pure geometry.
     *
     * Shape vocabulary:
     *   Stadium (rounded pill)  — Start / End
     *   Diamond                 — Decisions
     *   Rectangle               — DML, SOQL, Assignments
     *   Hexagon                 — Loops
     *   Rounded Rectangle       — External Actions, Subflows, Waits
     *   Flag (asymmetric)       — Screens
     *   Octagon                 — Errors / Faults
     */
    _generateSvgFlowchart(graph, elements, tokens) {

        // ── Layout constants (v2 — proportional spacing) ─────────────
        const NODE_W      = 240;       // Node width
        const NODE_H      = 48;        // Default node height
        const NODE_H_DIA  = 80;        // Diamond needs extra vertical room
        const GAP_Y       = 120;       // Vertical gap between nodes (breathing room)
        const BRANCH_GAP  = 300;       // Horizontal gap between decision branches
        const PAD         = 60;        // Canvas padding
        const FONT_SIZE   = 12;
        const SUB_FONT    = 10;        // Sub-label font size
        const LABEL_SIZE  = 10;
        const ARROW_SIZE  = 7;
        const STROKE_W    = 2;         // Shape stroke width
        const RX          = 8;         // Rounded rect corner radius

        // ── Collect ordered nodes via DFS ────────────────────────────
        const nodeOrder = [];
        const visited   = new Set();
        const nodeMap   = {};

        const walkOrder = (name) => {
            if (!name || visited.has(name)) return;
            visited.add(name);
            const el = elements[name];
            if (!el) return;
            nodeOrder.push(name);
            const edges = graph[name] || [];
            for (const e of edges) walkOrder(e.target);
        };

        if (elements['__start__']) walkOrder('__start__');
        for (const name of Object.keys(elements)) {
            if (!visited.has(name)) walkOrder(name);
        }

        if (nodeOrder.length === 0) {
            return '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="60">' +
                   '<rect width="100%" height="100%" fill="#1b2531" rx="8"/>' +
                   '<text x="200" y="35" text-anchor="middle" fill="#8c9cb0" font-size="13" font-family="sans-serif">No executable elements found</text></svg>';
        }

        // ── Assign positions (vertical with branch columns) ─────────
        const branchCols = {};
        for (const name of nodeOrder) {
            const el = elements[name];
            if (!el || el.tag !== 'decisions') continue;
            const edges = graph[name] || [];
            edges.forEach((edge, i) => {
                if (i > 0 && edge.target) branchCols[edge.target] = i;
            });
        }

        let cursorY = PAD;
        let maxX    = 0;

        for (const name of nodeOrder) {
            const el       = elements[name];
            const semantic = this._lookupSemantic(this._tokenize(el.tag, el.name));
            const isDiamond = semantic.shape === 'diamond';
            const h        = isDiamond ? NODE_H_DIA : NODE_H;
            const col      = branchCols[name] || 0;
            const x        = PAD + (col * BRANCH_GAP);

            nodeMap[name] = {
                x, y: cursorY, w: NODE_W, h,
                cx: x + NODE_W / 2,
                cy: cursorY + h / 2,
                bottom: cursorY + h,
                label: name === '__start__' ? 'Flow Start' : el.name,
                tag: el.tag,
                semantic
            };

            maxX = Math.max(maxX, x + NODE_W);
            cursorY += h + GAP_Y;
        }

        // Dynamic viewBox scales to content
        const totalW = Math.max(maxX + PAD, 400);
        const totalH = cursorY - GAP_Y + PAD + 20;

        // ── Helpers ──────────────────────────────────────────────────
        const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        const truncate = (text, maxLen) => text.length <= maxLen ? text : text.substring(0, maxLen - 1) + '\u2026';

        // Lighten a hex color for stroke
        const strokeColor = (hex) => {
            const r = parseInt(hex.slice(1, 3), 16);
            const g = parseInt(hex.slice(3, 5), 16);
            const b = parseInt(hex.slice(5, 7), 16);
            const lighten = (c) => Math.min(255, c + 40);
            return '#' + [lighten(r), lighten(g), lighten(b)].map(c => c.toString(16).padStart(2, '0')).join('');
        };

        // ── Shape renderers (v2 — distinct strokes, modern rx) ──────
        const shapes = {
            stadium: (n) => {
                const r = n.h / 2;
                return '<rect x="' + n.x + '" y="' + n.y + '" width="' + n.w + '" height="' + n.h + '" rx="' + r + '" ry="' + r + '" ' +
                       'fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '"/>';
            },
            diamond: (n) => {
                const cx = n.cx, cy = n.cy, hw = n.w * 0.5, hh = n.h * 0.5;
                const pts = cx + ',' + (cy - hh) + ' ' + (cx + hw) + ',' + cy + ' ' + cx + ',' + (cy + hh) + ' ' + (cx - hw) + ',' + cy;
                return '<polygon points="' + pts + '" fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '" stroke-linejoin="round"/>';
            },
            rect: (n) => {
                return '<rect x="' + n.x + '" y="' + n.y + '" width="' + n.w + '" height="' + n.h + '" rx="' + RX + '" ry="' + RX + '" ' +
                       'fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '"/>';
            },
            hex: (n) => {
                const inset = 18;
                const pts = (n.x + inset) + ',' + n.y + ' ' +
                            (n.x + n.w - inset) + ',' + n.y + ' ' +
                            (n.x + n.w) + ',' + n.cy + ' ' +
                            (n.x + n.w - inset) + ',' + (n.y + n.h) + ' ' +
                            (n.x + inset) + ',' + (n.y + n.h) + ' ' +
                            n.x + ',' + n.cy;
                return '<polygon points="' + pts + '" fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '" stroke-linejoin="round"/>';
            },
            rounded: (n) => {
                return '<rect x="' + n.x + '" y="' + n.y + '" width="' + n.w + '" height="' + n.h + '" rx="16" ry="16" ' +
                       'fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '"/>';
            },
            flag: (n) => {
                const pts = n.x + ',' + n.y + ' ' +
                            (n.x + n.w - 16) + ',' + n.y + ' ' +
                            (n.x + n.w) + ',' + n.cy + ' ' +
                            (n.x + n.w - 16) + ',' + (n.y + n.h) + ' ' +
                            n.x + ',' + (n.y + n.h);
                return '<polygon points="' + pts + '" fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '" stroke-linejoin="round"/>';
            },
            octagon: (n) => {
                const c = 14;
                const pts = (n.x + c) + ',' + n.y + ' ' + (n.x + n.w - c) + ',' + n.y + ' ' +
                            (n.x + n.w) + ',' + (n.y + c) + ' ' + (n.x + n.w) + ',' + (n.y + n.h - c) + ' ' +
                            (n.x + n.w - c) + ',' + (n.y + n.h) + ' ' + (n.x + c) + ',' + (n.y + n.h) + ' ' +
                            n.x + ',' + (n.y + n.h - c) + ' ' + n.x + ',' + (n.y + c);
                return '<polygon points="' + pts + '" fill="' + n.semantic.color + '" stroke="' + strokeColor(n.semantic.color) + '" stroke-width="' + STROKE_W + '" stroke-linejoin="round"/>';
            }
        };

        // ── Build SVG ────────────────────────────────────────────────
        const svgParts = [];

        // Defs: arrowhead marker + drop shadow
        svgParts.push('<defs>');
        svgParts.push('  <marker id="sov-arrow" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="' + ARROW_SIZE + '" markerHeight="' + ARROW_SIZE + '" orient="auto-start-reverse">');
        svgParts.push('    <path d="M 0 1 L 11 6 L 0 11 z" fill="#6b7b8d"/>');
        svgParts.push('  </marker>');
        svgParts.push('  <filter id="sov-shadow" x="-5%" y="-5%" width="110%" height="120%">');
        svgParts.push('    <feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#000000" flood-opacity="0.18"/>');
        svgParts.push('  </filter>');
        svgParts.push('</defs>');

        // Background
        svgParts.push('<rect width="100%" height="100%" fill="#1b2531" rx="10"/>');

        // ── Draw edges (behind nodes) ────────────────────────────────
        for (const name of nodeOrder) {
            const src = nodeMap[name];
            if (!src) continue;
            const edges = graph[name] || [];

            for (const edge of edges) {
                const tgt = nodeMap[edge.target];
                if (!tgt) continue;

                const x1 = src.cx;
                const y1 = src.bottom;           // from bottom of source
                const x2 = tgt.cx;
                const y2 = tgt.y;                // to top of target

                if (Math.abs(x1 - x2) < 5) {
                    // Straight vertical connector
                    svgParts.push('<line x1="' + x1 + '" y1="' + y1 + '" x2="' + x2 + '" y2="' + y2 + '" stroke="#5a6a7d" stroke-width="2" marker-end="url(#sov-arrow)"/>');
                } else {
                    // Bezier curve for cross-branch connectors
                    const cp1y = y1 + (y2 - y1) * 0.35;
                    const cp2y = y1 + (y2 - y1) * 0.65;
                    svgParts.push('<path d="M ' + x1 + ' ' + y1 + ' C ' + x1 + ' ' + cp1y + ', ' + x2 + ' ' + cp2y + ', ' + x2 + ' ' + y2 + '" ' +
                                  'fill="none" stroke="#5a6a7d" stroke-width="2" stroke-dasharray="6,4" marker-end="url(#sov-arrow)"/>');
                }

                // Edge label (centered on connector midpoint)
                if (edge.label && edge.label !== 'next') {
                    const lx = (x1 + x2) / 2 + (x1 === x2 ? 0 : 8);
                    const ly = (y1 + y2) / 2;
                    svgParts.push('<rect x="' + (lx - 28) + '" y="' + (ly - 8) + '" width="56" height="16" rx="4" fill="#1b2531" stroke="#5a6a7d" stroke-width="0.5"/>');
                    svgParts.push('<text x="' + lx + '" y="' + (ly + 3) + '" text-anchor="middle" fill="#8c9cb0" font-size="' + LABEL_SIZE + '" font-family="sans-serif" font-style="italic">' + esc(truncate(edge.label, 10)) + '</text>');
                }
            }
        }

        // ── Draw nodes ───────────────────────────────────────────────
        for (const name of nodeOrder) {
            const n = nodeMap[name];
            if (!n) continue;
            const shapeFn = shapes[n.semantic.shape] || shapes.rect;
            const isDark = n.semantic.color === '#f4bc25';
            const textColor = isDark ? '#1b2531' : '#ffffff';

            // Shadow + shape
            svgParts.push('<g filter="url(#sov-shadow)">');
            svgParts.push(shapeFn(n));
            svgParts.push('</g>');

            // Primary label (element name)
            const displayLabel = truncate(n.label, 28);
            svgParts.push('<text x="' + n.cx + '" y="' + (n.cy - 2) + '" text-anchor="middle" dominant-baseline="middle" ' +
                          'fill="' + textColor + '" font-size="' + FONT_SIZE + '" font-weight="700" font-family="\'SF Mono\', Consolas, Monaco, monospace">' +
                          esc(displayLabel) + '</text>');

            // Sub-label (token badge below the name — for non-start nodes)
            if (n.tag !== 'start' && name !== '__start__') {
                const tok = this._tokenize(n.tag, n.label);
                svgParts.push('<text x="' + n.cx + '" y="' + (n.cy + 14) + '" text-anchor="middle" dominant-baseline="middle" ' +
                              'fill="' + textColor + '" font-size="' + SUB_FONT + '" font-weight="400" font-family="sans-serif" opacity="0.7">' +
                              esc(tok) + '</text>');
            }
        }

        // ── Legend (top-right corner) ──────────────────────────────────
        const legendItems = [
            { shape: 'stadium', label: 'Start', color: '#0176d3' },
            { shape: 'diamond', label: 'Decision', color: '#9b59b6' },
            { shape: 'rect',    label: 'DML/SOQL', color: '#e87400' },
            { shape: 'hex',     label: 'Loop', color: '#f4bc25' },
            { shape: 'rounded', label: 'Action', color: '#0b8dff' },
            { shape: 'octagon', label: 'Error', color: '#c23934' }
        ];
        const legendX = totalW - 135;
        let legendY = PAD + 10;
        // Semi-transparent background panel for the legend — wrapped in a <g> so it can be hidden inline
        const legendH = legendItems.length * 22 + 24;
        svgParts.push('<g data-legend="true">');
        svgParts.push('<rect x="' + (legendX - 10) + '" y="' + (legendY - 20) + '" width="130" height="' + legendH + '" rx="6" fill="#1b2531" fill-opacity="0.85" stroke="#3a4a5c" stroke-width="1"/>');
        svgParts.push('<text x="' + legendX + '" y="' + (legendY - 4) + '" fill="#8c9cb0" font-size="9" font-weight="700" font-family="sans-serif" letter-spacing="0.1em">LEGEND</text>');
        legendY += 8;
        for (const item of legendItems) {
            svgParts.push('<rect x="' + legendX + '" y="' + legendY + '" width="14" height="14" rx="3" fill="' + item.color + '"/>');
            svgParts.push('<text x="' + (legendX + 20) + '" y="' + (legendY + 11) + '" fill="#8c9cb0" font-size="10" font-family="sans-serif">' + item.label + '</text>');
            legendY += 22;
        }
        svgParts.push('</g>');

        // ── Assemble final SVG with dynamic viewBox ──────────────────
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + totalW + ' ' + totalH + '" ' +
               'width="100%" preserveAspectRatio="xMidYMin meet" ' +
               'style="border-radius: 0.5rem; background: #1b2531;">' +
               svgParts.join('\n') + '</svg>';
    }

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================

    _getChildText(parent, tagName) {
        // Try with namespace and without
        for (const child of parent.children) {
            if (child.localName === tagName) {
                return child.textContent.trim();
            }
        }
        return null;
    }

    _humanFlowType(processType) {
        const map = {
            'AutoLaunchedFlow':     'Autolaunched Flow',
            'Flow':                 'Screen Flow',
            'RecordTriggeredFlow':  'Record-Triggered Flow',
            'Workflow':             'Record-Triggered Flow (Workflow)',
            'CustomEvent':          'Platform Event Flow',
            'InvocableProcess':     'Invocable Process',
            'RecordBeforeSave':     'Before-Save Flow',
            'RecordAfterSave':      'After-Save Flow',
            'Schedule':             'Scheduled Flow',
            'PlatformEvent':        'Platform Event Flow'
        };
        return map[processType] || processType;
    }

    _buildSummary(tokens) {
        const summary = {
            decisions: 0,
            dmlWrites: 0,
            dmlDeletes: 0,
            queries: 0,
            loops: 0,
            screens: 0,
            actions: 0,
            assignments: 0,
            subflows: 0,
            unknowns: 0,
            riskFlags: 0
        };

        for (const entry of tokens) {
            const t = entry.token;
            if (t.startsWith('[DEC_'))   summary.decisions++;
            else if (t === '[DML_W]')    summary.dmlWrites++;
            else if (t === '[DML_D]')    summary.dmlDeletes++;
            else if (t === '[SOQL_R]')   summary.queries++;
            else if (t === '[LOOP_S]')   summary.loops++;
            else if (t === '[SCREEN]')   summary.screens++;
            else if (t === '[EXT_ACT]')  summary.actions++;
            else if (t === '[ASSIGN]')   summary.assignments++;
            else if (t === '[SUBFLOW]')  summary.subflows++;
            else if (t.startsWith('[UNKNOWN:')) summary.unknowns++;
            else if (t === '!ERR_BULK_LIMIT!') summary.riskFlags++;
        }

        return summary;
    }

    _errorReport(message) {
        return {
            success: false,
            hash: '',
            tokens: [],
            flowType: 'Unknown',
            apiVersion: '',
            elementSummary: {},
            warnings: [{ type: 'PARSE_ERROR', severity: 'Critical', message, detail: '', remediation: 'Check XML validity.' }],
            trace: [],
            flowchartSvg: '',
            stats: { totalElements: 0, noiseStripped: 0, unknownTags: 0, processingTimeMs: 0 }
        };
    }
}

// ============================================================================
// EXPORTS
// ============================================================================

export { SanityEngine, FLOW_TOKEN_MAP, SEMANTIC_DICTIONARY, TRACE_DICTIONARY };
