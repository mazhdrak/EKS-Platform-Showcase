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

Rules: [`gitops/platform/observability/slo-demo-service.yaml`](../gitops/platform/observability/slo-demo-service.yaml).

## Error budget policy

- **Budget > 50%:** ship normally.
- **Budget 0–50%:** reliability work gets priority in planning; risky changes need a rollback plan written in the PR.
- **Budget exhausted:** only fixes and reliability work ship until the 30-day window recovers above 0.

## Caveats

- In local mode Prometheus keeps 2 days of data, so the 30-day figures are partial.
- With no traffic, the latency ratio is intentionally *no data* rather than 0% or 100%.
  Use `make load` for meaningful numbers.
