# Blocklist Fork — Project Context & Reference

This file captures the logic, nuances, and decisions for this fork of `ph00lt0/blocklist`. Attach it to new conversations so they start with full understanding.

## What This Project Is

A fork of [ph00lt0/blocklist](https://github.com/ph00lt0/blocklist) that adds personal customizations on top of the upstream domain blocklist. The upstream list blocks ~22,000+ tracker, analytics, ad, and data broker domains. This fork:

- Syncs upstream weekly via GitHub Actions (`.github/workflows/sync-upstream.yml`)
- Runs `apply-exclusions.sh` after every sync to apply fork-specific changes
- Publishes blocklists in 8 formats for different tools

## Repository Layout

| File | Purpose |
|---|---|
| `apply-exclusions.sh` | Main script — 6 stages, run after every upstream sync |
| `my-exclusions.txt` | Parent domains to fully unblock (parent + subdomains removed) |
| `my-inclusions.txt` | Exact domains to unblock (any domain, including subdomains — only that exact entry is removed) |
| `my-additions.txt` | Domains to force-add to all blocklist formats |
| `little-snitch-blocklist.lsrules` | JSON blocklist for Little Snitch (primary use case) |
| `blocklist.txt` | AdBlock Plus format (`\|\|domain^`) |
| `domains.txt` | Plain domain list |
| `wildcard-blocklist.txt` | Wildcard format (`*.domain`) |
| `unbound-blocklist.txt` | Unbound DNS format |
| `rpz-blocklist.txt` | RPZ format (`domain CNAME .`) |
| `pihole-blocklist.txt` | Pi-hole format (`0.0.0.0 domain`) |
| `hosts-blocklist.txt` | Hosts file format (`0.0.0.0 domain`) |

## The 6 Stages of `apply-exclusions.sh`

Run in order. Each stage depends on the previous ones.

1. **Restore fork HTML files** — Overwrites `install.html` and `little-snitch-install.html` with fork-specific URLs (upstream sync replaces these)
2. **Fix README URLs** — sed-replaces upstream GitHub URLs with fork URLs in README.md
3. **Fix Little Snitch metadata** — Updates `name` and `description` in `.lsrules` JSON to point to this fork
4. **Apply exclusions** (`my-exclusions.txt`) — Removes matching entries from all 8 blocklist formats
5. **Apply inclusions** (`my-inclusions.txt`) — Removes exact bare domain entries from all 8 formats
6. **Apply additions** (`my-additions.txt`) — Adds domains to all 8 formats if not already present, then re-sorts text files

## Critical: Exclusion vs Inclusion Behavior

These two mechanisms look similar but work very differently.

### Exclusions (Stage 4) — Broad removal

**Purpose:** Remove a parent domain so that its subdomains can be selectively allowed.

**Mechanism per format:**

| Format | sed pattern | Catches subdomains? |
|---|---|---|
| `blocklist.txt` | `/\|\|DOMAIN^/d` (unanchored) | NO — `\|\|sub.DOMAIN^` does not contain `\|\|DOMAIN^` |
| `wildcard-blocklist.txt` | `/\*\.DOMAIN/d` (unanchored) | NO — `*.sub.DOMAIN` does not contain `*.DOMAIN` |
| `domains.txt` | `/^DOMAIN$/d` (anchored) | NO |
| `pihole-blocklist.txt` | `/^0\.0\.0\.0 DOMAIN$/d` (anchored) | NO |
| `hosts-blocklist.txt` | `/^0\.0\.0\.0 DOMAIN$/d` (anchored) | NO |
| `unbound-blocklist.txt` | `/local-zone: "DOMAIN\." always_null/d` (unanchored) | NO |
| `rpz-blocklist.txt` | `/^DOMAIN CNAME \./d` (anchored) | NO |
| `lsrules` | Python `d != domain` exact match | NO |

**Key insight:** Despite being called "exclusions," the sed patterns actually only remove exact parent entries, NOT subdomain entries. Subdomains from upstream survive exclusion. This is fine for our purpose — we only need the parent domain gone.

**Why removing the parent matters (Little Snitch):** Little Snitch uses **suffix matching** on its `denied-remote-domains` list. If `alicdn.com` is in the list, LS blocks ALL `*.alicdn.com` subdomains automatically. Other blocklist consumers may behave differently, but for the `wildcard-blocklist.txt` format, `*.alicdn.com` achieves the same effect and IS removed by the exclusion pattern.

### Inclusions (Stage 5) — Surgical exact-domain removal

**Purpose:** Unblock a specific exact domain — whether it's a parent domain or a subdomain. Only that exact entry is removed; nothing else is touched.

**Mechanism:** All sed patterns are fully anchored (`^...$`). Only the exact domain string is removed. Other entries (parent, sibling subdomains, child subdomains, wildcards) are untouched.

**Use cases:**

- Unblock a parent domain while keeping its subdomains blocked (e.g., `sentry.io` — the main site is accessible, but `sub.sentry.io` stays blocked)
- Unblock an upstream subdomain that survived a parent exclusion (e.g., `g.alicdn.com` is in upstream as its own entry — excluding the parent `alicdn.com` only removes the parent, not this subdomain entry)

**Common pitfall:** If a subdomain like `g.alicdn.com` exists as its own entry in the upstream blocklist, excluding the parent `alicdn.com` does NOT remove it. The exclusion only removes the exact parent entry. To unblock such a subdomain, you must add it to `my-inclusions.txt`. Simply removing it from `my-additions.txt` is not enough if upstream has its own entry for it.

### Additions (Stage 6) — Force-add domains

**Purpose:** Ensure specific domains are blocked regardless of upstream changes.

**Use cases:**

- Re-block tracker subdomains after their parent was excluded (e.g., `aplus.aliexpress.com` after excluding `aliexpress.com`)
- Block domains not in upstream (e.g., `bat.bing.com`)
- Pin upstream domains so they stay blocked even if upstream removes them

**Mechanism:** `grep -qxF` checks for exact duplicates before appending. Text files are re-sorted with `sort -uf` after all additions. The lsrules JSON array is appended to (no sorting — JSON arrays are order-independent for LS).

## When to Use Which Mechanism

| Scenario | Mechanism | File |
|---|---|---|
| Need to access `www.example.com` but `example.com` is in upstream blocklist | Exclude `example.com`, then add back tracker subdomains you want blocked | `my-exclusions.txt` + `my-additions.txt` |
| Need to access `example.com` itself but want `tracker.example.com` blocked | Include `example.com` | `my-inclusions.txt` |
| Need to unblock a subdomain that exists as its own entry in upstream (e.g., `g.alicdn.com` after parent `alicdn.com` was excluded) | Include the subdomain | `my-inclusions.txt` |
| Previously added a subdomain to `my-additions.txt` but now need it unblocked | Remove from `my-additions.txt` AND check if upstream has its own entry — if so, also include it | `my-additions.txt` + `my-inclusions.txt` |
| Want to block a domain not in upstream | Add it | `my-additions.txt` |
| Want to ensure a domain stays blocked even if upstream drops it | Add it | `my-additions.txt` |

## The AliExpress Case Study

**Problem:** User needs to browse AliExpress. The upstream list contains `aliexpress.com` and `alicdn.com` as parent domains. In Little Snitch, these parent entries block ALL subdomains via suffix matching — including `www.aliexpress.com` (the actual site).

**Solution:**

1. **Excluded** parent domains: `aliexpress.com`, `alicdn.com`, `aliexpress-media.com`
   - This removes the parent entries from lsrules (stopping LS suffix matching) and from `wildcard-blocklist.txt` (removing `*.alicdn.com` etc.)
   - Subdomain entries in other formats survive because the sed patterns don't catch them

2. **Added** tracker subdomains to `my-additions.txt`:
   - `aplus.aliexpress.com`, `assets.alicdn.com`, etc. — these are trackers under the excluded parents
   - `afp.alicdn.com`, `at.alicdn.com`, etc. — upstream subdomains that should stay blocked (belt-and-suspenders)

3. **Included** `g.alicdn.com` in `my-inclusions.txt`:
   - `g.alicdn.com` exists as its own entry in the upstream blocklist. Excluding the parent `alicdn.com` did NOT remove it. It was initially added to `my-additions.txt` as a tracker, but later needed to be unblocked (for qwen.ai). Removing it from `my-additions.txt` alone was insufficient — the upstream entry still blocked it. Adding it to `my-inclusions.txt` surgically removes the upstream entry.

4. **Result:** Functional subdomains are allowed (`www.aliexpress.com`, `acs.aliexpress.com`, `ae01.alicdn.com`, `img.alicdn.com`, `g.alicdn.com`, `assets.aliexpress-media.com`, `ae-pic-a1.aliexpress-media.com`) while all tracker subdomains remain blocked.

**Note:** `aliexpress.ru` is a separate TLD (not a subdomain of `aliexpress.com`), so excluding `aliexpress.com` doesn't affect it. It's in both upstream and `my-additions.txt`.

## Upstream Sync Workflow

1. GitHub Actions runs weekly (Monday 6am UTC) or on manual trigger
2. Checks out fork, fetches upstream, merges `upstream/master`
3. Runs `apply-exclusions.sh` (all 6 stages)
4. Commits and pushes if anything changed

**Merge strategy:** `git config merge.ours.driver true` — fork-specific files use "ours" strategy to prevent upstream from overwriting them.

**Files protected from upstream overwrites:**

- `my-exclusions.txt`, `my-inclusions.txt`, `my-additions.txt` — not in upstream, so no conflict
- `apply-exclusions.sh` — fork-only file
- `install.html`, `little-snitch-install.html` — regenerated by Stage 1
- `README.md` — URLs fixed by Stage 2

## Environment Notes

- `python3` is available inside bash scripts (used by `apply-exclusions.sh` for JSON manipulation)
- Direct CLI use requires `uv run python3` instead of `python3` (enforced by system shim)
- The `.lsrules` file is JSON with `indent=4` formatting
- Git remote `origin` = `CaptainCodeAU/littlesnitch_blocklist.git`, `upstream` = `ph00lt0/blocklist.git`

## Adding a New Site (Checklist)

When a blocked site needs to be accessible:

1. Identify which parent domain(s) in the upstream blocklist are causing the block
2. Test in Little Snitch — parent domain suffix matching is usually the culprit
3. Add the parent domain(s) to `my-exclusions.txt`
4. Identify all subdomains of those parents that should remain blocked (trackers, analytics)
5. Add those subdomains to `my-additions.txt`
6. **Check for upstream subdomain entries** that need to be unblocked — excluding a parent does NOT remove subdomain entries that exist independently in the upstream list. Add any such subdomains to `my-inclusions.txt`
7. Run `apply-exclusions.sh`
8. **Verify in the lsrules file** (not just in `my-additions.txt`): allowed subdomains must NOT appear in any blocklist, tracker subdomains ARE in all blocklists, lsrules JSON is valid

## Unblocking a Previously Blocked Domain (Checklist)

When a domain needs to be unblocked (e.g., it was in `my-additions.txt` or exists in upstream):

1. Remove it from `my-additions.txt` if present
2. **Check if the domain exists in the upstream blocklist** — search the lsrules or domains.txt file. If it does, removing from `my-additions.txt` alone is NOT enough
3. If it exists in upstream, add it to `my-inclusions.txt` to surgically remove the upstream entry
4. Run `apply-exclusions.sh`
5. **Verify in the lsrules file** that the domain is actually gone — don't assume removal from `my-additions.txt` is sufficient
