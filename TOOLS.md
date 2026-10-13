# What you need

The core loop costs nothing. Every demand signal this engine reads is public data behind an
unauthenticated endpoint. You only start paying when you want contact details attached.

## To build it

**Claude Code.** Paste [BUILD-PROMPT.md](BUILD-PROMPT.md) into an empty directory. A first
working version is a short session, and most of that is you checking the scanner output
rather than Claude writing code.

**Python 3.11 or newer.** Standard library plus FastAPI and uvicorn. SQLite ships with
Python, so there is no database to install or host.

## Signal sources, all free

**Greenhouse, Lever and Ashby job boards.** Public JSON, no key, no account, no rate limit
worth worrying about at this volume. These are the demand signal for anything staffing
shaped.

```
https://api.lever.co/v0/postings/{token}?mode=json
https://boards-api.greenhouse.io/v1/boards/{token}/jobs?content=false
https://api.ashbyhq.com/posting-api/job-board/{token}?includeCompensation=false
```

**SEC EDGAR.** Free, if you want the wealth-management variant. Form 4 and Form 144 filings
tell you an insider has registered a large share sale, which is a liquidity event with a
date attached. EDGAR asks for a real User-Agent header identifying you, and that is the
only requirement.

**A search engine, for finding board tokens.** This is the step people skip. You need to
discover which companies have boards worth scanning, and the reliable way is to search the
board host itself:

```
site:job-boards.greenhouse.io "hospice registered nurse case manager"
```

Doing this by hand in a browser is free and works fine. Eight queries produced about 40
candidates, of which 8 survived scoring. If you want it scripted, any SERP API will do, and
at this frequency the cheapest tier covers it.

## Contact details, where it starts costing

The engine finds you a company with a hiring problem. Turning that into a person with an
email address is the paid part, and you should expect to lose candidates here.

Two separate jobs, and we use a different provider for each.

**Finding the person: AI-ark.** Give it a company and it returns a decision maker with name,
title and LinkedIn. It does not return an email, and that is the right division of labour.
Keys come from `AIARK_API_KEY`. If no key is set the enrichment step skips rather than
guessing. Swappable for Apollo, Clay, or any people-search API that takes a domain.

**Finding and verifying the address: MailTester Ninja.** One call does both, and it helps to
know how it works. There is no database being looked up. It generates every plausible local
part from the name (first.last, flast, first, f.last and so on), then validates each against
the mail server in turn, stopping at the first mailbox that is accepted.

That is why resolution sat near 50% on public-company executives. A name whose pattern is
not in the generated list, or a mail server that refuses to answer, returns nothing. Expect
to lose about half of your scored candidates here. It is not a bug, and it is exactly why
the engine records `candidates_tried` alongside `demand_found`.

The statuses it returns, which your sending rule should respect whatever provider you use:

| Result | Meaning | Safe to send |
|---|---|---|
| accepted | the mailbox exists | yes |
| catch-all | the server accepts everything, so this proves nothing | no |
| rejected | the mailbox does not exist | no |
| no answer | throttled or blocked | no |

Only an accepted mailbox should enter a campaign. Catch-all belongs in your records, never
in a send. An unverified list will cost you a sending domain, which is far more expensive
than the lookups.

Price both per lookup rather than per month until you know your volume, since your bill
tracks how many candidates clear the score floor, not how many boards you scan.

## Not needed

**A CRM.** SQLite holds the queue. Add the handoff to a real contact store later, when you
have something worth handing off.

**A sending tool, for v1.** The engine deliberately does not send. Marking something as sent
records the send. Wire your existing sender in afterwards, once you trust the queue.

**A server.** This runs on your laptop. It is a daily batch job and a local page. Host it
when leaving it running overnight starts to matter.

## Rough monthly cost

| | |
|---|---|
| Scanning job boards and EDGAR | free |
| Finding board tokens by hand | free |
| Email lookups | per lookup, and you will burn about half of them |
| Verification | per address, only for what you actually send |
| Hosting | free until you want it running without you |

The honest version: you can run this for nothing until the day you want email addresses
attached, and that bill scales with how many candidates clear your score floor, not with how
many boards you scan.
