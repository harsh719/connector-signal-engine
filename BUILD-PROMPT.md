# Build prompt

Open Claude Code in an empty directory and paste everything below the line. It is written
to be executed, not read. Adjust the stack line if you want something other than Python.

---

Build me a daily demand-signal engine for a connector business.

## Context

A connector gets paid for introducing someone who has a problem right now to someone who
solves exactly that problem. I need the first half found automatically every day: companies
that are publicly signalling a hiring problem, scored and queued, so I open my laptop and
today's targets are already waiting.

## Stack

Python 3.11, FastAPI, SQLite, and a plain HTML/JS page. No framework on the front end. If
I already have an app, build this as a self-contained module I can mount into it.

## The pipeline

1. A run is queued for a niche. A background loop claims it and executes it.
2. The scanner reads public ATS job boards for every token in a `VERTICALS` config.
3. Postings are grouped into one cluster per employer.
4. Each cluster is scored. Anything below the floor is dropped.
5. Survivors are written to a queue, deduplicated.
6. I work the queue one at a time, moving each row through a state machine.

## Board endpoints

All three are public, unauthenticated JSON. `{token}` is the company's board slug.

```
Lever       https://api.lever.co/v0/postings/{token}?mode=json
Greenhouse  https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=false
Ashby       https://api.ashbyhq.com/posting-api/job-board/{token}?includeCompensation=false
```

Greenhouse also exposes the company's display name at
`https://boards-api.greenhouse.io/v1/boards/{token}`.

Treat a 404 as "this token is not a board" and move on. Do not let one dead token kill a run.

## Non-negotiable design decisions

These came out of building this once and getting them wrong. Do not reinvent them.

**Dedupe is a database constraint, not an application check.** Put `UNIQUE` on a
`dedupe_key` column. A daily job will eventually race itself and an application-level check
loses that race, which means the same employer resurfaces every morning. Key shape:
`ats:<board_token>:<domain or email>`.

**Status changes only through dedicated transition endpoints.** A generic PATCH must not be
able to set `status`. Put the state machine in one function that every transition calls, so
a front-end bug cannot walk a row into a nonsense state.

```
new       -> sent, dismissed
sent      -> replied, dismissed
replied   -> accepted
accepted  -> terminal
dismissed -> new    (restore)
```

**Transitions are idempotent.** Calling "mark sent" twice is a no-op. It must not re-stamp
the timestamp or create a second downstream record.

**Marking sent does not send anything.** It records that I sent it. Actual transmission is a
separate concern. I do not want a UI bug mailing a stranger.

**Quality floor beats novelty.** When ranking what to write into the queue, apply the score
floor before preferring unseen employers. Without this the engine writes big national
employers with in-house recruiting teams purely because they have not been seen before. An
empty result is better than a weak one, because my morning is the scarce resource.

**Report honestly.** Store `candidates_tried` next to `demand_found`. A run that surfaces 4
from 11 candidates should say "found 4, tried 11" rather than looking broken. Most
candidates die on an unresolvable email and that is normal, not a bug.

## Scoring

Score each employer cluster, and only write it if it clears a floor (start the floor at 55
and tune it). Signals that earned their place:

- How many relevant roles are open. More open roles is a bigger problem.
- How recently they were posted. A posting from last week beats one from March.
- Geographic spread. Roles across several states is a harder problem than one office.
- Whether the roles are ones a staffing partner can actually place. Keep an explicit
  allowlist of role phrases per vertical rather than guessing from the title.
- Whether a signing bonus or referral bonus appears in the posting text. Someone paying a
  bonus has already admitted they cannot fill it themselves.

Score should be an integer so I can sort and set a floor. Keep the function pure and
testable, separate from anything doing network calls.

## Config shape

```python
VERTICALS = {
    "healthcare": {
        "lever":      ["<board-token>", "..."],
        "greenhouse": ["<board-token>", "..."],
        "ashby":      [],
        # Role phrases a staffing partner can place. Match against the posting title,
        # lowercased. This list is what stops the scanner queueing software engineers.
        "placeable":  ["registered nurse", "nurse practitioner", "hospice",
                       "home health", "case manager", "physical therap"],
    },
}
```

## Data model

Use `reference/schema.sql` from this repo verbatim. The comments explain why each column
exists; keep them.

## API

```
POST   /api/opportunities/runs          queue a run for a niche
GET    /api/opportunities/runs/{id}     progress, including stage text
GET    /api/opportunities               the queue, filterable by status/niche/side
POST   /api/opportunities/{id}/sent     idempotent transition
POST   /api/opportunities/{id}/replied  idempotent transition
POST   /api/opportunities/{id}/dismiss  with a reason
POST   /api/opportunities/{id}/promote  hand off to wherever I keep contacts
POST   /api/opportunities/import        seed the queue by hand
```

## The page

A board, not a one-at-a-time card. Group targets by niche so I can see the whole morning
and choose what to work, rather than being handed whatever scored highest. Clicking a card
opens a drawer that is the only work surface: context, the draft, the actions. Tabs for
Queue, Sent, Replied, Closed.

## Tests

Write real tests for the state machine (every legal and illegal transition), the dedupe key
builder, and the scorer. Those three are where a bug costs me a morning. Network code can
stay untested.

## Build order

1. Schema and the scorer, with tests
2. The scanner against one board token I give you, printed to stdout, before any database
   writes
3. The queue API and the state machine
4. The background drain
5. The page

Show me the scanner output for a real token before you wire up any writes. If the scoring
looks wrong I want to catch it there, not after it has written 40 rows.

## Do not

- Do not add a board token to `VERTICALS` without probing and scoring it first. Half of any
  candidate list will be real, reachable boards that write junk into the queue.
- Do not try to find board tokens by taking a list of companies I already contacted and
  guessing their slug. Those are the companies I sell to, which is the supply side, and
  searching them for demand returns agencies and VCs at about a 1.7% hit rate.
- Do not automate the supply side in v1. Deciding whether a firm is a genuine specialist is
  a judgment call. Shortlist it and let me dismiss.
