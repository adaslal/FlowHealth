/**
 * FH_MetadataValidatorTest — Tests for the Metadata Dependency Validator.
 *
 * Covers:
 *   - Happy path: all dependencies match → isSafeToDeploy = true
 *   - Missing objects, fields, classes, pages, tabs, record types
 *   - Mixed scenario with multiple missing types
 *   - Fields with implicit parent object detection
 *   - Blank/null XML error handling
 *   - Destination has MORE than Source (no false positives)
 *
 * @since Sprint 8
 */
@IsTest
private class FH_MetadataValidatorTest {

    // =========================================================================
    // HELPER: Build minimal PermissionSet XML
    // =========================================================================

    /**
     * Builds a minimal but valid PermissionSet XML with the given inner blocks.
     */
    private static String buildPermSetXml(String innerBlocks) {
        return '<?xml version="1.0" encoding="UTF-8"?>'
             + '<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">'
             + '<label>Test PermSet</label>'
             + innerBlocks
             + '</PermissionSet>';
    }

    // =========================================================================
    // TEST: Perfect match — safe to deploy
    // =========================================================================

    @IsTest
    static void testPerfectMatch_SafeToDeploy() {
        String innerBlocks = '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
            + '<fieldPermissions><field>Account.Industry</field><readable>true</readable><editable>false</editable></fieldPermissions>'
            + '<classAccesses><apexClass>MyController</apexClass><enabled>true</enabled></classAccesses>';

        String sourceXml = buildPermSetXml(innerBlocks);
        String destXml   = buildPermSetXml(innerBlocks);

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isTrue(report.isSafeToDeploy, 'Should be safe when all deps match');
        Assert.areEqual(0, report.totalMissingCount, 'No missing deps expected');
        Assert.isTrue(report.summaryMessage.contains('Successfully validated'), 'Should contain success message');
        Assert.isTrue(report.missingObjects.isEmpty(), 'No missing objects');
        Assert.isTrue(report.missingFields.isEmpty(), 'No missing fields');
        Assert.isTrue(report.missingClasses.isEmpty(), 'No missing classes');
    }

    // =========================================================================
    // TEST: Missing custom object
    // =========================================================================

    @IsTest
    static void testMissingObject() {
        String sourceXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
          + '<objectPermissions><object>Product_Display_Group__c</object><allowRead>true</allowRead></objectPermissions>'
        );
        String destXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy, 'Should NOT be safe');
        Assert.areEqual(1, report.missingObjects.size(), 'One missing object');
        Assert.areEqual('Product_Display_Group__c', report.missingObjects[0].name);
        Assert.areEqual('CustomObject', report.missingObjects[0].dependencyType);
        Assert.areEqual('objectPermissions', report.missingObjects[0].xmlContext);
    }

    // =========================================================================
    // TEST: Missing custom field with parent object detection
    // =========================================================================

    @IsTest
    static void testMissingField_WithParentObject() {
        String sourceXml = buildPermSetXml(
            '<objectPermissions><object>pse__Timecard_Header__c</object><allowRead>true</allowRead></objectPermissions>'
          + '<fieldPermissions><field>pse__Timecard_Header__c.End_Time__c</field><readable>true</readable><editable>false</editable></fieldPermissions>'
          + '<fieldPermissions><field>pse__Timecard_Header__c.Start_Time__c</field><readable>true</readable><editable>false</editable></fieldPermissions>'
          + '<fieldPermissions><field>pse__Timecard_Header__c.pse__Status__c</field><readable>true</readable><editable>false</editable></fieldPermissions>'
        );
        String destXml = buildPermSetXml(
            '<objectPermissions><object>pse__Timecard_Header__c</object><allowRead>true</allowRead></objectPermissions>'
          + '<fieldPermissions><field>pse__Timecard_Header__c.pse__Status__c</field><readable>true</readable><editable>false</editable></fieldPermissions>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy, 'Should NOT be safe');
        Assert.areEqual(2, report.missingFields.size(), 'Two missing fields');
        // Fields should report the parent object
        for (FH_MetadataValidator.MissingDependency dep : report.missingFields) {
            Assert.areEqual('pse__Timecard_Header__c', dep.parentObject, 'Parent object should be extracted');
            Assert.areEqual('CustomField', dep.dependencyType);
            Assert.areEqual('fieldPermissions', dep.xmlContext);
        }
        // Objects should match (both present)
        Assert.isTrue(report.missingObjects.isEmpty(), 'Object exists in both');
    }

    // =========================================================================
    // TEST: Missing Apex class
    // =========================================================================

    @IsTest
    static void testMissingClass() {
        String sourceXml = buildPermSetXml(
            '<classAccesses><apexClass>FlowHealthController</apexClass><enabled>true</enabled></classAccesses>'
          + '<classAccesses><apexClass>DevOnlyController</apexClass><enabled>true</enabled></classAccesses>'
        );
        String destXml = buildPermSetXml(
            '<classAccesses><apexClass>FlowHealthController</apexClass><enabled>true</enabled></classAccesses>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        Assert.areEqual(1, report.missingClasses.size());
        Assert.areEqual('DevOnlyController', report.missingClasses[0].name);
        Assert.areEqual('ApexClass', report.missingClasses[0].dependencyType);
    }

    // =========================================================================
    // TEST: Missing page
    // =========================================================================

    @IsTest
    static void testMissingPage() {
        String sourceXml = buildPermSetXml(
            '<pageAccesses><apexPage>DevDebugPage</apexPage><enabled>true</enabled></pageAccesses>'
        );
        String destXml = buildPermSetXml('');

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        Assert.areEqual(1, report.missingPages.size());
        Assert.areEqual('DevDebugPage', report.missingPages[0].name);
    }

    // =========================================================================
    // TEST: Missing tab
    // =========================================================================

    @IsTest
    static void testMissingTab() {
        String sourceXml = buildPermSetXml(
            '<tabSettings><tab>Product_Display_Group__c</tab><visibility>Visible</visibility></tabSettings>'
          + '<tabSettings><tab>standard-Account</tab><visibility>Visible</visibility></tabSettings>'
        );
        String destXml = buildPermSetXml(
            '<tabSettings><tab>standard-Account</tab><visibility>Visible</visibility></tabSettings>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        Assert.areEqual(1, report.missingTabs.size());
        Assert.areEqual('Product_Display_Group__c', report.missingTabs[0].name);
    }

    // =========================================================================
    // TEST: Missing record type
    // =========================================================================

    @IsTest
    static void testMissingRecordType() {
        String sourceXml = buildPermSetXml(
            '<recordTypeVisibilities><recordType>Account.Enterprise</recordType><visible>true</visible></recordTypeVisibilities>'
          + '<recordTypeVisibilities><recordType>Case.Support_Case</recordType><visible>true</visible></recordTypeVisibilities>'
        );
        String destXml = buildPermSetXml(
            '<recordTypeVisibilities><recordType>Account.Enterprise</recordType><visible>true</visible></recordTypeVisibilities>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        Assert.areEqual(1, report.missingRecordTypes.size());
        Assert.areEqual('Case.Support_Case', report.missingRecordTypes[0].name);
        Assert.areEqual('Case', report.missingRecordTypes[0].parentObject);
        Assert.areEqual('RecordType', report.missingRecordTypes[0].dependencyType);
    }

    // =========================================================================
    // TEST: Missing custom permission and application
    // =========================================================================

    @IsTest
    static void testMissingCustomPermAndApplication() {
        String sourceXml = buildPermSetXml(
            '<customPermissions><name>Enable_Debug_Mode</name><enabled>true</enabled></customPermissions>'
          + '<applicationVisibilities><application>DevConsole_App</application><visible>true</visible></applicationVisibilities>'
        );
        String destXml = buildPermSetXml('');

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        Assert.areEqual(1, report.missingCustomPermissions.size());
        Assert.areEqual('Enable_Debug_Mode', report.missingCustomPermissions[0].name);
        Assert.areEqual(1, report.missingApplications.size());
        Assert.areEqual('DevConsole_App', report.missingApplications[0].name);
        Assert.areEqual(2, report.totalMissingCount);
    }

    // =========================================================================
    // TEST: Mixed — multiple missing dependency types
    // =========================================================================

    @IsTest
    static void testMixedMissingDependencies() {
        String sourceXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
          + '<objectPermissions><object>Product_Display_Group__c</object><allowRead>true</allowRead></objectPermissions>'
          + '<fieldPermissions><field>Account.Industry</field><readable>true</readable><editable>false</editable></fieldPermissions>'
          + '<fieldPermissions><field>pse__Timecard_Header__c.End_Time__c</field><readable>true</readable><editable>false</editable></fieldPermissions>'
          + '<classAccesses><apexClass>DevOnlyController</apexClass><enabled>true</enabled></classAccesses>'
          + '<tabSettings><tab>Product_Display_Group__c</tab><visibility>Visible</visibility></tabSettings>'
        );
        String destXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
          + '<fieldPermissions><field>Account.Industry</field><readable>true</readable><editable>false</editable></fieldPermissions>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isFalse(report.isSafeToDeploy);
        // Product_Display_Group__c missing + pse__Timecard_Header__c (implicitly from field)
        Assert.areEqual(2, report.missingObjects.size(), 'Two missing objects');
        Assert.areEqual(1, report.missingFields.size(), 'One missing field');
        Assert.areEqual(1, report.missingClasses.size(), 'One missing class');
        Assert.areEqual(1, report.missingTabs.size(), 'One missing tab');
        Assert.isTrue(report.totalMissingCount >= 5, 'At least 5 total missing');
        Assert.isTrue(report.summaryMessage.contains('missing'), 'Summary should mention missing');
    }

    // =========================================================================
    // TEST: Destination has MORE than Source (no false positives)
    // =========================================================================

    @IsTest
    static void testDestinationHasMore_NoFalsePositives() {
        String sourceXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
        );
        String destXml = buildPermSetXml(
            '<objectPermissions><object>Account</object><allowRead>true</allowRead></objectPermissions>'
          + '<objectPermissions><object>Contact</object><allowRead>true</allowRead></objectPermissions>'
          + '<classAccesses><apexClass>ExtraController</apexClass><enabled>true</enabled></classAccesses>'
        );

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.isTrue(report.isSafeToDeploy, 'Source is subset of Dest — safe');
        Assert.areEqual(0, report.totalMissingCount);
    }

    // =========================================================================
    // TEST: Empty Source XML — should throw
    // =========================================================================

    @IsTest
    static void testBlankSourceXml_ThrowsException() {
        Boolean caught = false;
        try {
            FH_MetadataValidator.validatePermSetDependencies('', '<PermissionSet/>');
        } catch (FlowMetadataService.FlowHealthException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Source'), 'Error should mention Source');
        }
        Assert.isTrue(caught, 'Should throw for blank Source XML');
    }

    // =========================================================================
    // TEST: Empty Destination XML — should throw
    // =========================================================================

    @IsTest
    static void testBlankDestinationXml_ThrowsException() {
        Boolean caught = false;
        try {
            FH_MetadataValidator.validatePermSetDependencies('<PermissionSet/>', '');
        } catch (FlowMetadataService.FlowHealthException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Destination'), 'Error should mention Destination');
        }
        Assert.isTrue(caught, 'Should throw for blank Destination XML');
    }

    // =========================================================================
    // TEST: Both empty — minimal XML, no crashes
    // =========================================================================

    @IsTest
    static void testMinimalXml_EmptyPermSet() {
        String minXml = buildPermSetXml('');

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(minXml, minXml);
        Test.stopTest();

        Assert.isTrue(report.isSafeToDeploy, 'Empty perm sets should be safe');
        Assert.areEqual(0, report.totalMissingCount);
    }

    // =========================================================================
    // TEST: Singular vs plural summary message
    // =========================================================================

    @IsTest
    static void testSingularMissingSummaryMessage() {
        String sourceXml = buildPermSetXml(
            '<objectPermissions><object>Orphan__c</object><allowRead>true</allowRead></objectPermissions>'
        );
        String destXml = buildPermSetXml('');

        Test.startTest();
        FH_MetadataValidator.ValidationReport report =
            FH_MetadataValidator.validatePermSetDependencies(sourceXml, destXml);
        Test.stopTest();

        Assert.areEqual(1, report.totalMissingCount);
        Assert.isTrue(report.summaryMessage.contains('1 missing dependency'), 'Singular form for 1');
    }
}
