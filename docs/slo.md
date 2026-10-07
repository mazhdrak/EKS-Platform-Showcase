# Service level objectives: demo-service

| SLI | Measured as | SLO | Window | Error budget |
|---|---|---|---|---|
| Availability | non-5xx responses / all responses on `/api/hello` | 99.5% | 30 days | 0.5%, about 3.6 h of full outage |
| Latency | responses ≤ 250 ms / all responses on `/api/hello` | 99% | 30 days | 1% |

Metrics come from the service itself (`http_requests_total`, `http_request_duration_seconds`),
so they measure what the application saw. A load-balancer-side SLI would also catch requests
that never reached a pod. That is the right upgrade once an ingress exists.

## Alerting

Multi-window, multi-burn-rate alerts, following the Google SRE Workbook (chapter 5).
Both windows must exceed the threshold. The long window gives significance, and the short
window makes the alert reset quickly once the problem stops.

| Alert | Long / short window | Burn rate | Budget consumed at alert | Severity |
|---|---|---|---|---|
| `DemoServiceErrorBudgetBurnFast` | 1h / 5m | 14.4× | 2% | page |
| `DemoServiceErrorBudgetBurnMedium` | 6h / 30m | 6× | 5% | page |
| `DemoServiceErrorBudgetBurnSlow` | 1d / 2h | 3× | 10% | ticket |
| `DemoServiceErrorBudgetBurnChronic` | 3d / 6h | 1× | 10% | ticket |
| `DemoServiceLatencyBudgetBurnFast` | 1h / 5m | 14.4× | 2% | page |
| `DemoServiceErrorBudgetExhausted` | n/a | n/a | 100% | ticket |

### How long until an alert fires?

A burn-rate alert fires once the *long* window's error ratio crosses its threshold:

```
time to fire ≈ (threshold burn rate / actual burn rate) × long window + for:
```

The actual burn rate is the error ratio divided by the 0.5% budget. Some examples, assuming
a full window of clean history beforehand:

| Error rate | Burn | `BurnFast` (14.4×, 1h, `for: 2m`) | `BurnMedium` (6×, 6h, `for: 15m`) |
|---|---|---|---|
| 100% | 200× | ~6 min | ~26 min |
| 20% | 40× | ~24 min | ~69 min |
| 5% | 10× | never | ~3.9 h |

Small error rates are deliberately left to the slower alerts. With less history than the
long window (a new service, or a fresh local cluster) every alert fires sooner than this. This was learned the hard way in
[game day 001](postmortems/2026-10-game-day-001.md), where we expected a 20% error rate to page
in 5 minutes.

Rules: [`gitops/platform/observability/slo-demo-service.yaml`](../gitops/platform/observability/slo-demo-service.yaml).

## Error budget policy

- **Budget > 50%:** ship normally.
- **Budget 0–50%:** reliability work gets priority in planning; risky changes need a rollback plan written in the PR.
- **Budget exhausted:** only fixes and reliability work ship until the 30-day window recovers above 0.

## Caveats

- In local mode Prometheus keeps 2 days of data, so the 30-day figures are partial.
- With no traffic, the latency ratio is intentionally *no data* rather than 0% or 100%.
  Use `make load` for meaningful numbers.
