---
description: Sync epics and stories from the repo to Lark Base via the Avila Tools API
---

Invoke the planning-6-write-epics-and-hu-in-base skill.

Before doing anything, collect the three required inputs if not already provided:
1. Epic IDs to sync (e.g. `E-002 E-003`)
2. API Key (Bearer token — `sk-xxxx...`)
3. Base ID (target Lark Base identifier)

Do not proceed until all three are confirmed.

Then:
1. Locate the epic folders in the repo for each provided ID
2. Parse epic.md and all story .md files inside stories/
3. Translate content fields (name, description, acceptanceCriteria, questions) to Spanish
4. Build the JSON payload and show a summary preview to the user
5. Wait for user confirmation before sending
6. POST to the Avila Tools API endpoint
7. Report results clearly — success, failures, or warnings for missing folders

Never clone the repository. Never invent field values. Always confirm before the POST.
