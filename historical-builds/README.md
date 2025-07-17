# Accessing historical builds

This directory is now defunct. This directory used to contain files for every released version of `kubecost.yaml` across time.
All releases of the Kubecost Helm chart, starting with version v1.100.0 are tagged appropriately in version control.
To view source code for these versions, you can clone the repo and check out the appropriate tag:

```sh
git clone https://github.com/kubecost/cost-analyzer-helm-chart.git
cd cost-analyzer-helm-chart
git checkout v1.100.0
```

To view older historical builds of `kubecost.yaml`, check out the repo to any commit v1.99.0 or earlier, and this directory will be populated with copies of older build files.
