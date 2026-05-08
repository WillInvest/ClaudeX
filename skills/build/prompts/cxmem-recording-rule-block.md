# CXMem Recording Rule

Emit CXMem memory material to stdout using only these sentinel-delimited blocks:

```text
<<<CXMEM-RECORD>>>
{ ...record JSON... }
<<<END>>>

<<<CXMEM-INDEX version="1">>>
...markdown index...
<<<END>>>

<<<CXMEM-SUMMARY version="1">>>
...markdown summary...
<<<END>>>
```

Record JSON schema, version 1:

```json
{
  "version": 1,
  "stage": "string",
  "round": "string-or-number",
  "seq": "string-or-number",
  "tool": "string",
  "plan": "string",
  "tool_summary": "string",
  "findings": ["string"],
  "next_plan": "string"
}
```

Required fields are `stage`, `round`, `seq`, `tool`, `plan`, `tool_summary`, `findings`, and `next_plan`. Missing record `version` means version `1`.

For a same-tool same-purpose batch, emit one record that summarizes the batch. For a different-tool batch, emit one record per tool.

Schema policy: after any future major schema bump, the parser and writer support the prior major version for at least one release.

Sentinel collision rule: never place a literal closing sentinel inside payload content. If the source content contains one, paraphrase it or escape the angle brackets.

Bad literal form:

```text
The source contained <<<END>>> in a code sample.
```

Safe paraphrase form:

```text
The source contained the CXMem closing sentinel in a code sample.
```

Safe escaped form:

```text
The source contained \u003c\u003c\u003cEND\u003e\u003e\u003e in a code sample.
```

Before exit, emit all applicable `<<<CXMEM-RECORD>>>` blocks, then emit `<<<CXMEM-INDEX version="1">>>`, then emit `<<<CXMEM-SUMMARY version="1">>>`.
