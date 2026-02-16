# Flow Health - Sprint 1 Setup Guide

## Prerequisites
- A Salesforce Developer Edition or Scratch Org
- Salesforce CLI (sf) installed
- My Domain enabled (required for Named Credentials)

## Step 1: Create the SFDX Project

If you haven't already, clone or copy this project folder. Then authorize your org:

```bash
# Authorize your dev org
sf org login web --alias flowhealth-dev

# Set it as default
sf config set target-org flowhealth-dev
```

## Step 2: Set Up the Named Credential (Manual - Required)

The app calls the Tooling API to fetch Flow metadata. In Lightning context,
`UserInfo.getSessionId()` returns INVALID_SESSION_ID, so we use a Named
Credential with OAuth to authenticate.

### 2a: Create an External Client App

(Note: Salesforce replaced "Connected Apps" with "External Client Apps" in recent releases.)

1. Go to **Setup > External Client Apps > New External Client App**
2. Fill in:
   - **Name**: `Flow Health API`
   - **API Name**: `Flow_Health_API`
   - **Description**: `OAuth client for Flow Health Tooling API access`
   - **Distribution**: `local` (for development; change for AppExchange later)
3. Under **OAuth Settings**:
   - **Flow Type**: Select **Client Credentials** and/or **Web Server Flow**
   - **Callback URL**: `https://YOUR_MYDOMAIN.my.salesforce.com` (temporary placeholder — you'll update this after creating the Auth Provider in step 2b)
   - **Selected OAuth Scopes**:
     - `Access and manage your data (api)`
     - `Perform requests at any time (refresh_token, offline_access)`
4. Save. Note the **Client ID** (formerly Consumer Key) and **Client Secret** (formerly Consumer Secret).
5. Under **Policies**, set **Permitted Users** to "All users may self-authorize"

### 2b: Create an Auth Provider

1. Go to **Setup > Auth. Providers > New**
2. Select **Salesforce** as the Provider Type
3. Fill in:
   - **Name**: `FlowHealth_Auth`
   - **Consumer Key**: paste the **Client ID** from the External Client App
   - **Consumer Secret**: paste the **Client Secret** from the External Client App
   - **Authorize Endpoint URL**: `https://YOUR_MYDOMAIN.my.salesforce.com/services/oauth2/authorize`
   - **Token Endpoint URL**: `https://YOUR_MYDOMAIN.my.salesforce.com/services/oauth2/token`
   - **Default Scopes**: `api refresh_token`
4. Save. Salesforce will auto-generate a **Callback URL** at the bottom of the page (it will look like `https://YOUR_MYDOMAIN.my.salesforce.com/services/authcallback/FlowHealth_Auth`).
5. **Copy that Callback URL**, go back to the External Client App from step 2a, and update its Callback URL to match exactly.

### 2c: Create the Named Credential

1. Go to **Setup > Named Credentials > New Named Credential**
2. Fill in:
   - **Label**: `FlowHealth SelfOrg`
   - **Name**: `FlowHealth_SelfOrg` (MUST match exactly - this is referenced in Apex)
   - **URL**: `https://YOUR_MYDOMAIN.my.salesforce.com` (your org's My Domain URL)
   - **Identity Type**: Named Principal
   - **Authentication Protocol**: OAuth 2.0
   - **Authentication Provider**: Select `FlowHealth_Auth` (created above)
   - Check **Start Authentication Flow on Save**
3. Save. It will redirect you to authorize — click **Allow**.
4. If successful, the Named Credential status should show "Authenticated".

### 2d: Add Remote Site Setting

1. Go to **Setup > Remote Site Settings > New**
2. Fill in:
   - **Remote Site Name**: `FlowHealth_SelfOrg`
   - **Remote Site URL**: `https://YOUR_MYDOMAIN.my.salesforce.com`
   - Check **Active**
3. Save.

## Step 3: Deploy the Code

```bash
# Deploy to your org
sf project deploy start --source-dir force-app

# Run the tests to verify everything works
sf apex run test --class-names FlowHealthControllerTest --result-format human --wait 5
```

## Step 4: Assign Permission Set

```bash
# Assign the permission set to yourself
sf org assign permset --name Flow_Health_User
```

## Step 5: Add the Tab to Your App

1. Go to **Setup > App Manager**
2. Find your app (or create a new one) and click **Edit**
3. Under **Navigation Items**, add the **Flow Health** tab
4. Save

## Step 6: Test It!

1. Navigate to the **Flow Health** tab
2. You should see the flow selector with all active flows listed
3. Select a flow — it should display:
   - Flow properties (name, type, trigger, API version, run mode)
   - Element breakdown (counts by element type)

## Troubleshooting

### "Unable to load flow list" error
- Check that the Named Credential `FlowHealth_SelfOrg` exists and is authenticated
- Check that the Remote Site Setting is active
- Verify the Permission Set is assigned to your user

### "INVALID_SESSION_ID" error
- This means the Named Credential isn't working. Re-authenticate it:
  Setup > Named Credentials > FlowHealth_SelfOrg > Edit > Start Authentication Flow on Save

### "Session expired or invalid" error
- The OAuth token may have expired. Re-authenticate the Named Credential.

### No flows appearing in the dropdown
- Make sure you have at least one active flow in the org
- Check that your user has the "Manage Flows" permission

## Project Structure

```
FlowHealth/
├── sfdx-project.json
├── .forceignore
├── SETUP_GUIDE.md
└── force-app/main/default/
    ├── classes/
    │   ├── FlowMetadata.cls              # Wrapper classes for Tooling API JSON
    │   ├── FlowMetadataService.cls       # Tooling API callout service
    │   ├── FlowHealthController.cls      # LWC controller (@AuraEnabled methods)
    │   └── FlowHealthControllerTest.cls  # Unit tests with HTTP mocks
    ├── lwc/
    │   ├── flowHealthApp/                # Main container component
    │   │   ├── flowHealthApp.html
    │   │   ├── flowHealthApp.js
    │   │   ├── flowHealthApp.css
    │   │   └── flowHealthApp.js-meta.xml
    │   └── flowSelector/                 # Flow picker dropdown
    │       ├── flowSelector.html
    │       ├── flowSelector.js
    │       └── flowSelector.js-meta.xml
    ├── permissionsets/
    │   └── Flow_Health_User.permissionset-meta.xml
    └── tabs/
        └── Flow_Health.tab-meta.xml
```

## What's Next (Sprint 2)

Once Sprint 1 is working and you can see flow metadata in the UI:
1. Create Custom Metadata Types for health rules
2. Build the FlowRule interface and FlowRuleEngine
3. Implement the first 10 critical rules (DML in loops, missing fault paths, etc.)
4. Build the scoring algorithm
