-- Connector signal engine: data model.
--
-- Two tables. One holds the targets, one holds the runs that produced them. The comments
-- are the reasoning; keep them, because every one of them is a decision that was wrong
-- the first time.
--
-- SQLite dialect. Postgres needs SERIAL/BIGSERIAL and timestamptz instead of REAL, and
-- everything else carries over.

CREATE TABLE IF NOT EXISTS opportunities (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id        INTEGER,                -- the run that found it; NULL for manual imports
  client_id     INTEGER,                -- optional, if you run this for more than yourself

  side          TEXT NOT NULL,          -- demand | supply
  niche         TEXT NOT NULL,          -- e.g. recruitment | wealth

  -- Who to contact. Everything here can be NULL at write time: the engine queues a scored
  -- employer first and attaches a person later, because the scoring is free and the email
  -- lookup is not.
  person_name   TEXT,
  title         TEXT,
  company       TEXT,
  domain        TEXT,
  email         TEXT,
  email_status  TEXT,                   -- valid | unknown | invalid | catch_all
  email_source  TEXT,
  linkedin_url  TEXT,

  -- Why this row exists. signal_ref is the thing you can go and check by hand: an ATS
  -- board token, a job URL, a SEC accession number.
  signal_source TEXT,                   -- ats_greenhouse | ats_lever | ats_ashby |
                                        -- form_4 | form_144 | supply_search | manual
  signal_ref    TEXT,
  signal_at     REAL,
  signal_summary TEXT,                  -- one line, shown on the queue card
  signal_facts  TEXT,                   -- JSON: the checkable numbers behind the claim

  company_context TEXT,
  score         INTEGER,

  outreach_subject TEXT,
  outreach_body    TEXT,

  status        TEXT DEFAULT 'new',     -- new | sent | replied | accepted | dismissed
  dismiss_reason TEXT,
  sent_at       REAL,
  replied_at    REAL,

  -- Set when a row is promoted out of the queue into whatever you use to keep contacts.
  -- This is the single seam between this module and the rest of your system. Nothing else
  -- here should know about your CRM.
  relationship_id INTEGER,

  -- Stops a daily scan re-surfacing the same party. UNIQUE at the DATABASE level, not in
  -- application code: a daily job will eventually race itself and an app-level check loses
  -- that race, which means the same employer greets you every morning forever.
  --   demand (ATS)  ats:<board_token>:<email or domain>
  --   demand (SEC)  w4:<person_cik>:<issuer_cik>
  --   supply        sup:<niche>:<domain>
  dedupe_key    TEXT NOT NULL,

  created_by    INTEGER,
  created_at    REAL,
  updated_at    REAL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_opportunities_dedupe ON opportunities(dedupe_key);
CREATE INDEX IF NOT EXISTS idx_opportunities_queue ON opportunities(status, niche, score DESC);


CREATE TABLE IF NOT EXISTS opportunity_runs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  niche         TEXT NOT NULL,
  status        TEXT DEFAULT 'queued',  -- queued | running | done | failed | cancelled
  client_id     INTEGER,

  demand_requested INTEGER DEFAULT 4,
  supply_requested INTEGER DEFAULT 5,
  demand_found     INTEGER DEFAULT 0,
  supply_found     INTEGER DEFAULT 0,

  -- Candidates attempted, including the ones dropped for an unresolvable email. Surfaced
  -- in the UI so a short run reads as honest ("found 4 of 4, tried 11") instead of looking
  -- broken. Email resolution ran around 50% on public-company executives, so most runs
  -- drop a lot of candidates and that is normal.
  candidates_tried INTEGER DEFAULT 0,

  stage         TEXT,                   -- human-readable progress, e.g. "enriching 6 of 11"
  error         TEXT,

  created_by    INTEGER,
  created_at    REAL,
  started_at    REAL,
  finished_at   REAL
);

CREATE INDEX IF NOT EXISTS idx_runs_claim ON opportunity_runs(status, id);
