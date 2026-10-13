# Scoring

This is the real function, with the reasoning. It is the part worth copying.

## The signal is an aging seat, not an open seat

"They are hiring" is not a signal. Every company is hiring. The signal is a role they have
been trying to fill and cannot.

So the scanner only keeps postings open between 30 and 365 days.

```python
MIN_DAYS_OPEN, MAX_DAYS_OPEN = 30, 365
```

Under 30 days the employer is still working it themselves and has no reason to talk to you.
Over 365 days it is usually a ghost listing nobody took down. The middle is where somebody
is quietly frustrated.

## Skip boards that are too big

```python
MAX_BOARD = 400          # a board above this scores 0 and is dropped
```

A company with 600 open roles has a recruiting department. They are not short of help, they
are short of candidates, and they already pay people to solve that. This single cap removed
most of the noise.

## The function

```python
MIN_WRITE_SCORE = 55     # below this, it never reaches the queue

def score_cluster(c):
    if c["board_size"] > MAX_BOARD:
        return 0

    real_states = [x for x in c["states"] if x not in ("unknown", "remote")]
    n = len(real_states)
    s = 0

    s += min(c["placeable"], 12) * 3                     # aging seats you can place
    s += min(c["bonus_roles"], 10) * 4                   # seats advertising a bonus
    s += 12 if c["bonus_total_usd"] >= 50000 else (6 if c["bonus_total_usd"] else 0)
    s += min(int(c["stale_pct"] / 5), 12)                # share of the board that is stale
    s += 8 if c["median_days"] >= 90 else (5 if c["median_days"] >= 60 else 0)

    if n == 1:   s += 10                                 # one state is one sellable desk
    elif n == 2: s += 4
    elif n >= 6: s -= 10                                 # too scattered for one desk
    if n == 0:   s -= 8                                  # remote only, no desk to sell

    return max(0, min(99, s))
```

## Why each term is weighted the way it is

**Sign-on bonuses carry the most weight per unit, at 4 points each plus up to 12 more for
the total value.** A company advertising money to fill a seat has publicly stated three
things: it has budget, it has already tried money, and it still cannot fill the role. That
is a much louder signal than an old posting, which only proves the posting is old.

**Volume is capped at 12 placeable seats.** One desk can only work so many roles. Six
hundred openings is not 150 times better than four, it is evidence of a different kind of
company, and that company is handled by `MAX_BOARD` anyway.

**Stale percentage measures the share of the whole board that is aging**, not the raw count.
Four aging seats out of six is a company with a problem. Four out of four hundred is a
rounding error.

**Geography is counted backwards from the obvious.** One state scores +10 and six or more
scores minus 10. This is the term most people would get wrong, including an earlier version
of this file.

The reason: you are selling this to one staffing partner, and one partner works one desk.
Roles concentrated in a single state are a desk somebody can actually take. The same number
of roles scattered across eight states is eight small problems that no single partner wants.
Remote-only scores worst of all, because there is no geography to sell at all.

**States are matched against a real list, not split on commas.** Locations arrive as free
text: "Grand Rapids", "Ocala FL", "Arlington, Texas". Splitting on the trailing comma reads
city names as states and inflates the state count, which then corrupts the geography term.
Match against an actual state table and return "unknown" rather than guessing.

## Tuning it

The floor of 55 is where this landed after watching what got dismissed by hand. Start there,
then move it based on what you find yourself throwing away. If you are dismissing most of
the queue, the floor is too low. If the queue is empty on a good day, it is too high.

Keep the function pure, with no network calls inside it, so you can test it against saved
clusters and change weights without scanning anything.

## Finding boards worth scanning

The engine is only as good as the board tokens you feed it. This is where your time actually
goes.

The instinct is to take companies you already know and guess their board slug. Do not. See
below.

What works is searching the board host directly, because board URLs contain the company
token, so a search engine has already indexed the thing you are trying to guess:

```
site:job-boards.greenhouse.io "hospice registered nurse case manager"
site:jobs.lever.co "home health registered nurse"
site:jobs.ashbyhq.com "nurse practitioner"
```

Use the role phrase your clients place, not the industry. "Registered nurse case manager"
finds employers. "Healthcare" finds nothing useful.

Eight queries of that shape produced about 40 candidate tokens.

## Score before you add

Of those 40, eight cleared the floor. The other 32 were real, live, reachable boards. They
would not have thrown an error. They would have quietly written junk into the queue every
morning, and most looked completely fine from the outside.

Probe every candidate live, score it, and only then add it to the config.

## The failure worth repeating

The shortcut that did not work: take the 989 company domains already in the CRM, strip the
TLD, probe each as a board token across all three platforms. Hit rate about 1.7%, and the
hits were agencies and VCs.

The reason is structural. Those 989 domains were every company that had been outreached to,
which in a connector business is the supply side. It was a week spent searching for demand
inside a list of supply.

Demand and supply live in different places. Automating the side you already have a list of
feels productive and gives you a pipeline full of people who do exactly what your clients
do.
