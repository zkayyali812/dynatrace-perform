# Dynatrace Perform Demo: Event-Driven Ansible

This demo showcases **Event-Driven Ansible (EDA)** integrated with **Dynatrace** for automated incident remediation on **OpenShift/Kubernetes**. All Ansible Automation Platform configuration is managed entirely as **Config as Code**.

## Demo Scenario

```
┌──────────────────┐    Problem     ┌──────────────────┐    Event      ┌──────────────────┐
│    Dynatrace     │ ────────────▶  │  EDA Controller  │ ───────────▶  │  AAP Controller  │
│   (Monitoring)   │    Webhook     │  (Event Stream)  │   Trigger     │  (Job Templates) │
└──────────────────┘                └──────────────────┘               └──────────────────┘
                                             │                                  │
                                             │ Rulebook                         │ Remediation
                                             │ Evaluation                       │ Playbook
                                             ▼                                  ▼
                                    ┌──────────────────┐               ┌──────────────────┐
                                    │  Match Problem   │               │  OpenShift/K8s   │
                                    │  Type & Filter   │               │   Auto-Healing   │
                                    └──────────────────┘               └──────────────────┘
```

**Flow:**
1. Dynatrace detects a problem (high CPU, memory, app errors)
2. Problem notification sent via webhook to EDA Controller Event Stream
3. EDA rulebook evaluates the event and matches conditions
4. Rulebook triggers an AAP Controller job template
5. Remediation playbook executes on OpenShift/Kubernetes
6. Problem is acknowledged/closed in Dynatrace

## Repository Structure

```
├── operators/                  # Operator installation YAMLs
│   ├── aap/                    # AAP operator & custom resources
│   └── dynatrace/              # Dynatrace operator & DynaKube
├── controller_config/          # AAP Controller Config as Code
│   ├── credentials/            # Credential definitions
│   ├── inventories/            # Inventory definitions
│   ├── labels/                 # Label definitions for job tagging
│   ├── projects/               # Project definitions
│   ├── job_templates/          # Job template definitions
│   └── execution_environments/ # EE definitions
├── eda_config/                 # EDA Controller Config as Code
│   ├── credentials/            # EDA credentials
│   ├── decision_environments/  # Decision environment definitions
│   ├── projects/               # EDA project definitions
│   ├── event_streams/          # Event stream definitions
│   └── rulebook_activations/   # Rulebook activation definitions
├── rulebooks/                  # EDA Rulebooks
├── playbooks/                  # Ansible Playbooks
│   ├── remediation/            # Auto-remediation playbooks
│   ├── utilities/              # Utility playbooks
│   └── setup/                  # Setup/config playbooks
├── demo/                       # Demo resources
│   ├── app/                    # Demo app Kubernetes manifests
│   ├── scripts/                # Webhook simulator scripts
│   ├── payloads/               # Sample Dynatrace payloads
│   └── docs/                   # Integration documentation
└── group_vars/                 # Variable definitions
```

## Prerequisites

- Ansible Automation Platform 2.5+
- EDA Controller (integrated or standalone)
- OpenShift/Kubernetes cluster
- Python 3.9+
- Red Hat Automation Hub token (for ansible.controller and ansible.eda collections)
- Ansible Collections:
  - `ansible.controller` (from Automation Hub)
  - `ansible.eda` (from Automation Hub)
  - `kubernetes.core`
  - `redhat.openshift`

## Quick Start

### 1. Configure Automation Hub Token

```bash
# Get your token from: https://console.redhat.com/ansible/automation-hub/token
export ANSIBLE_GALAXY_SERVER_AUTOMATION_HUB_TOKEN=<your-token>
```

### 2. Install Required Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Configure Your Environment

Copy and edit the example variables:

```bash
cp group_vars/all.example.yml group_vars/all.yml
# Edit with your AAP/EDA Controller URLs and credentials
```

### 4. Deploy Config as Code

```bash
# Deploy AAP Controller and EDA Controller configuration
ansible-playbook playbooks/setup/configure_aap.yml
```

### 5. Deploy the Demo App

Deploy a simple nginx application that the remediation playbooks will target:

```bash
# Using the Ansible playbook
ansible-playbook playbooks/setup/deploy_demo_app.yml
```

Verify the app is running:

```bash
oc get pods -n demo-app
# Should see 2 pods running
```

### 6. Test with Webhook Simulator

```bash
# Send a simulated Dynatrace high CPU problem
./demo/scripts/send_problem.sh high_cpu

# Send a simulated pod crash problem
./demo/scripts/send_problem.sh pod_crash
```

## Demo App

The demo app is a simple nginx deployment in the `demo-app` namespace. The remediation playbooks will:
- **High CPU**: Restart or scale the deployment
- **Memory**: Scale up and delete pods to release memory
- **Pod Crash**: Delete crashed pods and trigger rollout
- **Service Unavailable**: Restart the deployment
- **Error Rate**: Scale up replicas

You can trigger real problems for Dynatrace to detect:

```bash
# High CPU - run stress test
oc run stress-test --image=progrium/stress -n demo-app --restart=Never -- --cpu 4 --timeout 60s

# Pod Crash - delete pods
oc delete pod -l app=demo-app -n demo-app

# Service Unavailable - scale to zero
oc scale deployment demo-app --replicas=0 -n demo-app
```

## Demo Walkthrough

See [demo/docs/DEMO_GUIDE.md](demo/docs/DEMO_GUIDE.md) for a step-by-step presentation guide.

## Dynatrace Integration

For production integration with Dynatrace, see [demo/docs/DYNATRACE_SETUP.md](demo/docs/DYNATRACE_SETUP.md).

## Problem Types & Remediations

| Dynatrace Problem | EDA Condition | Remediation Action |
|-------------------|---------------|-------------------|
| High CPU | `event.ProblemTitle contains "CPU"` | Restart high-CPU pods |
| Memory Exhaustion | `event.ProblemTitle contains "memory"` | Scale deployment, clear caches |
| Pod CrashLoopBackOff | `event.ProblemTitle contains "crash"` | Delete stuck pods, trigger rollout |
| Service Unavailable | `event.ProblemTitle contains "availability"` | Restart deployment |
| High Error Rate | `event.ProblemTitle contains "error rate"` | Scale up replicas |

## License

Apache-2.0
