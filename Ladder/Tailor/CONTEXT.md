# Tailor — language

Slice-local terms. `Profile`, `Role`, `Achievement`, `Application`, and
`Tailoring` are defined in the root `CONTEXT.md`; none is restated here.

**Tailor sheet**:
The entry sheet collecting company, role title, and the pasted job
description. Nothing it collects is persisted in this slice — the
`Application` model arrives with cv-export (decisions/0001).
_Avoid_: New Application sheet (until an Application actually exists), JD form

**Tailor run**:
One invocation of tailoring: payload built from the Profile plus the pasted
job description, sent through `IntelligenceService`, validated into a tailor
result.
_Avoid_: generation, tailoring session, query

**Tailor result**:
The validated structure the service returns — selected achievements with
their rephrasings, the CV summary, gaps, and the rationale — held in memory
for review, never persisted.
_Avoid_: proposal (CV Import's term), output, response

**CV summary**:
The short opening paragraph generated per tailor run — tailored to the job
description, grounded strictly in payload facts, never stored on the Profile
(decisions/0006). Rendered by cv-export under the identity header.
_Avoid_: profile summary, personal statement, objective

**Rephrasing**:
The service's proposed per-application wording for one selected Achievement.
The canonical `Achievement.text` stays untouched; a rephrasing exists only in
the tailor result and reviewed outcome.
_Avoid_: rewrite, edit, improved bullet

**Gap**:
A job-description requirement the service found no supporting Achievement
for. Surfaced verbatim from the result; the slice never re-derives gaps.
_Avoid_: weakness, missing skill, shortfall

**Rationale**:
The service's stated reasoning for its selection, surfaced verbatim for
transparency. Persisted later by cv-export as `cvSelectionRationale`.
_Avoid_: justification, explanation, reasoning trace

**Review**:
The side-by-side accept/reject step over each rephrasing — canonical text
beside proposed — producing the reviewed outcome. In this slice review judges
rewordings only; it never adds or removes achievements from the selection.
_Avoid_: approval screen, comparison view, diff

**Reviewed outcome**:
The post-review result: per selected achievement, the accepted rephrasing or
the canonical text. The input cv-export will consume; transient like
everything else here.
_Avoid_: final CV, tailored profile, export

**Repair request**:
The single follow-up request sent when a response fails validation, carrying
the original request content, the invalid response, and the validation
failure for the service to fix (decisions/0004).
_Avoid_: retry, second attempt, re-roll

**API key**:
The user's Anthropic key, entered in Settings and stored only as a Keychain
generic-password item behind the key-store protocol.
_Avoid_: token, credential, secret
