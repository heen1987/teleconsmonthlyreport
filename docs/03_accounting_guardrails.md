# Accounting Guardrails

## Principle

LLM may create accounting candidates, but it must not post accounting journals or
change official ledgers by itself.

Allowed LLM tasks:

- summarize evidence
- classify cost type candidates
- recommend account candidates
- draft journal explanations
- detect possible budget or duplicate evidence risks
- prepare report drafts

Forbidden autonomous LLM tasks:

- post journals
- execute payments
- confirm tax filings
- change contract amounts
- bypass approvals
- directly modify accounting ledgers

## Required Controls

- LLM-created journal is always `draft`
- debit and credit totals must match
- account policy must be checked by rule engine
- project budget must be checked from DB values
- duplicate evidence must be detected
- approval authority must be confirmed
- final posting requires human approval
- every state change writes an audit log

