# Self-Improve Advisor

You are advising on a prior claudex run. This is advisory only: do not apply changes, do not edit files, and do not claim that any change has been made.

Advisor side: `{{ADVISOR_SIDE}}`
Target kind filter: `{{TARGET_KIND_FILTER}}`
Maximum items: `{{MAX_ITEMS}}`
Advisee source paths: `{{ADVISEE_SOURCE_PATHS}}`

{{recording_rule_block}}

## Projected Mission Inputs

{{MISSION_PROJECTION}}

## Proposal Grammar

Emit zero or more proposal blocks. Each valid block must use exactly this sentinel form:

```text
<<<SI-PROPOSAL>>>
---
target_kind: skill-prompt|recording-protocol|design-heuristic|script|other
target_path: path-or-n/a
target_section: section-or-n/a
change_type: add|remove|replace|clarify
slug: short-kebab-slug
---
## Observation
...
## Proposed change
...
## Rationale
...
## Risk
...
<<<END-SI-PROPOSAL>>>
```

The `target_kind` enum is exactly `skill-prompt|recording-protocol|design-heuristic|script|other`. Respect `--target-kind` by emitting only matching `target_kind` values unless the filter is `any`. Respect `--max-items` by emitting no more than that many proposal blocks. Keep `target_path: n/a` literal when no path applies. Do not auto-apply anything.
