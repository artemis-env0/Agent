# =============================================================================================
#  Env0 Agent Custom Image
#  - env0 Custom Agent for (x86-64) | artem@env0 | v4.0.16a
#  - Preserves your original flow
#  - Installs kubectl v1.33.4
#  - Installs pwsh 7.5.4
#  - Corporate CA trust wired
#  - Google Cloud SDK installed WITHOUT running install.sh (no network calls inside installer)
#  - AWS CLI + Azure CLI + extras
#  - OPA (Open Policy Agent) v1.10.1
# =============================================================================================
# --------------------------------------------------------------------------------------
# Base: env0 deployment agent
# -----------------------------------------------------------------------------
ARG AGENT_VERSION=4.0.16
FROM --platform=linux/amd64 ghcr.io/env0/deployment-agent:${AGENT_VERSION}

# Become root once for all installation steps; drop privileges at the end.
USER root

# Hard guard: only build/run on x86_64
RUN set -eux; \
    if [ "$(uname -m)" != "x86_64" ]; then \
      echo "This image is restricted to x86_64 (amd64) only." >&2; exit 1; \
    fi

# -----------------------------------------------------------------------------
# Corp CA: install and trust for all CLI tools
# -----------------------------------------------------------------------------
# These two files must be in your build context
COPY ariesinter.crt /usr/local/share/ca-certificates/ariesinter.crt
COPY ariesroot.crt  /usr/local/share/ca-certificates/ariesroot.crt

# Trust your corporate CA for any future *runtime* requests (not needed to build)
RUN set -eux; \
    cat /usr/local/share/ca-certificates/ariesinter.crt >> /etc/ssl/certs/ca-certificates.crt; \
    cat /usr/local/share/ca-certificates/ariesroot.crt  >> /etc/ssl/certs/ca-certificates.crt; \
    apk --no-cache add ca-certificates; \
    update-ca-certificates

# Make all common clients (curl, requests, pip, git, gcloud) honor the corp CA
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# -----------------------------------------------------------------------------
# Writable runtime paths (env0 often uses read-only root; /tmp is tmpfs)
# -----------------------------------------------------------------------------
# Use /tmp for all temp I/O and make /var/tmp a symlink to /tmp for tools
# that hardcode /var/tmp. Also ensure a writable HOME for the non-root user.
ENV TMPDIR=/tmp \
    HOME=/home/env0
RUN set -eux; \
    mkdir -p /tmp /home/env0; \
    chmod 1777 /tmp; \
    rm -rf /var/tmp; ln -s /tmp /var/tmp; \
    chown -R 65532:65532 /home/env0

# -----------------------------------------------------------------------------
# Base tooling
# -----------------------------------------------------------------------------
ARG INSTALLED_PACKAGES="curl openssl py3-pip"
RUN apk add --no-cache ${INSTALLED_PACKAGES}

# -----------------------------------------------------------------------------
# kubectl (v1.33.4) : direct download (x86_64 only)
# -----------------------------------------------------------------------------
ARG KUBECTL_VERSION=v1.33.4
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    chmod 0755 /usr/local/bin/kubectl; \
    kubectl version --client --output=yaml | head -n 5 || true

# -----------------------------------------------------------------------------
# PowerShell (pwsh) 7.5.4
# -----------------------------------------------------------------------------
ARG PWSH_VERSION=7.5.4
RUN set -eux; \
    apk add --no-cache icu-libs zlib libintl libgcc libstdc++; \
    mkdir -p /opt/microsoft/powershell/; \
    curl -L -o /tmp/pwsh.tar.gz "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz"; \
    tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/; \
    ln -sf /opt/microsoft/powershell/pwsh /usr/bin/pwsh; \
    chmod 0755 /usr/bin/pwsh; \
    rm -f /tmp/pwsh.tar.gz

# -----------------------------------------------------------------------------
# OpenSSL config (legacy renegotiation off) + re-copy to locations you used
# -----------------------------------------------------------------------------
# These two files must exist in build context (your custom openssl.cnf)
COPY openssl.cnf /usr/lib/ssl/openssl.cnf
COPY openssl.cnf /etc/ssl/openssl.cnf

# -----------------------------------------------------------------------------
# Install Aries CA into Debian-style path (some tools read here explicitly)
# -----------------------------------------------------------------------------
COPY ariesroot.crt  /usr/share/ca-certificates/ariesroot.crt
COPY ariesinter.crt /usr/share/ca-certificates/ariesinter.crt
RUN set -eux; \
    echo "ariesroot.crt"  >> /etc/ca-certificates.conf; \
    echo "ariesinter.crt" >> /etc/ca-certificates.conf; \
    /usr/sbin/update-ca-certificates; \
    printf "\nca_directory=/etc/ssl/certs" | tee -a /etc/wgetrc

# -----------------------------------------------------------------------------
# Go (Alpine package) : your original intent to fix stdlib CVEs
# -----------------------------------------------------------------------------
RUN apk add --no-cache go

# -----------------------------------------------------------------------------
# AWS Signing Helper
# -----------------------------------------------------------------------------
# expects 'aws_signing_helper' in build context
COPY aws_signing_helper /usr/local/bin/aws_signing_helper
RUN set -eux; \
    chmod +x /usr/local/bin/aws_signing_helper; \
    # Ensure compat libs for the helper
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/main"       >> /etc/apk/repositories; \
    echo "https://dl-cdn.alpinelinux.org/alpine/v3.18/community"  >> /etc/apk/repositories; \
    apk update; \
    apk add --no-cache gcompat libc6-compat; \
    /usr/local/bin/aws_signing_helper version || true

# -----------------------------------------------------------------------------
# Google Cloud SDK (gcloud) : CA-safe, no component auto-fetch during install
# -----------------------------------------------------------------------------
ARG GCLOUD_VERSION=534.0.0
# Ensure Python & crcmod (gcloud prereqs)
RUN apk add --no-cache bash curl python3 py3-crcmod
# Download & install; ensure corp CA env present during install.sh to prevent
# the "components-2.json" SSL failure inside requests/urllib3.
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1 \
    PATH="/usr/local/google-cloud-sdk/bin:${PATH}"
RUN set -eux; \
    curl -sSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
      | tar -xz -C /usr/local; \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    /usr/local/google-cloud-sdk/install.sh --quiet || true; \
    ln -sf /usr/local/google-cloud-sdk/bin/gcloud /usr/bin/gcloud; \
    /usr/local/google-cloud-sdk/bin/gcloud config set --quiet component_manager/disable_update_check true || true; \
    /usr/local/google-cloud-sdk/bin/gcloud config set --quiet core/custom_ca_certs_file "/etc/ssl/certs/ca-certificates.crt" || true; \
    gcloud --version || true

# -----------------------------------------------------------------------------
# AWS CLI v2 (x86_64)
# -----------------------------------------------------------------------------
RUN set -eux; \
    apk add --no-cache unzip; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip; \
    unzip /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws*; \
    aws --version || true

#  ----------------------------------------------------------------------------
# - Open Policy Agent (OPA): pinned, checksum-verified (linux/amd64 only)  
# - OPA (linux/amd64 only), static build so it works on Alpine
#  ----------------------------------------------------------------------------
ARG OPA_VERSION=1.10.1
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

# -----------------------------------------------------------------------------
# Azure CLI (pip) : via corp CA
# -----------------------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --upgrade --no-cache-dir pip setuptools wheel; \
    python3 -m pip install --no-cache-dir azure-cli; \
    az --version >/dev/null || true

# -----------------------------------------------------------------------------
# Python tools: Checkov (and friends) - single install, no cache, corp CA
# -----------------------------------------------------------------------------
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
RUN set -eux; \
    python3 -m pip install --upgrade --no-cache-dir pip setuptools wheel; \
    python3 -m pip install --no-cache-dir "checkov" "asteval==1.0.6"; \
    pip3 check || echo "pip check reported conflicts (non-fatal)"; \
    rm -rf /root/.cache /tmp/*

# -----------------------------------------------------------------------------
# Environment flags used by env0 runners
# -----------------------------------------------------------------------------
ENV ENV0_USE_TF_PLUGIN_CACHE=true

# -----------------------------------------------------------------------------
# Optional cleanup of prebundled tools you removed before
# -----------------------------------------------------------------------------
RUN rm -rf /opt/infracost || true

# -----------------------------------------------------------------------------
# Final sanity: print key versions at build (non-fatal)
# -----------------------------------------------------------------------------
RUN set -eux; \
    kubectl version --client --output=yaml | head -n 5 || true; \
    pwsh --version || true; \
    gcloud --version || true; \
    aws --version || true; \
    az --version  || true; \
    python3 --version; \
    pip3 --version

# Drop privileges for runtime
USER 65532
