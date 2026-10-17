# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- The frontend nginx now proxies `GET /forecasting/anomaly/detect` to the aggregator (authenticated listener, same as `/model/`) instead of the forecasting pod, so the Anomalies page respects RBAC Teams allocation and cloud-cost filters. Requires an aggregator that serves `/anomaly/detect`. Deployments that set `frontend.nginxConfigMapName` supply their own nginx config and must add this location themselves (KCM-6595)

### Fixed

- Bump network costs image to v0.19.4 to remove CVEs, no code changes (#4877)
- Network costs `additionalSecurityContext` now overrides `securityContext` defaults instead of being ignored (#4825)
- Bump kubecost-modeling image to v0.2.3 (#4884) to fix forecasting run rate calculation
- Cluster Controller Service Accounts now work with a custom name (#4842)

## [3.3.0] - 2026-09-21

> Initial changelog entry — history prior to this release is not captured here.
> See [GitHub releases](https://github.com/kubecost/kubecost/releases) for full history before this file was introduced.
