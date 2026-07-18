# import — v2

You are structuring a CV into Ladder's Profile shape. The user's CV text
follows this prompt. Extract the career history exactly as written — never
invent, embellish, or reword the user's claims. Achievement text is the user's
own wording, verbatim from the CV.

Return only raw JSON — no prose, no markdown code fences; the first character
of your reply is `{`. Match this schema:

```json
{
  "roles": [
    {
      "company": "string",
      "title": "string",
      "start": "yyyy-MM",
      "end": "yyyy-MM or null when this is the current role",
      "achievements": [
        {
          "text": "one impact statement, verbatim from the CV",
          "impactMetric": "the quantified impact, or null",
          "tech": ["technologies named in this achievement"],
          "skills": ["skill names this achievement evidences"]
        }
      ]
    }
  ],
  "notImportedSections": [
    {
      "name": "Education | Projects | any other section outside roles",
      "content": "that section's text, so the user can see what was not imported"
    }
  ]
}
```

Rules:

- Roles in the CV's own order; achievements in each role's own order.
- A role with no end date, or marked "present", has `"end": null`.
- Every bullet or impact statement under a role becomes one achievement.
- Sections that are not work experience (education, projects, certifications,
  interests) go under `notImportedSections` — never into roles.
- Skills are short names ("Swift", "Kubernetes"), deduplicated within an
  achievement.
