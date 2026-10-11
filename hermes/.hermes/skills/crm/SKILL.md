---
name: crm
description: "Use when editing ~/src/crm, after asking product choices."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [crm, react, fastapi]
    related_skills: []
---

# Personal CRM (`~/src/crm`)

Hugo and Maxence's prospecting CRM. Not a site in `frontend-site-changes` — do not run that skill's Vercel/Hetzner deploy loop.

## When to Use

- Any edit under `~/src/crm`: batches, contacts, accounts, work queue, workspace switch.
- The user says to go into the CRM and change how a page works.

## Procedure

1. **Ask the product choices before editing** when the request leaves open who is listed, whether a prior batch blocks adding, or how a multi-select commits. The user wants those questions first. Do not ask about styling defaults you can copy from the page.
2. **Read the page and the matching API before adding an endpoint.** The contact list already returns `batch_summaries` (batch id, name, start date, state, next action). Reuse that. The list `q` param matches first name, last name, company, and email — not account name. A name/company search on a picker must filter the full list client-side, or account-name matches disappear.
3. **Match the page.** Amber primary buttons, `input` / `buttonPrimary` from `frontend/src/components/ui.tsx`, dense Tailwind like the surrounding file. Extract filter, sort, and label logic into a small module next to the page and cover it with vitest. There is no component test runner.
4. **Batch add stays the existing member API.** Checkboxes on the batch page, one Add selected, each person added as `active` with `DEFAULT_ACTION_TYPES`. Multiple people from the same account may be active in a batch; do not add an account-conflict 409 or confirmation retry. A different add error stops; people already added stay added and leave the selection. People already in this batch are checked and disabled. People in any other batch show `Already in {batch name}` and remain selectable. A prior-decline warning is informational, not a block.
5. **Verify.** Frontend: `cd frontend && npm test && npm run lint && npm run build`. Backend, only if you touched it: `cd backend && uv run pytest`. Pre-existing oxlint fast-refresh warnings in `components/ui.tsx` are not yours.
6. **Stop at a local verify unless the user asks to ship.** The tree often has unrelated dirty files. For a merge, make a clean worktree from `main` under the scratch directory, apply only this feature’s hunks (including narrow edits to shared files), and run frontend/backend tests there before committing explicit paths. Keep the original dirty tree intact. Do not `git add -A`.
7. **Deploy the merged change with the server’s actual layout.** First inspect `/opt/crm`: production may be a file copy without `.git`, so `git pull` is not a deploy step there. Push the scoped commit to GitHub, then transfer only changed source files or apply a narrow patch to existing server files; do not replace shared API/backend files with clean-worktree copies if the server has other uncommitted workspace features. Build/recreate the affected Compose services using `docker-compose.yml` plus `docker-compose.vps.yml` (the caddy target can also rebuild/recreate API through dependencies). Never `docker compose down -v`. Read back the served JS bundle for the new marker, API health, service status, and data counts before reporting it live.

## Pitfalls

1. **Do not treat a Vite app as `frontend-site-changes`.** That skill's live check greps a Vercel bundle. This CRM is docker compose on a VPS; following that loop reports the wrong host and can ship unrelated dirty files.
2. **Do not hide prior-batch contacts or block adding them.** The label is informational. Hiding them, or turning the label into a confirm, reverses the chosen picker.
3. **Do not reintroduce an account-conflict confirmation.** Activating multiple people at one company in a batch is intentional. Preserve the separate do-not-contact guard and other genuine error handling.
4. **A negative reply is not a company-wide rejection.** `POST /contacts/{id}/reply` with negative sentiment stamps `BatchMember.declined_at` for active memberships and drops them; expose that timestamp in `ContactBatchSummary` for the picker. Group by `account_id` among owner-scoped contacts, but label the specific person and batch (“Previous decline at this company: Name (Batch)”), not “Company declined.” Require the source batch’s `start_date` to precede the current batch’s start date: excluding only the current batch falsely marks a later-starting batch as previous. A generic `dropped` state or `status=lost` is not proof of a negative reply.
5. **New plan-action types need a PostgreSQL check-constraint migration.** `plan_actions.ck_plan_actions_type` enumerates action strings, so updating frontend options, API Literal types, metadata, and `OUTREACH_TYPES` alone passes SQLite tests but fails on PostgreSQL. Exercise Alembic against an isolated local Postgres database and add active members via the real API. Owner revision `f8c2a91d4e70` is now tracked in Git; later migrations must descend from it. Before production migration, take a `pg_dump -Fc` backup, restore it to a disposable database, and compare row counts. Deploy migration before new API/UI. Once new-type actions exist, old code/downgrade is not a safe rollback; prefer a forward fix and never delete plan actions silently.
6. **Avoid macOS AppleDouble sidecars in production tar transfers.** BSD tar on macOS can add `._*.py` entries containing NUL bytes; Alembic scans `versions/*.py` and fails before migrating. Set `COPYFILE_DISABLE=1` when creating the archive, inspect the destination for sidecars, remove only the generated files if needed, then rebuild the affected image; simply removing source sidecars after an image build leaves them embedded in that image.
7. **Distinguish a batch's week number from its database ID.** A request for “batch 3” can mean the batch named `week3 - audits`, not `/batches/3`. List names, IDs, member counts, owners, and states before any bulk write; match the user's described count, then guard the exact target in the update script and read it back afterward.
8. **Removing someone from a batch must not remove their contact or other memberships.** Use the owner-scoped `DELETE /api/batch-members/{id}`; it cascades only that membership's plan actions. Confirm the action in the UI, invalidate both batch and contact queries, and test that another batch's membership and queued work remain.
