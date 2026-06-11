# Recovery Baseline

Current recovered output baseline:

```text
tech-priests_0.1.628
```

The source tree should be backpatched from this recovered output before new repair work continues.

Rules:

- Edit `tech-priests_src/` as source.
- Treat `tech-priests_0.1.628/` as recovered truth until a newer versioned output is deliberately prepared.
- Do not hand-patch output folders as the primary workflow.
- Prepare future test outputs by copying source into a new versioned output folder.
- Do not assign or monkey-patch protected Factorio globals such as `log`, `script`, `game`, `defines`, or `storage`.
