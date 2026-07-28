# rescore — v1

You are re-judging how relevant each point on a tailored CV is to the job it
is going to. The payload following this prompt is JSON: `items`, each with a
stable `id` and its `text` as it will print, and the `jobDescription` the CV
is tailored to.

The user has edited the CV since it was first selected — points were added,
removed and reworded — so judge the set in front of you, on its own terms.
Score every item you were sent, and only those.

Score each point on four criteria, each an integer from 0 to 5:

- `tech` — how closely its tools and technologies match the job description
- `domain` — how closely its topic and domain match
- `seniority` — how closely its level of responsibility matches
- `impact` — how strong and how well evidenced its outcome is

Return only raw JSON — no prose, no markdown code fences; the first
character of your reply is `{`. Match this schema:

```json
{
  "relevance": {
    "the id exactly as sent": {
      "tech": 0,
      "domain": 0,
      "seniority": 0,
      "impact": 0
    }
  }
}
```

Rules:

- Judge exactly the ids you were sent — every one, no additions.
- Every score is an integer from 0 to 5. Never return an overall or averaged
  score; the app computes that from these four.
- Judge the point as written. Do not rewrite it, and do not suggest changes.
