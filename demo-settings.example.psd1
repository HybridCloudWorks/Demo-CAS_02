# Copy to demo-settings.psd1 (git-ignored). Placeholders only. Never commit real values.
# Read by Setup-ApprovalGate.ps1 and Cleanup-Demo.ps1; parameters passed on the command line override these.
# Deploy-Demo.ps1 needs no settings (it applies the saved plans in terraform/<stack>/tfplan).
@{
    # ---- GitHub ----
    Repo           = '<GITHUB_OWNER>/<REPO_NAME>'   # your fork, e.g. octocat/Demo-CAS_02
    Reviewer       = '<GITHUB_REVIEWER_LOGIN>'      # approves remediation runs; must NOT be the account that dispatches
    Environment    = 'remediation-approval'

    # ---- Azure (identity: az login; no secrets) ----
    TenantId       = '<AZURE_TENANT_ID>'
    SubscriptionId = '<AZURE_SUBSCRIPTION_ID>'
    ResourceGroup  = 'rg-arc-hybrid-demo'
    Location       = '<AZURE_LOCATION>'
    AppName        = 'gh-oidc-demo-cas02-remediation'

    # ---- AWS / Google Cloud ----
    AwsRegion      = '<AWS_REGION>'
    GcpProject     = '<GCP_PROJECT_ID>'
}
