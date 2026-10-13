# Scoring, and how to find boards worth scanning

The engine is only as good as the list of board tokens you feed it. This is where your time
actually goes, and it is the part no prompt can do for you.

## Finding board tokens

The first instinct is to take companies you already know about and guess their board slug.
Do not. See the failure note at the bottom.

What works is searching the board host directly. Board URLs contain the company token, so a
search engine has already indexed the exact thing you are trying to guess:

```
site:job-boards.greenhouse.io "hospice registered nurse case manager"
site:jobs.lever.co "home health registered nurse"
site:jobs.ashbyhq.com "nurse practitioner"
```

Use the role phrase your clients actually place, not the industry. "Registered nurse case
manager" finds employers. "Healthcare" finds nothing useful.

Eight queries of this shape produced about 40 candidate tokens.

## Then score before you add

Of those 40, eight cleared the floor. The other 32 were real, live, reachable boards. They
would not have thrown an error. They would have quietly written junk into the queue every
morning, and most of them looked completely fine from the outside.

So the rule is: probe every candidate live, score it, and only then add it to the config.

## What the score is made of

Score an employer cluster, not an individual posting. One company with nine open nursing
roles across three states is a far better target than nine companies with one each, and only
a cluster view can see that.

**Volume.** How many placeable roles are open right now. This is the backbone of the score.

**Recency.** When were they posted. A role posted last week is a live problem. One from four
months ago has either been filled or is a ghost listing.

**Geographic spread.** Roles across several states is a harder problem than several roles in
one building, and harder problems are worth more to someone who solves them.

**Placeability.** Does the title match a role your clients actually place. Keep this as an
explicit list of phrases per vertical and match it lowercased against the title. This single
list is what stops a healthcare scanner queueing a company's software engineers.

**Bonus language.** If the posting text mentions a signing bonus or a referral bonus, the
employer has already admitted in public that it cannot fill the role on its own. Weight it.

Make the score an integer, keep the function pure so you can test it without the network,
and set a floor. Start at 55 and move it based on what you find yourself dismissing.

## Quality floor beats novelty

When choosing what to write into the queue, apply the floor first and prefer unseen
employers second, not the other way round.

Getting this backwards produces a queue full of large national employers with their own
in-house recruiting teams, selected purely because they had not been seen before. They score
badly for a reason. An empty run is better than a weak one, because the scarce resource is
your morning, not the row count.

## The failure worth repeating

The shortcut that did not work: take the 989 company domains already in the CRM, strip the
TLD, probe each as a board token across all three platforms. Hit rate about 1.7%, and the
hits were agencies and VCs.

The reason is structural, not technical. Those 989 domains were every company that had been
outreached to, which in a connector business is the supply side. It was a week spent
searching for demand inside a list of supply.

Demand and supply live in different places. Automating the side you already have a list of
feels productive and gives you a pipeline full of people who do exactly what your clients
do.
