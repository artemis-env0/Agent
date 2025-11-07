# env0 Agent Helm Chart (Custom)

This chart deploys the env0 agent using your custom image and aligns with the official env0 agent configuration.

## Quickstart

```bash
# Create namespace
kubectl create ns env0

# Prepare values
cat > my-values.yaml <<'YAML'
image:
  repository: ghcr.io/your-org/env0-agent-custom
  tag: v1.0.0

agent:
  createSecret: true
  key: "<YOUR_AGENT_KEY>"
  secret: "<YOUR_AGENT_SECRET>"

# If your registry is private:
# imagePullSecrets:
#   - name: regcred
YAML

# Install
helm upgrade --install env0-agent ./ -n env0 --create-namespace -f my-values.yaml

# Verify
kubectl -n env0 get pods
kubectl -n env0 logs deploy/env0-agent-env0-agent -f
```
---

Download Helm Installation Script v1106-25:  [`deploy_env0_helm`](https://github.com/artemis-env0/Agent/releases/download/1106-25/deploy_env0_helm.sh) 

## Values

See [`values.yaml`](./values.yaml) for all available options with comments. Schema validation via `values.schema.json`.

## Common options

- `agent.existingSecret`: reference a pre-created Secret with `AGENT_KEY` and `AGENT_SECRET`
- `agent.envFrom`/`agent.extraEnv`: mount cloud creds or other secrets
- `agent.proxy.*`: inject proxy env vars if needed
- `agent.caBundle.*`: optionally mount a CA bundle Secret and set SSL-related env vars
- `resources`: set requests/limits
- `nodeSelector` defaults to `amd64` to match your Dockerfile
- `rbac.create`: enable and provide custom `rbac.rules` as needed

## Uninstall
```bash
helm uninstall env0-agent -n env0
```

## Notes
This chart is built to be lint-friendly and portable across Kubernetes 1.23+.

## Contributor
artem@env0 | v1106-25
