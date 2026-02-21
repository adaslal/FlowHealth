/**
 * PermSetMetadata - Wrapper classes for Permission Set XML structure.
 *
 * A Salesforce Permission Set XML contains:
 *   - Top-level metadata (label, description, license, hasActivationRequired)
 *   - Object permissions (CRUD per object)
 *   - Field permissions (read/edit per field)
 *   - User permissions (system-level permissions like ApiEnabled, ViewSetup)
 *   - Tab settings (visible/hidden per tab)
 *   - Class accesses (Apex class access)
 *   - Page accesses (VF page access)
 *   - Record type visibilities
 *   - Application visibilities
 *   - Custom metadata type accesses
 *   - Custom setting accesses
 *   - Flow accesses
 *
 * These classes mirror the XML structure so we can parse → analyze → transform.
 * The purifier reads dirty XML, runs rules, and outputs clean XML.
 */
public class PermSetMetadata {

    // =========================================================================
    // Top-level Permission Set definition
    // =========================================================================

    public class PermissionSetDefinition {
        public String label;
        public String description;
        public String license;             // e.g., 'Salesforce'
        public Boolean hasActivationRequired;
        public Boolean isCustom;           // Derived: true if user-created
        public String fileName;            // Original filename (for export)

        // Permission blocks
        public List<ObjectPermission> objectPermissions;
        public List<FieldPermission> fieldPermissions;
        public List<UserPermission> userPermissions;
        public List<TabSetting> tabSettings;
        public List<ClassAccess> classAccesses;
        public List<PageAccess> pageAccesses;
        public List<RecordTypeVisibility> recordTypeVisibilities;
        public List<ApplicationVisibility> applicationVisibilities;
        public List<CustomMetadataTypeAccess> customMetadataTypeAccesses;
        public List<CustomSettingAccess> customSettingAccesses;
        public List<FlowAccess> flowAccesses;
        public List<CustomPermission> customPermissions;

        public PermissionSetDefinition() {
            this.objectPermissions = new List<ObjectPermission>();
            this.fieldPermissions = new List<FieldPermission>();
            this.userPermissions = new List<UserPermission>();
            this.tabSettings = new List<TabSetting>();
            this.classAccesses = new List<ClassAccess>();
            this.pageAccesses = new List<PageAccess>();
            this.recordTypeVisibilities = new List<RecordTypeVisibility>();
            this.applicationVisibilities = new List<ApplicationVisibility>();
            this.customMetadataTypeAccesses = new List<CustomMetadataTypeAccess>();
            this.customSettingAccesses = new List<CustomSettingAccess>();
            this.flowAccesses = new List<FlowAccess>();
            this.customPermissions = new List<CustomPermission>();
        }

        /** Total permission entries across all blocks. */
        public Integer getTotalPermissionCount() {
            return objectPermissions.size() + fieldPermissions.size() +
                   userPermissions.size() + tabSettings.size() +
                   classAccesses.size() + pageAccesses.size() +
                   recordTypeVisibilities.size() + applicationVisibilities.size() +
                   customMetadataTypeAccesses.size() + customSettingAccesses.size() +
                   flowAccesses.size() + customPermissions.size();
        }
    }

    // =========================================================================
    // Object Permissions (CRUD per SObject)
    // =========================================================================

    public class ObjectPermission {
        public String object_x;            // SObject API name (serialized as "object")
        public Boolean allowCreate;
        public Boolean allowRead;
        public Boolean allowEdit;
        public Boolean allowDelete;
        public Boolean viewAllRecords;
        public Boolean modifyAllRecords;
    }

    // =========================================================================
    // Field Permissions (read/edit per field)
    // =========================================================================

    public class FieldPermission {
        public String field;               // Object.FieldName format
        public Boolean readable;
        public Boolean editable;

        /** Extracts the object name from the field reference. */
        public String getObjectName() {
            if (field == null) return null;
            Integer dotIdx = field.indexOf('.');
            return dotIdx > 0 ? field.substring(0, dotIdx) : null;
        }

        /** Extracts the field name from the field reference. */
        public String getFieldName() {
            if (field == null) return null;
            Integer dotIdx = field.indexOf('.');
            return dotIdx > 0 ? field.substring(dotIdx + 1) : field;
        }
    }

    // =========================================================================
    // User Permissions (system-level)
    // =========================================================================

    public class UserPermission {
        public String name;                // e.g., 'ApiEnabled', 'ViewSetup'
        public Boolean enabled;
    }

    // =========================================================================
    // Tab Settings
    // =========================================================================

    public class TabSetting {
        public String tab;                 // Tab API name
        public String visibility;          // 'DefaultOn', 'DefaultOff', 'Hidden'
    }

    // =========================================================================
    // Apex Class Access
    // =========================================================================

    public class ClassAccess {
        public String apexClass;
        public Boolean enabled;
    }

    // =========================================================================
    // Visualforce Page Access
    // =========================================================================

    public class PageAccess {
        public String apexPage;
        public Boolean enabled;
    }

    // =========================================================================
    // Record Type Visibility
    // =========================================================================

    public class RecordTypeVisibility {
        public String recordType;          // Object.RecordTypeName format
        public Boolean visible;
        public Boolean personAccountDefault;
    }

    // =========================================================================
    // Application Visibility
    // =========================================================================

    public class ApplicationVisibility {
        public String application;
        public Boolean visible;
        public Boolean isDefault;
    }

    // =========================================================================
    // Custom Metadata Type Access
    // =========================================================================

    public class CustomMetadataTypeAccess {
        public String name;
        public Boolean enabled;
    }

    // =========================================================================
    // Custom Setting Access
    // =========================================================================

    public class CustomSettingAccess {
        public String name;
        public Boolean enabled;
    }

    // =========================================================================
    // Flow Access
    // =========================================================================

    public class FlowAccess {
        public String flow;
        public Boolean enabled;
    }

    // =========================================================================
    // Custom Permission
    // =========================================================================

    public class CustomPermission {
        public String name;
        public Boolean enabled;
    }
}
