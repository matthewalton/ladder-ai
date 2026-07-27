# 0004 — Validation failure gets exactly one repair request

Status: accepted (from ROADMAP: "schema validation with one retry-with-repair")

## Context

ARCHITECTURE.md §6 mitigates LLM structured-output drift with
"JSON-schema-validated responses; retry-with-repair loop". [CVIMPORT-10]
deferred the loop to this slice. Unlimited retries hide a broken prompt and
burn the user's tokens; zero retries fail runs a single repair would save.

## Decision

A response failing validation (schema decode or referential check against the
Profile) triggers exactly one repair request carrying the original request,
the invalid response, and the validation failure. A repair response failing
validation fails the run — never a third request.

## Consequences

- Worst case per run is two requests; cost and latency stay bounded.
- [TAILOR-9] and [TAILOR-10] pin the loop's two exits; the fixture service's
  recorded requests make the count assertable.
- Referential validation ([TAILOR-8]) and schema validation share one repair
  path — the service is told what to fix in either case.
