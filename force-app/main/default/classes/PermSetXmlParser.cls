/**
 * PermSetXmlParser - Parses Permission Set XML into PermSetMetadata objects.
 *
 * This is the Privacy Mode bridge for PermSet Purifier — users upload a
 * .permissionset-meta.xml file, and this parser produces a strongly-typed
 * PermSetMetadata.PermissionSetDefinition for analysis and transformation.
 *
 * XML STRUCTURE (simplified):
 * <PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
 *   <label>My Perm Set</label>
 *   <description>...</description>
 *   <license>Salesforce</license>
 *   <hasActivationRequired>false</hasActivationRequired>
 *   <objectPermissions>
 *     <object>Account</object>
 *     <allowCreate>true</allowCreate>
 *     ...
 *   </objectPermissions>
 *   <fieldPermissions>
 *     <field>Account.Industry</field>
 *     <readable>true</readable>
 *     <editable>false</editable>
 *   </fieldPermissions>
 *   <userPermissions>
 *     <name>ApiEnabled</name>
 *     <enabled>true</enabled>
 *   </userPermissions>
 *   ...
 * </PermissionSet>
 */
public class PermSetXmlParser {

    private static final String SF_NAMESPACE = 'http://soap.sforce.com/2006/04/metadata';

    /**
     * Parse a Permission Set XML string into a PermissionSetDefinition.
     *
     * @param xmlContent  The raw XML content
     * @return PermSetMetadata.PermissionSetDefinition
     */
    public static PermSetMetadata.PermissionSetDefinition parse(String xmlContent) {
        if (String.isBlank(xmlContent)) {
            throw new FlowMetadataService.FlowHealthException(
                'Permission Set XML content cannot be blank.'
            );
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlContent);
            Dom.XmlNode root = doc.getRootElement();

            if (root == null) {
                throw new FlowMetadataService.FlowHealthException(
                    'Invalid Permission Set XML: no root element found.'
                );
            }

            return parseDefinition(root);
        } catch (FlowMetadataService.FlowHealthException e) {
            throw e;
        } catch (Exception e) {
            throw new FlowMetadataService.FlowHealthException(
                'Failed to parse Permission Set XML: ' + e.getMessage()
            );
        }
    }

    // =========================================================================
    // Root parser
    // =========================================================================

    private static PermSetMetadata.PermissionSetDefinition parseDefinition(Dom.XmlNode root) {
        PermSetMetadata.PermissionSetDefinition def = new PermSetMetadata.PermissionSetDefinition();

        for (Dom.XmlNode child : root.getChildElements()) {
            String name = child.getName();

            if (name == 'label') {
                def.label = child.getText();
            } else if (name == 'description') {
                def.description = child.getText();
            } else if (name == 'license') {
                def.license = child.getText();
            } else if (name == 'hasActivationRequired') {
                def.hasActivationRequired = parseBool(child.getText());
            } else if (name == 'objectPermissions') {
                def.objectPermissions.add(parseObjectPermission(child));
            } else if (name == 'fieldPermissions') {
                def.fieldPermissions.add(parseFieldPermission(child));
            } else if (name == 'userPermissions') {
                def.userPermissions.add(parseUserPermission(child));
            } else if (name == 'tabSettings') {
                def.tabSettings.add(parseTabSetting(child));
            } else if (name == 'classAccesses') {
                def.classAccesses.add(parseClassAccess(child));
            } else if (name == 'pageAccesses') {
                def.pageAccesses.add(parsePageAccess(child));
            } else if (name == 'recordTypeVisibilities') {
                def.recordTypeVisibilities.add(parseRecordTypeVisibility(child));
            } else if (name == 'applicationVisibilities') {
                def.applicationVisibilities.add(parseApplicationVisibility(child));
            } else if (name == 'customMetadataTypeAccesses') {
                def.customMetadataTypeAccesses.add(parseCustomMetadataTypeAccess(child));
            } else if (name == 'customSettingAccesses') {
                def.customSettingAccesses.add(parseCustomSettingAccess(child));
            } else if (name == 'flowAccesses') {
                def.flowAccesses.add(parseFlowAccess(child));
            } else if (name == 'customPermissions') {
                def.customPermissions.add(parseCustomPermission(child));
            }
            // Unknown elements are silently ignored (forward-compatible)
        }

        return def;
    }

    // =========================================================================
    // Element parsers
    // =========================================================================

    private static PermSetMetadata.ObjectPermission parseObjectPermission(Dom.XmlNode node) {
        PermSetMetadata.ObjectPermission op = new PermSetMetadata.ObjectPermission();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            String text = child.getText();
            if (name == 'object') {
                op.object_x = text;
            } else if (name == 'allowCreate') {
                op.allowCreate = parseBool(text);
            } else if (name == 'allowRead') {
                op.allowRead = parseBool(text);
            } else if (name == 'allowEdit') {
                op.allowEdit = parseBool(text);
            } else if (name == 'allowDelete') {
                op.allowDelete = parseBool(text);
            } else if (name == 'viewAllRecords') {
                op.viewAllRecords = parseBool(text);
            } else if (name == 'modifyAllRecords') {
                op.modifyAllRecords = parseBool(text);
            }
        }
        return op;
    }

    private static PermSetMetadata.FieldPermission parseFieldPermission(Dom.XmlNode node) {
        PermSetMetadata.FieldPermission fp = new PermSetMetadata.FieldPermission();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            String text = child.getText();
            if (name == 'field') {
                fp.field = text;
            } else if (name == 'readable') {
                fp.readable = parseBool(text);
            } else if (name == 'editable') {
                fp.editable = parseBool(text);
            }
        }
        return fp;
    }

    private static PermSetMetadata.UserPermission parseUserPermission(Dom.XmlNode node) {
        PermSetMetadata.UserPermission up = new PermSetMetadata.UserPermission();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            String text = child.getText();
            if (name == 'name') {
                up.name = text;
            } else if (name == 'enabled') {
                up.enabled = parseBool(text);
            }
        }
        return up;
    }

    private static PermSetMetadata.TabSetting parseTabSetting(Dom.XmlNode node) {
        PermSetMetadata.TabSetting ts = new PermSetMetadata.TabSetting();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'tab') {
                ts.tab = child.getText();
            } else if (name == 'visibility') {
                ts.visibility = child.getText();
            }
        }
        return ts;
    }

    private static PermSetMetadata.ClassAccess parseClassAccess(Dom.XmlNode node) {
        PermSetMetadata.ClassAccess ca = new PermSetMetadata.ClassAccess();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'apexClass') {
                ca.apexClass = child.getText();
            } else if (name == 'enabled') {
                ca.enabled = parseBool(child.getText());
            }
        }
        return ca;
    }

    private static PermSetMetadata.PageAccess parsePageAccess(Dom.XmlNode node) {
        PermSetMetadata.PageAccess pa = new PermSetMetadata.PageAccess();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'apexPage') {
                pa.apexPage = child.getText();
            } else if (name == 'enabled') {
                pa.enabled = parseBool(child.getText());
            }
        }
        return pa;
    }

    private static PermSetMetadata.RecordTypeVisibility parseRecordTypeVisibility(Dom.XmlNode node) {
        PermSetMetadata.RecordTypeVisibility rtv = new PermSetMetadata.RecordTypeVisibility();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'recordType') {
                rtv.recordType = child.getText();
            } else if (name == 'visible') {
                rtv.visible = parseBool(child.getText());
            } else if (name == 'personAccountDefault') {
                rtv.personAccountDefault = parseBool(child.getText());
            }
        }
        return rtv;
    }

    private static PermSetMetadata.ApplicationVisibility parseApplicationVisibility(Dom.XmlNode node) {
        PermSetMetadata.ApplicationVisibility av = new PermSetMetadata.ApplicationVisibility();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'application') {
                av.application = child.getText();
            } else if (name == 'visible') {
                av.visible = parseBool(child.getText());
            } else if (name == 'default') {
                av.isDefault = parseBool(child.getText());
            }
        }
        return av;
    }

    private static PermSetMetadata.CustomMetadataTypeAccess parseCustomMetadataTypeAccess(Dom.XmlNode node) {
        PermSetMetadata.CustomMetadataTypeAccess cma = new PermSetMetadata.CustomMetadataTypeAccess();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'name') {
                cma.name = child.getText();
            } else if (name == 'enabled') {
                cma.enabled = parseBool(child.getText());
            }
        }
        return cma;
    }

    private static PermSetMetadata.CustomSettingAccess parseCustomSettingAccess(Dom.XmlNode node) {
        PermSetMetadata.CustomSettingAccess csa = new PermSetMetadata.CustomSettingAccess();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'name') {
                csa.name = child.getText();
            } else if (name == 'enabled') {
                csa.enabled = parseBool(child.getText());
            }
        }
        return csa;
    }

    private static PermSetMetadata.FlowAccess parseFlowAccess(Dom.XmlNode node) {
        PermSetMetadata.FlowAccess fa = new PermSetMetadata.FlowAccess();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'flow') {
                fa.flow = child.getText();
            } else if (name == 'enabled') {
                fa.enabled = parseBool(child.getText());
            }
        }
        return fa;
    }

    private static PermSetMetadata.CustomPermission parseCustomPermission(Dom.XmlNode node) {
        PermSetMetadata.CustomPermission cp = new PermSetMetadata.CustomPermission();
        for (Dom.XmlNode child : node.getChildElements()) {
            String name = child.getName();
            if (name == 'name') {
                cp.name = child.getText();
            } else if (name == 'enabled') {
                cp.enabled = parseBool(child.getText());
            }
        }
        return cp;
    }

    // =========================================================================
    // Utility
    // =========================================================================

    private static Boolean parseBool(String text) {
        return text != null && text.trim().equalsIgnoreCase('true');
    }
}
