# iShell dependencies

The project pins native dependencies as Git submodules and uses HTTPS package sources for the Python setup flow.

| Dependency | Source | Revision |
|---|---|---|
| libapps | `ish-app/libapps` | `b8cacae35e5b11d64bb736a053921c16ca7faf9e` (latest available on `master`) |
| libarchive | `libarchive/libarchive` | `9525f90ca4bd14c7b335e2f8c84a4607b0af6bdf` (`v3.8.1`) |
| Linux/iSH kernel | `ish-app/linux` | existing pinned revision `8ec9bf17f89c6dba818f3ed2427de4223e78644` |

## Runtime package sources

- Alpine Linux x86 v3.19 main: `https://dl-cdn.alpinelinux.org/alpine/v3.19/main`
- Alpine Linux x86 v3.19 community: `https://dl-cdn.alpinelinux.org/alpine/v3.19/community`
- Python packages: `https://pypi.org/simple`

The first-launch Python setup checks for missing packages and asks before installing them. It creates `ishell-doctor` and an isolated-environment workflow using `python3 -m venv`. Large data-science packages are intentionally not installed automatically.

The upstream `ish-app/linux` remote currently exposes no fetchable branch/tag, so its existing pinned revision is intentionally preserved rather than replaced with an unverifiable commit.
