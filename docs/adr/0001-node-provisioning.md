# 0001: EKS managed node groups, not Karpenter (yet)

- Status: accepted
- Date: 2026-10-07

## Context

The cluster needs worker nodes. Options considered: EKS managed node groups, Karpenter, and EKS Auto Mode.

## Decision

One managed node group on Spot, with several instance types (`t3.large`, `t3a.large`, `m5.large`) to improve Spot availability.

## Consequences

- Fewest moving parts, and nodes exist before Argo CD does, so there is no bootstrapping cycle.
- Bin-packing is worse than Karpenter's, and scaling is coarse. Acceptable at this size.
- **When to revisit:** more than about 10 nodes, mixed workload shapes (GPU, arm64), or a cost target
  that needs consolidation. Karpenter would then run on a small managed group and own everything else.
- Auto Mode was rejected for this repo because it hides the node layer, which is the part this showcase is meant to show.
