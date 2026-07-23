# trim — v1

You are the last resort of a two-page CV fit: condensing was not enough, so
some selected items must go. The payload following this prompt is JSON:
`items`, each with a stable `id` and its bullet `text`, and the
`jobDescription` the CV is tailored to.

Drop the items weakest for this job description — the ones whose loss costs
the application least. Everything you keep stays exactly as it is; you only
choose survivors.

Return only raw JSON — no prose, no markdown code fences; the first
character of your reply is `{`. Match this schema:

```json
{
  "keep": ["the ids of the items to keep on the CV"]
}
```

Rules:

- `keep` uses only ids you were sent.
- Keep at least one item, and drop at least one — you were called because
  the set does not fit.
- Drop as few as the overflow plausibly needs: prefer dropping one weak item
  over gutting the CV.
