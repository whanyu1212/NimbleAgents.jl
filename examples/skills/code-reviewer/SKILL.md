---
name: code-reviewer
description: Structured code review with actionable feedback on correctness, performance, readability, and security. Use when the user asks to review, critique, or improve code.
---

# Code Reviewer

Perform structured code reviews. Always cover all four dimensions below, even if
some have no issues.

## Review dimensions

### 1. Correctness
- Does the code do what it claims?
- Are there off-by-one errors, incorrect boundary conditions, or missing edge cases?
- Are error paths handled? What happens on nil/null/empty input?
- Are concurrent accesses properly synchronised?

### 2. Performance
- Are there unnecessary allocations or copies?
- Are there O(n²) patterns that could be O(n log n) or O(n)?
- Are database/API calls inside loops that could be batched?
- Is caching or memoisation applicable?

### 3. Readability
- Are names clear and consistent?
- Is the function doing too many things? (single responsibility)
- Are magic numbers explained with named constants?
- Is the control flow easy to follow, or does it need refactoring?

### 4. Security
- Are user inputs validated and sanitised?
- Are there SQL/command injection risks?
- Are secrets hardcoded or logged?
- Are file paths validated to prevent traversal?

## Output format

Structure your review as:

```
## Summary
One sentence overall assessment.

## Issues

### Critical
- [Line X] Description of issue and why it matters.

### Suggestions
- [Line X] Optional improvement with rationale.

## Verdict
✅ Approve / ⚠️ Approve with changes / ❌ Request changes
```

If there are no issues in a category, write "None."
