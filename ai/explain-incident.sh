#!/usr/bin/env bash
# explain-incident.sh : send the curated evidence + system prompt to a Microsoft Foundry model deployment (Entra ID auth).
# No API key: uses `az account get-access-token`. Output is written next to the evidence as ai-explanation.json and
# labelled AI-GENERATED. Endpoint shape and api-version: verification required against current official documentation.
# Env: FOUNDRY_ENDPOINT, FOUNDRY_DEPLOYMENT, EVIDENCE_FILE (path), QUESTION (optional)
set -euo pipefail
: "${FOUNDRY_ENDPOINT:?}"; : "${FOUNDRY_DEPLOYMENT:?}"; : "${EVIDENCE_FILE:?}"
QUESTION="${QUESTION:-What broke in the hybrid estate, which server is affected, where is it hosted, what evidence supports that, and what is the approved next step?}"
here="$(cd "$(dirname "$0")" && pwd)"
token=$(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)
sys=$(cat "$here/system-prompt.md")
evidence=$(jq -c 'del(.ai_explanation, .change_proposal, .approval, .execution, .verification)' "$EVIDENCE_FILE")
payload=$(jq -n --arg s "$sys" --arg q "$QUESTION" --arg e "$evidence" '{messages:[{role:"system",content:$s},{role:"user",content:("EVIDENCE PACKAGE:\n"+$e+"\n\nQUESTION: "+$q)}],temperature:0,response_format:{type:"json_object"}}')
resp=$(curl -fsS "${FOUNDRY_ENDPOINT}/openai/deployments/${FOUNDRY_DEPLOYMENT}/chat/completions?api-version=2024-10-21" \
  -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -d "$payload")
unset token
echo "$resp" | jq -r '.choices[0].message.content' | jq '. + {generated_by:"AI-GENERATED (Microsoft Foundry). Advisory only. Not executed."}' | tee "$(dirname "$EVIDENCE_FILE")/ai-explanation.json"
