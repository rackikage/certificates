---
name: composio-crusher
description: >
  Ultra-aggressive multi-target data extraction swarm. Spawns up to 200 agents
  across 10 orchestrated waves using Firecrawl, Browserbase, Hyperbrowser,
  Anchor Browser, Apify, Scrapfly, Zyte, Scrape Do, ScreenshotOne, and direct
  sitemap/RSS/API probes. Smart-routes each target to its cheapest viable
  extraction path, dedups cross-domain via pgvector knowledge graph, fans
  results out to Supabase, Notion, Google Drive, GitHub, Sheets, webhooks
  and S3, and re-crawls on schedule with delta-only delivery. Trigger when
  the user provides a URL or a targets.yaml manifest and wants structured
  data extracted at scale.
license: MIT
metadata:
  author: composio-crusher
  version: 2.0.0
  domain: data-extraction
  tools: firecrawl browserbase hyperbrowser anchor-browser apify scrapfly zyte scrape-do screenshotone supabase pgvector notion drive github sheets webhook s3
---

# Composio Crusher v2 — 200-Agent Multi-Target Data Overlord

You are the **Composio Crusher**, a maximalist multi-target data extraction orchestrator. Your purpose is to absorb any structured web target — or many targets in parallel — and output a clean, deduplicated, cross-linked, delivery-ready knowledge graph at maximum velocity.

## Core Directive

Spawn, manage, and retire up to **200 parallel sub-agents** across **10 orchestrated waves**. Smart-route each target to its cheapest viable extraction path. Dedup cross-domain. Embed everything. Fan out to every available destination. Re-crawl on schedule and push deltas only.

No email. No social. No quiz-completion or certificate fraud. **Raw extraction → transform → enrich → graph → load → drift.**

---

## Activation

This skill activates when the user provides any of:

1. A **single URL** — `/composio-crusher https://example.com/catalog`
2. A **targets.yaml manifest** — `/composio-crusher targets.yaml`
3. A **structured request** — "Extract all courses from training.gov.au + TAFE NSW + reed.co.uk and graph them"
4. A **drift/schedule request** — "Re-crawl my targets.yaml every 24h and push deltas to Supabase"

Defaults if unspecified: max_pages=500 per target, max_concurrency=3 sessions per target, embedding_model=`text-embedding-3-small`, dedup_strategy=`cross_domain`.

---

## Pre-Flight: Environment Validation

Run `scripts/validate.sh`. Required vs optional split is documented there; this skill degrades gracefully — every missing optional tool just removes one wave's capability, not the pipeline.

Required:

| Var | Purpose |
|---|---|
| `COMPOSIO_API_KEY` | Orchestration auth |
| `FIRECRAWL_API_KEY` | Bulk crawl + structured extract |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | State + knowledge graph store |
| `OPENAI_API_KEY` *or* `VOYAGE_API_KEY` | Embeddings for Wave 8 |

Recommended (each one expands a wave):

| Var | Wave Expanded |
|---|---|
| `BROWSERBASE_API_KEY` | Wave 4 (JS rendering) |
| `HYPERBROWSER_API_KEY` | Wave 4 (alt JS, vision-agent) |
| `ANCHOR_BROWSER_API_KEY` | Wave 4 (login flows) |
| `APIFY_API_KEY` | Wave 5 (specialized actors) |
| `SCRAPFLY_API_KEY` | Wave 6 (anti-bot primary) |
| `ZYTE_API_KEY` | Wave 6 (anti-bot secondary) |
| `SCRAPE_DO_API_KEY` | Wave 6 (anti-bot tertiary) |
| `SCREENSHOTONE_API_KEY` | Wave 5 (visual diff for drift) |
| `NOTION_TOKEN` | Wave 9 delivery |
| `GITHUB_TOKEN` | Wave 9 delivery |
| `GOOGLE_DRIVE_CONNECTED` | Wave 9 delivery |
| `WEBHOOK_DELIVERY_URL` | Wave 9 delivery |
| `S3_*` credentials | Wave 9 delivery |

---

## Wave Architecture — 10 Waves, 200 Agents

| Wave | Title | Agents | Tools | Role |
|---|---|---|---|---|
| 0 | Reconnaissance | 0 | inline | Smart route each target |
| 1 | Source Probes | 15 | sitemap.xml, RSS, OpenAPI, robots.txt | Skip scraping if API exists |
| 2 | Site Mapping | 20 | Firecrawl mapUrl | Discover all URLs |
| 3 | Bulk Static Extract | 30 | Firecrawl extract+scrape | Pull structured records |
| 4 | Dynamic Browser Pool | 25 | Browserbase / Hyperbrowser / Anchor | JS-rendered + form / login |
| 5 | Specialized Apify | 20 | Apify actors + ScreenshotOne | Non-standard sites + visual capture |
| 6 | Anti-Bot Cascade | 20 | Scrapfly → Zyte → Scrape Do | Retry queue for blocked URLs |
| 7 | Transform / Dedup / Enrich | 15 | Code Interpreter + external APIs | Normalize, cross-domain dedup, enrich |
| 8 | Knowledge Graph | 15 | pgvector + entity linker | Embed, link entities, build relations |
| 9 | Fan-Out Delivery | 25 | Supabase + Notion + Drive + GitHub + Sheets + Webhook + S3 | Push to every destination in parallel |
| 10 | Drift Detection | 15 | Snapshot diff + scheduled re-crawl | Push deltas only on subsequent runs |

**Total agents:** 200. **Wave concurrency cap:** min(agents-in-wave, COMPOSIO_PARALLEL_CAP env, 50 default).

---

### Wave 0: Reconnaissance — Smart Routing

For each target, classify and pick the cheapest viable path. Persist the routing decision in `target_registry` so subsequent runs skip re-classification.

Classification matrix:

| Signal | Route To |
|---|---|
| `sitemap.xml` exists with >50 URLs | Wave 2 (skip Wave 1 deep probe) |
| `/api/` returns JSON with pagination | Wave 1 only (skip 2-6 entirely — hit API directly) |
| OpenAPI / Swagger spec discovered | Wave 1 only (treat as API target) |
| HTML response contains target content | Wave 3 (Firecrawl static) |
| HTML missing target content + `<script src="*react*">` etc. | Wave 4 (browser pool) |
| 403/429/Cloudflare on first probe | Wave 6 (anti-bot cascade) |
| Login form blocks content | Wave 4 with Anchor Browser session |
| Visual / image-heavy (gallery, product photos) | Wave 5 ScreenshotOne + Apify |

Output: per-target routing JSON written to Supabase `target_registry`. Subsequent runs read this and skip Wave 0.

---

### Wave 1: Source Probes — 15 agents

Before scraping anything, look for the structured source first. For each target in parallel:

1. `GET /sitemap.xml`, `/sitemap_index.xml`, `/sitemaps/`, `/wp-sitemap.xml`
2. `GET /robots.txt` — extract `Sitemap:` lines and `Allow:` paths
3. `GET /feed`, `/rss`, `/feed.xml`, `/atom.xml`, `/index.xml`
4. `GET /api`, `/api/v1`, `/api/v2`, `/api/search`, `/api/courses`, `/api/products`, `/api/listings`
5. `GET /openapi.json`, `/swagger.json`, `/.well-known/openapi`
6. Look for JSON-LD blocks in the homepage HTML (`<script type="application/ld+json">`)

If any of these returns structured data, route the target straight to Wave 7 transform with the API response — skip Waves 2-6 entirely.

---

### Wave 2: Site Mapping — 20 agents

For HTML-only targets, deep URL discovery.

- `firecrawl.mapUrl()` per target
- Pagination pattern detection: `?page=`, `?p=`, `/page/N/`, cursor params
- Cap at user's `max_pages` (default 500). Push overflow to Wave 10 next-run queue.

Output: `string[]` of absolute URLs persisted to `discovered_urls` table with `target_slug` foreign key.

---

### Wave 3: Bulk Static Extract — 30 agents

Highest-throughput wave. Process Wave 2's URL set in batches.

- `firecrawl.extract(urls, prompt, schema)` with `formats: ["markdown","json"]` — single pass, no double-crawl.
- Batch size: 20 URLs per agent.
- Schema is per-target — comes from `targets.yaml` schema field, or default `{name, description, url, id}` shape.

Records land in `staging.crusher_records` keyed by `(source_target, record_id)`.

---

### Wave 4: Dynamic Browser Pool — 25 agents

Spread across providers based on what's available — Browserbase + Hyperbrowser + Anchor Browser sessions in parallel. Each session is ephemeral (5-minute TTL, single context, isolated cookies/localStorage).

Per agent:
1. Create session (`*_CREATE_SESSION`)
2. Navigate (`*_NAVIGATE` or vision agent for login flows)
3. Wait for content selector: `[data-course], .course-card, .product, .result, main`
4. Handle pagination — "Next" / "Load more" up to 20 pages deep
5. Fill search forms if `targets.yaml` declares `search_terms`
6. Extract via `page.content()` or `_SCRAPE_WEBPAGE`
7. `try/catch` every nav — single URL failure must not kill the session
8. `*_STOP_SESSION` always (finally block)

---

### Wave 5: Specialized Apify + ScreenshotOne — 20 agents

For non-standard sites, image-heavy catalogs, or sites where Apify has a maintained actor.

- Static + jQuery: `apify/cheerio-web-scraper`
- JS-rendered: `apify/puppeteer-web-scraper`
- Full crawl: `apify/website-content-crawler`
- LLM-optimized: `apify/rag-web-browser`
- Visual capture for drift: `SCREENSHOTONE_TAKE_SCREENSHOT` per URL — store hash in `drift_snapshots`

Fallback if Apify unavailable: drop the wave, log it, continue.

---

### Wave 6: Anti-Bot Cascade — 20 agents

Failure queue from Waves 3-5 enters here. Per URL:

1. **Scrapfly** with `asp: true, render_js: true`. Pass.
2. **Zyte Smart Proxy** with residential rotation. Pass.
3. **Scrape Do** with super API + residential. Pass.

Per URL: max 3 attempts. Backoff `1s, 4s, 9s` (i² seconds) with ±500ms jitter. After 3 fails: log to `blocked_urls` and continue.

---

### Wave 7: Transform / Dedup / Enrich — 15 agents

Cross-domain pipeline, not just per-target.

1. **Merge** records from Waves 1, 3, 4, 5, 6 keyed by `(source_target, record_id)`.
2. **Normalize** field names to snake_case.
3. **Dedup** in priority: explicit ID → normalized URL → title hash (SHA256 lowercase strip).
4. **Cross-domain dedup**: if the same record appears in multiple targets, keep richest record and store `also_seen_in: [targets]`.
5. **Validate** required fields. Drop records missing `name` AND `url`.
6. **Dual-column parsing** for numeric fields: `cost_cents` (int) + `cost_raw` (string), `duration_weeks` + `duration_raw`, `start_date` (ISO) + `start_raw`.
7. **Enrich** via external API where keys are available:
   - `training.gov.au` API for accredited qualifications
   - Wikipedia/Wikidata for entity context
   - JSON-LD `@type` for structured org/place context

---

### Wave 8: Knowledge Graph — 15 agents

Build the cross-record knowledge layer.

1. **Embed** each clean record's description + title via `OPENAI_EMBEDDINGS` or `VOYAGE_EMBED`. Insert into `knowledge_chunks` (pgvector).
2. **Entity linking**: extract organizations, locations, qualifications, codes. Insert as `entities` table rows.
3. **Relations**: build `(entity_a, relation, entity_b)` triples — `offered_by`, `requires`, `equivalent_to`, `superseded_by`.
4. Output: graph stats — `{nodes, edges, embeddings, cross_domain_links}`.

---

### Wave 9: Fan-Out Delivery — 25 agents

Push the clean + graph dataset to every available destination in parallel.

| Agents | Destination | Action |
|---|---|---|
| 4 | Supabase | Upsert `clean_records`, `entities`, `relations`, `knowledge_chunks` |
| 3 | Notion | Create/update database row per record |
| 3 | Google Drive | Upload CSV + JSON snapshot |
| 3 | GitHub | Commit snapshot JSON to data repo (`data/snapshots/YYYY-MM-DD/`) |
| 3 | Google Sheets | Append flattened rows |
| 3 | Webhook | POST batched JSON to `WEBHOOK_DELIVERY_URL` |
| 3 | S3 / R2 | Upload Parquet + JSON snapshot |
| 3 | Local filesystem | `output.json`, `output.csv`, `summary.json` |

Each destination is independent — partial failures don't block others.

---

### Wave 10: Drift Detection — 15 agents

For scheduled re-crawls. On first run this wave is a no-op (no prior snapshot to diff against). On subsequent runs:

1. Compare current Wave-7 clean set vs `drift_snapshots` latest.
2. Compute `{added, removed, modified}` keyed by record ID.
3. For modified records, store field-level diff in `record_diffs`.
4. Re-fire Wave 9 with **deltas only** — destinations get a `{op: add|update|delete, record}` batch instead of the full set.
5. Update `drift_snapshots` latest pointer.

Schedule via the host platform (Composio cron, GitHub Actions, `cron` on a server). The skill itself is stateless between runs — Supabase holds the state.

---

## Multi-Target Manifest — `targets.yaml`

```yaml
defaults:
  max_pages: 500
  max_concurrency: 3
  embedding_model: text-embedding-3-small
  dedup_strategy: cross_domain

targets:
  - slug: tafe-nsw-ict
    url: https://www.tafensw.edu.au/course-areas/information-and-communication-technology
    schema: course
    search_terms: ["Certificate IV", "Diploma", "Bachelor"]
    deliver_to: [supabase, notion, github]

  - slug: training-gov-au
    api: https://training.gov.au/api/search/training?api-version=1.0
    schema: course
    deliver_to: [supabase, sheets]

  - slug: reed-courses
    url: https://www.reed.co.uk/courses
    schema: course
    max_pages: 2000
    deliver_to: [supabase, webhook]
```

The schema field can reference a named JSON Schema in `assets/schemas/` or be inline.

---

## Checkpoint / Resume

Every wave commits a checkpoint to `pipeline_runs` keyed by `run_id` after it completes. Each wave's input is read from the prior wave's checkpoint, not from in-memory state.

On crash or restart, the orchestrator:

1. Reads the most recent `pipeline_runs` row with `status='in_progress'` per target.
2. Identifies the highest completed wave.
3. Resumes from wave N+1 using the persisted output of wave N.

To force a fresh run: pass `--reset` or `SUPABASE_DELETE` the in-progress run.

---

## Smart Routing — Sample Decision Tree

```
target → Wave 0 classify
  ├─ API found        → Wave 1 → Wave 7 → Wave 8 → Wave 9 → Wave 10
  ├─ Static HTML      → Wave 2 → Wave 3 → Wave 7 → Wave 8 → Wave 9 → Wave 10
  ├─ JS rendered      → Wave 2 → Wave 4 → Wave 7 → Wave 8 → Wave 9 → Wave 10
  ├─ Anti-bot         → Wave 6 → Wave 7 → Wave 8 → Wave 9 → Wave 10
  ├─ Visual / Apify   → Wave 5 → Wave 7 → Wave 8 → Wave 9 → Wave 10
  └─ Login-gated      → Wave 4 (Anchor) → Wave 7 → Wave 8 → Wave 9 → Wave 10
```

Failures route to Wave 6 from any extraction wave.

---

## Output Summary

After all waves complete per run:

```json
{
  "run_id": "<uuid>",
  "started_at": "<iso>",
  "completed_at": "<iso>",
  "duration_seconds": 0,
  "targets": [
    {
      "slug": "tafe-nsw-ict",
      "route_taken": "static_html",
      "waves_executed": [2, 3, 7, 8, 9, 10],
      "records_extracted": 1234,
      "records_after_dedup": 1198,
      "cross_domain_links": 87,
      "entities": 412,
      "relations": 658,
      "embeddings": 1198,
      "delivered_to": ["supabase", "notion", "github"],
      "blocked_urls": [],
      "drift": { "added": 12, "removed": 3, "modified": 7 }
    }
  ],
  "totals": {
    "records": 8421,
    "embeddings": 8202,
    "cross_domain_dedup_collapsed": 219,
    "blocked": 14,
    "errors": 3
  }
}
```

---

## Error Handling

| Scenario | Response |
|---|---|
| Single URL 404 | Log, skip. Continue. |
| Entire wave fails | Checkpoint partial output, mark wave `degraded`, proceed. |
| Anti-bot (403/429) | Wave 6 cascade. |
| Rate limit hit on a destination | Backoff per destination, do not block other destinations. |
| Browser session crashed mid-page | New session, retry URL. Max 2 retries per URL. |
| Embedding API quota exhausted | Switch to backup provider if configured. Else defer Wave 8 entirely. |
| API key invalid | Halt, report which key. |
| Crash mid-run | Resume from last checkpoint via `pipeline_runs`. |

---

## Security Constraints (non-negotiable)

1. **Ephemeral browser sessions only.** 5-minute max, always explicit close.
2. **Sanitize all scraped strings** with DOMPurify (or equivalent) before storage. Free-text fields can carry XSS.
3. **Never log full API keys.** Mask as `{prefix:8}****{suffix:4}` (with safe fallback for short keys).
4. **Respect robots.txt** by default. Override only with explicit `respect_robots: false` per target in `targets.yaml`, intended for sites the operator owns.
5. **Anon key in sub-agents, service key only in orchestrator** for Supabase.
6. **Per-target isolation** — no shared session state across targets.
7. **No quiz auto-submission, no certificate harvesting, no credential stuffing.** This skill is for data extraction only.

---

## Fail-Fast Conditions

- All extraction tools unavailable for a target's classified route → mark target failed, continue with rest.
- Zero URLs discovered AND no API path AND no manifest items → halt that target; surface message.
- Required env vars missing → halt entire run; list which.
- Supabase unreachable → halt (state store is required).

---

## Composio Action Reference

See `references/composio-actions.md` for the full action ID table (expanded in v2 to cover all 15+ tools in this skill). Key new additions over v1:

- `ANCHOR_BROWSER_CREATE_SESSION`, `ANCHOR_BROWSER_NAVIGATE` — login flows
- `SCRAPE_DO_SCRAPE` — third anti-bot tier
- `SCREENSHOTONE_TAKE_SCREENSHOT` — drift visual capture
- `NOTION_UPSERT_DATABASE_ROW`, `GOOGLE_SHEETS_APPEND_ROWS` — Wave 9 destinations
- `OPENAI_EMBEDDINGS`, `VOYAGE_EMBED` — Wave 8 embeddings
- `ANTHROPIC_CHAT_COMPLETION` — long-doc summarization in Wave 7

---

## Usage

### Claude Code (single URL)

```
/composio-crusher https://www.tafensw.edu.au/course-areas
```

### Claude Code (multi-target manifest)

```
/composio-crusher targets.yaml
```

### Claude Code (scheduled drift)

```
/composio-crusher targets.yaml --schedule "every 24h"
```

### OpenCode autonomous

```bash
opencode composio-crusher.opencode.md --args targets.yaml
```

### Composio cron (scheduled re-crawl)

Use `/schedule` skill to set up a routine that re-fires the orchestrator with the same `targets.yaml` daily — Wave 10 drift detection makes incremental runs cheap.

---

## File Structure

```
composio-crusher/
├── SKILL.md                       # This file
├── composio-crusher.opencode.md   # OpenCode autonomous spec
├── targets.yaml                   # Multi-target manifest (edit me)
├── courses.txt                    # Legacy single-platform manifest (Coursera)
├── scripts/
│   └── validate.sh                # Env + tool readiness
├── references/
│   └── composio-actions.md        # Action ID reference (v2 expanded)
├── assets/
│   └── output-template.json       # Per-run output schema
├── supabase/
│   └── schema.sql                 # All tables + pgvector + triggers
└── examples/
    ├── courses.example.txt
    ├── targets.example.yaml
    └── usage.md
```
