-- Composio Crusher v2 — Supabase schema
-- Run: psql "$SUPABASE_DB_URL" < supabase/schema.sql

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- for gen_random_uuid()

-- ═══════════════════════════════════════════════════════════════════
-- Shared update-timestamp trigger function
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- target_registry: Wave 0 routing decisions, cached across runs
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS target_registry (
  slug                 TEXT PRIMARY KEY,
  url                  TEXT NOT NULL,
  api_url              TEXT,
  classified_route     TEXT NOT NULL
                       CHECK (classified_route IN ('api','static_html','js_rendered','apify','anti_bot','login_gated','mixed')),
  classification_signals JSONB NOT NULL DEFAULT '{}'::jsonb,
  schema_name          TEXT,
  defaults_overrides   JSONB DEFAULT '{}'::jsonb,
  last_classified_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS target_registry_route_idx ON target_registry(classified_route);
DROP TRIGGER IF EXISTS target_registry_touch ON target_registry;
CREATE TRIGGER target_registry_touch BEFORE UPDATE ON target_registry
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- pipeline_runs: wave-level checkpoint state per run × target
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS pipeline_runs (
  run_id               UUID NOT NULL DEFAULT gen_random_uuid(),
  target_slug          TEXT NOT NULL REFERENCES target_registry(slug) ON DELETE CASCADE,
  status               TEXT NOT NULL
                       CHECK (status IN ('queued','in_progress','completed','failed','degraded')),
  highest_wave_completed INTEGER NOT NULL DEFAULT -1,
  waves_executed       INTEGER[] NOT NULL DEFAULT '{}',
  checkpoints          JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_log            JSONB NOT NULL DEFAULT '[]'::jsonb,
  started_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at         TIMESTAMPTZ,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (run_id, target_slug)
);
CREATE INDEX IF NOT EXISTS pipeline_runs_status_idx ON pipeline_runs(status);
CREATE INDEX IF NOT EXISTS pipeline_runs_target_idx ON pipeline_runs(target_slug, started_at DESC);
DROP TRIGGER IF EXISTS pipeline_runs_touch ON pipeline_runs;
CREATE TRIGGER pipeline_runs_touch BEFORE UPDATE ON pipeline_runs
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- discovered_urls: Wave 2 output — URL bank per target
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS discovered_urls (
  id                   BIGSERIAL PRIMARY KEY,
  target_slug          TEXT NOT NULL REFERENCES target_registry(slug) ON DELETE CASCADE,
  run_id               UUID,
  url                  TEXT NOT NULL,
  discovered_via       TEXT,  -- 'sitemap'|'firecrawl_map'|'pagination'|'rss'|'api'|'jsonld'
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','extracted','blocked','failed','skipped')),
  attempted_at         TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (target_slug, url)
);
CREATE INDEX IF NOT EXISTS discovered_urls_target_status_idx
  ON discovered_urls(target_slug, status);

-- ═══════════════════════════════════════════════════════════════════
-- staging.crusher_records: Wave 3-6 landing zone (pre-transform)
-- ═══════════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.crusher_records (
  id                   BIGSERIAL PRIMARY KEY,
  target_slug          TEXT NOT NULL,
  source_url           TEXT,
  record_id            TEXT,
  wave_origin          INTEGER,
  record_data          JSONB NOT NULL,
  extracted_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (target_slug, record_id)
);
CREATE INDEX IF NOT EXISTS crusher_records_target_idx
  ON staging.crusher_records(target_slug);
CREATE INDEX IF NOT EXISTS crusher_records_extracted_idx
  ON staging.crusher_records(extracted_at DESC);

-- ═══════════════════════════════════════════════════════════════════
-- clean_records: Wave 7 output — normalized + dedup
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS clean_records (
  id                   BIGSERIAL PRIMARY KEY,
  global_id            TEXT NOT NULL UNIQUE,  -- chosen ID after dedup
  primary_target_slug  TEXT NOT NULL,
  also_seen_in         TEXT[] NOT NULL DEFAULT '{}',
  name                 TEXT NOT NULL,
  description          TEXT,
  url                  TEXT,
  record_type          TEXT,  -- 'course'|'product'|'job'|'org' etc
  cost_cents           BIGINT,
  cost_raw             TEXT,
  duration_weeks       NUMERIC(8,2),
  duration_raw         TEXT,
  start_date           DATE,
  start_raw            TEXT,
  attributes           JSONB NOT NULL DEFAULT '{}'::jsonb,
  enriched_attributes  JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS clean_records_target_idx ON clean_records(primary_target_slug);
CREATE INDEX IF NOT EXISTS clean_records_type_idx ON clean_records(record_type);
CREATE INDEX IF NOT EXISTS clean_records_cost_idx ON clean_records(cost_cents);
CREATE INDEX IF NOT EXISTS clean_records_attrs_gin ON clean_records USING GIN (attributes);
DROP TRIGGER IF EXISTS clean_records_touch ON clean_records;
CREATE TRIGGER clean_records_touch BEFORE UPDATE ON clean_records
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ═══════════════════════════════════════════════════════════════════
-- entities + relations: Wave 8 knowledge graph
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS entities (
  id                   BIGSERIAL PRIMARY KEY,
  entity_key           TEXT NOT NULL UNIQUE,
  entity_type          TEXT NOT NULL,  -- 'org'|'location'|'qualification'|'code'|'person'
  display_name         TEXT NOT NULL,
  attributes           JSONB NOT NULL DEFAULT '{}'::jsonb,
  external_refs        JSONB NOT NULL DEFAULT '{}'::jsonb,  -- wikidata, ABN, etc
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS entities_type_idx ON entities(entity_type);

CREATE TABLE IF NOT EXISTS relations (
  id                   BIGSERIAL PRIMARY KEY,
  subject_entity       TEXT NOT NULL REFERENCES entities(entity_key) ON DELETE CASCADE,
  predicate            TEXT NOT NULL,  -- 'offered_by'|'requires'|'equivalent_to'|'superseded_by'
  object_entity        TEXT NOT NULL REFERENCES entities(entity_key) ON DELETE CASCADE,
  source_record_id     TEXT,
  confidence           NUMERIC(4,3) NOT NULL DEFAULT 1.000,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (subject_entity, predicate, object_entity)
);
CREATE INDEX IF NOT EXISTS relations_subject_idx ON relations(subject_entity);
CREATE INDEX IF NOT EXISTS relations_object_idx ON relations(object_entity);
CREATE INDEX IF NOT EXISTS relations_pred_idx ON relations(predicate);

-- ═══════════════════════════════════════════════════════════════════
-- knowledge_chunks: Wave 8 pgvector embeddings
-- Default 1536d for OpenAI text-embedding-3-small.
-- Change vector(1536) to vector(1024) for Voyage, vector(3072) for OpenAI -large.
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS knowledge_chunks (
  id                   BIGSERIAL PRIMARY KEY,
  global_record_id     TEXT REFERENCES clean_records(global_id) ON DELETE CASCADE,
  target_slug          TEXT,
  source_url           TEXT,
  chunk_index          INTEGER NOT NULL DEFAULT 0,
  content              TEXT NOT NULL,
  content_hash         TEXT NOT NULL,
  embedding            vector(1536),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (global_record_id, content_hash)
);
CREATE INDEX IF NOT EXISTS knowledge_chunks_record_idx ON knowledge_chunks(global_record_id);
CREATE INDEX IF NOT EXISTS knowledge_chunks_target_idx ON knowledge_chunks(target_slug);
CREATE INDEX IF NOT EXISTS knowledge_chunks_hnsw_idx
  ON knowledge_chunks USING hnsw (embedding vector_cosine_ops);

-- RPC: semantic search helper
CREATE OR REPLACE FUNCTION match_chunks(
  query_embedding vector(1536),
  match_count INTEGER DEFAULT 10,
  filter_target TEXT DEFAULT NULL
) RETURNS TABLE (
  global_record_id TEXT,
  content TEXT,
  similarity NUMERIC
) AS $$
  SELECT
    kc.global_record_id,
    kc.content,
    (1 - (kc.embedding <=> query_embedding))::NUMERIC AS similarity
  FROM knowledge_chunks kc
  WHERE filter_target IS NULL OR kc.target_slug = filter_target
  ORDER BY kc.embedding <=> query_embedding
  LIMIT match_count;
$$ LANGUAGE sql STABLE;

-- ═══════════════════════════════════════════════════════════════════
-- drift_snapshots + record_diffs: Wave 10
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS drift_snapshots (
  id                   BIGSERIAL PRIMARY KEY,
  run_id               UUID NOT NULL,
  target_slug          TEXT NOT NULL,
  record_set_hash      TEXT NOT NULL,
  record_count         INTEGER NOT NULL,
  record_ids           TEXT[] NOT NULL DEFAULT '{}',
  captured_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS drift_snapshots_target_time_idx
  ON drift_snapshots(target_slug, captured_at DESC);

CREATE TABLE IF NOT EXISTS record_diffs (
  id                   BIGSERIAL PRIMARY KEY,
  run_id               UUID NOT NULL,
  target_slug          TEXT NOT NULL,
  global_record_id     TEXT NOT NULL,
  op                   TEXT NOT NULL CHECK (op IN ('add','update','delete')),
  field_changes        JSONB NOT NULL DEFAULT '{}'::jsonb,
  observed_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS record_diffs_run_idx ON record_diffs(run_id);
CREATE INDEX IF NOT EXISTS record_diffs_target_op_idx ON record_diffs(target_slug, op);

-- ═══════════════════════════════════════════════════════════════════
-- blocked_urls: Wave 6 exhausted retries
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS blocked_urls (
  id                   BIGSERIAL PRIMARY KEY,
  target_slug          TEXT NOT NULL,
  url                  TEXT NOT NULL,
  last_status          INTEGER,
  last_error_type      TEXT,  -- 'captcha'|'403'|'429'|'timeout'
  attempts             INTEGER NOT NULL DEFAULT 0,
  last_attempted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (target_slug, url)
);
CREATE INDEX IF NOT EXISTS blocked_urls_target_idx ON blocked_urls(target_slug);

-- ═══════════════════════════════════════════════════════════════════
-- delivery_log: Wave 9 audit trail per destination
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS delivery_log (
  id                   BIGSERIAL PRIMARY KEY,
  run_id               UUID NOT NULL,
  target_slug          TEXT NOT NULL,
  destination          TEXT NOT NULL,  -- 'supabase'|'notion'|'drive'|'github'|'sheets'|'webhook'|'s3'|'local'
  op                   TEXT NOT NULL,
  status               TEXT NOT NULL CHECK (status IN ('ok','degraded','failed')),
  records_count        INTEGER,
  external_id          TEXT,
  payload_size_bytes   BIGINT,
  error_message        TEXT,
  delivered_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS delivery_log_run_dest_idx ON delivery_log(run_id, destination);
