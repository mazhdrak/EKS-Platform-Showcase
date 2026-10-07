# 0003: Page on SLO burn, not on resource thresholds

- Status: accepted
- Date: 2026-10-07

## Context

Alerts like "CPU > 80%" or "pod restarted" fire often, correlate poorly with user impact,
and train people to ignore pages.

## Decision

- User-facing services get explicit SLOs ([docs/slo.md](../slo.md)).
- Paging alerts are multi-window, multi-burn-rate alerts on those SLOs.
- Resource and Kubernetes-health alerts shipped by kube-prometheus-stack stay, routed as
  tickets rather than pages.
- Every paging alert has a `runbook_url`.

## Consequences

- Fewer, more meaningful pages. A slow trickle of errors creates a ticket, not a 3 a.m. wake-up.
- Each new service needs an SLO definition before it can page anyone. That is intentional.
