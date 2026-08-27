## GitHub Actions Version Management

- MUST verify a GitHub Action version exists before updating or downgrading it
- MUST use execute_command to validate versions online: 
  `curl -s https://api.github.com/repos/<owner>/<repo>/git/refs/tags | grep '"ref"' | grep '@v<N>'`
- Or check the GitHub Marketplace page directly
- NEVER assume a version does not exist based on training knowledge alone
- When modifying any GitHub Action, MUST verify that all actions in the workflow are current
- MUST use online lookups—do not depend on stale training data
- If a new version is available, always suggest updating it
