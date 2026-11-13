# Persistent configs storage

> **Not yet supported in Kubecost 3.3.** `aggregator.persistentConfigsStorage.enabled` and
> `aggregator.persistentConfigsStorage.removeClaimTemplate` are groundwork for a future release.
> Do not set `enabled: false` on Kubecost 3.3 or earlier: the Aggregator still reads settings,
> reports, and budgets from the `persistent-configs` volume, and they would no longer be visible.

The Aggregator StatefulSet has two PersistentVolumeClaims:

| Claim | Mounted at | Holds |
| --- | --- | --- |
| `aggregator-db-storage-*` | Aggregator database path | The Aggregator database. Not affected by anything on this page. |
| `persistent-configs-*` | `/var/configs` | Flat files for settings and reports created in the UI. |

Once the Aggregator keeps this configuration in its database, the `persistent-configs` claim is
no longer needed. This page describes how to stop mounting it, and optionally remove it.

## Values

| Value | Default | Effect |
| --- | --- | --- |
| `aggregator.persistentConfigsStorage.enabled` | `true` | When `false`, `/var/configs` is mounted as an emptyDir (volume `configs-scratch`) instead of the PVC. |
| `aggregator.persistentConfigsStorage.removeClaimTemplate` | `false` | Only takes effect when `enabled` is `false`. Drops the `persistent-configs` claim template from the StatefulSet. |

## Stage 1: stop mounting the volume

```sh
helm upgrade kubecost <chart> --namespace kubecost --reuse-values \
  --set aggregator.persistentConfigsStorage.enabled=false
```

- This is a plain `helm upgrade`. The Aggregator pod restarts once.
- The claim template and the existing `persistent-configs-*` PVC stay, but nothing mounts them.
  The old files remain on the volume.
- The emptyDir is named `configs-scratch`, not `persistent-configs`. The StatefulSet controller
  replaces any pod volume named after a claim template with the claim itself, so reusing the
  name would silently keep the PVC mounted.
- Anything written to `/var/configs` is lost when the pod restarts.

After upgrading, confirm the settings, reports, and budgets you expect are present in the UI.

### Rolling back

Either of these restores the old files, because the PVC was never touched:

```sh
helm rollback kubecost --namespace kubecost
# or
helm upgrade kubecost <chart> --namespace kubecost --reuse-values \
  --set aggregator.persistentConfigsStorage.enabled=true
```

If you have already completed stage 2, only the second form works, and only if the old PVC
still exists.

## Stage 2 (optional): remove the claim template

This only saves the cost of the unused PVC. Do it after stage 1 has been running long enough
that you are sure you will not roll back.

StatefulSet `volumeClaimTemplates` are immutable, so an existing release needs the StatefulSet
deleted (without deleting its pods) before `helm upgrade` can recreate it:

```sh
# 1. Back up the StatefulSet, then delete it and leave the pods running.
kubectl --namespace kubecost get statefulset kubecost-aggregator -o yaml > aggregator-statefulset.yaml
kubectl --namespace kubecost delete statefulset kubecost-aggregator --cascade=orphan

# 2. Upgrade with the claim template removed. --atomic rolls back if the upgrade fails.
helm upgrade kubecost <chart> --namespace kubecost --reuse-values \
  --set aggregator.persistentConfigsStorage.removeClaimTemplate=true --atomic
```

Replace `kubecost` and `kubecost-aggregator` with your release namespace and the Aggregator
StatefulSet name (`<release>-aggregator`).

Fresh installs can set both `enabled=false` and `removeClaimTemplate=true` at once, with no
manual step.

## Deleting the unused PVC

Removing the claim template does not delete the PVC. Delete it once you no longer need the old files:

```sh
kubectl --namespace kubecost delete pvc persistent-configs-kubecost-aggregator-<ordinal>
```

**Do not delete `aggregator-db-storage-*`.** That claim holds the Aggregator database.
