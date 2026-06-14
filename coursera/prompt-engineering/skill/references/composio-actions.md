# Composio Action Reference — composio-crusher v2

Action IDs in your Composio workspace may differ — confirm via `composio actions list` or the dashboard before production use. The MCP integration path may expose different names than the direct API path.

---

## Wave 1 — Source Probes (HTTP only)

No Composio action needed. Hit URLs directly via `curl` / `fetch`:

| Path | Format |
|---|---|
| `/sitemap.xml`, `/sitemap_index.xml`, `/wp-sitemap.xml` | XML |
| `/robots.txt` | text |
| `/feed`, `/rss`, `/feed.xml`, `/atom.xml`, `/index.xml` | XML / Atom |
| `/api`, `/api/v1`, `/api/v2`, `/api/search`, `/api/<entity>` | JSON |
| `/openapi.json`, `/swagger.json`, `/.well-known/openapi` | JSON Schema |
| `<script type="application/ld+json">` in HTML | JSON-LD |

---

## Wave 2-3 — Firecrawl

| Action ID | Purpose |
|---|---|
| `FIRECRAWL_MAP_URL` | Discover all URLs on a domain |
| `FIRECRAWL_SCRAPE` | Single-page fetch with `formats: ["markdown","json","html"]` |
| `FIRECRAWL_CRAWL` | Recursive crawl with depth limit |
| `FIRECRAWL_EXTRACT` | Schema-bound extraction with prompt |
| `FIRECRAWL_BATCH_SCRAPE` | Batched parallel scrape |

Gotcha: use `formats`, NOT the deprecated `outputs`.

---

## Wave 4 — Browser Pool

### Browserbase
| Action ID | Purpose |
|---|---|
| `BROWSERBASE_CREATE_SESSION` | Start isolated browser |
| `BROWSERBASE_NAVIGATE` | Go to URL |
| `BROWSERBASE_GET_CONTENT` | Rendered HTML |
| `BROWSERBASE_EXECUTE_JS` | JS in page context |
| `BROWSERBASE_GET_COOKIES` | Extract cookies |
| `BROWSERBASE_CLOSE_SESSION` | Terminate |

### Hyperbrowser
| Action ID | Purpose |
|---|---|
| `HYPERBROWSER_CREATE_SESSION` | `use_stealth: true` |
| `HYPERBROWSER_NAVIGATE` | Navigate |
| `HYPERBROWSER_SCRAPE_WEBPAGE` | Content |
| `HYPERBROWSER_START_BROWSER_USE_TASK` | Vision agent (slower, use sparingly) |
| `HYPERBROWSER_CREATE_SCRAPE_JOB` | Background scrape job |
| `HYPERBROWSER_START_EXTRACT_JOB` | Schema-bound extract |
| `HYPERBROWSER_GET_COOKIES` | Cookies |
| `HYPERBROWSER_STOP_SESSION` | Terminate |

### Anchor Browser (login flows)
| Action ID | Purpose |
|---|---|
| `ANCHOR_BROWSER_CREATE_SESSION` | `stealth: true`, persistent profile optional |
| `ANCHOR_BROWSER_NAVIGATE` | Navigate |
| `ANCHOR_BROWSER_FILL_FORM` | Form filling for auth pages |
| `ANCHOR_BROWSER_GET_CONTENT` | Rendered content |
| `ANCHOR_BROWSER_GET_COOKIES` | Extract auth cookies |
| `ANCHOR_BROWSER_STOP_SESSION` | Terminate |

---

## Wave 5 — Apify + ScreenshotOne

| Action ID | Purpose |
|---|---|
| `APIFY_RUN_ACTOR` | Run any actor (sync or async) |
| `APIFY_GET_RUN` | Poll status |
| `APIFY_GET_DATASET_ITEMS` | Read results |
| `SCREENSHOTONE_TAKE_SCREENSHOT` | Visual capture for drift / image-heavy targets |
| `SCREENSHOT_FYI_CAPTURE` | Fallback screenshot provider |

Preferred Apify actors:
- `apify/cheerio-web-scraper` — static, fast, cheap
- `apify/puppeteer-web-scraper` — JS-rendered
- `apify/website-content-crawler` — full-site crawl with depth limit
- `apify/rag-web-browser` — LLM-optimized page extraction
- `apify/instagram-scraper` / `apify/facebook-scraper` — social listings (use only on your own accounts)

---

## Wave 6 — Anti-Bot Cascade

| Action ID | Purpose |
|---|---|
| `SCRAPFLY_SCRAPE` | Primary: anti-bot + JS render |
| `ZYTE_SMART_PROXY_FETCH` | Secondary: residential proxy rotation |
| `SCRAPE_DO_SCRAPE` | Tertiary: super API + residential |

Per URL: max 3 attempts, exponential backoff with jitter.

---

## Wave 7 — Transform / Enrich

| Action ID | Purpose |
|---|---|
| `CODEINTERPRETER_EXECUTE_CODE` | Python for normalize / dedup / parse |
| `ANTHROPIC_CHAT_COMPLETION` | Long-doc summarization, entity normalization |
| `OPENAI_CHAT_COMPLETION` | Backup LLM |

External enrichment hits (no Composio action; direct HTTP):
- `training.gov.au` open API
- Wikipedia REST + Wikidata SPARQL
- `companies.house.gov.uk` / ASIC equivalents
- ABN Lookup (AU)

---

## Wave 8 — Knowledge Graph

| Action ID | Purpose |
|---|---|
| `OPENAI_EMBEDDINGS` | `text-embedding-3-small` (1536d) or `-large` (3072d) |
| `VOYAGE_EMBED` | Alt embedding provider |
| `SUPABASE_INSERT` | `knowledge_chunks(id, content, embedding vector)` |
| `SUPABASE_RPC` | Call `match_chunks(query_vec, k)` for semantic search |

---

## Wave 9 — Delivery Destinations

| Action ID | Destination |
|---|---|
| `SUPABASE_UPSERT` | Primary store |
| `SUPABASE_INSERT` | Append-only tables |
| `SUPABASE_SELECT` | State / drift comparison |
| `NOTION_CREATE_PAGE` | New database row |
| `NOTION_UPDATE_PAGE` | Update existing row |
| `NOTION_QUERY_DATABASE` | Lookup by external_id |
| `GOOGLE_DRIVE_UPLOAD_FILE` | CSV / JSON snapshot |
| `GOOGLE_DRIVE_CREATE_FOLDER` | Per-run folder |
| `GOOGLE_SHEETS_APPEND_ROWS` | Flat row delivery |
| `GOOGLE_SHEETS_BATCH_UPDATE` | Bulk replace |
| `GITHUB_CREATE_FILE` | Snapshot commit |
| `GITHUB_UPDATE_FILE` | Update existing snapshot |
| `GITHUB_CREATE_PULL_REQUEST` | Data-PR pattern for review |
| `WEBHOOK_POST` | Batched JSON to operator endpoint |
| `S3_PUT_OBJECT` | Parquet / JSON to bucket |
| `S3_LIST_OBJECTS` | Snapshot inventory |

---

## Wave 10 — Drift / Snapshot

No new Composio actions — uses `SUPABASE_SELECT` to read prior `drift_snapshots` row, `CODEINTERPRETER_EXECUTE_CODE` to diff, then `SUPABASE_INSERT` for new snapshot + `SUPABASE_INSERT` into `record_diffs` for field-level changes. Then re-fires Wave 9 with `op: add|update|delete` deltas.

Schedule re-runs via:
- `composio listen` for trigger events
- Composio cron (server-side scheduled routine)
- GitHub Actions `schedule:` workflow
- Plain `cron` on a server

---

## Verification Commands

```bash
composio actions list                           # all available
composio actions list --app firecrawl
composio actions list --app browserbase
composio actions list --app hyperbrowser
composio actions list --app apify
composio actions list --app scrapfly
composio actions list --app zyte
composio actions list --app supabase
composio actions list --app notion
composio actions list --app github
composio actions list --app googledrive
composio actions list --app googlesheets
composio actions get FIRECRAWL_EXTRACT          # schema for one
composio connections list                       # active integrations
```

---

## Gotchas

1. **`formats` vs `outputs`** — Firecrawl uses `formats: ["markdown","json"]`. `outputs` is deprecated.
2. **`apify/web-scraper` is deprecated** — use `apify/cheerio-web-scraper` (static) or `apify/puppeteer-web-scraper` (JS).
3. **Browser session caps** — Free Browserbase: 1 concurrent. Hyperbrowser: plan-dependent. Anchor: plan-dependent. Wave 4 sizes itself to whatever the pool supports.
4. **Supabase keys** — anon key in sub-agents (RLS-enforced), service key only in orchestrator.
5. **Firecrawl extract LLM cost** — proportional to page size. Batch-split large URL lists.
6. **Voyage vs OpenAI dimensions** — `voyage-3` is 1024d, `voyage-3-large` is 1024d (configurable), OpenAI `text-embedding-3-small` is 1536d. Set `knowledge_chunks.embedding` column dimension to match your chosen provider — `schema.sql` defaults to 1536d (OpenAI small).
7. **Hyperbrowser action availability** — some action IDs (e.g. `HYPERBROWSER_EXECUTE_JS`) may not be exposed in your workspace; the SKILL prefers the vision-agent task surface for those operations when the JS action is absent.
8. **Notion external_id pattern** — to make `NOTION_UPDATE_PAGE` idempotent, store the Composio Crusher record ID in a Notion text property and query by it before deciding create-vs-update.
