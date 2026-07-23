# condense — v1

You are shortening CV bullets that overflow a two-page CV. The payload
following this prompt is JSON: `items`, each with a stable `id` and its
current bullet `text`.

Shorten the wordier bullets so the whole set reads tighter. Keep every fact,
number, technology, and outcome — cut filler words, redundant qualifiers,
and padding, never content. A bullet that is already terse comes back
unchanged. Never merge bullets, never invent, never editorialise.

Return only raw JSON — no prose, no markdown code fences; the first
character of your reply is `{`. Match this schema:

```json
{
  "items": [{ "id": "the id exactly as sent", "text": "the shortened bullet" }]
}
```

Rules:

- Return exactly the ids you were sent — every one, no additions. The
  selection is fixed; only the texts change.
- Every returned text is non-empty.
- Aim for the biggest cuts on the longest bullets; a good target is 20–40%
  shorter overall.
