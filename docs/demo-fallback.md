# Backup demonstration — "Hybrid Estate Briefing" (read-only)

Open `backup/` — it contains everything needed with **zero live dependencies**:

| File | Shows |
|---|---|
| `backup/01-inventory.json` | Captured Resource Graph inventory: 2 demo machines, Connected, CloudOrigin AWS / GCP |
| `backup/02-health-before.json` | Captured health query: arc-aws-demo unhealthy, arc-gcp-demo healthy |
| `backup/03-policy.json` | Captured policy compliance |
| `backup/04-extensions.json` | Captured extension inventory (AMA on all three) |
| `evidence/sanitized-example.json` | The full sanitized incident package |
| `backup/05-ai-explanation.md` | Pre-generated, labelled AI explanation and change proposal |
| `backup/06-approval-record.md` | Captured approval record (reviewer redacted) |
| `backup/07-health-after.json` | Captured verification: arc-aws-demo healthy |
| `backup/08-remediation-transcript.txt` | Captured console output of `remediate.sh` on arc-aws-demo (90-second clip optional) |

Same narrative, same order: **Detect → Explain → Approve → Remediate → Verify → Document.** Narrate each file; nothing is executed, nothing is rebuilt.

## Switch criteria (switch immediately, do not debug on stage)
Hyper-V VM fails to start · Hyper-V networking fails · Arc connection unavailable · AWS auth fails · GCP auth fails · Azure auth fails · `terraform apply` fails · quota blocks deployment · a required cloud API is unavailable · model endpoint fails · approval workflow fails · network instability · unexpected billing or security exposure · main path exceeds its time box (demo must start by 0:75 and finish by 1:45).

## Switch procedure (< 60 seconds)
1. Say: "I'm switching to the captured briefing so we keep the full lifecycle."
2. Open `backup/` in the editor; open `evidence/sanitized-example.json` and the slide "Backup demonstration".
3. Walk the eight files in order; end on the verification diff and the incident record.

What the backup still proves: AWS stays in AWS, GCP stays in GCP, a private server would join the same way, Arc provides the shared Azure relationship, AI proposes but does not execute, a human approves, a deterministic runbook remediates, the same query verifies.
