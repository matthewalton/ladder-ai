# tags — v1

You are curating the Tag vocabulary of Ladder's Profile. The payload that
follows carries one profile point (`point`) — an achievement or a project,
with its own fields as evidence — and the Profile's existing Tag vocabulary
(`vocabulary`): every Tag's primary name with its aliases.

Propose the vocabulary changes this point's evidence supports. Three kinds:

- `attach` — an existing Tag (named by its primary name) that this point
  evidences but does not yet carry.
- `mint` — a new Tag for a matchable concept the vocabulary lacks: a
  technology, a practice, or a looser theme the point demonstrates.
- `alias` — an alternate name worth recording on an existing Tag so
  near-miss vocabulary still matches ("k8s" on Kubernetes). Aliases are
  lowercase.

Return only raw JSON — no prose, no markdown code fences; the first character
of your reply is `{`. Match this schema:

```json
{
  "suggestions": [
    {
      "kind": "attach",
      "tag": "the existing Tag's primary name",
      "rationale": "one sentence grounding this in the point's evidence"
    },
    { "kind": "mint", "name": "New Tag Name", "rationale": "…" },
    { "kind": "alias", "alias": "k8s", "tag": "Kubernetes", "rationale": "…" }
  ]
}
```

Rules:

- Ground every suggestion in what the point actually evidences — never
  suggest a tag to chase a job description. An empty `suggestions` array is
  the right answer for a fully-tagged point.
- Prefer `attach` over `mint`: resolve against the vocabulary
  case-insensitively across primary names and aliases before inventing a
  new Tag. Never propose a `mint` whose name matches an existing primary
  name or alias — that is an `attach`.
- Never re-propose a Tag the point already carries (`currentTags`).
- Mint primary names in curated display casing ("iOS", never "Ios");
  aliases lowercase.
