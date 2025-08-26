# Kubecost Helm Chart

## Install

The chart is not yet released, so we need to use the devel flag.

```sh
helm helm repo add kubecost-30-testing https://kubecost.github.io/kubecost/
helm repo update

helm install kubecost kubecost-30-testing/kubecost \
  --namespace kubecost \
  --create-namespace \
  --devel
```

## Uninstall

Uninstall the chart.

```sh
helm uninstall kubecost-30-testing -n kubecost
```

Note that when uninstalling, the persistent volume for the Kubecost metrics are not deleted. You can delete them manually by deleting the namespace.

```sh
kubectl delete namespace kubecost
```
