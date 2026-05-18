---
name: test-restructure
description: Refactor an existing test suite — snapshot, classify, restructure module by module, compare. — refactoriza las pruebas / arregla los tests
---

Invoke the agent-skills:test-restructure skill.

1. Capture a full test snapshot (pass/fail baseline) before touching anything
2. Walk the test files and classify each: RESTRUCTURE, REFACTOR, RELOCATE, or SKIP
3. Present the classification report and wait for confirmation
4. Refactor module by module — run tests after each module
5. Compare the final snapshot against the baseline: no regressions allowed
