@isTest
private class PermSetXmlParserTest {

    private static final String PERM_SET_NAMESPACE = 'http://soap.sforce.com/2006/04/metadata';

    @isTest
    static void testParseCompletePermissionSetXml() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Complete Permission Set</label>' +
            '<description>Test permission set with all element types</description>' +
            '<license>Salesforce</license>' +
            '<hasActivationRequired>true</hasActivationRequired>' +
            '<objectPermissions>' +
            '<object>Account</object>' +
            '<allowCreate>true</allowCreate>' +
            '<allowRead>true</allowRead>' +
            '<allowEdit>true</allowEdit>' +
            '<allowDelete>false</allowDelete>' +
            '<viewAllRecords>true</viewAllRecords>' +
            '<modifyAllRecords>false</modifyAllRecords>' +
            '</objectPermissions>' +
            '<fieldPermissions>' +
            '<field>Account.Name</field>' +
            '<readable>true</readable>' +
            '<editable>true</editable>' +
            '</fieldPermissions>' +
            '<userPermissions>' +
            '<name>ActivateContract</name>' +
            '<enabled>true</enabled>' +
            '</userPermissions>' +
            '<tabSettings>' +
            '<tab>standard-Account</tab>' +
            '<visibility>Visible</visibility>' +
            '</tabSettings>' +
            '<classAccesses>' +
            '<apexClass>MyApexClass</apexClass>' +
            '<enabled>true</enabled>' +
            '</classAccesses>' +
            '<pageAccesses>' +
            '<apexPage>MyApexPage</apexPage>' +
            '<enabled>true</enabled>' +
            '</pageAccesses>' +
            '<recordTypeVisibilities>' +
            '<recordType>Account.Business</recordType>' +
            '<visible>true</visible>' +
            '<personAccountDefault>false</personAccountDefault>' +
            '</recordTypeVisibilities>' +
            '<applicationVisibilities>' +
            '<application>standard__Account</application>' +
            '<visible>true</visible>' +
            '<default>true</default>' +
            '</applicationVisibilities>' +
            '<customMetadataTypeAccesses>' +
            '<name>CustomMetadataType__mdt</name>' +
            '<enabled>true</enabled>' +
            '</customMetadataTypeAccesses>' +
            '<customSettingAccesses>' +
            '<name>CustomSettings__c</name>' +
            '<enabled>true</enabled>' +
            '</customSettingAccesses>' +
            '<flowAccesses>' +
            '<flow>My_Flow</flow>' +
            '<enabled>true</enabled>' +
            '</flowAccesses>' +
            '<customPermissions>' +
            '<name>MyCustomPermission</name>' +
            '<enabled>true</enabled>' +
            '</customPermissions>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual('Complete Permission Set', result.label);
        Assert.areEqual('Test permission set with all element types', result.description);
        Assert.areEqual('Salesforce', result.license);
        Assert.areEqual(true, result.hasActivationRequired);
        Assert.areEqual(1, result.objectPermissions.size());
        Assert.areEqual(1, result.fieldPermissions.size());
        Assert.areEqual(1, result.userPermissions.size());
        Assert.areEqual(1, result.tabSettings.size());
        Assert.areEqual(1, result.classAccesses.size());
        Assert.areEqual(1, result.pageAccesses.size());
        Assert.areEqual(1, result.recordTypeVisibilities.size());
        Assert.areEqual(1, result.applicationVisibilities.size());
        Assert.areEqual(1, result.customMetadataTypeAccesses.size());
        Assert.areEqual(1, result.customSettingAccesses.size());
        Assert.areEqual(1, result.flowAccesses.size());
        Assert.areEqual(1, result.customPermissions.size());
    }

    @isTest
    static void testParseBasicPermissionSet() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Basic Permission Set</label>' +
            '<description>Permission set with only basic fields</description>' +
            '<license>Salesforce</license>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual('Basic Permission Set', result.label);
        Assert.areEqual('Permission set with only basic fields', result.description);
        Assert.areEqual('Salesforce', result.license);
        Assert.areEqual(false, result.hasActivationRequired);
        Assert.areEqual(0, result.objectPermissions.size());
    }

    @isTest
    static void testParseObjectPermissions() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Object Permission Set</label>' +
            '<objectPermissions>' +
            '<object>Account</object>' +
            '<allowCreate>true</allowCreate>' +
            '<allowRead>true</allowRead>' +
            '<allowEdit>true</allowEdit>' +
            '<allowDelete>false</allowDelete>' +
            '<viewAllRecords>true</viewAllRecords>' +
            '<modifyAllRecords>false</modifyAllRecords>' +
            '</objectPermissions>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(1, result.objectPermissions.size());
        PermSetMetadata.ObjectPermission objPerm = result.objectPermissions[0];
        Assert.areEqual('Account', objPerm.object_x);
        Assert.areEqual(true, objPerm.allowCreate);
        Assert.areEqual(true, objPerm.allowRead);
        Assert.areEqual(true, objPerm.allowEdit);
        Assert.areEqual(false, objPerm.allowDelete);
        Assert.areEqual(true, objPerm.viewAllRecords);
        Assert.areEqual(false, objPerm.modifyAllRecords);
    }

    @isTest
    static void testParseFieldPermissions() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Field Permission Set</label>' +
            '<fieldPermissions>' +
            '<field>Account.Name</field>' +
            '<readable>true</readable>' +
            '<editable>true</editable>' +
            '</fieldPermissions>' +
            '<fieldPermissions>' +
            '<field>Account.BillingCity</field>' +
            '<readable>true</readable>' +
            '<editable>false</editable>' +
            '</fieldPermissions>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.fieldPermissions.size());
        PermSetMetadata.FieldPermission fieldPerm1 = result.fieldPermissions[0];
        Assert.areEqual('Account.Name', fieldPerm1.field);
        Assert.areEqual(true, fieldPerm1.readable);
        Assert.areEqual(true, fieldPerm1.editable);

        PermSetMetadata.FieldPermission fieldPerm2 = result.fieldPermissions[1];
        Assert.areEqual('Account.BillingCity', fieldPerm2.field);
        Assert.areEqual(true, fieldPerm2.readable);
        Assert.areEqual(false, fieldPerm2.editable);
    }

    @isTest
    static void testParseUserPermissions() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>User Permission Set</label>' +
            '<userPermissions>' +
            '<name>ActivateContract</name>' +
            '<enabled>true</enabled>' +
            '</userPermissions>' +
            '<userPermissions>' +
            '<name>ActivateOrder</name>' +
            '<enabled>false</enabled>' +
            '</userPermissions>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.userPermissions.size());
        PermSetMetadata.UserPermission userPerm1 = result.userPermissions[0];
        Assert.areEqual('ActivateContract', userPerm1.name);
        Assert.areEqual(true, userPerm1.enabled);

        PermSetMetadata.UserPermission userPerm2 = result.userPermissions[1];
        Assert.areEqual('ActivateOrder', userPerm2.name);
        Assert.areEqual(false, userPerm2.enabled);
    }

    @isTest
    static void testParseTabSettings() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Tab Setting Permission Set</label>' +
            '<tabSettings>' +
            '<tab>standard-Account</tab>' +
            '<visibility>Visible</visibility>' +
            '</tabSettings>' +
            '<tabSettings>' +
            '<tab>standard-Contact</tab>' +
            '<visibility>Hidden</visibility>' +
            '</tabSettings>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.tabSettings.size());
        PermSetMetadata.TabSetting tabSetting1 = result.tabSettings[0];
        Assert.areEqual('standard-Account', tabSetting1.tab);
        Assert.areEqual('Visible', tabSetting1.visibility);

        PermSetMetadata.TabSetting tabSetting2 = result.tabSettings[1];
        Assert.areEqual('standard-Contact', tabSetting2.tab);
        Assert.areEqual('Hidden', tabSetting2.visibility);
    }

    @isTest
    static void testParseClassAccesses() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Class Access Permission Set</label>' +
            '<classAccesses>' +
            '<apexClass>MyApexClass</apexClass>' +
            '<enabled>true</enabled>' +
            '</classAccesses>' +
            '<classAccesses>' +
            '<apexClass>AnotherApexClass</apexClass>' +
            '<enabled>false</enabled>' +
            '</classAccesses>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.classAccesses.size());
        PermSetMetadata.ClassAccess classAccess1 = result.classAccesses[0];
        Assert.areEqual('MyApexClass', classAccess1.apexClass);
        Assert.areEqual(true, classAccess1.enabled);

        PermSetMetadata.ClassAccess classAccess2 = result.classAccesses[1];
        Assert.areEqual('AnotherApexClass', classAccess2.apexClass);
        Assert.areEqual(false, classAccess2.enabled);
    }

    @isTest
    static void testParsePageAccesses() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Page Access Permission Set</label>' +
            '<pageAccesses>' +
            '<apexPage>MyApexPage</apexPage>' +
            '<enabled>true</enabled>' +
            '</pageAccesses>' +
            '<pageAccesses>' +
            '<apexPage>AnotherApexPage</apexPage>' +
            '<enabled>false</enabled>' +
            '</pageAccesses>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.pageAccesses.size());
        PermSetMetadata.PageAccess pageAccess1 = result.pageAccesses[0];
        Assert.areEqual('MyApexPage', pageAccess1.apexPage);
        Assert.areEqual(true, pageAccess1.enabled);

        PermSetMetadata.PageAccess pageAccess2 = result.pageAccesses[1];
        Assert.areEqual('AnotherApexPage', pageAccess2.apexPage);
        Assert.areEqual(false, pageAccess2.enabled);
    }

    @isTest
    static void testParseRecordTypeVisibilities() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Record Type Visibility Permission Set</label>' +
            '<recordTypeVisibilities>' +
            '<recordType>Account.Business</recordType>' +
            '<visible>true</visible>' +
            '<personAccountDefault>false</personAccountDefault>' +
            '</recordTypeVisibilities>' +
            '<recordTypeVisibilities>' +
            '<recordType>Account.Personal</recordType>' +
            '<visible>false</visible>' +
            '<personAccountDefault>true</personAccountDefault>' +
            '</recordTypeVisibilities>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.recordTypeVisibilities.size());
        PermSetMetadata.RecordTypeVisibility rtv1 = result.recordTypeVisibilities[0];
        Assert.areEqual('Account.Business', rtv1.recordType);
        Assert.areEqual(true, rtv1.visible);
        Assert.areEqual(false, rtv1.personAccountDefault);

        PermSetMetadata.RecordTypeVisibility rtv2 = result.recordTypeVisibilities[1];
        Assert.areEqual('Account.Personal', rtv2.recordType);
        Assert.areEqual(false, rtv2.visible);
        Assert.areEqual(true, rtv2.personAccountDefault);
    }

    @isTest
    static void testParseApplicationVisibilities() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Application Visibility Permission Set</label>' +
            '<applicationVisibilities>' +
            '<application>standard__Account</application>' +
            '<visible>true</visible>' +
            '<default>true</default>' +
            '</applicationVisibilities>' +
            '<applicationVisibilities>' +
            '<application>standard__Contact</application>' +
            '<visible>true</visible>' +
            '<default>false</default>' +
            '</applicationVisibilities>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.applicationVisibilities.size());
        PermSetMetadata.ApplicationVisibility appVis1 = result.applicationVisibilities[0];
        Assert.areEqual('standard__Account', appVis1.application);
        Assert.areEqual(true, appVis1.visible);
        Assert.areEqual(true, appVis1.isDefault);

        PermSetMetadata.ApplicationVisibility appVis2 = result.applicationVisibilities[1];
        Assert.areEqual('standard__Contact', appVis2.application);
        Assert.areEqual(true, appVis2.visible);
        Assert.areEqual(false, appVis2.isDefault);
    }

    @isTest
    static void testParseCustomMetadataTypeAccesses() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Custom Metadata Type Access Permission Set</label>' +
            '<customMetadataTypeAccesses>' +
            '<name>CustomMetadataType__mdt</name>' +
            '<enabled>true</enabled>' +
            '</customMetadataTypeAccesses>' +
            '<customMetadataTypeAccesses>' +
            '<name>AnotherCustomMetadata__mdt</name>' +
            '<enabled>false</enabled>' +
            '</customMetadataTypeAccesses>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.customMetadataTypeAccesses.size());
        PermSetMetadata.CustomMetadataTypeAccess cmtAccess1 = result.customMetadataTypeAccesses[0];
        Assert.areEqual('CustomMetadataType__mdt', cmtAccess1.name);
        Assert.areEqual(true, cmtAccess1.enabled);

        PermSetMetadata.CustomMetadataTypeAccess cmtAccess2 = result.customMetadataTypeAccesses[1];
        Assert.areEqual('AnotherCustomMetadata__mdt', cmtAccess2.name);
        Assert.areEqual(false, cmtAccess2.enabled);
    }

    @isTest
    static void testParseCustomSettingAccesses() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Custom Setting Access Permission Set</label>' +
            '<customSettingAccesses>' +
            '<name>CustomSettings__c</name>' +
            '<enabled>true</enabled>' +
            '</customSettingAccesses>' +
            '<customSettingAccesses>' +
            '<name>AnotherCustomSetting__c</name>' +
            '<enabled>false</enabled>' +
            '</customSettingAccesses>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.customSettingAccesses.size());
        PermSetMetadata.CustomSettingAccess csAccess1 = result.customSettingAccesses[0];
        Assert.areEqual('CustomSettings__c', csAccess1.name);
        Assert.areEqual(true, csAccess1.enabled);

        PermSetMetadata.CustomSettingAccess csAccess2 = result.customSettingAccesses[1];
        Assert.areEqual('AnotherCustomSetting__c', csAccess2.name);
        Assert.areEqual(false, csAccess2.enabled);
    }

    @isTest
    static void testParseFlowAccesses() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Flow Access Permission Set</label>' +
            '<flowAccesses>' +
            '<flow>My_Flow</flow>' +
            '<enabled>true</enabled>' +
            '</flowAccesses>' +
            '<flowAccesses>' +
            '<flow>Another_Flow</flow>' +
            '<enabled>false</enabled>' +
            '</flowAccesses>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.flowAccesses.size());
        PermSetMetadata.FlowAccess flowAccess1 = result.flowAccesses[0];
        Assert.areEqual('My_Flow', flowAccess1.flow);
        Assert.areEqual(true, flowAccess1.enabled);

        PermSetMetadata.FlowAccess flowAccess2 = result.flowAccesses[1];
        Assert.areEqual('Another_Flow', flowAccess2.flow);
        Assert.areEqual(false, flowAccess2.enabled);
    }

    @isTest
    static void testParseCustomPermissions() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Custom Permission Permission Set</label>' +
            '<customPermissions>' +
            '<name>MyCustomPermission</name>' +
            '<enabled>true</enabled>' +
            '</customPermissions>' +
            '<customPermissions>' +
            '<name>AnotherCustomPermission</name>' +
            '<enabled>false</enabled>' +
            '</customPermissions>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual(2, result.customPermissions.size());
        PermSetMetadata.CustomPermission custPerm1 = result.customPermissions[0];
        Assert.areEqual('MyCustomPermission', custPerm1.name);
        Assert.areEqual(true, custPerm1.enabled);

        PermSetMetadata.CustomPermission custPerm2 = result.customPermissions[1];
        Assert.areEqual('AnotherCustomPermission', custPerm2.name);
        Assert.areEqual(false, custPerm2.enabled);
    }

    @isTest
    static void testParseHasActivationRequired() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Activation Required Permission Set</label>' +
            '<hasActivationRequired>true</hasActivationRequired>' +
            '</PermissionSet>';

        PermSetMetadata.PermissionSetDefinition result = PermSetXmlParser.parse(xmlContent);

        Assert.areEqual('Activation Required Permission Set', result.label);
        Assert.areEqual(true, result.hasActivationRequired);
    }

    @isTest
    static void testParseBlankXmlThrowsException() {
        String xmlContent = '';

        try {
            PermSetXmlParser.parse(xmlContent);
            Assert.fail('Expected FlowHealthException to be thrown for blank XML');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @isTest
    static void testParseNullXmlThrowsException() {
        try {
            PermSetXmlParser.parse(null);
            Assert.fail('Expected FlowHealthException to be thrown for null XML');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @isTest
    static void testParseMalformedXmlThrowsException() {
        String xmlContent = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<PermissionSet xmlns="' + PERM_SET_NAMESPACE + '">' +
            '<label>Malformed XML</label>' +
            '<!-- Missing closing tag -->';

        try {
            PermSetXmlParser.parse(xmlContent);
            Assert.fail('Expected FlowHealthException to be thrown for malformed XML');
        } catch (FlowMetadataService.FlowHealthException e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}
