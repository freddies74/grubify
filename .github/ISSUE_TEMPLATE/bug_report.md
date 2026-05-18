---
name: Bug Report
about: Standard template for reporting bugs and production issues
title: "[Category] Brief description of the problem"
labels: bug
---

## Summary
<!-- 1-2 sentence overview: what is failing, what is the root cause, and what is the user-facing impact. -->

## Severity
<!-- Use one of the following: -->
<!-- **P1 — Production outage.** Service is down or a critical user flow is broken. -->
<!-- **P2 — Major degradation.** Service is partially impaired; workaround may exist. -->
<!-- **P3 — Minor issue.** Non-critical functionality affected; no immediate user impact. -->
<!-- **P4 — Improvement.** Optimization or hardening opportunity. -->

## Root Cause
<!-- - Identify the exact file(s) and line(s) responsible. -->
<!-- - Link to the source file in the repository. -->
<!-- - Include relevant code snippets showing the problematic code. -->
<!-- - Explain *why* the code is wrong and the mechanism of failure. -->

## Evidence from Production
<!-- - **Resource details:** container/app name, revision, resource group. -->
<!-- - **Log excerpts:** Include a table or code block of the most relevant log entries with timestamps (UTC). -->
<!-- - **Metrics:** Include any relevant metrics (memory, CPU, request rates, error rates). -->
<!-- - **Timeline:** Show the progression from normal → degraded → failure. -->

## Impact
<!-- Bullet list of concrete consequences: -->
<!-- - What user-facing functionality is broken? -->
<!-- - What is the blast radius (single endpoint vs. full service)? -->
<!-- - Is there a cascading effect (e.g., crash loops, downstream failures)? -->

## Recommended Fix
<!-- - Provide a concrete diff showing the minimal change needed. -->
<!-- - If multiple approaches exist, list them with trade-offs. -->
<!-- - If the fix requires a follow-up, note that. -->

## Environment

| Property | Value |
|---|---|
| Resource | |
| Resource Group | |
| Subscription | |
| Container Image | |
| CPU / Memory | |
| Revision / Version | |
| File(s) | |
