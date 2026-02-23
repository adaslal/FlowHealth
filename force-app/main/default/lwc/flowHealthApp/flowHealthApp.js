/**
 * flowHealthApp - Main container component for Flow Health.
 *
 * This is the top-level component placed on a Lightning App Page.
 * It coordinates child components and manages the overall state.
 *
 * SPRINT 1: Flow selector + metadata summary (element counts).
 * SPRINT 2: Health score, rule analysis, findings display.
 * SPRINT 3: Bulk analysis dashboard — scan all flows, org-wide metrics, sortable table.
 * SPRINT 4: Historical trends, report export (CSV + PDF), rule configuration settings.
 */
import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFlowList from '@salesforce/apex/FlowHealthController.getFlowList';
import getFlowDetail from '@salesforce/apex/FlowHealthController.getFlowDetail';
import analyzeFlow from '@salesforce/apex/FlowHealthController.analyzeFlow';
import analyzeFlowWithSnapshot from '@salesforce/apex/FlowHealthController.analyzeFlowWithSnapshot';
// Sprint 4: History + Trend
import getFlowHistory from '@salesforce/apex/FlowHealthController.getFlowHistory';
import getOrgTrend from '@salesforce/apex/FlowHealthController.getOrgTrend';
import getFlowTrendSummary from '@salesforce/apex/FlowHealthController.getFlowTrendSummary';
// Sprint 4: Rule Configuration
import getAllRuleConfigs from '@salesforce/apex/FlowHealthController.getAllRuleConfigs';
import saveRuleChanges from '@salesforce/apex/FlowHealthController.saveRuleChanges';
import getDeployStatus from '@salesforce/apex/FlowHealthController.getDeployStatus';
// Sprint 5: Custom Rules
import getCustomRules from '@salesforce/apex/FlowHealthController.getCustomRules';
import saveCustomRule from '@salesforce/apex/FlowHealthController.saveCustomRule';
import deleteCustomRule from '@salesforce/apex/FlowHealthController.deleteCustomRule';
import toggleCustomRule from '@salesforce/apex/FlowHealthController.toggleCustomRule';
import testCustomRule from '@salesforce/apex/FlowHealthController.testCustomRule';
// Sprint 6: Version Comparison
import getFlowVersions from '@salesforce/apex/FlowHealthController.getFlowVersions';
import compareFlowVersions from '@salesforce/apex/FlowHealthController.compareFlowVersions';
// Sprint 7: PermSet Patchmaster
import generatePermSetPatch from '@salesforce/apex/FlowHealthController.generatePermSetPatch';

// Process type labels (shared between single + bulk views)
const PROCESS_TYPE_LABELS = {
    'AutoLaunchedFlow': 'Autolaunched',
    'Flow': 'Screen Flow',
    'RecordTriggeredFlow': 'Record-Triggered',
    'Workflow': 'Record-Triggered',
    'CustomEvent': 'Platform Event',
    'InvocableProcess': 'Invocable Process'
};

// Grade color map
const GRADE_COLORS = {
    'A': '#04844B',
    'B': '#2E844A',
    'C': '#DD7A01',
    'D': '#BA5005',
    'F': '#C23934'
};

export default class FlowHealthApp extends NavigationMixin(LightningElement) {

    // =========================================================================
    // VIEW MODE: 'single', 'bulk', or 'settings'
    // =========================================================================

    @track viewMode = 'single';
    @track cameFromBulk = false;

    // =========================================================================
    // SINGLE FLOW STATE (Sprint 1-2)
    // =========================================================================

    @track selectedFlowName = null;
    @track flowDetail = null;
    @track analysisResult = null;
    @track isAnalyzing = false;
    @track analysisPhase = '';
    @track error = null;

    // Element count display data
    @track elementSummary = [];

    // Element breakdown drill-down
    @track selectedElementType = null;
    @track selectedElementNames = [];

    // Findings display data
    @track findingsDisplay = [];
    @track activeSections = [];

    // =========================================================================
    // SPRINT 4: SINGLE FLOW TREND STATE
    // =========================================================================

    @track flowHistory = [];
    @track trendSummary = null;
    @track trendLoading = false;

    // =========================================================================
    // BULK DASHBOARD STATE (Sprint 3)
    // =========================================================================

    @track bulkFlowsList = [];
    @track bulkResults = [];
    @track bulkIsScanning = false;
    @track bulkScanIndex = 0;
    @track bulkCurrentFlowName = '';
    @track bulkScanComplete = false;
    @track bulkScanError = null;
    @track bulkFlowsLoaded = false;

    // =========================================================================
    // SPRINT 4: ORG TREND STATE (Bulk Dashboard)
    // =========================================================================

    @track orgTrendData = [];
    @track orgTrendLoaded = false;

    // =========================================================================
    // SPRINT 4: SETTINGS / RULE CONFIG STATE
    // =========================================================================

    @track ruleConfigs = [];
    @track ruleConfigsLoaded = false;
    @track ruleConfigsLoading = false;
    @track ruleConfigsSaving = false;
    @track ruleConfigsSaved = false;
    @track ruleConfigError = null;
    @track ruleDeployJobId = null;
    @track modifiedRules = {}; // key: developerName, value: changed fields

    // =========================================================================
    // SPRINT 5: CUSTOM RULES STATE
    // =========================================================================

    @track customRules = [];
    @track customRulesLoaded = false;
    @track customRulesLoading = false;
    @track customRuleError = null;
    @track showCustomRuleModal = false;
    @track editingRule = {};

    // Test Rule state
    @track testFlowsList = [];
    @track testFlowsLoaded = false;
    @track testRuleFlowName = '';
    @track testRuleLoading = false;
    @track testRuleResult = null;

    // =========================================================================
    // SPRINT 6: VERSION COMPARISON STATE
    // =========================================================================

    @track showCompareModal = false;
    @track compareFlowName = '';       // DeveloperName of the flow being compared
    @track compareVersions = [];       // List of FlowVersionInfo for the selector
    @track compareOldVersionId = '';
    @track compareNewVersionId = '';
    @track compareLoading = false;
    @track compareLoadingVersions = false;
    @track compareDiffResult = null;
    @track compareError = null;
    @track hideCosmeticChanges = false;

    // =========================================================================
    // REFRESH FROM ORG STATE
    // =========================================================================

    @track isRefreshing = false;

    // =========================================================================
    // SPRINT 7: PERMSET PATCHMASTER STATE
    // =========================================================================

    @track patchDestXml = '';              // Destination (Prod) XML
    @track patchSrcXml = '';               // Source (Dev) XML
    @track patchResult = null;             // PermSetPatchService.PatchResult
    @track patchLoading = false;
    @track patchError = null;
    @track patchSuccessVisible = false;    // Success toast visibility
    @track showPatchedXmlPreview = false;  // Toggle for patched XML preview

    // =========================================================================
    // VIEW TOGGLE HANDLERS
    // =========================================================================

    handleViewToggle(event) {
        const view = event.currentTarget.dataset.view;
        this.viewMode = view;
        if (view === 'bulk' && !this.bulkFlowsLoaded) {
            this.loadBulkFlowList();
        }
        if (view === 'bulk' && !this.orgTrendLoaded) {
            this.loadOrgTrend();
        }
        if (view === 'settings' && !this.ruleConfigsLoaded) {
            this.loadRuleConfigs();
        }
        if (view === 'settings' && !this.customRulesLoaded) {
            this.loadCustomRules();
        }
    }

    handleBackToDashboard() {
        this.viewMode = 'bulk';
        this.cameFromBulk = false;
        this.selectedFlowName = null;
        this.flowDetail = null;
        this.analysisResult = null;
        this.error = null;
        this.isAnalyzing = false;
        this.flowHistory = [];
        this.trendSummary = null;
    }

    // =========================================================================
    // SINGLE FLOW HANDLERS (Sprint 1-2)
    // =========================================================================

    handleFlowSelect(event) {
        const { developerName } = event.detail;
        this.selectedFlowName = developerName;
        this.flowDetail = null;
        this.analysisResult = null;
        this.error = null;
        this.selectedElementType = null;
        this.selectedElementNames = [];
        this.flowHistory = [];
        this.trendSummary = null;
        this.isAnalyzing = true;
        this.analysisPhase = 'Fetching flow metadata...';

        getFlowDetail({ flowDeveloperName: developerName })
            .then(result => {
                this.flowDetail = result;
                this.buildElementSummary(result);
                this.analysisPhase = 'Running health rules...';
                return analyzeFlow({ flowDeveloperName: developerName });
            })
            .then(result => {
                this.analysisResult = result;
                this.buildFindingsDisplay(result);
                this.isAnalyzing = false;
                // Sprint 4: Load trend data after analysis
                this.loadFlowTrend(developerName);
            })
            .catch(error => {
                this.error = this.extractError(error);
                this.isAnalyzing = false;
            });
    }

    /**
     * Refresh from Org — re-analyzes the currently selected flow
     * without clearing the previous results until the new data arrives.
     * This is the "Developer Productivity Loop" feature.
     */
    handleRefreshFromOrg() {
        if (!this.selectedFlowName || this.isRefreshing) return;

        const developerName = this.selectedFlowName;
        this.isRefreshing = true;
        this.error = null;

        getFlowDetail({ flowDeveloperName: developerName })
            .then(result => {
                this.flowDetail = result;
                this.buildElementSummary(result);
                return analyzeFlow({ flowDeveloperName: developerName });
            })
            .then(result => {
                this.analysisResult = result;
                this.buildFindingsDisplay(result);
                this.isRefreshing = false;
                this.loadFlowTrend(developerName);
            })
            .catch(error => {
                this.error = this.extractError(error);
                this.isRefreshing = false;
            });
    }

    get refreshButtonLabel() {
        return this.isRefreshing ? 'Refreshing...' : 'Refresh from Org';
    }

    buildElementSummary(detail) {
        const iconMap = {
            'actionCalls': { icon: 'standard:apex', label: 'Action Calls' },
            'assignments': { icon: 'standard:assignment', label: 'Assignments' },
            'decisions': { icon: 'standard:decision', label: 'Decisions' },
            'loops': { icon: 'standard:loop', label: 'Loops' },
            'recordCreates': { icon: 'standard:record_create', label: 'Record Creates' },
            'recordUpdates': { icon: 'standard:record_update', label: 'Record Updates' },
            'recordDeletes': { icon: 'standard:record_delete', label: 'Record Deletes' },
            'recordLookups': { icon: 'standard:record_lookup', label: 'Record Lookups' },
            'screens': { icon: 'standard:screen', label: 'Screens' },
            'subflows': { icon: 'standard:flow', label: 'Subflows' },
            'variables': { icon: 'standard:variable', label: 'Variables' },
            'formulas': { icon: 'standard:formula', label: 'Formulas' }
        };

        this.elementSummary = Object.keys(detail.elementCounts)
            .filter(key => detail.elementCounts[key] > 0)
            .map(key => ({
                key: key,
                count: detail.elementCounts[key],
                label: (iconMap[key] && iconMap[key].label) ? iconMap[key].label : key,
                icon: (iconMap[key] && iconMap[key].icon) ? iconMap[key].icon : 'standard:default',
                cardClass: 'slds-box slds-box_x-small slds-theme_default element-card element-card-clickable'
            }))
            .sort((a, b) => b.count - a.count);
    }

    buildFindingsDisplay(result) {
        if (!result || !result.findingsByCategory) {
            this.findingsDisplay = [];
            return;
        }

        const categoryIcons = {
            'Performance': 'utility:metrics',
            'Error Handling': 'utility:shield',
            'Design': 'utility:palette',
            'Security': 'utility:lock'
        };

        const severityOrder = { 'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3 };

        this.findingsDisplay = Object.keys(result.findingsByCategory)
            .map(category => {
                const findings = result.findingsByCategory[category]
                    .map((f, idx) => ({
                        ...f,
                        key: category + '_' + idx,
                        severityBadgeClass: this.getSeverityBadgeClass(f.severity),
                        hasElement: f.elementName != null
                    }))
                    .sort((a, b) => (severityOrder[a.severity] || 99) - (severityOrder[b.severity] || 99));

                const catScore = result.categoryScores ? result.categoryScores[category] : null;

                return {
                    category: category,
                    icon: categoryIcons[category] || 'utility:info',
                    count: findings.length,
                    score: catScore != null ? catScore : '--',
                    scoreClass: this.getScoreColorClass(catScore),
                    findings: findings
                };
            })
            .sort((a, b) => {
                const order = ['Performance', 'Error Handling', 'Design', 'Security'];
                return (order.indexOf(a.category) - order.indexOf(b.category));
            });

        this.activeSections = this.findingsDisplay.map(c => c.category);
    }

    /**
     * Flat summary list of ALL findings across all categories,
     * sorted by severity (Critical → Low) for the compact summary table.
     * Each item gets a unique anchor key for scroll-to linking.
     */
    get findingsSummaryTable() {
        if (!this.findingsDisplay || this.findingsDisplay.length === 0) return [];

        // Severity weights — Critical always on top, matching strategic priority weights
        const severityWeight = { 'Critical': 100, 'High': 50, 'Medium': 10, 'Low': 1 };

        // Flatten all findings across categories
        const flat = [];
        this.findingsDisplay.forEach(cat => {
            cat.findings.forEach(f => {
                flat.push({
                    ...f,
                    tableRowClass: 'findings-summary-row severity-row-' + (f.severity || 'Medium').toLowerCase(),
                    sortWeight: severityWeight[f.severity] || 0
                });
            });
        });

        // Sort by weight descending (Critical 100 → High 50 → Medium 10 → Low 1)
        flat.sort((a, b) => b.sortWeight - a.sortWeight);

        // Assign idx, anchorKey, and elementLabel AFTER sorting
        return flat.map((item, idx) => ({
            ...item,
            idx: idx + 1,
            elementLabel: item.hasElement ? item.elementName + ' (' + item.elementType + ')' : 'Flow-Level Rule',
            anchorKey: 'finding-card-' + idx
        }));
    }

    /**
     * Handles click on a summary table row → smooth-scrolls to the matching Remediation Card.
     */
    handleFindingRowClick(event) {
        const anchorKey = event.currentTarget.dataset.anchor;
        if (!anchorKey) return;
        const targetEl = this.template.querySelector('[data-card-id="' + anchorKey + '"]');
        if (targetEl) {
            targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
            // Flash highlight effect
            targetEl.classList.add('finding-card-highlight');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                targetEl.classList.remove('finding-card-highlight');
            }, 1500);
        }
    }

    handleElementTileClick(event) {
        const typeKey = event.currentTarget.dataset.type;
        if (this.selectedElementType === typeKey) {
            this.selectedElementType = null;
            this.selectedElementNames = [];
        } else {
            this.selectedElementType = typeKey;
            const names = this.flowDetail && this.flowDetail.elementNames
                ? this.flowDetail.elementNames[typeKey]
                : [];
            this.selectedElementNames = (names || []).map((name, idx) => ({
                key: typeKey + '_' + idx,
                name: name
            }));
        }
        this.elementSummary = this.elementSummary.map(item => ({
            ...item,
            cardClass: item.key === this.selectedElementType
                ? 'slds-box slds-box_x-small slds-theme_default element-card element-card-selected'
                : 'slds-box slds-box_x-small slds-theme_default element-card element-card-clickable'
        }));
    }

    get hasSelectedElements() {
        return this.selectedElementType !== null && this.selectedElementNames.length > 0;
    }

    get selectedElementLabel() {
        const item = this.elementSummary.find(e => e.key === this.selectedElementType);
        return item ? item.label : this.selectedElementType;
    }

    // =========================================================================
    // SPRINT 4: FLOW TREND (Single Flow)
    // =========================================================================

    loadFlowTrend(flowDevName) {
        this.trendLoading = true;
        // Load history + trend summary in parallel using Promise.all
        Promise.all([
            getFlowHistory({ flowDeveloperName: flowDevName }),
            getFlowTrendSummary({ flowDeveloperName: flowDevName })
        ])
            .then(([history, summary]) => {
                // History comes newest-first; reverse for chart (oldest-left to newest-right)
                this.flowHistory = (history || []).reverse();
                this.trendSummary = summary;
                this.trendLoading = false;
            })
            .catch(() => {
                // Trend is supplementary — don't block the main UI
                this.trendLoading = false;
            });
    }

    get hasTrendData() {
        return this.flowHistory.length > 1;
    }

    get trendBadgeText() {
        if (!this.trendSummary) return '';
        if (this.trendSummary.isFirstScan) return 'First scan';
        const delta = this.trendSummary.scoreDelta;
        if (delta > 0) return '+' + delta + ' pts';
        if (delta < 0) return delta + ' pts';
        return 'No change';
    }

    get trendBadgeClass() {
        if (!this.trendSummary || this.trendSummary.isFirstScan) return 'trend-badge trend-badge-neutral';
        if (this.trendSummary.scoreDelta > 0) return 'trend-badge trend-badge-up';
        if (this.trendSummary.scoreDelta < 0) return 'trend-badge trend-badge-down';
        return 'trend-badge trend-badge-neutral';
    }

    get trendDirectionIcon() {
        if (!this.trendSummary || this.trendSummary.isFirstScan) return 'utility:info';
        if (this.trendSummary.scoreDelta > 0) return 'utility:arrowup';
        if (this.trendSummary.scoreDelta < 0) return 'utility:arrowdown';
        return 'utility:dash';
    }

    /**
     * Builds SVG path data for the trend line chart.
     * Returns an array of point objects {x, y, score, label} for SVG rendering.
     */
    get trendChartPoints() {
        if (this.flowHistory.length < 2) return [];

        const chartWidth = 400;
        const chartHeight = 80;
        const padding = 10;
        const usableWidth = chartWidth - (padding * 2);
        const usableHeight = chartHeight - (padding * 2);

        const maxPoints = this.flowHistory.length;
        const step = maxPoints > 1 ? usableWidth / (maxPoints - 1) : 0;

        return this.flowHistory.map((snap, idx) => {
            const score = snap.Score__c || 0;
            const x = padding + (idx * step);
            const y = padding + usableHeight - ((score / 100) * usableHeight);
            return { x, y, score };
        });
    }

    get trendChartLinePath() {
        const pts = this.trendChartPoints;
        if (pts.length < 2) return '';
        return pts.map((p, i) => (i === 0 ? 'M' : 'L') + p.x + ',' + p.y).join(' ');
    }

    get trendChartAreaPath() {
        const pts = this.trendChartPoints;
        if (pts.length < 2) return '';
        const chartHeight = 80;
        const padding = 10;
        const bottom = chartHeight - padding;
        let path = 'M' + pts[0].x + ',' + bottom;
        pts.forEach(p => { path += ' L' + p.x + ',' + p.y; });
        path += ' L' + pts[pts.length - 1].x + ',' + bottom + ' Z';
        return path;
    }

    get trendChartLastPoint() {
        const pts = this.trendChartPoints;
        return pts.length > 0 ? pts[pts.length - 1] : null;
    }

    // =========================================================================
    // BULK DASHBOARD HANDLERS (Sprint 3)
    // =========================================================================

    loadBulkFlowList() {
        getFlowList()
            .then(result => {
                this.bulkFlowsList = result || [];
                this.bulkFlowsLoaded = true;
            })
            .catch(error => {
                this.bulkScanError = this.extractError(error);
                this.bulkFlowsLoaded = true;
            });
    }

    handleScanAllFlows() {
        this.bulkResults = [];
        this.bulkIsScanning = true;
        this.bulkScanComplete = false;
        this.bulkScanError = null;
        this.bulkScanIndex = 0;
        this.scanNextFlow(0);
    }

    scanNextFlow(index) {
        if (index >= this.bulkFlowsList.length) {
            this.bulkIsScanning = false;
            this.bulkScanComplete = true;
            // Refresh org trend after bulk scan
            this.loadOrgTrend();
            return;
        }

        const flow = this.bulkFlowsList[index];
        this.bulkScanIndex = index + 1;
        this.bulkCurrentFlowName = flow.masterLabel || flow.developerName;

        // Sprint 4: Use analyzeFlowWithSnapshot for bulk scans to auto-save history
        analyzeFlowWithSnapshot({
            flowDeveloperName: flow.developerName,
            scanType: 'Bulk'
        })
            .then(result => {
                this.bulkResults = [...this.bulkResults, {
                    flow: flow,
                    result: result,
                    failed: false
                }];
                this.scanNextFlow(index + 1);
            })
            .catch(error => {
                this.bulkResults = [...this.bulkResults, {
                    flow: flow,
                    result: null,
                    failed: true,
                    errorMessage: this.extractError(error)
                }];
                this.scanNextFlow(index + 1);
            });
    }

    handleBulkRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'view_details') {
            this.cameFromBulk = true;
            this.viewMode = 'single';
            this.handleFlowSelect({
                detail: { developerName: row.developerName }
            });
        }
    }

    // =========================================================================
    // SPRINT 4: ORG TREND (Bulk Dashboard)
    // =========================================================================

    loadOrgTrend() {
        getOrgTrend()
            .then(result => {
                this.orgTrendData = result || [];
                this.orgTrendLoaded = true;
            })
            .catch(() => {
                this.orgTrendLoaded = true;
            });
    }

    get hasOrgTrend() {
        return this.orgTrendData.length > 1;
    }

    get orgTrendChartPoints() {
        if (this.orgTrendData.length < 2) return [];

        const chartWidth = 600;
        const chartHeight = 100;
        const padding = 10;
        const usableWidth = chartWidth - (padding * 2);
        const usableHeight = chartHeight - (padding * 2);

        const maxPoints = this.orgTrendData.length;
        const step = maxPoints > 1 ? usableWidth / (maxPoints - 1) : 0;

        return this.orgTrendData.map((pt, idx) => {
            const score = pt.avgScore || 0;
            const x = padding + (idx * step);
            const y = padding + usableHeight - ((score / 100) * usableHeight);
            return { x, y, score, date: pt.scanDate, flowCount: pt.flowCount };
        });
    }

    get orgTrendLinePath() {
        const pts = this.orgTrendChartPoints;
        if (pts.length < 2) return '';
        return pts.map((p, i) => (i === 0 ? 'M' : 'L') + p.x + ',' + p.y).join(' ');
    }

    get orgTrendAreaPath() {
        const pts = this.orgTrendChartPoints;
        if (pts.length < 2) return '';
        const chartHeight = 100;
        const padding = 10;
        const bottom = chartHeight - padding;
        let path = 'M' + pts[0].x + ',' + bottom;
        pts.forEach(p => { path += ' L' + p.x + ',' + p.y; });
        path += ' L' + pts[pts.length - 1].x + ',' + bottom + ' Z';
        return path;
    }

    // =========================================================================
    // SPRINT 4: CSV EXPORT
    // =========================================================================

    /**
     * Exports single-flow findings as CSV.
     */
    handleExportCsv() {
        if (!this.analysisResult || !this.analysisResult.findings) return;

        const rows = [
            ['Rule ID', 'Rule Name', 'Category', 'Severity', 'Element Name', 'Element Type', 'Description', 'Remediation']
        ];

        this.analysisResult.findings.forEach(f => {
            rows.push([
                this.csvEscape(f.ruleId),
                this.csvEscape(f.ruleName),
                this.csvEscape(f.category),
                this.csvEscape(f.severity),
                this.csvEscape(f.elementName || ''),
                this.csvEscape(f.elementType || ''),
                this.csvEscape(f.description),
                this.csvEscape(f.remediation)
            ]);
        });

        // Header row with flow info
        const header = 'Flow: ' + (this.flowDetail ? this.flowDetail.label : this.selectedFlowName) +
            ' | Score: ' + this.healthScore + '/100 | Grade: ' + this.healthGrade + '\n\n';

        const csvContent = header + rows.map(r => r.join(',')).join('\n');
        const filename = 'FlowHealth_' + (this.selectedFlowName || 'Report') + '_' +
            new Date().toISOString().slice(0, 10) + '.csv';

        this.downloadFile(csvContent, filename, 'text/csv');
    }

    /**
     * Exports bulk dashboard results as CSV.
     * Includes a "Most Common Failure" column showing the #1 rule violation per flow.
     */
    handleExportBulkCsv() {
        if (!this.hasBulkResults) return;

        // Compute org-wide most common failure (across all flows)
        const orgRuleCounts = {};
        this.bulkResults.forEach(item => {
            if (!item.failed && item.result && item.result.findings) {
                item.result.findings.forEach(f => {
                    const key = f.ruleId + ': ' + f.ruleName;
                    orgRuleCounts[key] = (orgRuleCounts[key] || 0) + 1;
                });
            }
        });
        let orgMostCommon = 'N/A';
        let orgMaxCount = 0;
        Object.keys(orgRuleCounts).forEach(key => {
            if (orgRuleCounts[key] > orgMaxCount) {
                orgMaxCount = orgRuleCounts[key];
                orgMostCommon = key + ' (' + orgRuleCounts[key] + ' occurrences)';
            }
        });

        // =====================================================================
        // TABLE 1: FLOW HEALTH SCORES
        // =====================================================================
        const table1 = [
            ['FLOW HEALTH SCORES'],
            ['Flow Name', 'Developer Name', 'Type', 'Score', 'Grade', 'Findings', 'Critical', 'High', 'Medium', 'Low', 'Top Failure']
        ];

        this.bulkResults.forEach(item => {
            if (item.failed) {
                table1.push([
                    this.csvEscape(item.flow.masterLabel || item.flow.developerName),
                    this.csvEscape(item.flow.developerName),
                    this.csvEscape(PROCESS_TYPE_LABELS[item.flow.processType] || item.flow.processType || ''),
                    'Error', '', '', '', '', '', '', ''
                ]);
            } else {
                const r = item.result;
                const sev = r.findingsBySeverity || {};

                // Compute per-flow most common failure
                const flowRuleCounts = {};
                if (r.findings) {
                    r.findings.forEach(f => {
                        const key = f.ruleId + ': ' + f.ruleName;
                        flowRuleCounts[key] = (flowRuleCounts[key] || 0) + 1;
                    });
                }
                let flowMostCommon = 'None';
                let flowMaxCount = 0;
                Object.keys(flowRuleCounts).forEach(key => {
                    if (flowRuleCounts[key] > flowMaxCount) {
                        flowMaxCount = flowRuleCounts[key];
                        flowMostCommon = key + (flowRuleCounts[key] > 1 ? ' (x' + flowRuleCounts[key] + ')' : '');
                    }
                });

                table1.push([
                    this.csvEscape(item.flow.masterLabel || item.flow.developerName),
                    this.csvEscape(item.flow.developerName),
                    this.csvEscape(PROCESS_TYPE_LABELS[item.flow.processType] || item.flow.processType || ''),
                    r.score,
                    r.grade,
                    r.totalFindings,
                    sev.Critical || 0,
                    sev.High || 0,
                    sev.Medium || 0,
                    sev.Low || 0,
                    this.csvEscape(flowMostCommon)
                ]);
            }
        });

        // Org summary row
        table1.push([]);
        table1.push(['ORG SUMMARY', '', '', this.avgScore, this.avgGrade, this.bulkTotalFindings, this.bulkTotalCritical, '', '', '', this.csvEscape(orgMostCommon)]);

        // =====================================================================
        // TABLE 2: ORG-WIDE STRATEGIC ACTION PLAN (separate table)
        // =====================================================================
        const table2 = [];
        const insights = this.strategicInsights;

        if (insights.length > 0) {
            table2.push(['ORG-WIDE STRATEGIC ACTION PLAN']);
            table2.push(['Rank', 'Rule ID', 'Rule Name', 'Severity', 'Occurrences', 'Affected Flows', 'Affected %', 'Priority', 'Description', 'Remediation']);

            const criticalItems = insights.filter(i => i.isCriticalTier);
            const otherItems = insights.filter(i => !i.isCriticalTier);

            if (criticalItems.length > 0) {
                table2.push(['--- NEEDS IMMEDIATE ATTENTION ---']);
                criticalItems.forEach(insight => {
                    table2.push([
                        insight.rank,
                        this.csvEscape(insight.ruleId),
                        this.csvEscape(insight.ruleName),
                        insight.severity,
                        insight.totalCount,
                        insight.affectedFlowCount,
                        insight.affectedPercent + '%',
                        insight.displayPriority,
                        this.csvEscape(this.wrapText(insight.description, 60)),
                        this.csvEscape(this.wrapText(insight.remediation, 60))
                    ]);
                });
            }

            if (otherItems.length > 0) {
                table2.push(['--- IMPROVEMENT OPPORTUNITIES ---']);
                otherItems.forEach(insight => {
                    table2.push([
                        insight.rank,
                        this.csvEscape(insight.ruleId),
                        this.csvEscape(insight.ruleName),
                        insight.severity,
                        insight.totalCount,
                        insight.affectedFlowCount,
                        insight.affectedPercent + '%',
                        insight.displayPriority,
                        this.csvEscape(this.wrapText(insight.description, 60)),
                        this.csvEscape(this.wrapText(insight.remediation, 60))
                    ]);
                });
            }
        }

        // Export as TWO separate CSV files so tables are truly independent
        // File 1: Flow Health Scores
        const csv1Content = table1.map(r => r.join(',')).join('\n');
        const date = new Date().toISOString().slice(0, 10);
        this.downloadFile(csv1Content, 'FlowHealth_Scores_' + date + '.csv', 'text/csv');

        // File 2: Strategic Action Plan (with slight delay so browser handles both downloads)
        if (table2.length > 0) {
            const csv2Content = table2.map(r => r.join(',')).join('\n');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.downloadFile(csv2Content, 'FlowHealth_ActionPlan_' + date + '.csv', 'text/csv');
            }, 500);
        }

    }

    /**
     * Wraps text at a given character width using newlines within the cell.
     * This prevents CSV columns from being excessively wide.
     */
    wrapText(text, maxWidth) {
        if (!text || text.length <= maxWidth) return text || '';
        const words = text.split(' ');
        const lines = [];
        let currentLine = '';
        words.forEach(word => {
            if (currentLine.length + word.length + 1 > maxWidth && currentLine.length > 0) {
                lines.push(currentLine);
                currentLine = word;
            } else {
                currentLine = currentLine ? currentLine + ' ' + word : word;
            }
        });
        if (currentLine) lines.push(currentLine);
        return lines.join('\n');
    }

    csvEscape(val) {
        if (val == null) return '';
        const str = String(val);
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
            return '"' + str.replace(/"/g, '""') + '"';
        }
        return str;
    }

    /**
     * Downloads file content using a data URI approach.
     *
     * IMPORTANT: The previous implementation used Blob + URL.createObjectURL +
     * document.body.appendChild(), which fails in Lightning Locker Service because:
     * 1. document.body returns a SecureDocument wrapper, not the real DOM body
     * 2. createElement('a') returns a SecureElement in a different namespace
     * 3. appendChild across Locker namespaces is blocked
     *
     * This fix uses a data: URI which bypasses all Locker Service DOM restrictions.
     * The hidden <a> element in the template (data-id="downloadLink") lives inside
     * the component's shadow DOM, so Locker doesn't interfere.
     */
    downloadFile(content, filename, mimeType) {
        // Use the hidden anchor element in the component's own shadow DOM
        const link = this.template.querySelector('[data-id="downloadLink"]');
        if (link) {
            // Data URI approach — works with Locker Service and LWS
            const encodedContent = encodeURIComponent(content);
            link.href = 'data:' + mimeType + ';charset=utf-8,' + encodedContent;
            link.download = filename;
            link.click();
        } else {
            // Fallback: open in new window (still works in Locker Service)
            const encodedContent = encodeURIComponent(content);
            window.open('data:' + mimeType + ';charset=utf-8,' + encodedContent);
        }
    }

    /**
     * Opens the Visualforce PDF report in a new tab.
     */
    handleExportPdf() {
        if (!this.selectedFlowName) return;
        // Navigate to the VF page which renders as PDF
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/apex/FlowHealthReport?flow=' + encodeURIComponent(this.selectedFlowName)
            }
        });
    }

    get canExportSingle() {
        return this.analysisResult !== null;
    }

    get canExportBulk() {
        return this.hasBulkResults;
    }

    // =========================================================================
    // SPRINT 4: RULE CONFIGURATION (Settings Tab)
    // =========================================================================

    loadRuleConfigs() {
        this.ruleConfigsLoading = true;
        this.ruleConfigError = null;

        getAllRuleConfigs()
            .then(result => {
                this.ruleConfigs = (result || []).map(r => ({
                    ...r,
                    id: r.DeveloperName
                }));
                this.ruleConfigsLoaded = true;
                this.ruleConfigsLoading = false;
                this.modifiedRules = {};
            })
            .catch(error => {
                this.ruleConfigError = this.extractError(error);
                this.ruleConfigsLoading = false;
                this.ruleConfigsLoaded = true;
            });
    }

    get ruleConfigColumns() {
        return [
            { label: 'Rule ID', fieldName: 'Rule_Id__c', type: 'text', initialWidth: 100 },
            { label: 'Rule Name', fieldName: 'MasterLabel', type: 'text', initialWidth: 180 },
            { label: 'Category', fieldName: 'Category__c', type: 'text', initialWidth: 130 },
            { label: 'Severity', fieldName: 'Severity__c', type: 'text', editable: true, initialWidth: 100 },
            { label: 'Weight', fieldName: 'Weight__c', type: 'number', editable: true, initialWidth: 80 },
            { label: 'Max Deduction', fieldName: 'Max_Deduction__c', type: 'number', editable: true, initialWidth: 120 },
            { label: 'Active', fieldName: 'Is_Active__c', type: 'boolean', editable: true, initialWidth: 70 },
            { label: 'Description', fieldName: 'Description__c', type: 'text', wrapText: true }
        ];
    }

    get ruleConfigData() {
        return this.ruleConfigs;
    }

    get hasRuleConfigs() {
        return this.ruleConfigs.length > 0;
    }

    get hasModifiedRules() {
        return Object.keys(this.modifiedRules).length > 0;
    }

    get saveButtonDisabled() {
        return !this.hasModifiedRules || this.ruleConfigsSaving;
    }

    handleRuleCellChange(event) {
        const draftValues = event.detail.draftValues;

        draftValues.forEach(draft => {
            const devName = draft.id;
            if (!this.modifiedRules[devName]) {
                // Find original record
                const original = this.ruleConfigs.find(r => r.DeveloperName === devName);
                if (original) {
                    this.modifiedRules[devName] = {
                        developerName: original.DeveloperName,
                        label: original.MasterLabel,
                        severity: original.Severity__c,
                        weight: original.Weight__c,
                        maxDeduction: original.Max_Deduction__c,
                        isActive: original.Is_Active__c
                    };
                }
            }
            // Apply draft changes
            if (this.modifiedRules[devName]) {
                if (draft.Severity__c !== undefined) this.modifiedRules[devName].severity = draft.Severity__c;
                if (draft.Weight__c !== undefined) this.modifiedRules[devName].weight = draft.Weight__c;
                if (draft.Max_Deduction__c !== undefined) this.modifiedRules[devName].maxDeduction = draft.Max_Deduction__c;
                if (draft.Is_Active__c !== undefined) this.modifiedRules[devName].isActive = draft.Is_Active__c;
            }
        });

        // Force reactivity
        this.modifiedRules = { ...this.modifiedRules };
    }

    handleSaveRuleChanges() {
        const changes = Object.values(this.modifiedRules);
        if (changes.length === 0) return;

        this.ruleConfigsSaving = true;
        this.ruleConfigsSaved = false;
        this.ruleConfigError = null;

        saveRuleChanges({ rulesJson: JSON.stringify(changes) })
            .then(jobId => {
                this.ruleDeployJobId = jobId;
                // Poll for deployment status
                this.pollDeployStatus();
            })
            .catch(error => {
                this.ruleConfigError = this.extractError(error);
                this.ruleConfigsSaving = false;
            });
    }

    pollDeployStatus() {
        if (!this.ruleDeployJobId) {
            this.ruleConfigsSaving = false;
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            getDeployStatus({ jobId: this.ruleDeployJobId })
                .then(status => {
                    if (status === 'Succeeded') {
                        this.ruleConfigsSaving = false;
                        this.ruleConfigsSaved = true;
                        this.modifiedRules = {};
                        // Clear draft values from datatable
                        const table = this.template.querySelector('lightning-datatable.rule-config-table');
                        if (table) {
                            table.draftValues = [];
                        }
                        // Reload configs to show updated values
                        this.loadRuleConfigs();
                        // Auto-hide success message after 3 seconds
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => { this.ruleConfigsSaved = false; }, 3000);
                    } else if (status === 'Failed') {
                        this.ruleConfigError = 'Metadata deployment failed. Please check your permissions.';
                        this.ruleConfigsSaving = false;
                    } else {
                        // Still in progress — keep polling
                        this.pollDeployStatus();
                    }
                })
                .catch(() => {
                    // If status check fails, assume success after delay
                    this.ruleConfigsSaving = false;
                    this.ruleConfigsSaved = true;
                    this.modifiedRules = {};
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => { this.ruleConfigsSaved = false; }, 3000);
                });
        }, 2000);
    }

    handleResetRuleDefaults() {
        this.modifiedRules = {};
        const table = this.template.querySelector('lightning-datatable.rule-config-table');
        if (table) {
            table.draftValues = [];
        }
        this.ruleConfigsSaved = false;
        this.ruleConfigError = null;
    }

    // =========================================================================
    // BULK DASHBOARD COMPUTED PROPERTIES
    // =========================================================================

    get isSingleView() { return this.viewMode === 'single'; }
    get isBulkView() { return this.viewMode === 'bulk'; }
    get isSettingsView() { return this.viewMode === 'settings'; }
    get isPermsetView() { return this.viewMode === 'permset'; }

    get singleToggleClass() {
        return this.viewMode === 'single'
            ? 'slds-button view-toggle-btn view-toggle-btn-active'
            : 'slds-button view-toggle-btn';
    }

    get bulkToggleClass() {
        return this.viewMode === 'bulk'
            ? 'slds-button view-toggle-btn view-toggle-btn-active'
            : 'slds-button view-toggle-btn';
    }

    get settingsToggleClass() {
        return this.viewMode === 'settings'
            ? 'slds-button view-toggle-btn view-toggle-btn-active'
            : 'slds-button view-toggle-btn';
    }

    get permsetToggleClass() {
        return this.viewMode === 'permset'
            ? 'slds-button view-toggle-btn view-toggle-btn-active'
            : 'slds-button view-toggle-btn';
    }

    get showBackButton() { return this.cameFromBulk; }

    get bulkFlowCount() { return this.bulkFlowsList.length; }

    get canStartScan() { return this.bulkFlowsList.length > 0 && !this.bulkIsScanning; }
    get scanButtonDisabled() { return !this.canStartScan; }

    get bulkProgressPercent() {
        if (!this.bulkFlowsList.length) return 0;
        return Math.round((this.bulkScanIndex / this.bulkFlowsList.length) * 100);
    }

    get bulkProgressBarStyle() {
        return 'width: ' + this.bulkProgressPercent + '%;';
    }

    get bulkScanProgress() {
        return this.bulkScanIndex + ' of ' + this.bulkFlowsList.length;
    }

    get hasBulkResults() { return this.bulkResults.length > 0; }
    get noBulkResults() { return this.bulkResults.length === 0 && !this.bulkIsScanning; }
    get hasBulkScanError() { return this.bulkScanError !== null; }

    get successfulResults() {
        return this.bulkResults.filter(r => !r.failed);
    }

    get bulkFlowsAnalyzedCount() {
        return this.successfulResults.length;
    }

    get bulkFailedCount() {
        return this.bulkResults.filter(r => r.failed).length;
    }

    get avgScore() {
        const results = this.successfulResults;
        if (results.length === 0) return 0;
        const total = results.reduce((sum, r) => sum + r.result.score, 0);
        return Math.round(total / results.length);
    }

    get avgGrade() {
        const s = this.avgScore;
        if (s >= 90) return 'A';
        if (s >= 80) return 'B';
        if (s >= 70) return 'C';
        if (s >= 60) return 'D';
        return 'F';
    }

    get avgScoreStyle() {
        const color = GRADE_COLORS[this.avgGrade] || '#706e6b';
        return 'color: ' + color + ';';
    }

    get bulkTotalFindings() {
        return this.successfulResults.reduce((sum, r) => sum + r.result.totalFindings, 0);
    }

    get bulkTotalCritical() {
        return this.successfulResults.reduce((sum, r) => {
            const sev = r.result.findingsBySeverity;
            return sum + (sev && sev.Critical ? sev.Critical : 0);
        }, 0);
    }

    get gradeDistribution() {
        const counts = { 'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0 };
        const gradeLabels = { 'A': 'Excellent', 'B': 'Good', 'C': 'Fair', 'D': 'Needs Work', 'F': 'Critical' };
        const colors = GRADE_COLORS;

        this.successfulResults.forEach(r => {
            const g = r.result.grade;
            if (counts[g] !== undefined) {
                counts[g]++;
            }
        });

        const max = Math.max(1, ...Object.values(counts));

        return ['A', 'B', 'C', 'D', 'F'].map(grade => ({
            grade: grade,
            gradeLabel: grade + ' - ' + gradeLabels[grade],
            count: counts[grade],
            barStyle: 'width: ' + Math.round((counts[grade] / max) * 100) + '%; background-color: ' + colors[grade] + ';',
            barColor: colors[grade]
        }));
    }

    // =========================================================================
    // STRATEGIC INSIGHTS — Org-Wide Risk Aggregation (Lego Block)
    //
    // INPUT:  this.bulkResults (array of { flow, result, failed } objects)
    // OUTPUT: Top 3 most frequent rule violations ranked by Strategic Priority
    //
    // Strategic Priority = frequency × severityWeight × (affectedFlows / totalFlows)
    // This weighs both how often a rule fires AND how many distinct flows it hits.
    // =========================================================================

    /**
     * Aggregates findings across all bulk scan results to identify org-wide risks.
     * Returns ALL rule violations ranked by weighted strategic priority.
     *
     * Priority Formula: (SeverityWeight × 1000) + TotalOccurrences
     *   Severity Weights: Critical=100, High=50, Medium=10, Low=1
     *   This guarantees a single Critical always outranks any number of High items.
     *
     * Each insight contains:
     *   - ruleId, ruleName, category, severity, description, remediation
     *   - totalCount, affectedFlowCount, affectedPercent
     *   - strategicPriority (weighted score), rankLabel, progressBarWidth
     *   - severityBadgeClass, businessImpact, isCriticalTier
     */
    get strategicInsights() {
        const results = this.successfulResults;
        if (results.length === 0) return [];

        const totalFlows = results.length;
        const severityWeights = { 'Critical': 100, 'High': 50, 'Medium': 10, 'Low': 1 };

        // Pass 1: Aggregate frequency, affected flows, and capture first description/remediation
        const ruleMap = {};
        results.forEach(item => {
            if (!item.result || !item.result.findings) return;

            const rulesInThisFlow = new Set();

            item.result.findings.forEach(f => {
                const key = f.ruleId;
                if (!ruleMap[key]) {
                    ruleMap[key] = {
                        ruleId: f.ruleId,
                        ruleName: f.ruleName,
                        category: f.category || 'Other',
                        severity: f.severity || 'Medium',
                        description: f.description || '',
                        remediation: f.remediation || '',
                        totalCount: 0,
                        affectedFlows: new Set()
                    };
                }
                ruleMap[key].totalCount++;
                rulesInThisFlow.add(key);
            });

            rulesInThisFlow.forEach(ruleKey => {
                ruleMap[ruleKey].affectedFlows.add(item.flow.developerName);
            });
        });

        // Pass 2: Calculate weighted strategic priority
        const ruleList = Object.values(ruleMap).map(r => {
            const affectedFlowCount = r.affectedFlows.size;
            const affectedPercent = Math.round((affectedFlowCount / totalFlows) * 100);
            const severityWeight = severityWeights[r.severity] || 1;
            const strategicPriority = (severityWeight * 1000) + r.totalCount;

            return {
                ruleId: r.ruleId,
                ruleName: r.ruleName,
                category: r.category,
                severity: r.severity,
                description: r.description,
                remediation: r.remediation,
                totalCount: r.totalCount,
                affectedFlowCount: affectedFlowCount,
                affectedPercent: affectedPercent,
                strategicPriority: strategicPriority,
                severityBadgeClass: this.getSeverityBadgeClass(r.severity),
                isCriticalTier: r.severity === 'Critical' || r.severity === 'High'
            };
        });

        // Sort by strategic priority descending (severity-dominant ordering)
        ruleList.sort((a, b) => b.strategicPriority - a.strategicPriority);

        // Pass 3: Enrich with display properties
        const maxPriority = ruleList.length > 0 ? ruleList[0].strategicPriority : 1;

        return ruleList.map((insight, idx) => {
            const barPercent = maxPriority > 0
                ? Math.max(8, Math.round((insight.strategicPriority / maxPriority) * 100))
                : 8;

            let impactText;
            if (insight.affectedPercent >= 75) {
                impactText = 'Pervasive — affecting ' + insight.affectedPercent +
                    '% of flows. Resolving this produces the largest single improvement to Org Health.';
            } else if (insight.affectedPercent >= 40) {
                impactText = 'Found in ' + insight.affectedPercent +
                    '% of flows (' + insight.affectedFlowCount +
                    ' flows). Fixing this will significantly increase your overall score.';
            } else {
                impactText = 'Affects ' + insight.affectedFlowCount +
                    ' flow(s) (' + insight.affectedPercent +
                    '%). Concentrated risk — prioritize for targeted remediation.';
            }

            // Normalize priority to a 0–100 display score
            const displayPriority = maxPriority > 0
                ? Math.round((insight.strategicPriority / maxPriority) * 100)
                : 0;

            return {
                ...insight,
                key: 'insight_' + idx,
                rank: idx + 1,
                rankLabel: '#' + (idx + 1),
                displayPriority: displayPriority,
                progressBarWidth: 'width:' + barPercent + '%',
                businessImpact: impactText,
                isExpanded: false
            };
        });
    }

    get hasStrategicInsights() {
        return this.strategicInsights.length > 0;
    }

    /**
     * Critical/High tier items that need immediate attention.
     */
    get criticalTierInsights() {
        return this.strategicInsights.filter(i => i.isCriticalTier);
    }

    get hasCriticalTierInsights() {
        return this.criticalTierInsights.length > 0;
    }

    /**
     * Medium/Low tier items — important but not urgent.
     */
    get otherTierInsights() {
        return this.strategicInsights.filter(i => !i.isCriticalTier);
    }

    get hasOtherTierInsights() {
        return this.otherTierInsights.length > 0;
    }

    /**
     * Toggle expand/collapse on a strategic insight card to show description/remediation.
     */
    handleToggleInsightDetail(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        if (!ruleId) return;
        const el = this.template.querySelector('[data-insight-body="' + ruleId + '"]');
        if (el) {
            const isHidden = el.classList.contains('slds-hide');
            if (isHidden) {
                el.classList.remove('slds-hide');
                event.currentTarget.setAttribute('aria-expanded', 'true');
            } else {
                el.classList.add('slds-hide');
                event.currentTarget.setAttribute('aria-expanded', 'false');
            }
        }
    }

    // --- Datatable ---

    get bulkTableColumns() {
        return [
            { label: 'Flow Name', fieldName: 'label', type: 'text', sortable: true },
            { label: 'Type', fieldName: 'processTypeLabel', type: 'text', sortable: true },
            { label: 'Score', fieldName: 'score', type: 'number', sortable: true,
              cellAttributes: { class: { fieldName: 'scoreClass' } }
            },
            { label: 'Grade', fieldName: 'grade', type: 'text', sortable: true },
            { label: 'Findings', fieldName: 'totalFindings', type: 'number', sortable: true },
            { label: 'Critical', fieldName: 'criticalCount', type: 'number', sortable: true },
            { label: 'High', fieldName: 'highCount', type: 'number', sortable: true },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [
                        { label: 'View Details', name: 'view_details' }
                    ]
                }
            }
        ];
    }

    get bulkTableData() {
        return this.bulkResults.map((item, idx) => {
            if (item.failed) {
                return {
                    id: 'row_' + idx,
                    developerName: item.flow.developerName,
                    label: item.flow.masterLabel || item.flow.developerName,
                    processTypeLabel: PROCESS_TYPE_LABELS[item.flow.processType] || item.flow.processType || '--',
                    score: '--',
                    grade: 'Error',
                    totalFindings: '--',
                    criticalCount: '--',
                    highCount: '--',
                    scoreClass: 'slds-text-color_error'
                };
            }
            const r = item.result;
            const sev = r.findingsBySeverity || {};
            return {
                id: 'row_' + idx,
                developerName: item.flow.developerName,
                label: item.flow.masterLabel || item.flow.developerName,
                processTypeLabel: PROCESS_TYPE_LABELS[item.flow.processType] || item.flow.processType || '--',
                score: r.score,
                grade: r.grade,
                totalFindings: r.totalFindings,
                criticalCount: sev.Critical || 0,
                highCount: sev.High || 0,
                scoreClass: ''
            };
        }).sort((a, b) => {
            const scoreA = typeof a.score === 'number' ? a.score : -1;
            const scoreB = typeof b.score === 'number' ? b.score : -1;
            return scoreA - scoreB;
        });
    }

    @track bulkSortBy = 'score';
    @track bulkSortDirection = 'asc';

    handleBulkSort(event) {
        this.bulkSortBy = event.detail.fieldName;
        this.bulkSortDirection = event.detail.sortDirection;
    }

    get sortedBulkTableData() {
        const data = [...this.bulkTableData];
        const field = this.bulkSortBy;
        const dir = this.bulkSortDirection === 'asc' ? 1 : -1;

        return data.sort((a, b) => {
            const valA = a[field];
            const valB = b[field];
            if (typeof valA !== typeof valB) {
                return typeof valA === 'number' ? -1 * dir : 1 * dir;
            }
            if (valA === valB) return 0;
            if (typeof valA === 'string') {
                return valA.localeCompare(valB) * dir;
            }
            return (valA - valB) * dir;
        });
    }

    // =========================================================================
    // SPRINT 5: CUSTOM RULES METHODS
    // =========================================================================

    loadCustomRules() {
        this.customRulesLoading = true;
        this.customRuleError = null;
        getCustomRules()
            .then(result => {
                this.customRules = result || [];
                this.customRulesLoaded = true;
                this.customRulesLoading = false;
            })
            .catch(error => {
                this.customRuleError = this.extractError(error);
                this.customRulesLoading = false;
                this.customRulesLoaded = true;
            });
    }

    get hasCustomRules() {
        return this.customRulesLoaded && this.customRules.length > 0;
    }

    get hasNoCustomRules() {
        return this.customRulesLoaded && !this.customRulesLoading && this.customRules.length === 0;
    }

    get customRulesDisplay() {
        return this.customRules.map(rule => {
            const ruleTypeLabels = {
                'Element Count Threshold': 'Fires when element count exceeds threshold',
                'Element Name Pattern': 'Fires when element names match a regex pattern',
                'Flow Property Check': 'Fires when a flow property doesn\'t match expected value',
                'Element In Loop Check': 'Fires when target elements are inside loops',
                'Missing Fault Path Check': 'Fires when target elements lack fault connectors'
            };
            return {
                id: rule.Id,
                ruleId: rule.Rule_Id__c,
                name: rule.Name,
                category: rule.Category__c,
                severity: rule.Severity__c,
                isActive: rule.Is_Active__c,
                description: rule.Description__c,
                ruleType: rule.Rule_Type__c,
                ruleTypeLabel: (ruleTypeLabels[rule.Rule_Type__c] || rule.Rule_Type__c) +
                    (rule.Target_Element_Type__c ? ' (' + rule.Target_Element_Type__c + ')' : '') +
                    (rule.Threshold_Value__c ? ' > ' + rule.Threshold_Value__c : ''),
                severityBadgeClass: 'slds-badge slds-m-left_x-small severity-badge-' +
                    (rule.Severity__c || 'medium').toLowerCase(),
                badgeStyle: 'background: #0176d3; color: white; font-weight: 700;'
            };
        });
    }

    get customRuleModalTitle() {
        return this.editingRule.id ? 'Edit Custom Rule' : 'New Custom Rule';
    }

    // Computed: which conditional fields to show based on Rule Type
    get isCountThresholdType() { return this.editingRule.ruleType === 'Element Count Threshold'; }
    get isNamePatternType() { return this.editingRule.ruleType === 'Element Name Pattern'; }
    get isFlowPropertyType() { return this.editingRule.ruleType === 'Flow Property Check'; }
    get isElementInLoopType() { return this.editingRule.ruleType === 'Element In Loop Check'; }
    get isMissingFaultPathType() { return this.editingRule.ruleType === 'Missing Fault Path Check'; }

    // Picklist options for the custom rule modal
    get ruleTypeOptions() {
        return [
            { label: 'Element Count Threshold — flag if too many of an element type', value: 'Element Count Threshold' },
            { label: 'Element Name Pattern — flag elements matching a name regex', value: 'Element Name Pattern' },
            { label: 'Flow Property Check — flag if flow property != expected value', value: 'Flow Property Check' },
            { label: 'Element In Loop Check — flag if element type is inside a loop', value: 'Element In Loop Check' },
            { label: 'Missing Fault Path Check — flag elements without fault paths', value: 'Missing Fault Path Check' }
        ];
    }

    get elementTypeOptions() {
        return [
            { label: 'All Elements', value: 'All Elements' },
            { label: 'Record Creates', value: 'Record Creates' },
            { label: 'Record Updates', value: 'Record Updates' },
            { label: 'Record Deletes', value: 'Record Deletes' },
            { label: 'Record Lookups', value: 'Record Lookups' },
            { label: 'Loops', value: 'Loops' },
            { label: 'Decisions', value: 'Decisions' },
            { label: 'Assignments', value: 'Assignments' },
            { label: 'Screens', value: 'Screens' },
            { label: 'Action Calls', value: 'Action Calls' },
            { label: 'Subflows', value: 'Subflows' }
        ];
    }

    get flowPropertyOptions() {
        return [
            { label: 'Has Description', value: 'Has Description' },
            { label: 'Process Type', value: 'Process Type' },
            { label: 'Run Mode (Sharing)', value: 'Run Mode' },
            { label: 'Trigger Type', value: 'Trigger Type' },
            { label: 'API Version', value: 'API Version' }
        ];
    }

    get categoryOptions() {
        return [
            { label: 'Performance', value: 'Performance' },
            { label: 'Error Handling', value: 'Error Handling' },
            { label: 'Design', value: 'Design' },
            { label: 'Security', value: 'Security' }
        ];
    }

    get severityOptions() {
        return [
            { label: 'Critical', value: 'Critical' },
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    handleNewCustomRule() {
        // Generate next CUST-NNN ID
        const maxId = this.customRules.reduce((max, r) => {
            const match = (r.Rule_Id__c || '').match(/CUST-(\d+)/);
            return match ? Math.max(max, parseInt(match[1], 10)) : max;
        }, 0);
        const nextId = 'CUST-' + String(maxId + 1).padStart(3, '0');

        this.editingRule = {
            id: null,
            name: '',
            ruleId: nextId,
            ruleType: 'Element Count Threshold',
            category: 'Design',
            severity: 'Medium',
            weight: 5,
            targetElementType: 'All Elements',
            thresholdValue: null,
            namePattern: '',
            flowProperty: null,
            expectedValue: '',
            description: '',
            remediation: '',
            isActive: true
        };
        this.testRuleResult = null;
        this.testRuleFlowName = '';
        this.showCustomRuleModal = true;
        this.loadTestFlowsList();
    }

    handleEditCustomRule(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const rule = this.customRules.find(r => r.Id === ruleId);
        if (!rule) return;

        this.editingRule = {
            id: rule.Id,
            name: rule.Name,
            ruleId: rule.Rule_Id__c,
            ruleType: rule.Rule_Type__c,
            category: rule.Category__c,
            severity: rule.Severity__c,
            weight: rule.Weight__c,
            targetElementType: rule.Target_Element_Type__c || 'All Elements',
            thresholdValue: rule.Threshold_Value__c,
            namePattern: rule.Name_Pattern__c || '',
            flowProperty: rule.Flow_Property__c,
            expectedValue: rule.Expected_Value__c || '',
            description: rule.Description__c || '',
            remediation: rule.Remediation__c || '',
            isActive: rule.Is_Active__c
        };
        this.testRuleResult = null;
        this.testRuleFlowName = '';
        this.showCustomRuleModal = true;
        this.loadTestFlowsList();
    }

    handleCloseCustomRuleModal() {
        this.showCustomRuleModal = false;
        this.editingRule = {};
    }

    handleCustomRuleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;
        this.editingRule = { ...this.editingRule, [field]: value };
    }

    handleSaveCustomRule() {
        const rule = this.editingRule;
        if (!rule.name || !rule.ruleId) {
            this.customRuleError = 'Rule Name and Rule ID are required.';
            return;
        }

        const payload = JSON.stringify({
            id: rule.id,
            name: rule.name,
            ruleId: rule.ruleId,
            category: rule.category,
            severity: rule.severity,
            weight: rule.weight,
            description: rule.description,
            remediation: rule.remediation,
            ruleType: rule.ruleType,
            targetElementType: rule.targetElementType,
            thresholdValue: rule.thresholdValue,
            namePattern: rule.namePattern,
            flowProperty: rule.flowProperty,
            expectedValue: rule.expectedValue,
            isActive: rule.isActive
        });

        this.showCustomRuleModal = false;
        this.customRulesLoading = true;

        saveCustomRule({ ruleJson: payload })
            .then(() => {
                this.loadCustomRules();
            })
            .catch(error => {
                this.customRuleError = this.extractError(error);
                this.customRulesLoading = false;
            });
    }

    handleDeleteCustomRule(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const rule = this.customRules.find(r => r.Id === ruleId);
        const ruleName = rule ? rule.Name : 'this rule';

        // eslint-disable-next-line no-alert
        if (!confirm('Delete custom rule "' + ruleName + '"? This cannot be undone.')) return;

        this.customRulesLoading = true;
        deleteCustomRule({ ruleId: ruleId })
            .then(() => {
                this.loadCustomRules();
            })
            .catch(error => {
                this.customRuleError = this.extractError(error);
                this.customRulesLoading = false;
            });
    }

    handleToggleCustomRule(event) {
        const ruleId = event.currentTarget.dataset.ruleId;
        const isActive = event.detail.checked;

        toggleCustomRule({ ruleId: ruleId, isActive: isActive })
            .then(() => {
                // Update local state without full reload
                this.customRules = this.customRules.map(r =>
                    r.Id === ruleId ? { ...r, Is_Active__c: isActive } : r
                );
            })
            .catch(error => {
                this.customRuleError = this.extractError(error);
                this.loadCustomRules(); // Reload to reset toggle state
            });
    }

    // =========================================================================
    // SPRINT 5: TEST RULE (Real-time validation in modal)
    // =========================================================================

    /**
     * Loads the flow list for the test rule flow selector.
     * Reuses getFlowList but stores in a separate array.
     */
    loadTestFlowsList() {
        if (this.testFlowsLoaded) return;
        getFlowList()
            .then(result => {
                this.testFlowsList = result || [];
                this.testFlowsLoaded = true;
            })
            .catch(() => {
                this.testFlowsLoaded = true;
            });
    }

    get testFlowOptions() {
        return this.testFlowsList.map(f => ({
            label: (f.masterLabel || f.developerName) + ' (' + f.developerName + ')',
            value: f.developerName
        }));
    }

    get hasTestFlowOptions() {
        return this.testFlowsList.length > 0;
    }

    handleTestFlowChange(event) {
        this.testRuleFlowName = event.detail.value;
        // Clear previous test results when flow changes
        this.testRuleResult = null;
    }

    get canTestRule() {
        return this.testRuleFlowName && this.editingRule.ruleType && !this.testRuleLoading;
    }

    get testRuleButtonDisabled() {
        return !this.canTestRule;
    }

    handleTestRule() {
        if (!this.canTestRule) return;

        const rule = this.editingRule;
        const payload = JSON.stringify({
            name: rule.name || 'Test Rule',
            ruleId: rule.ruleId || 'TEST',
            category: rule.category,
            severity: rule.severity,
            weight: rule.weight,
            ruleType: rule.ruleType,
            targetElementType: rule.targetElementType,
            thresholdValue: rule.thresholdValue,
            namePattern: rule.namePattern,
            flowProperty: rule.flowProperty,
            expectedValue: rule.expectedValue,
            description: rule.description,
            remediation: rule.remediation
        });

        this.testRuleLoading = true;
        this.testRuleResult = null;

        testCustomRule({
            ruleJson: payload,
            flowDeveloperName: this.testRuleFlowName
        })
            .then(result => {
                this.testRuleResult = {
                    passed: result.passed,
                    totalFindings: result.totalFindings,
                    findings: (result.findings || []).map((f, idx) => ({
                        ...f,
                        key: 'test_' + idx,
                        hasElement: f.elementName != null,
                        severityBadgeClass: this.getSeverityBadgeClass(f.severity)
                    }))
                };
                this.testRuleLoading = false;
            })
            .catch(error => {
                this.testRuleResult = {
                    passed: false,
                    totalFindings: 0,
                    error: this.extractError(error),
                    findings: []
                };
                this.testRuleLoading = false;
            });
    }

    get hasTestResult() {
        return this.testRuleResult !== null;
    }

    get testResultPassed() {
        return this.testRuleResult && this.testRuleResult.passed;
    }

    get testResultFailed() {
        return this.testRuleResult && !this.testRuleResult.passed && !this.testRuleResult.error;
    }

    get testResultError() {
        return this.testRuleResult && this.testRuleResult.error;
    }

    get testResultMessage() {
        if (!this.testRuleResult) return '';
        if (this.testRuleResult.error) return 'Error: ' + this.testRuleResult.error;
        if (this.testRuleResult.passed) return 'Rule passed — no findings detected on this flow.';
        return this.testRuleResult.totalFindings + ' finding(s) detected:';
    }

    get testResultIconName() {
        if (!this.testRuleResult) return 'utility:info';
        if (this.testRuleResult.error) return 'utility:error';
        if (this.testRuleResult.passed) return 'utility:check';
        return 'utility:warning';
    }

    get testResultVariant() {
        if (!this.testRuleResult) return '';
        if (this.testRuleResult.error) return 'error';
        if (this.testRuleResult.passed) return 'success';
        return 'warning';
    }

    get testResultBannerClass() {
        if (!this.testRuleResult) return '';
        if (this.testRuleResult.error) return 'slds-notify slds-notify_alert slds-alert_error slds-m-top_small';
        if (this.testRuleResult.passed) return 'slds-box slds-theme_success slds-m-top_small';
        return 'slds-box slds-theme_warning slds-m-top_small';
    }

    get hasTestFindings() {
        return this.testRuleResult && this.testRuleResult.findings && this.testRuleResult.findings.length > 0;
    }

    // =========================================================================
    // SPRINT 6: VERSION COMPARISON HANDLERS
    // =========================================================================

    /**
     * Opens the Compare Versions modal.
     * Can be triggered from single-flow view (uses selectedFlowName)
     * or from bulk drill-down.
     */
    handleOpenCompare() {
        const flowName = this.selectedFlowName;
        if (!flowName) return;

        this.compareFlowName = flowName;
        this.compareVersions = [];
        this.compareOldVersionId = '';
        this.compareNewVersionId = '';
        this.compareDiffResult = null;
        this.compareError = null;
        this.showCompareModal = true;
        this.compareLoadingVersions = true;

        getFlowVersions({ flowDeveloperName: flowName })
            .then(result => {
                this.compareVersions = (result || []).map(v => ({
                    ...v,
                    optionLabel: v.displayLabel
                }));
                this.compareLoadingVersions = false;

                // Auto-select: newest as "new", second-newest as "old"
                if (this.compareVersions.length >= 2) {
                    this.compareNewVersionId = this.compareVersions[0].id;
                    this.compareOldVersionId = this.compareVersions[1].id;
                }
            })
            .catch(error => {
                this.compareError = this.extractError(error);
                this.compareLoadingVersions = false;
            });
    }

    handleCloseCompare() {
        this.showCompareModal = false;
        this.compareDiffResult = null;
        this.compareError = null;
        this.hideCosmeticChanges = false;
    }

    handleOldVersionChange(event) {
        this.compareOldVersionId = event.detail.value;
        this.compareDiffResult = null;
    }

    handleNewVersionChange(event) {
        this.compareNewVersionId = event.detail.value;
        this.compareDiffResult = null;
    }

    get compareVersionOptions() {
        return this.compareVersions.map(v => ({
            label: v.optionLabel,
            value: v.id
        }));
    }

    get canCompare() {
        return this.compareOldVersionId && this.compareNewVersionId
            && this.compareOldVersionId !== this.compareNewVersionId
            && !this.compareLoading;
    }

    get compareButtonDisabled() {
        return !this.canCompare;
    }

    handleRunCompare() {
        if (!this.canCompare) return;

        this.compareLoading = true;
        this.compareDiffResult = null;
        this.compareError = null;

        compareFlowVersions({
            oldVersionId: this.compareOldVersionId,
            newVersionId: this.compareNewVersionId
        })
            .then(result => {
                this.compareDiffResult = this.enrichDiffResult(result);
                this.compareLoading = false;
            })
            .catch(error => {
                this.compareError = this.extractError(error);
                this.compareLoading = false;
            });
    }

    /**
     * Enriches the raw diff result with display properties for the LWC template.
     */
    enrichDiffResult(raw) {
        if (!raw) return null;

        const changeTypeIcons = {
            'Added': 'utility:add',
            'Removed': 'utility:delete',
            'Modified': 'utility:edit'
        };

        const changeTypeBadge = {
            'Added': 'slds-badge slds-badge_success',
            'Removed': 'slds-badge slds-badge_error',
            'Modified': 'slds-badge slds-badge_warning'
        };

        const riskBadge = {
            'Critical': 'slds-badge severity-badge-critical',
            'High': 'slds-badge severity-badge-high',
            'Medium': 'slds-badge severity-badge-medium',
            'Low': 'slds-badge severity-badge-low',
            'Info': 'slds-badge'
        };

        const changes = (raw.changes || []).map((c, idx) => ({
            ...c,
            key: 'change_' + idx,
            icon: changeTypeIcons[c.changeType] || 'utility:info',
            changeTypeBadgeClass: changeTypeBadge[c.changeType] || 'slds-badge',
            riskBadgeClass: riskBadge[c.riskLevel] || 'slds-badge',
            hasValues: c.oldValue != null && c.newValue != null,
            isCosmetic: c.isCosmetic === true,
            isFunctional: c.isCosmetic !== true,
            semanticBadgeClass: c.isCosmetic === true
                ? 'slds-badge semantic-badge-cosmetic'
                : 'slds-badge semantic-badge-functional',
            semanticLabel: c.isCosmetic === true ? 'Cosmetic' : 'Functional',
            changeRowClass: c.isCosmetic === true
                ? 'compare-change-row cosmetic-change-row slds-p-vertical_x-small slds-border_bottom'
                : 'compare-change-row slds-p-vertical_x-small slds-border_bottom'
        }));

        // Semantic counts
        const functionalChanges = changes.filter(c => !c.isCosmetic).length;
        const cosmeticChanges = changes.filter(c => c.isCosmetic).length;

        // Group changes by category
        const grouped = {};
        changes.forEach(c => {
            const cat = c.category || 'Other';
            if (!grouped[cat]) {
                grouped[cat] = { category: cat, changes: [], key: 'cat_' + cat };
            }
            grouped[cat].changes.push(c);
        });

        return {
            ...raw,
            enrichedChanges: changes,
            groupedChanges: Object.values(grouped),
            totalChanges: changes.length,
            functionalChanges: functionalChanges,
            cosmeticChanges: cosmeticChanges,
            hasCosmeticChanges: cosmeticChanges > 0,
            hasChanges: changes.length > 0,
            noChanges: changes.length === 0,
            scoreDeltaDisplay: raw.scoreDelta > 0
                ? '+' + raw.scoreDelta
                : String(raw.scoreDelta),
            scoreDeltaClass: raw.scoreDelta > 0
                ? 'slds-text-color_success'
                : (raw.scoreDelta < 0 ? 'slds-text-color_error' : ''),
            oldScoreColor: GRADE_COLORS[raw.oldGrade] || '#706e6b',
            newScoreColor: GRADE_COLORS[raw.newGrade] || '#706e6b',
            regressionWarning: raw.isRegression
                ? 'Health score dropped by ' + Math.abs(raw.scoreDelta) + ' points — this version introduces regressions.'
                : null,
            improvementNote: raw.isImprovement
                ? 'Health score improved by ' + raw.scoreDelta + ' points!'
                : null
        };
    }

    get hasCompareDiffResult() {
        return this.compareDiffResult !== null;
    }

    get hasCompareError() {
        return this.compareError !== null;
    }

    get compareVersionsLoaded() {
        return !this.compareLoadingVersions;
    }

    get compareHasRegression() {
        return this.compareDiffResult && this.compareDiffResult.isRegression;
    }

    get compareHasImprovement() {
        return this.compareDiffResult && this.compareDiffResult.isImprovement;
    }

    // =========================================================================
    // LOGIC HASHING: Semantic Meaning Layer
    // =========================================================================

    handleToggleHideCosmetic() {
        this.hideCosmeticChanges = !this.hideCosmeticChanges;
    }

    /**
     * Returns grouped changes filtered based on the Hide Cosmetic toggle.
     * When toggle is active, cosmetic changes are excluded entirely.
     */
    get displayedGroupedChanges() {
        if (!this.compareDiffResult || !this.compareDiffResult.groupedChanges) return [];
        if (!this.hideCosmeticChanges) {
            return this.compareDiffResult.groupedChanges;
        }
        // Filter out cosmetic changes from each group
        return this.compareDiffResult.groupedChanges
            .map(group => ({
                ...group,
                changes: group.changes.filter(c => !c.isCosmetic)
            }))
            .filter(group => group.changes.length > 0);
    }

    get displayedTotalChanges() {
        if (!this.compareDiffResult) return 0;
        if (this.hideCosmeticChanges) {
            return this.compareDiffResult.functionalChanges || 0;
        }
        return this.compareDiffResult.totalChanges || 0;
    }

    get hasDisplayedChanges() {
        return this.displayedTotalChanges > 0;
    }

    get noDisplayedChanges() {
        return this.displayedTotalChanges === 0 && this.compareDiffResult !== null;
    }

    get semanticSummaryText() {
        if (!this.compareDiffResult) return '';
        const f = this.compareDiffResult.functionalChanges || 0;
        const c = this.compareDiffResult.cosmeticChanges || 0;
        return f + ' functional, ' + c + ' cosmetic';
    }

    get hasCosmeticChangesInResult() {
        return this.compareDiffResult && this.compareDiffResult.cosmeticChanges > 0;
    }

    // =========================================================================
    // SPRINT 7: PERMSET PATCHMASTER HANDLERS
    // =========================================================================

    handlePatchDestChange(event) {
        this.patchDestXml = event.target.value;
        this.patchResult = null;
        this.patchError = null;
    }

    handlePatchSrcChange(event) {
        this.patchSrcXml = event.target.value;
        this.patchResult = null;
        this.patchError = null;
    }

    handlePatchFileUpload(event) {
        const file = event.target.files[0];
        if (!file) return;

        const inputType = event.target.dataset.input; // 'dest' or 'src'
        const reader = new FileReader();
        reader.onload = (e) => {
            if (inputType === 'dest') {
                this.patchDestXml = e.target.result;
            } else {
                this.patchSrcXml = e.target.result;
            }
            this.patchResult = null;
            this.patchError = null;
        };
        reader.readAsText(file);
    }

    handleGeneratePatch() {
        if (!this.patchDestXml || !this.patchSrcXml) return;

        this.patchLoading = true;
        this.patchError = null;
        this.patchResult = null;
        this.patchSuccessVisible = false;
        this.showPatchedXmlPreview = false;

        generatePermSetPatch({
            destinationXml: this.patchDestXml,
            sourceXml: this.patchSrcXml
        })
            .then(result => {
                this.patchResult = this.enrichPatchResult(result);
                this.patchLoading = false;
                // Show success toast, auto-dismiss after 4s
                this.patchSuccessVisible = true;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.patchSuccessVisible = false; }, 4000);
            })
            .catch(error => {
                this.patchError = this.extractError(error);
                this.patchLoading = false;
            });
    }

    /**
     * Reset & New Scan — clears ALL Patchmaster state for a clean slate.
     * No page refresh required.
     */
    handlePatchReset() {
        this.patchDestXml = '';
        this.patchSrcXml = '';
        this.patchResult = null;
        this.patchError = null;
        this.patchLoading = false;
        this.patchSuccessVisible = false;
        this.showPatchedXmlPreview = false;

        // Force-clear textarea DOM values (LWC one-way binding won't
        // reliably sync empty-string back to a manually-edited textarea)
        this.template.querySelectorAll('.permset-xml-textarea').forEach(el => {
            el.value = '';
        });

        // Reset file-upload inputs so the same file can be re-selected
        this.template.querySelectorAll('input[type="file"]').forEach(el => {
            el.value = '';
        });
    }

    handleTogglePatchedXmlPreview() {
        this.showPatchedXmlPreview = !this.showPatchedXmlPreview;
    }

    get patchedXmlPreviewLabel() {
        return this.showPatchedXmlPreview ? 'Hide patched XML' : 'Preview patched XML';
    }

    get patchedXmlPreviewIcon() {
        return this.showPatchedXmlPreview ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get patchedXmlValue() {
        return this.patchResult ? this.patchResult.patchedXml || '' : '';
    }

    handleDownloadPatchedXml() {
        if (!this.patchResult || !this.patchResult.patchedXml) return;

        const filename = 'PermissionSet_Patched_' + new Date().toISOString().slice(0, 10) + '.permissionset-meta.xml';
        this.downloadFile(this.patchResult.patchedXml, filename, 'application/xml');
    }

    handleCopyPatchedXml() {
        if (!this.patchResult || !this.patchResult.patchedXml) return;

        const textarea = document.createElement('textarea');
        textarea.value = this.patchResult.patchedXml;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);

        this._copyConfirmed = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._copyConfirmed = false; }, 2000);
    }

    /**
     * Enriches the PatchResult with display properties.
     */
    enrichPatchResult(result) {
        if (!result) return null;

        const actions = (result.actionsApplied || []).map((a, idx) => ({
            ...a,
            key: 'patch_' + idx,
            actionBadgeClass: this.getPatchActionBadgeClass(a.actionType),
            actionIcon: this.getPatchActionIcon(a.actionType)
        }));

        const parts = [];
        if (result.addedCount > 0) parts.push(result.addedCount + ' added');
        if (result.modifiedCount > 0) parts.push(result.modifiedCount + ' modified');
        if (result.preservedCount > 0) parts.push(result.preservedCount + ' preserved');

        return {
            ...result,
            enrichedActions: actions,
            hasActions: actions.length > 0,
            noActions: actions.length === 0,
            summaryLabel: parts.join(' · ') || 'No changes needed'
        };
    }

    getPatchActionBadgeClass(actionType) {
        const map = {
            'ADDED': 'slds-badge slds-badge_success',
            'MODIFIED': 'slds-badge slds-badge_warning',
            'PRESERVED': 'slds-badge slds-badge_inverse'
        };
        return map[actionType] || 'slds-badge';
    }

    getPatchActionIcon(actionType) {
        const map = {
            'ADDED': 'utility:add',
            'MODIFIED': 'utility:edit',
            'PRESERVED': 'utility:lock'
        };
        return map[actionType] || 'utility:info';
    }

    // Computed: Patchmaster view properties
    get hasPatchDestXml() { return this.patchDestXml && this.patchDestXml.trim().length > 0; }
    get hasPatchSrcXml() { return this.patchSrcXml && this.patchSrcXml.trim().length > 0; }
    get patchGenerateDisabled() { return !this.hasPatchDestXml || !this.hasPatchSrcXml || this.patchLoading; }
    get hasPatchError() { return this.patchError !== null; }
    get hasPatchResult() { return this.patchResult !== null; }

    // =========================================================================
    // SHARED HELPERS
    // =========================================================================

    extractError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    getSeverityBadgeClass(severity) {
        const map = {
            'Critical': 'slds-badge severity-badge-critical',
            'High': 'slds-badge severity-badge-high',
            'Medium': 'slds-badge severity-badge-medium',
            'Low': 'slds-badge severity-badge-low'
        };
        return map[severity] || 'slds-badge';
    }

    getScoreColorClass(score) {
        if (score == null) return '';
        if (score >= 90) return 'score-excellent';
        if (score >= 80) return 'score-good';
        if (score >= 70) return 'score-fair';
        if (score >= 60) return 'score-needs-work';
        return 'score-critical';
    }

    // =========================================================================
    // SINGLE FLOW COMPUTED PROPERTIES (Sprint 1-2)
    // =========================================================================

    get hasDetail() { return this.flowDetail !== null; }
    get hasAnalysis() { return this.analysisResult !== null; }
    get hasFindings() { return this.analysisResult && this.analysisResult.totalFindings > 0; }
    get noFindings() { return this.analysisResult && this.analysisResult.totalFindings === 0; }
    get hasError() { return this.error !== null; }

    get healthScore() { return this.analysisResult ? this.analysisResult.score : null; }
    get healthGrade() { return this.analysisResult ? this.analysisResult.grade : null; }
    get healthGradeLabel() { return this.analysisResult ? this.analysisResult.gradeLabel : null; }
    get healthGradeColor() { return this.analysisResult ? this.analysisResult.gradeColor : null; }
    get totalFindings() { return this.analysisResult ? this.analysisResult.totalFindings : 0; }

    get scoreRingStyle() {
        const score = this.healthScore || 0;
        const circumference = 283;
        const offset = circumference - (score / 100) * circumference;
        return 'stroke-dasharray: ' + circumference + '; stroke-dashoffset: ' + offset + ';';
    }

    get scoreRingColor() { return this.healthGradeColor || '#706e6b'; }
    get gradeStyle() { return 'color: ' + (this.healthGradeColor || '#706e6b') + ';'; }

    get criticalCount() { return (this.analysisResult && this.analysisResult.findingsBySeverity) ? (this.analysisResult.findingsBySeverity.Critical || 0) : 0; }
    get highCount() { return (this.analysisResult && this.analysisResult.findingsBySeverity) ? (this.analysisResult.findingsBySeverity.High || 0) : 0; }
    get mediumCount() { return (this.analysisResult && this.analysisResult.findingsBySeverity) ? (this.analysisResult.findingsBySeverity.Medium || 0) : 0; }
    get lowCount() { return (this.analysisResult && this.analysisResult.findingsBySeverity) ? (this.analysisResult.findingsBySeverity.Low || 0) : 0; }

    get processTypeLabel() {
        return (this.flowDetail && PROCESS_TYPE_LABELS[this.flowDetail.processType]) || (this.flowDetail ? this.flowDetail.processType : 'Unknown');
    }

    get triggerTypeLabel() {
        if (!this.flowDetail) return 'N/A';

        // If the Tooling API returned a trigger type, use it
        const triggerLabels = {
            'RecordBeforeSave': 'Before Save',
            'RecordAfterSave': 'After Save',
            'RecordBeforeDelete': 'Before Delete',
            'Scheduled': 'Scheduled',
            'PlatformEvent': 'Platform Event'
        };
        if (this.flowDetail.triggerType && triggerLabels[this.flowDetail.triggerType]) {
            return triggerLabels[this.flowDetail.triggerType];
        }

        // Smart fallback based on processType when triggerType is null
        const fallbackByProcessType = {
            'Flow': 'User-Launched (Screen)',
            'AutoLaunchedFlow': 'Invocable / Subflow',
            'RecordTriggeredFlow': 'Record Change',
            'Workflow': 'Record Change',
            'CustomEvent': 'Platform Event',
            'InvocableProcess': 'Invocable Process'
        };
        return fallbackByProcessType[this.flowDetail.processType] || this.flowDetail.triggerType || 'N/A';
    }

    get runModeLabel() {
        if (!this.flowDetail) return 'Default';

        // If the Tooling API returned a run mode, use it
        const runModeLabels = {
            'SystemModeWithSharing': 'System Mode (With Sharing)',
            'SystemModeWithoutSharing': 'System Mode (Without Sharing)',
            'DefaultMode': 'Default Mode (User Context)'
        };
        if (this.flowDetail.runInMode && runModeLabels[this.flowDetail.runInMode]) {
            return runModeLabels[this.flowDetail.runInMode];
        }

        // Smart fallback based on processType when runInMode is null
        const fallbackByProcessType = {
            'Flow': 'User Context',
            'AutoLaunchedFlow': 'System Context',
            'RecordTriggeredFlow': 'System Context',
            'Workflow': 'System Context',
            'CustomEvent': 'System Context',
            'InvocableProcess': 'System Context'
        };
        return fallbackByProcessType[this.flowDetail.processType] || this.flowDetail.runInMode || 'Default';
    }

    get hasDescription() {
        return this.flowDetail && this.flowDetail.description != null && this.flowDetail.description !== '';
    }

    get descriptionStatus() {
        return this.hasDescription ? 'slds-text-body_regular' : 'slds-text-color_error';
    }

    get descriptionText() {
        return this.hasDescription ? this.flowDetail.description : 'No description provided';
    }
}
