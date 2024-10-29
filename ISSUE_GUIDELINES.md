# Issue Guidelines

Issues filed in this repository are specific to the Kubecost Helm chart only. If your issue pertains to the Kubecost application and not the Helm chart, follow the guidance below.

To help route you to the best location, see some examples of feature requests and bug reports [below](#examples-of-helm-requests).

## Kubecost Feature Requests

For all feature requests to Kubecost, please create an enhancement request in the [feature requests and bugs repository](https://github.com/kubecost/features-bugs).

## Kubecost Bug Reports

Bug reports for the Kubecost application stack should be directed to the [feature requests and bugs repository](https://github.com/kubecost/features-bugs).

## Examples of Helm Requests

Find a couple examples of valid Helm feature and bug requests below.

### Helm Feature Requests

In the following example of a feature request, a user is stating an issue related to Prometheus, a dependency of Kubecost, and proposing a solution on how to mitigate it. Prometheus is deployed via the Helm chart and so this feature request would result in a new value made available in the Helm chart which, when used, results in a Kubecost dependency being deployed with a Pod priorityClassName.

**Problem Statement**

"Prometheus-node-exporter might be de-prioritized and stuck in Pending on "well-packed" nodes. It would be good to have the option of setting a priorityClassName to give these pods a higher chance of getting scheduled."

**Solution Description**

"Surface a priorityClassName attr."

### Examples of Helm Bug Reports

In the following example of a bug report, a user is claiming that using an existing capability in the Helm chart's value file does not work in a specific configuration. Because `global.podAnnotations` does exist yet when used with multiple annotations causes a failure, this failure is directly attributable to the Helm chart's templating language and not a function of any of the Kubecost application components.

**Problem Statement**

"When the `global.podAnnotations` flag is used and multiple annotations are written, Kubecost fails to deploy because of a templating issue in the cost-analyzer Deployment."

**Solution Description**

"The `global.podAnnotations` flag should support defining multiple annotations."
