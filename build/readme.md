<h3 align="left">
  <img width="600" height="128" alt="image" src="https://raw.githubusercontent.com/artemis-env0/Packages/refs/heads/main/Images/Logo%20Pack/01%20Main%20Logo/Digital/SVG/envzero_logomark_fullcolor_rgb.svg"/>
</h3>

-----
## Env0 Agent Custom Dockerfile(s) Image (AMD64) :: Breakdown

This README documents the **latest-safe** Env0 agent image variant. It pins each tool to specific versions and installs them with minimal dependencies to keep CaaS Hub / Aqua scans as close to zero as practicable.

----

### Contents (What’s in the image)

| Component | Version | Install Method | Notes |
|---|---:|---|---|
| **Base (Env0 agent)** | `AGENT_VERSION=4.0.34` | `FROM ghcr.io/env0/deployment-agent:${AGENT_VERSION}` | Keep aligned with your Env0 Helm chart. |
| **kubectl** | **v1.34.2** | Direct AMD64 binary from `dl.k8s.io` | Current stable line with recent fixes. |
| **PowerShell** | **7.5.4** | Official GitHub release tarball | Only minimal Alpine libs added (`icu-libs`, etc.). |
| **Google Cloud SDK** | **549.0.0** | Tarball extract only (no `install.sh`) | Avoids installer’s extra network calls & component churn. |
| **AWS CLI v2** | **2.32.13** | Official bundled installer (zip) | Self-contained :  avoids Python CVEs. |
| **Azure CLI** | **2.81.0** | `pip` install with temporary build deps | Pinned :  build deps removed post-install. |
| **OPA (Open Policy Agent)** | **1.11.1** | Static AMD64 binary + SHA256 verification | Static build avoids musl/glibc symbol issues. |
| **Corporate CA trust** | N/A | Certs copied + env vars wired | Ensures outbound TLS via your internal CA. |
| **Python deps** | Minimal | Targeted `pip` installs only | Smaller footprint :  fewer CVEs. |
| **Runtime layout** | N/A | `/tmp` writable :  `/var/tmp` → `/tmp` | Works in read-only-root runtimes (Env0). |

-----

### Where versions are set (in your Dockerfile)

```dockerfile
# Base agent
ARG AGENT_VERSION=4.0.34

# kubectl
ARG KUBECTL_VERSION=v1.34.2

# PowerShell
ARG PWSH_VERSION=7.5.4

# Google Cloud SDK
ARG GCLOUD_VERSION=549.0.0

# Azure CLI
ARG AZ_CLI_VERSION=2.81.0

# OPA (static)
ARG OPA_VERSION=1.11.1
```

- **AWS CLI v2** is pinned through its installer URL (AMD64):  
  `https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip`
- **OPA** integrity is enforced by downloading the `.sha256` alongside the binary and verifying with `sha256sum`.

-----

### Why these versions & methods

- **kubectl v1.34.2**: Latest stable :  single binary keeps dependency surface tiny.
- **PowerShell 7.5.4**: Latest minimal runtime libs only.
- **gcloud 549.0.0**: Extract-only (no `install.sh`), avoiding networked component pulls that often trigger SSL/CERT prompts and CVE noise.
- **AWS CLI v2 2.32.13**: Self-contained bundle dramatically fewer Python CVEs than `awscli` from PyPI.
- **Azure CLI 2.81.0**: Pinned to a known PyPI build :  build deps installed only for the install and then removed.
- **OPA 1.11.1 (static)**: Static AMD64 build avoids runtime symbol errors (e.g., `__res_init`) and shared-lib CVEs on Alpine.

-----

### TLS / corporate CA wiring

Your `aries*.crt` files are added to the system trust store and appended to `/etc/ssl/certs/ca-certificates.crt`. These variables ensure common tooling uses that bundle:

```
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
PIP_CERT=/etc/ssl/certs/ca-certificates.crt
```

-----

### Read-only runtime support (Env0-friendly)

- `/tmp` is world-writable and `/var/tmp` is symlinked to `/tmp`, so tools with temp-file needs won’t fail in read-only root setups (like Env0).
- The image drops privileges to non-root `65532:65532` at the end.

-----

### Build & tag

```bash
# From the Dockerfile directory:
docker build   --build-arg AGENT_VERSION=4.0.34   --build-arg KUBECTL_VERSION=v1.34.2   --build-arg PWSH_VERSION=7.5.4   --build-arg GCLOUD_VERSION=549.0.0   --build-arg AZ_CLI_VERSION=2.81.0   --build-arg OPA_VERSION=1.11.1   -t your-registry/env0-agent:latest-safe .

# Push if needed:
docker push your-registry/env0-agent:latest-safe
```

> Keep the **Env0 base tag** aligned with the Helm chart you deploy to avoid inheriting CVEs from upstream layers.

-----

### Scanning tips (to keep CVEs near zero)

- **Scan the final, pushed image** (not intermediate layers). Some scanners surface findings from layers that aren’t in the final artifact.
- **Pin versions** (as shown). Floating tags change under your feet and often introduce new CVEs.
- Prefer **static/single-binary tools** (kubectl, OPA, AWS CLI v2) to avoid deep dependency trees.
- **Remove build dependencies** immediately after use (the Dockerfile does this for Azure CLI).
- If a scanner flags **Go stdlib** inside upstream vendor binaries (e.g., the Env0 base or third-party CLIs), the true fix is an **upstream image update** :  swapping the base or the vendor binary version is your lever.

-----

### Download

- <img width="16" height="16" alt="image" src="https://raw.githubusercontent.com/artemis-env0/Packages/refs/heads/main/Images/Logo%20Pack/03%20Logomark/Digital/SVG/envzero_logomark_fullcolor_rgb.svg"/> Download env0 S.H.A.G. Agent Dockerfile DF-v4.0.34d LTSB:  [`env0_docker_img.dockerfile`](https://github.com/artemis-env0/Agent/releases/download/DF-4.0.34d/env0_docker_img_master_LTSB.dockerfile)
- <img width="16" height="16" alt="image" src="https://raw.githubusercontent.com/artemis-env0/Packages/refs/heads/main/Images/Logo%20Pack/03%20Logomark/Digital/SVG/envzero_logomark_fullcolor_rgb.svg"/> Download env0 S.H.A.G. Agent Dockerfile DF-v4.0.34d Standard:  [`env0_docker_img.dockerfile`](https://github.com/artemis-env0/Agent/releases/download/DF-4.0.34d/env0_docker_img_master_STD.dockerfile)
- <img width="16" height="16" alt="image" src="https://raw.githubusercontent.com/artemis-env0/Packages/refs/heads/main/Images/Logo%20Pack/03%20Logomark/Digital/SVG/envzero_logomark_fullcolor_rgb.svg"/> Download env0 S.H.A.G. Agent Dockerfile DF-v4.0.34d Extended:  [`env0_docker_img.dockerfile`](https://github.com/artemis-env0/Agent/releases/download/DF-4.0.34d/env0_docker_img_master_EXT.dockerfile)

-----

### Updating later

1. Bump the `ARG` values above (and the AWS CLI v2 URL if the major/minor changes).
2. Rebuild and rescan the **final tag**.
3. If a specific CVE appears:
   - Identify which binary/layer it belongs to.
   - If it’s **upstream**, look for a newer vendor tag.
   - If it’s a **Python package**, pin/upgrade in the Dockerfile and rebuild.

-----

### Troubleshooting

- **gcloud SSL/CERT errors** during build: the tarball-only method plus the corporate CA env vars typically resolves these.
- **OPA symbol errors** at runtime: the static AMD64 build is used specifically to avoid musl/glibc issues on Alpine.
- **More CVEs after “adding tools”**: adding compilers or full toolchains (e.g., Go) can expand the surface significantly. Prefer single binaries unless the compiler is truly required at runtime.

-----

### Changelog template 

Keep a `CHANGELOG.md` mapping your image tags (e.g., `v2.2.x`) to the exact component versions and scan outcomes.

```
- v2.2.x (tag: latest-safe)
  - Base: ghcr.io/env0/deployment-agent:4.0.34
  - kubectl v1.34.2
  - PowerShell 7.5.4
  - gcloud 549.0.0
  - AWS CLI v2 2.32.13
  - Azure CLI 2.81.0
  - OPA 1.11.1 (static)
  - Notes: corporate CA wired :  read-only runtime safe :  build deps removed.
```
-----

- Long-Term Support Branch (a.k.a: LTSB) Image : Removes GO toolchain from installer and relies solely on the env0 agent build to handle all go / go post-processing
- Standard Image                               : Includes GO toolchain like above, maintains safe stable and cleared version(s) of agents to reduce / eliminate vuls
- Extended Image                               : Includes GO + Newest Realeases of all Runtimes, Agents, Libraries etc...
