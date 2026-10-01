# Cost management

**Prices, availability and free-tier eligibility vary by region, account age and date. Verify before the session.**

| Item | Low-cost choice | How to check current price |
|---|---|---|
| AWS EC2 | `t3.micro` (x86-64). AWS Free Tier is credit-based for accounts created after 15 July 2025 ($100 at sign-up, up to $100 more for activities, 6 months). | AWS Pricing Calculator; `aws pricing get-products --service-code AmazonEC2 --region us-east-1 --filters Type=TERM_MATCH,Field=instanceType,Value=t3.micro ...` (CLI syntax: verification required) |
| GCP Compute Engine | `e2-micro`: 1 instance/month free only in us-west1, us-central1, us-east1 with 30 GB standard PD. `e2-small` is not free. | Google Cloud Pricing Calculator; `gcloud compute machine-types describe e2-micro --zone <GCP_ZONE>` for specs |
| Azure Arc control plane | Free: inventory, tags, Resource Graph, RBAC, Run Command/Custom Script Extension | Arc pricing page |
| Azure Machine Configuration on Arc | **$6 per Arc server per month**, pro-rated hourly; off/disconnected hours not billed. Three servers for one day ≈ $0.60 | Azure Policy pricing page |
| Log Analytics | Pay-per-GB ingestion; the heartbeat is ~1 line/min/machine (negligible, well under free 5 GB/month allowance where applicable) | Azure Monitor pricing |
| Microsoft Foundry model calls | Tokens per request; ~20 evaluation prompts + demo ≈ a few hundred thousand tokens | Foundry model pricing page |
| Hyper-V | Local electricity only | — |

## Rough estimation method
`hours_running × hourly_rate + storage_GB × monthly_rate × days/30 + Arc MC servers × $6 × days/30 + log GB × ingest rate`. For a 2-day rehearsal + event window with t3.micro, e2-micro, 36 GB of disks and Machine Configuration on three servers, expect low single-digit USD. Do not quote a fixed price to attendees.

## Controls
- **Budget alerts:** AWS Budgets (`aws budgets create-budget`), GCP billing budget (`gcloud billing budgets create`), Azure Cost Management budget scoped to the RG — all at a $10 threshold with email action. (CLI syntax: verification required.)
- **Expiration tag/label** on everything: `ExpirationDate=<EXPIRATION_DATE>` / `expirationdate=<yyyy-mm-dd>`.
- **Short-lived lab:** build the morning of the rehearsal; destroy the same evening; rebuild for the event.
- **Automatic shutdown:** AWS/GCP instance schedules (optional); the simplest control is `Remove-AllDemoResources.ps1` immediately after the session.
- **Destroy-and-verify checklist:** docs/cleanup.md step 8 plus the verification block in `Remove-AllDemoResources.ps1`.
