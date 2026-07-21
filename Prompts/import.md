# import — v3

You are structuring a CV into Ladder's Profile shape. The user's CV text
follows this prompt. Extract the career history exactly as written — never
invent, embellish, or reword the user's claims. Achievement text is the user's
own wording, verbatim from the CV.

Return only raw JSON — no prose, no markdown code fences; the first character
of your reply is `{`. Match this schema:

```json
{
  "identity": {
    "name": "the person's name, from the CV header — required, never empty",
    "headline": "their title line, e.g. 'Software Engineer · React / TypeScript', or null",
    "contact": {
      "email": "string or null",
      "phone": "string or null",
      "location": "string or null, e.g. 'London, UK'",
      "link": "their personal/portfolio URL or null — not per-project links"
    }
  },
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
  "education": [
    {
      "institution": "string",
      "qualification": "e.g. 'B.Sc. Computer Science'",
      "start": "yyyy-MM",
      "end": "yyyy-MM or null when still in progress",
      "detail": "grade, honours, or other detail line, or null"
    }
  ],
  "projects": [
    {
      "name": "string",
      "link": "the project's URL, or null",
      "summary": "the project's one-line description, or null",
      "points": [
        {
          "text": "one point about the project, verbatim from the CV",
          "impactMetric": "the quantified impact, or null",
          "tech": ["technologies named in this point"],
          "skills": ["skill names this point evidences"]
        }
      ]
    }
  ],
  "interests": ["short interest strings, in the CV's own order"],
  "notImportedSections": [
    {
      "name": "Summary | Certifications | any other section outside the schema",
      "content": "that section's text, so the user can see what was not imported"
    }
  ]
}
```

Rules:

- `identity.name` is required and never empty; a CV always names its owner.
- Roles in the CV's own order; achievements in each role's own order. The
  same for education, projects, project points, and interests.
- A role with no end date, or marked "present", has `"end": null`; the same
  for in-progress education.
- Every bullet or impact statement under a role becomes one achievement;
  every bullet or sentence describing a project becomes one project point. A
  project described by a single paragraph gets that paragraph split into its
  natural statements as points.
- Skills are short names ("Swift", "Kubernetes"), deduplicated within an
  achievement. A skills section in the CV informs the skills you attach to
  achievements and points — it is not a section of its own in the schema.
- The CV's summary/profile paragraph goes under `notImportedSections` (name
  it as the CV does, e.g. "Profile" or "Summary") — never into the schema.
  The same for certifications, references, and anything else the schema has
  no place for. Dates that are years only ("2016 – 2021") become January of
  that year ("2016-01").
