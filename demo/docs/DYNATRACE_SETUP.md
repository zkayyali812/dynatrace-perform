# Dynatrace Integration Setup

This guide covers how to configure Dynatrace to send problem notifications to your Event-Driven Ansible (EDA) Controller and enable true closed-loop remediation.

## Overview

```
┌──────────────────┐    Problem     ┌──────────────────┐    Event      ┌──────────────────┐
│    Dynatrace     │ ────────────▶  │  EDA Controller  │ ───────────▶  │  AAP Controller  │
│   (Monitoring)   │    Webhook     │  (Event Stream)  │   Trigger     │  (Job Templates) │
└──────────────────┘                └──────────────────┘               └──────────────────┘
         ▲                                                                      │
         │                                                                      │
         │                    Closed-Loop                                       │
         └───────────────── (Comment/Close) ────────────────────────────────────┘
```

## Prerequisites

1. Dynatrace environment with API access
2. EDA Controller with Event Stream configured
3. OpenShift cluster with Dynatrace Operator (for real monitoring)
4. Network connectivity from Dynatrace to EDA Controller

---

## Step 1: Install Dynatrace on OpenShift (For Real E2E Demo)

For a true end-to-end demo where Dynatrace detects real problems, you need the Dynatrace Operator monitoring your cluster.

### Option A: Via OperatorHub (Recommended)

1. In OpenShift Console, navigate to **Operators** > **OperatorHub**
2. Search for **Dynatrace Operator**
3. Click **Install** and follow the wizard
4. Create a `dynakube` custom resource:

```yaml
apiVersion: dynatrace.com/v1beta1
kind: DynaKube
metadata:
  name: dynakube
  namespace: dynatrace
spec:
  apiUrl: https://YOUR_ENVIRONMENT_ID.live.dynatrace.com/api
  tokens: dynakube
  oneAgent:
    classicFullStack:
      tolerations:
        - effect: NoSchedule
          operator: Exists
```

5. Create the required secret with your Dynatrace tokens:

```bash
oc create secret generic dynakube \
  --namespace dynatrace \
  --from-literal=apiToken=YOUR_API_TOKEN \
  --from-literal=paasToken=YOUR_PAAS_TOKEN
```

### Option B: Via Helm

```bash
# Add Dynatrace Helm repo
helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable

# Install operator
helm install dynatrace-operator dynatrace/dynatrace-operator \
  --namespace dynatrace \
  --create-namespace

# Create tokens secret and DynaKube CR as shown above
```

### Verify OneAgent is Running

```bash
oc get pods -n dynatrace
# You should see oneagent pods running on each node
```

---

## Step 2: Get Your Event Stream Webhook URL

1. Log into your EDA Controller
2. Navigate to **Event Streams** in the left menu
3. Click on your event stream (e.g., `dynatrace-problems`)
4. Copy the **Webhook URL** - it will look like:
   ```
   https://eda-controller.example.com/api/eda/v1/external_event_stream/<uuid>/post/
   ```
5. Note the **Authentication Token** if using Token-based auth

---

## Step 3: Create Dynatrace Problem Notification

### Via Dynatrace UI

1. Log into your Dynatrace environment
2. Navigate to **Settings** > **Integration** > **Problem notifications**
3. Click **Add notification**
4. Select **Custom Integration**
5. Configure the integration:

| Setting | Value |
|---------|-------|
| Display name | `Ansible Automation Platform` |
| Webhook URL | Your EDA Event Stream URL |
| Accept any SSL certificate | Enable if using self-signed certs |

6. Add the following **Custom headers**:
   ```
   Authorization: Bearer <your-eda-token>
   Content-Type: application/json
   ```

7. Set the **Payload** to the following JSON template:

```json
{
  "ProblemID": "{ProblemID}",
  "PID": "{PID}",
  "ProblemTitle": "{ProblemTitle}",
  "ProblemURL": "{ProblemURL}",
  "State": "{State}",
  "ProblemSeverity": "{ProblemSeverity}",
  "ProblemImpact": "{ProblemImpact}",
  "ImpactedEntity": "{ImpactedEntity}",
  "ImpactedEntities": {ImpactedEntities},
  "ProblemDetails": {ProblemDetailsJSON},
  "Tags": {Tags},
  "StartTime": {ProblemStartTime},
  "EndTime": {ProblemEndTime}
}
```

8. Configure **Alerting profile** to filter which problems trigger notifications
9. Click **Save**

### Via Dynatrace API

```bash
curl -X POST "https://<your-environment>.live.dynatrace.com/api/config/v1/notifications" \
  -H "Authorization: Api-Token <your-dynatrace-api-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "WEBHOOK",
    "name": "Ansible Automation Platform",
    "alertingProfile": "<your-alerting-profile-id>",
    "active": true,
    "url": "https://eda-controller.example.com/api/eda/v1/external_event_stream/<uuid>/post/",
    "acceptAnyCertificate": false,
    "headers": [
      {
        "name": "Authorization",
        "value": "Bearer <your-eda-token>"
      }
    ],
    "payload": "{\"ProblemID\": \"{ProblemID}\", \"PID\": \"{PID}\", \"ProblemTitle\": \"{ProblemTitle}\", \"ProblemURL\": \"{ProblemURL}\", \"State\": \"{State}\", \"ProblemSeverity\": \"{ProblemSeverity}\", \"ProblemImpact\": \"{ProblemImpact}\", \"ImpactedEntity\": \"{ImpactedEntity}\", \"ImpactedEntities\": {ImpactedEntities}, \"ProblemDetails\": {ProblemDetailsJSON}, \"Tags\": {Tags}, \"StartTime\": {ProblemStartTime}, \"EndTime\": {ProblemEndTime}}"
  }'
```

---

## Step 4: Create an Alerting Profile

Create an alerting profile to filter which problems trigger automation:

1. Navigate to **Settings** > **Alerting** > **Alerting profiles**
2. Click **Add alerting profile**
3. Configure filters:
   - **Severity**: Select severity levels to include
   - **Problem duration**: Minimum time before alerting
   - **Tags**: Filter by entity tags
4. Save the profile and use it in your notification

### Recommended Alerting Profile for Demo

```yaml
Name: Ansible Automation
Severity filters:
  - CRITICAL (immediate)
  - WARNING (5 minute delay)
Tag filter:
  - Include: team:platform
Problem type:
  - Include: CPU saturation
  - Include: Memory issues
  - Include: Pod crash
```

---

## Step 5: Configure Dynatrace API Token (For Closed-Loop)

For the remediation playbooks to close problems in Dynatrace after remediation, create an API token:

1. Navigate to **Settings** > **Integration** > **Dynatrace API**
2. Click **Generate token**
3. Configure permissions:
   - `problems.read` - Read problems
   - `problems.write` - Write problem comments and close problems
4. Save the token securely
5. Add it to your AAP Controller credentials or environment:
   ```bash
   export DYNATRACE_API_TOKEN="dt0c01.XXXX..."
   export DYNATRACE_URL="https://abc12345.live.dynatrace.com"
   ```

---

## Step 6: Enable Closed-Loop Remediation

The closed-loop functionality is built into the remediation playbooks. When triggered by the closed-loop rulebook, each playbook will automatically close the problem in Dynatrace after successful remediation.

### Configure Dynatrace Credentials

Add your Dynatrace credentials to `vars.yml`:

```yaml
# Dynatrace Configuration (for closed-loop)
dynatrace_environment_url: "https://abc12345.live.dynatrace.com"
dynatrace_api_token: "{{ lookup('env', 'DYNATRACE_API_TOKEN') }}"
```

Then set the environment variable:
```bash
export DYNATRACE_API_TOKEN="dt0c01.XXXX..."
```

### Enable the Closed-Loop Rulebook

In EDA Controller:
1. Disable the "Dynatrace Problem Handler" activation
2. Enable the "Dynatrace Closed-Loop Handler" activation

Or via Config as Code, edit `config/eda/rulebook_activations/rulebook_activations.yml`:
- Set first activation `state: "disabled"`
- Set second activation `state: "enabled"`

### How It Works

The closed-loop rulebook passes `close_problem: true` to each job template. The remediation playbooks check this flag and add a detailed comment to the Dynatrace problem documenting:
- What remediation action was taken
- The affected deployment/service
- Timestamp of the remediation

Dynatrace will automatically detect when the problem is resolved and close it on its own.

---

## Testing the Integration

### Method 1: Using the Webhook Simulator (No Real Dynatrace Needed)

Test your setup without generating real Dynatrace problems:

```bash
# Set your event stream URL and token
export EDA_EVENT_STREAM_URL="https://eda-controller.example.com/api/eda/v1/external_event_stream/<uuid>/post/"
export EDA_AUTH_TOKEN="your-token"

# Send a simulated high CPU problem
./demo/scripts/send_problem.sh high_cpu
```

### Method 2: Trigger a Real Problem (Requires OneAgent)

Generate actual problems that Dynatrace will detect:

#### High CPU Problem
```bash
# Deploy stress container to your app namespace (OpenShift-compatible)
oc run stress-test -n demo-app --restart=Never \
  --image=polinux/stress \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"stress-test","image":"polinux/stress","command":["stress"],"args":["--cpu","4","--timeout","120s"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'

# Watch for Dynatrace to detect the problem (may take 2-5 minutes)
```

#### Memory Exhaustion
```bash
# Deploy memory stress (OpenShift-compatible)
oc run memory-stress -n demo-app --restart=Never \
  --image=polinux/stress \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"memory-stress","image":"polinux/stress","command":["stress"],"args":["--vm","2","--vm-bytes","512M","--timeout","120s"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'
```

#### Pod Crash
```bash
# Force a pod to crash
oc delete pod -l app=demo-app --namespace=demo-app
```

### Method 3: Use Dynatrace Custom Events API

Create a synthetic problem directly in Dynatrace:

```bash
curl -X POST "https://<environment>.live.dynatrace.com/api/v2/problems" \
  -H "Authorization: Api-Token <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "High CPU saturation on demo-app",
    "impactLevel": "APPLICATION",
    "severityLevel": "CRITICAL"
  }'
```

---

## Troubleshooting

### Webhook Not Received

1. Check EDA Controller logs for incoming requests
2. Verify network connectivity from Dynatrace to EDA Controller
3. Check firewall rules allow the connection
4. Verify the Event Stream is active

### Rulebook Not Triggering

1. Check rulebook activation status in EDA Controller
2. Review rulebook conditions match the payload structure
3. Check EDA Controller logs for event processing errors

### Job Template Not Launching

1. Verify AAP Controller credential in EDA Controller
2. Check job template exists and is enabled
3. Review EDA Controller logs for AAP API errors

### Comment Not Appearing in Dynatrace

1. Verify DYNATRACE_API_TOKEN has `problems.write` permission
2. Check DYNATRACE_URL is correct (no trailing slash)
3. Review job output for API errors
4. Ensure problem ID format matches (e.g., `P-12345678`)
5. Check the problem still exists (hasn't been auto-closed yet)

---

## Payload Field Reference

| Field | Description | Example |
|-------|-------------|---------|
| `ProblemID` | Unique problem identifier | `P-12345678` |
| `PID` | Full problem ID with version | `-123_456V2` |
| `ProblemTitle` | Human-readable title | `High CPU saturation` |
| `State` | Problem state | `OPEN`, `RESOLVED` |
| `ProblemSeverity` | Severity level | `CRITICAL`, `WARNING`, `INFO` |
| `ImpactedEntity` | Primary affected entity | `demo-app-pod-xyz` |
| `Tags` | Entity tags array | `["env:prod", "app:demo"]` |

---

## Security Considerations

1. **Use HTTPS** for all webhook communications
2. **Use strong tokens** for Event Stream authentication
3. **Limit API token scope** to minimum required permissions
4. **Use network policies** to restrict access to EDA Controller
5. **Rotate tokens** regularly

---

## Next Steps

- Review [DEMO_GUIDE.md](DEMO_GUIDE.md) for presentation walkthrough
- Customize rulebooks for your specific problem types
- Add additional remediation playbooks for your environment
