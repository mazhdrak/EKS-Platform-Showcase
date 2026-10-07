# Runbook: demo-service SLO burn

**Alerts:** `DemoServiceErrorBudgetBurn*`, `DemoServiceLatencyBudgetBurnFast`, `DemoServiceErrorBudgetExhausted`

## 1. Confirm impact (2 min)

- Grafana → **demo-service / SLO**. Is the error ratio or latency elevated *now*, or did it already recover?
- Is traffic normal? A drop in request rate combined with errors can mean upstream failure, not this service.

## 2. Did something change? (most incidents are changes)

```bash
kubectl -n argocd get application demo-service -o jsonpath='{.status.history[-3:]}' | jq
git log --oneline -10 -- apps/demo-service
kubectl -n demo rollout history deploy/demo-service
```

If a deploy lines up with the start of the burn, **revert first, investigate later**:

```bash
git revert <sha> && git push   # Argo CD rolls back within ~2 min
```

Do not `kubectl rollout undo`. Argo CD's self-heal will put the bad version back.

## 3. If no change explains it

```bash
kubectl -n demo get pods -o wide
kubectl -n demo logs deploy/demo-service --since=15m | jq 'select(.status >= 500)' | head
kubectl -n demo get events --sort-by=.lastTimestamp | tail -20
kubectl top pods -n demo
```

| Symptom | Likely cause | Action |
|---|---|---|
| Pods restarting, `OOMKilled` | memory limit too low or leak | raise limit via PR; open a bug |
| Pods `Pending` | node capacity / Spot reclaim | check `kubectl get nodes`; scale the node group |
| Errors only on one node | node problem | `kubectl cordon` + `drain` that node |
| `FAULT_ERROR_RATE` ≠ 0 | game day left on | revert the commit |

## 4. Afterwards

- Paging alert → write a postmortem within 2 working days ([template](../postmortems/TEMPLATE.md)).
- Budget exhausted → the error budget policy in [docs/slo.md](../slo.md) applies.
