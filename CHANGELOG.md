# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `aggregator.persistentConfigsStorage.enabled` (default `true`). Set it to `false` to stop mounting the `persistent-configs` PVC: `/var/configs` becomes an emptyDir (volume `configs-scratch`) and the ClickHouse volume is unchanged. The claim template and the existing PVC stay, so this is a plain `helm upgrade` that restarts the aggregator pod and can be reverted with `helm rollback`
- `aggregator.persistentConfigsStorage.removeClaimTemplate` (default `false`). Together with `enabled: false`, drops the `persistent-configs` claim template from the aggregator StatefulSet. On an existing release this needs `kubectl delete statefulset --cascade=orphan` before `helm upgrade`, because volumeClaimTemplates are immutable
- `NOTES.txt` prints next steps when `aggregator.persistentConfigsStorage.enabled` is `false`, linking to [docs/persistent-configs-storage.md](docs/persistent-configs-storage.md) for rollback, claim template removal, and PVC cleanup. These settings are not yet supported in Kubecost 3.3 and are targeted for a future release

### Changed

- SMTP configuration through `kubecostProductConfigs.smtp` is available in all editions. Kubecost's built-in email service stops working on 2026-11-30 (#4945)

### Fixed

- The aggregator now mounts the SMTP secret when `kubecostProductConfigs.smtp.config` is set, so an inline SMTP config takes effect. Before, only `smtp.secretname` was mounted (#4945)
- Bump network costs image to v0.19.4 to remove CVEs, no code changes (#4877)
- Network costs `additionalSecurityContext` now overrides `securityContext` defaults instead of being ignored (#4825)
- Bump kubecost-modeling image to v0.2.3 (#4884) to fix forecasting run rate calculation
- Cluster Controller Service Accounts now work with a custom name (#4842)

## [3.3.0] - 2026-09-21

> Initial changelog entry — history prior to this release is not captured here.
> See [GitHub releases](https://github.com/kubecost/kubecost/releases) for full history before this file was introduced.
