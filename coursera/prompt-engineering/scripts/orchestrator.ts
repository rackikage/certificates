#!/usr/bin/env npx tsx
/**
 * composio-crusher orchestrator.ts
 *
 * The actual executable brain behind the Composio Crusher skill.
 * Run directly: `npx tsx scripts/orchestrator.ts <url> [schema] [max_pages]`
 * Or invoke via Claude Code / OpenCode which will call this script.
 *
 * Requires: COMPOSIO_API_KEY, FIRECRAWL_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
 */

import { Composio } from "composio-core";
import Firecrawl from "@mendable/firecrawl-js";
import { createClient } from "@supabase/supabase-js";
import { readFileSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// ─── Types ───────────────────────────────────────────────────────────
interface CleanRecord {
  [key: string]: unknown;
  name?: string;
  title?: string;
  url?: string;
  id?: string;
  course_code?: string;
}

interface OrchestratorConfig {
  targetUrl: string;
  schemaName: string;
  maxPages: number;
  schema: Record<string, unknown>;
}

// ─── Config ──────────────────────────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);

if (args.length < 1) {
  console.error("Usage: orchestrator.ts <url> [schema_name] [max_pages]");
  process.exit(1);
}

const CONFIG: OrchestratorConfig = {
  targetUrl: args[0],
  schemaName: args[1] || "default",
  maxPages: parseInt(args[2] || "500", 10),
  schema: loadCustomSchema(args[1]),
};

// Lazy-init clients
let _composio: Composio | null = null;
let _firecrawl: Firecrawl | null = null;
let _supabase: ReturnType<typeof createClient> | null = null;

function getComposio(): Composio {
  if (!_composio) {
    _composio = new Composio({ apiKey: process.env.COMPOSIO_API_KEY! });
  }
  return _composio;
}

function getFirecrawl(): Firecrawl {
  if (!_firecrawl) {
    _firecrawl = new Firecrawl({ apiKey: process.env.FIRECRAWL_API_KEY! });
  }
  return _firecrawl;
}

function getSupabase() {
  if (!_supabase) {
    _supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    );
  }
  return _supabase;
}

// ─── Utilities ───────────────────────────────────────────────────────
const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

function sanitize(input: string): string {
  return input
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/<[^>]*>/g, "")
    .trim();
}

function snakeCase(str: string): string {
  return str
    .replace(/([A-Z])/g, "_$1")
    .replace(/\s+/g, "_")
    .toLowerCase()
    .replace(/^_/, "");
}

function normalizeFieldNames(record: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(record)) {
    out[snakeCase(k)] = v;
  }
  return out;
}

function dedupKey(record: CleanRecord): string {
  return (
    record.course_code ||
    record.id ||
    (record.url || "").replace(/\/$/, "").replace(/\?.*/, "") ||
    (record.name || record.title || "")
      .toLowerCase()
      .trim()
  );
}

// ─── Wave Implementations ────────────────────────────────────────────

async function wave0(): Promise<"static" | "js" | "api" | "bot-protected"> {
  console.log("[Wave 0] Reconnaissance...");
  try {
    const resp = await fetch(CONFIG.targetUrl, { method: "HEAD" });
    const ct = resp.headers.get("content-type") || "";

    if (CONFIG.targetUrl.includes("/api/") || ct.includes("application/json")) {
      return "api";
    }

    const body = await resp.text();
    if (
      body.includes("<script") &&
      (body.includes("__NEXT_DATA__") ||
        body.includes("react-root") ||
        body.includes("vue-app"))
    ) {
      return "js";
    }

    if (resp.status === 403 || resp.status === 401) {
      return "bot-protected";
    }

    return "static";
  } catch {
    return "js";
  }
}

async function wave1(): Promise<string[]> {
  console.log("[Wave 1] Mapping site...");
  const firecrawl = getFirecrawl();
  const mapResult = await firecrawl.mapUrl(CONFIG.targetUrl);
  const urls = (mapResult.links || []).slice(0, CONFIG.maxPages);
  console.log(`  Discovered ${urls.length} URLs`);
  return urls;
}

async function wave2_3(urls: string[]): Promise<CleanRecord[]> {
  console.log(`[Wave 2-3] Extracting ${urls.length} pages...`);
  if (urls.length === 0) return [];

  const firecrawl = getFirecrawl();
  const batchSize = Math.max(1, Math.ceil(urls.length / 20));
  const batches: string[][] = [];
  for (let i = 0; i < urls.length; i += batchSize) {
    batches.push(urls.slice(i, i + batchSize));
  }

  const results = await Promise.allSettled(
    batches.map((batch) =>
      firecrawl.extract(batch, {
        prompt: "Extract structured data from these pages",
        schema: CONFIG.schema as any,
        formats: ["markdown", "json"],
      })
    )
  );

  const records: CleanRecord[] = [];
  for (const r of results) {
    if (r.status === "fulfilled") {
      const data = (r.value as any)?.data?.records || [];
      records.push(...data.map((rec: any) => normalizeFieldNames(rec)));
    }
  }
  console.log(`  Extracted ${records.length} raw records`);
  return records;
}

async function wave4(urls: string[]): Promise<CleanRecord[]> {
  console.log("[Wave 4] Browser automation...");
  const composio = getComposio();
  const records: CleanRecord[] = [];

  try {
    const session = await composio.actions.BROWSERBASE_CREATE_SESSION({
      context: { isolation: "single", timeToLive: 300 },
    });

    for (let i = 0; i < Math.min(urls.length, 50); i++) {
      try {
        await composio.actions.BROWSERBASE_NAVIGATE({
          sessionId: session.id,
          url: urls[i],
        });
        await delay(3000);

        const content = await composio.actions.BROWSERBASE_GET_CONTENT({
          sessionId: session.id,
        });

        const html: string = content?.data || content?.content || "";
        const title =
          html.match(/<h[1-3][^>]*>([^<]+)<\/h[1-3]>/)?.[1] || "";
        records.push({
          name: sanitize(title),
          url: urls[i],
          source: "browserbase",
        });
      } catch (e: any) {
        console.warn(`  [Wave 4] Failed on ${urls[i]}: ${e.message}`);
      }
    }

    await composio.actions.BROWSERBASE_CLOSE_SESSION({ sessionId: session.id });
  } catch (e: any) {
    console.error(`[Wave 4] Browser session error: ${e.message}`);
  }

  console.log(`  Browser extracted ${records.length} records`);
  return records;
}

async function wave5(): Promise<CleanRecord[]> {
  console.log("[Wave 5] Apify scraping...");
  if (!process.env.APIFY_API_KEY) {
    console.log("  Skipping — no APIFY_API_KEY");
    return [];
  }

  const composio = getComposio();
  try {
    const result = await composio.actions.APIFY_RUN_ACTOR({
      actorId: "apify/cheerio-web-scraper",
      input: {
        startUrls: [{ url: CONFIG.targetUrl }],
        maxPagesPerCrawl: CONFIG.maxPages,
        pageFunction: `
          async function pageFunction(context) {
            const $ = context.jQuery;
            const items = [];
            $('a[href], .item, .card, li').each((i, el) => {
              const text = $(el).text().trim();
              if (text.length > 10 && text.length < 200) {
                items.push({
                  name: text.substring(0, 150),
                  url: $(el).attr('href') || '',
                });
              }
            });
            return items;
          }
        `,
      },
    });
    const records: CleanRecord[] = (result.data?.results || []).map((r: any) =>
      normalizeFieldNames(r)
    );
    console.log(`  Apify extracted ${records.length} records`);
    return records;
  } catch (e: any) {
    console.warn(`  [Wave 5] Apify error: ${e.message}`);
    return [];
  }
}

async function wave6(failedUrls: string[]): Promise<CleanRecord[]> {
  console.log(`[Wave 6] Anti-bot retry for ${failedUrls.length} URLs...`);
  const records: CleanRecord[] = [];
  const backoff = [1000, 4000, 9000];

  for (const url of failedUrls) {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        if (process.env.SCRAPFLY_API_KEY) {
          const resp = await fetch(
            `https://api.scrapfly.io/scrape?key=${process.env.SCRAPFLY_API_KEY}&url=${encodeURIComponent(url)}&asp=true&render_js=true`
          );
          if (resp.ok) {
            const data = await resp.json();
            records.push({
              name: sanitize(data.result?.title || ""),
              url,
              source: "scrapfly",
            });
            break;
          }
        }

        if (process.env.ZYTE_API_KEY) {
          const resp = await fetch("https://api.zyte.com/v1/extract", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Basic ${Buffer.from(process.env.ZYTE_API_KEY + ":").toString("base64")}`,
            },
            body: JSON.stringify({
              url,
              httpResponseBody: true,
              actions: [{ action: "wait", milliseconds: 3000 }],
            }),
          });
          if (resp.ok) {
            const data = await resp.json();
            const html = Buffer.from(data.httpResponseBody, "base64").toString();
            const title = html.match(/<title[^>]*>([^<]+)<\/title>/)?.[1] || "";
            records.push({
              name: sanitize(title),
              url,
              source: "zyte",
            });
            break;
          }
        }

        await delay(backoff[attempt] + Math.random() * 500);
      } catch (e: any) {
        console.warn(`  [Wave 6] Attempt ${attempt + 1} for ${url}: ${e.message}`);
        if (attempt < 2) await delay(backoff[attempt] + Math.random() * 500);
      }
    }
  }

  console.log(`  Anti-bot rescued ${records.length} records`);
  return records;
}

async function wave7(allRecords: CleanRecord[]): Promise<{
  clean: CleanRecord[];
  dropped: number;
  errors: string[];
}> {
  console.log(`[Wave 7] Transforming ${allRecords.length} records...`);
  const seen = new Set<string>();
  const clean: CleanRecord[] = [];
  const errors: string[] = [];

  for (const record of allRecords) {
    try {
      const key = dedupKey(record);
      if (!key || seen.has(key)) continue;
      seen.add(key);

      if (!record.name && !record.title && !record.url) {
        errors.push(`Dropped record: no name/title/url`);
        continue;
      }

      const name = (record.name || record.title || "") as string;
      const levelMatch = name.match(
        /(Certificate\s*(I{1,3}|IV)|Diploma|Advanced\s*Diploma|Bachelor|Master|Graduate\s*Certificate|Graduate\s*Diploma|Short\s*Course)/i
      );
      if (levelMatch) {
        record.level = levelMatch[1];
      }

      clean.push({
        ...record,
        name: sanitize(name),
        title: undefined,
      });
    } catch (e: any) {
      errors.push(`Transform error: ${e.message}`);
    }
  }

  console.log(
    `  Clean: ${clean.length}, Dropped: ${allRecords.length - clean.length - errors.length}, Errors: ${errors.length}`
  );
  return { clean, dropped: allRecords.length - clean.length, errors };
}

async function wave8(
  records: CleanRecord[],
  startTime: number
): Promise<string[]> {
  console.log(`[Wave 8] Loading ${records.length} records...`);
  const destinations: string[] = [];

  // Local filesystem
  const fs = await import("fs/promises");
  const outputPath = "composio-output.json";
  await fs.writeFile(
    outputPath,
    JSON.stringify(
      {
        target: CONFIG.targetUrl,
        total_records: records.length,
        generated_at: new Date().toISOString(),
        schema: CONFIG.schemaName,
        records,
      },
      null,
      2
    )
  );
  destinations.push("local_json");

  // CSV
  const csvHeaders = ["name", "url", "id", "course_code", "level"];
  const csvLines = [csvHeaders.join(",")];
  for (const r of records) {
    csvLines.push(
      csvHeaders
        .map((h) => `"${(r[h] || "").toString().replace(/"/g, '""')}"`)
        .join(",")
    );
  }
  await fs.writeFile("composio-output.csv", csvLines.join("\n"));
  destinations.push("local_csv");

  // Supabase
  if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
    try {
      const supabase = getSupabase();
      const { error } = await supabase.from("staging.courses").upsert(
        records.map((r) => ({
          course_code: r.course_code || r.id || null,
          title: r.name || null,
          data_json: r,
          created_at: new Date().toISOString(),
        })),
        { onConflict: "course_code", ignoreDuplicates: false }
      );
      if (!error) destinations.push("supabase");
      else console.warn(`  Supabase error: ${error.message}`);
    } catch (e: any) {
      console.warn(`  Supabase write failed: ${e.message}`);
    }
  }

  // GitHub
  if (process.env.GITHUB_TOKEN) {
    try {
      const composio = getComposio();
      await composio.actions.GITHUB_CREATE_COMMIT({
        message: `data snapshot: ${new URL(CONFIG.targetUrl).hostname} - ${new Date().toISOString().split("T")[0]} - ${records.length} records`,
        files: {
          "data/extraction-snapshots/composio-output.json": JSON.stringify(
            records,
            null,
            2
          ),
        },
      });
      destinations.push("github");
    } catch (e: any) {
      console.warn(`  GitHub commit failed: ${e.message}`);
    }
  }

  const duration = (Date.now() - startTime) / 1000;
  console.error("=== COMPOSIO CRUSHER COMPLETE ===");
  console.error(`Target: ${CONFIG.targetUrl}`);
  console.error(`Records: ${records.length}`);
  console.error(`Duration: ${duration.toFixed(0)}s`);
  console.error(`Destinations: ${destinations.join(", ")}`);

  return destinations;
}

// ─── Orchestrator ────────────────────────────────────────────────────
async function main() {
  const startTime = Date.now();
  console.log(`\n🚀 Composio Crusher — ${CONFIG.targetUrl}`);
  console.log(`   Schema: ${CONFIG.schemaName}, Max pages: ${CONFIG.maxPages}\n`);

  // Wave 0
  const targetType = await wave0();
  console.log(`   Target classified as: ${targetType}\n`);

  // Wave 1
  const urls = await wave1();
  if (urls.length === 0) {
    console.error("[ABORT] No URLs discovered. Check the target URL.");
    process.exit(1);
  }

  // Waves 2-3 or 4
  let allRecords: CleanRecord[] = [];
  let failedUrls: string[] = [];

  if (targetType === "static") {
    allRecords = await wave2_3(urls);
  } else if (targetType === "js") {
    allRecords = await wave4(urls);
  } else if (targetType === "api") {
    console.log("[Wave 2-3] Direct API extraction...");
    try {
      const resp = await fetch(CONFIG.targetUrl, {
        headers: { Accept: "application/json" },
      });
      const data = await resp.json();
      const items = Array.isArray(data)
        ? data
        : data.data || data.results || data.items || [];
      allRecords = items.map((item: any) => normalizeFieldNames(item));
      console.log(`  API returned ${allRecords.length} records`);
    } catch (e: any) {
      console.error(`  API fetch failed: ${e.message}`);
    }
  } else {
    failedUrls = urls;
  }

  // Wave 5
  if (targetType !== "bot-protected") {
    const apifyRecords = await wave5();
    allRecords.push(...apifyRecords);
  }

  // Wave 6
  if (failedUrls.length > 0) {
    const rescued = await wave6(failedUrls);
    allRecords.push(...rescued);
  }

  // Wave 7
  const { clean, dropped, errors } = await wave7(allRecords);

  // Wave 8
  const destinations = await wave8(clean, startTime);

  const duration = (Date.now() - startTime) / 1000;
  const summary = {
    target: CONFIG.targetUrl,
    total_records_found: allRecords.length,
    unique_records_after_dedup: clean.length,
    records_dropped: dropped,
    waves_completed: 8,
    waves_with_errors: errors.length > 0 ? 1 : 0,
    errors_logged: errors.length,
    duration_seconds: Math.round(duration),
    destinations_written: destinations,
    schema_used: CONFIG.schemaName,
    sample_records: clean.slice(0, 3),
  };

  console.log(`\n📊 Summary:\n${JSON.stringify(summary, null, 2)}`);
}

// ─── Schema Loader ───────────────────────────────────────────────────
function loadCustomSchema(name: string): Record<string, unknown> {
  const schemaPath = join(__dirname, "..", "assets", "schemas", `${name}.json`);
  if (existsSync(schemaPath)) {
    try {
      const raw = readFileSync(schemaPath, "utf-8");
      return JSON.parse(raw);
    } catch {
      console.warn(`  Failed to parse schema "${name}" from ${schemaPath}`);
    }
  }

  // Fallback to default
  const defaultPath = join(__dirname, "..", "assets", "schemas", "default.json");
  if (existsSync(defaultPath)) {
    try {
      return JSON.parse(readFileSync(defaultPath, "utf-8"));
    } catch {
      // proceed with inline default
    }
  }

  return {
    type: "object",
    properties: {
      records: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            description: { type: "string" },
            url: { type: "string" },
            id: { type: "string" },
          },
        },
      },
    },
  };
}

// ─── Run ─────────────────────────────────────────────────────────────
main().catch((err) => {
  console.error("[FATAL]", err);
  process.exit(1);
});
