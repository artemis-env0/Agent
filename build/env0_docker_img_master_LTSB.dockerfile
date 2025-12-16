#  ────────────────────────────────────────────────────────────────────────────────────────────
#  Env0 Agent Custom Image - AMD64 Kubernetes Optimized | v2.4.1L | Long-Term Support Branch
#  |  Based on env0/deployment-agent
#      |  linux/amd64 only
#      |  env0 Custom Agent for (x86-64) | artem@env0 | v4.0.49
#  |  Installs kubectl v1.34.2
#  |  Installs pwsh 7.5.4
#  |  Corporate CA trust wired
#  |  Google Cloud SDK installed WITHOUT running install.sh (no network calls inside installer)
#  |  AWS CLI v2 (replaces pip awscli to reduce Python CVEs)
#  |  Azure CLI pinned to 2.81.0
#  |  OPA (Open Policy Agent) v1.11.0
#  |  Vulnerability Patch v.2025.12.11
#  └────────────────────────────────────────────────────────────────────────────────────────────

ARG AGENT_VERSION=4.0.49
FROM ghcr.io/env0/deployment-agent:${AGENT_VERSION}

USER root

# ─────────────────────────────────────────────────────────────────────────────
# Corporate CA trust (must exist in build context)
# ─────────────────────────────────────────────────────────────────────────────
COPY ariesinter.crt /usr/local/share/ca-certificates/
COPY ariesroot.crt  /usr/local/share/ca-certificates/

RUN set -eux; \
    apk add --no-cache ca-certificates curl openssl py3-pip bash python3 unzip; \
    update-ca-certificates; \
    cat /usr/local/share/ca-certificates/aries*.crt >> /etc/ssl/certs/ca-certificates.crt; \
    # Baseline OS security updates (addresses CVEs in Alpine userland where possible)
    apk upgrade --no-cache

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt \
    CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1

# ─────────────────────────────────────────────────────────────────────────────
# Writable runtime paths (env0 often uses read-only root; /tmp is tmpfs)
# ─────────────────────────────────────────────────────────────────────────────
ENV TMPDIR=/tmp \
    HOME=/home/env0
RUN set -eux; \
    mkdir -p /tmp /home/env0; \
    chmod 1777 /tmp; \
    rm -rf /var/tmp; ln -s /tmp /var/tmp; \
    chown -R 65532:65532 /home/env0

# ─────────────────────────────────────────────────────────────────────────────
# kubectl (AMD64)
# ─────────────────────────────────────────────────────────────────────────────
ARG KUBECTL_VERSION=v1.34.2
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    chmod +x /usr/local/bin/kubectl

# ─────────────────────────────────────────────────────────────────────────────
# PowerShell (AMD64)
# ─────────────────────────────────────────────────────────────────────────────
ARG PWSH_VERSION=7.5.4
RUN set -eux; \
    apk add --no-cache icu-libs zlib libintl libgcc libstdc++; \
    curl -L -o /tmp/pwsh.tar.gz \
      "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz"; \
    mkdir -p /opt/microsoft/powershell; \
    tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell; \
    ln -sf /opt/microsoft/powershell/pwsh /usr/bin/pwsh; \
    rm -f /tmp/pwsh.tar.gz

# ─────────────────────────────────────────────────────────────────────────────
# OpenSSL config
# ─────────────────────────────────────────────────────────────────────────────
COPY openssl.cnf /etc/ssl/openssl.cnf
COPY openssl.cnf /usr/lib/ssl/openssl.cnf
RUN printf "\nca_directory=/etc/ssl/certs" >> /etc/wgetrc

# ─────────────────────────────────────────────────────────────────────────────
# Go (native AMD64)
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Removed to reduce Go-stdlib CVE surface (toolchain not required at runtime)

# ─────────────────────────────────────────────────────────────────────────────
# AWS Signing Helper (AMD64)
# ─────────────────────────────────────────────────────────────────────────────
COPY aws_signing_helper /usr/local/bin/aws_signing_helper
RUN set -eux; \
    chmod +x /usr/local/bin/aws_signing_helper; \
    apk add --no-cache gcompat libc6-compat; \
    file /usr/local/bin/aws_signing_helper || true; \
    echo "Skipping aws_signing_helper execution on ARM host (x86 binary)"

# ─────────────────────────────────────────────────────────────────────────────
# Google Cloud SDK (AMD64)
# ─────────────────────────────────────────────────────────────────────────────
ARG GCLOUD_VERSION=534.0.0
RUN set -eux; \
    apk add --no-cache py3-crcmod; \
    curl -sSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
      | tar -xz -C /usr/local; \
    ln -sf /usr/local/google-cloud-sdk/bin/gcloud /usr/bin/gcloud; \
    gcloud config set --quiet component_manager/disable_update_check true ; \
    gcloud config set --quiet core/custom_ca_certs_file "/etc/ssl/certs/ca-certificates.crt"
ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"

# ─────────────────────────────────────────────────────────────────────────────
# AWS CLI (switch to v2 to reduce Python dependency CVEs)
# ─────────────────────────────────────────────────────────────────────────────
# v2 is a bundled binary; requires glibc compatibility (gcompat/libc6-compat already installed)
RUN set -eux; \
    curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install --update; \
    ln -sf /usr/local/bin/aws /usr/bin/aws || true; \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# ─────────────────────────────────────────────────────────────────────────────
# Azure CLI
# ─────────────────────────────────────────────────────────────────────────────
# Pin to latest documented release to pick up security fixes.
ARG AZ_CLI_VERSION=2.81.0
RUN set -eux; \
    apk add --no-cache gcc python3-dev musl-dev linux-headers libffi-dev openssl-dev; \
    pip3 install --upgrade --no-cache-dir pip setuptools wheel; \
    pip3 install --no-cache-dir "azure-cli==${AZ_CLI_VERSION}"; \
    apk del gcc python3-dev musl-dev linux-headers libffi-dev openssl-dev

# ─────────────────────────────────────────────────────────────────────────────
# Additional Python dependencies (custom)
# ─────────────────────────────────────────────────────────────────────────────
RUN set -eux; \
    pip3 install --no-cache-dir azure-identity azure-mgmt-network requests

#  ----------------------------------------------------------------------------
# | Open Policy Agent (OPA): pinned, checksum-verified (linux/amd64 only)
#  ----------------------------------------------------------------------------
ARG OPA_VERSION=1.11.0
USER root
RUN arch="$(uname -m)"; \
    [ "$arch" = "x86_64" ] || { echo "OPA requires linux/amd64 (got $arch)"; exit 1; }; \
    bin="opa_linux_amd64_static"; \
    base="https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}"; \
    curl -fsSL --retry 5 --connect-timeout 10 --max-time 300 -o "/tmp/$bin" "$base/$bin"; \
    curl -fsSL --retry 5 --connect-timeout 10 --max-time 300 -o "/tmp/$bin.sha256" "$base/$bin.sha256"; \
    awk '{print $1"  /tmp/'"$bin"'"}' "/tmp/$bin.sha256" > "/tmp/$bin.sha256.checked"; \
    sha256sum -c "/tmp/$bin.sha256.checked"; \
    install -m0755 "/tmp/$bin" /usr/local/bin/opa; \
    rm -f "/tmp/$bin" "/tmp/$bin.sha256" "/tmp/$bin.sha256.checked"; \
    opa version

# ─────────────────────────────────────────────────────────────────────────────
# Checkov + asteval
# ─────────────────────────────────────────────────────────────────────────────
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    TMPDIR=/var/tmp
RUN set -eux; \
    pip3 install --no-cache-dir "checkov" "asteval==1.0.6"; \
    rm -rf /root/.cache /tmp/* /var/tmp/*

# ─────────────────────────────────────────────────────────────────────────────
#  Vulnerability remediation (CaaS Hub report)
#   - cryptography: upgrade to address CVE-2024-12797
#   - PyJWT: intentionally left as-is (disputed)
#   - coreutils (PyPI 0.9): force-remove if present to avoid legacy CVEs
#   Notes:
#     * Findings in the base agent or vendor CLIs that bundle their own libs
#       may require upstream image bumps to remediate fully.
# ─────────────────────────────────────────────────────────────────────────────
RUN set -eux; \
    pip3 install --no-cache-dir --upgrade 'cryptography>=43.0.3'; \
    pip3 uninstall -y coreutils || true

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup + runtime env
# ─────────────────────────────────────────────────────────────────────────────
RUN rm -rf /opt/infracost /var/cache/apk/* /tmp/* /root/.cache
ENV ENV0_USE_TF_PLUGIN_CACHE=true

# ─────────────────────────────────────────────────────────────────────────────
# Drop privileges
# ─────────────────────────────────────────────────────────────────────────────
USER 65532:65532
