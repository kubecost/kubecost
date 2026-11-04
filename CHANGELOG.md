# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Bump network costs image to v0.19.4 to remove CVEs, no code changes (#4877)
- Network costs `additionalSecurityContext` now overrides `securityContext` defaults instead of being ignored (#4825)
- Bump kubecost-modeling image to v0.2.3 (#4884) to fix forecasting run rate calculation
- Cluster Controller Service Accounts now work with a custom name (#4842)

## [3.4.0] - Unreleased

### Fixed

- Aggregator now mounts the SMTP secret when `kubecostProductConfigs.smtp.config` is set (KCM-6687)

### Deprecated

- The built-in SMTP server will be discontinued on 2026-11-30. SMTP configuration through `kubecostProductConfigs.smtp` is available in all editions.

## [3.3.0] - 2026-09-21

> Initial changelog entry — history prior to this release is not captured here.
> See [GitHub releases](https://github.com/kubecost/kubecost/releases) for full history before this file was introduced.
