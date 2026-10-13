# Connector signal engine

A daily queue of demand signals for a connector business, built so that you open your
laptop and today's targets are already there instead of going hunting for them.

This repo is a build spec, not a library. You paste [BUILD-PROMPT.md](BUILD-PROMPT.md)
into Claude Code and it builds you a working version. The useful part here is not the
code, it is the decisions, and in particular the two approaches that failed.

## What a connector does, in one paragraph

You get paid for the match. That means you need both halves: someone with a problem
right now (demand), and someone who solves exactly that problem (supply). You bring them
together and you take a fee. The reason this closes over email without a sales call is
that you turn up already holding the other side, so there is nothing to pitch. The hard
part is not the email. It is finding fresh demand every single day without it becoming
your whole job.

This engine automates that part.

## What it actually does

Demand signals are public if you know where to look. The signal is not that a company is
hiring, because every company is hiring. It is that a company has been trying to fill the
same nursing role for four months and cannot.

1. Scans public ATS job boards (Greenhouse, Lever, Ashby) for a vertical's roles
2. Keeps only postings open between 30 and 365 days, which is the aging-seat window
3. Groups postings into a cluster per employer and scores the cluster
4. Drops anything below a quality floor, and any board with more than 400 postings
5. Writes survivors into a queue, deduplicated so the same employer never shows up twice
6. Tracks each one through `new` to `sent` to `replied` to `accepted`
7. Hands accepted ones off to wherever you keep contacts

The full scoring function is in [reference/scoring.md](reference/scoring.md), with the
reasoning behind each weight. Two of its judgments are worth reading before you write your
own: sign-on bonuses carry the heaviest weight, and roles concentrated in one state score
far better than the same roles scattered across eight.

A second signal source, for a wealth-management niche, reads SEC Form 4 and Form 144
filings: an insider registering a large share sale is a liquidity event with a date on it.

## What it does not do

Worth saying plainly, because this is where these projects usually oversell.

**It does not send email.** Marking something as sent records the send. Transmission goes
through whatever you already use. Keeping those separate means a UI bug cannot mail a
stranger.

**It does not find supply.** Judging whether a firm is a real specialist with case studies
you would put in front of a client is taste, not a query. The honest answer after building
this is that the supply half is still a human reviewing a shortlist, and the dismiss rate
there is high on purpose.

**It does not prove anything about your close rate.** It fills a queue. What you do with
the queue is the business.

## The two failures, which are the point

**Searching for demand inside a list of supply.** The obvious shortcut was to take the 989
company domains already sitting in the CRM, strip the TLD, and probe each one as a job
board token. Hit rate was about 1.7%, and the hits were agencies and VCs.

The reason took embarrassingly long to see. Those 989 domains are every company that had
been outreached to, which in a connector business is the supply side. A week went into
searching for demand inside a list of supply.

If you take one thing from this repo: demand and supply live in completely different
places. It is very easy to automate the side you already have a list of, feel productive,
and build a pipeline full of people who do what your clients do.

**Adding boards without scoring them.** The fix was to search the board host directly,
because board URLs contain the company token and a search engine has already indexed what
you are trying to guess:

```
site:job-boards.greenhouse.io "hospice registered nurse case manager"
site:jobs.lever.co "home health registered nurse"
site:jobs.ashbyhq.com "nurse practitioner"
```

Eight queries produced about 40 candidates. Every one was then probed live and scored
before being allowed near the queue, and only 8 of the 40 cleared the floor. The other 32
were real, working boards that would have written junk into the morning queue forever.
Most looked completely fine from the outside.

Do not add a board token without scoring it first.

## What we actually use

Naming the real stack, because "use an email finder" is not useful when you are trying to
get this working. All of it is swappable and none of it is an endorsement. This is just
what is running.

| Job | What we use | Swappable for |
|---|---|---|
| Build the thing | Claude Code | Any coding agent, or write it yourself |
| Demand signal | Greenhouse, Lever and Ashby public board APIs | Nothing. These are the source |
| Wealth-niche signal | SEC EDGAR Form 4 and Form 144 | Nothing, it is the filing system |
| Finding board tokens | Google, by hand, with `site:` queries | Any SERP API if you want it scripted |
| Finding the person | AI-ark | Apollo, Clay, or any people-search API |
| Finding the address | MailTester Ninja | Any finder, but see the note below |
| Verifying the address | MailTester Ninja, same call | Any verifier |
| Storage | SQLite | Postgres when you outgrow one laptop |

The two paid pieces split by job. **AI-ark** answers "who do I contact at this company",
returning a name, title and LinkedIn, and never an email. **MailTester Ninja** answers "what
is their address", and it is worth understanding how: there is no database being looked up.
It generates every plausible local part from the name (first.last, flast, first, and so on),
then validates each one against the mail server in turn and stops at the first mailbox that
is accepted. Finding and verifying are the same call, which is why there is no separate
verification step.

That mechanism is also why resolution sits near 50%. A name whose pattern is not in the list,
or a server that refuses to answer, produces nothing. Expect to lose about half your scored
candidates here, which is exactly why the schema records `candidates_tried` next to
`demand_found`.

Statuses that matter, if you swap in a different verifier: only a confirmed-accepted mailbox
should ever enter a campaign. Catch-all belongs in your records, never in a send.

## Build it

1. Read [TOOLS.md](TOOLS.md) and get the accounts you need. The core loop needs nothing
   paid.
2. Open Claude Code in an empty directory.
3. Paste [BUILD-PROMPT.md](BUILD-PROMPT.md).
4. Expect to spend your real time on `VERTICALS`, not on the code. The engine is only as
   good as the boards you feed it, and that list is yours to build.

[reference/schema.sql](reference/schema.sql) is the data model with the reasoning kept in
the comments. [reference/scoring.md](reference/scoring.md) is the scoring rule and the
board discovery method.

## Credit

The connector method this automates (the signal, the framing, the email-only close) is
taught by Saad in Sales System Mastery. This repo is just the signal-finding step,
industrialised, including the parts that did not work.
