#!/bin/bash
# - For explicit and portable : Uncomment line below (Usually line: 3) and comment line above (Usually line: 1)
#!/usr/bin/env bash

# 1) Unpack or install from .tgz directly
tar -xzf env0-agent-0.2.0.tgz
cd env0-agent

# 2) Prepare your values (swap repo/tag to your custom image)
cat > my-values.yaml <<'YAML'
image:
  repository: ghcr.io/your-org/env0-agent-custom
  tag: v1.0.0

agent:
  createSecret: true
  key: "<YOUR_AGENT_KEY>"
  secret: "<YOUR_AGENT_SECRET>"

# Optional if your registry is private
# imagePullSecrets:
#   - name: regcred
YAML

# 3) Install
helm upgrade --install env0-agent ./ -n env0 --create-namespace -f my-values.yaml

# 4) Verify
kubectl -n env0 get pods
kubectl -n env0 logs deploy/env0-agent-env0-agent -f
