# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `mcp.extraEnv` and `mcp.fullImageName` pass additional environment variables to, and override the image of, the MCP server (#4954)
- The MCP server now trusts the custom CAs configured through `global.updateCaTrust` (#4954)

### Changed

- Bump the `mcp-kubecost` subchart to 0.18.2 (#4954). `mcp.image.registry` is now honored instead of always being overridden by `global.imageRegistry`
- SMTP configuration through `kubecostProductConfigs.smtp` is available in all editions. Kubecost's built-in email service stops working on 2026-11-30 (#4945)

### Fixed

- The aggregator now mounts the SMTP secret when `kubecostProductConfigs.smtp.config` is set, so an inline SMTP config takes effect. Before, only `smtp.secretname` was mounted (#4945)
- Bump network costs image to v0.19.4 to remove CVEs, no code changes (#4877)
- Network costs `additionalSecurityContext` now overrides `securityContext` defaults instead of being ignored (#4825)
- Bump kubecost-modeling image to v0.2.3 (#4884) to fix forecasting run rate calculation
- Cluster Controller Service Accounts now work with a custom name (#4842)

### Removed

- `mcp.config.useCacViews` was removed from the MCP subchart. It is ignored if set (#4954)

## [3.3.0] - 2026-09-21

> Initial changelog entry — history prior to this release is not captured here.
> See [GitHub releases](https://github.com/kubecost/kubecost/releases) for full history before this file was introduced.
