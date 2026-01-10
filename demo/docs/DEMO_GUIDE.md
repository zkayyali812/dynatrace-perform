# Demo Presentation Guide

Step-by-step guide for presenting the Dynatrace + Event-Driven Ansible demo at Dynatrace Perform.

## Demo Overview

**Duration:** 10-15 minutes

**Key Messages:**
1. Event-Driven Ansible responds to Dynatrace problems in real-time
2. Config as Code enables GitOps workflows for automation platform
3. Automated remediation reduces MTTR (Mean Time To Resolution)
4. Closed-loop automation acknowledges problems after remediation

## Pre-Demo Checklist

- [ ] AAP Controller accessible and configured
- [ ] EDA Controller accessible with active rulebook activation
- [ ] Event Stream URL ready
- [ ] Webhook simulator script configured
- [ ] Demo application deployed (or using simulated remediation)
- [ ] Terminal windows arranged for demo
- [ ] Browser tabs open:
  - [ ] Dynatrace environment
  - [ ] EDA Controller (Rulebook Activations)
  - [ ] AAP Controller (Jobs)
  - [ ] OpenShift/Kubernetes console (optional)

---

## Demo Flow

### Act 1: Set the Stage (2 minutes)

#### Talking Points

> "Today I'll show you how Event-Driven Ansible transforms Dynatrace problem detection into automated remediation. We're going to see a complete closed-loop automation scenario."

> "The key components are:
> - **Dynatrace** detecting problems in our environment
> - **Event-Driven Ansible** receiving and processing problem events
> - **Ansible Automation Platform** executing remediation playbooks
> - Everything configured as **Config as Code** in Git"

#### Show: Architecture Diagram

Display the architecture from the README:

```
┌──────────────────┐    Problem     ┌──────────────────┐    Event      ┌──────────────────┐
│    Dynatrace     │ ────────────▶  │  EDA Controller  │ ───────────▶  │  AAP Controller  │
│   (Monitoring)   │    Webhook     │  (Event Stream)  │   Trigger     │  (Job Templates) │
└──────────────────┘                └──────────────────┘               └──────────────────┘
```

---

### Act 2: Show Config as Code (3 minutes)

#### Talking Points

> "First, let's look at how everything is defined as code. No clicking through UIs to configure our automation platform."

#### Show: Repository Structure

```bash
# In terminal
tree -L 2 .
```

#### Show: Controller Configuration

```bash
# Show job templates defined as code
cat config/controller/job_templates/job_templates.yml
```

> "All our job templates are defined in YAML. We have specific remediations for CPU issues, memory problems, pod crashes, and more."

#### Show: EDA Configuration

```bash
# Show event streams and rulebook activations
cat config/eda/event_streams/event_streams.yml
cat config/eda/rulebook_activations/rulebook_activations.yml
```

> "Event Streams provide a webhook endpoint that Dynatrace sends problem notifications to. The rulebook activation links everything together."

#### Show: Rulebook

```bash
# Show the main rulebook
cat rulebooks/dynatrace_problem_handler.yml
```

> "The rulebook defines the conditions for matching different problem types and the actions to take. Notice how we match on problem titles and trigger specific job templates."

---

### Act 3: Show the Automation in Action (5 minutes)

#### Talking Points

> "Now let's see this in action. I'm going to simulate a Dynatrace problem notification."

#### Step 1: Show EDA Controller - Rulebook Activation

1. Open EDA Controller UI
2. Navigate to **Rulebook Activations**
3. Show the active `Dynatrace Problem Handler` activation
4. Point out the status and event stream link

> "Our rulebook is running and waiting for events. It's connected to our Event Stream."

#### Step 2: Trigger the Problem

**Option A: Use Webhook Simulator**
```bash
# In terminal, make it visible
export EDA_EVENT_STREAM_URL="<your-event-stream-url>"
export EDA_AUTH_TOKEN="<your-token>"

./demo/scripts/send_problem.sh high_cpu
```

**Option B: Trigger Real Dynatrace Problem**
- Show the Dynatrace environment
- Point to an existing or manually triggered problem

> "I'm sending a simulated high CPU problem. In production, this would come directly from Dynatrace when it detects an issue."

#### Step 3: Watch EDA Controller Process Event

1. In EDA Controller, click on the rulebook activation
2. Show the **History** or **Events** tab
3. Point out the incoming event and rule match

> "See how the event was received and matched our 'Remediate High CPU' rule. It's now triggering the job template."

#### Step 4: Watch AAP Controller Execute Remediation

1. Switch to AAP Controller
2. Navigate to **Jobs**
3. Show the running/completed job
4. Click into the job output

> "The remediation playbook is now running. It's connecting to our OpenShift cluster, identifying the affected pods, and taking action."

#### Show: Job Output Highlights

Point out key sections:
- Problem ID logging
- Deployment identification
- Scaling or restart action
- Verification of pod status

> "Notice how the playbook logs the problem ID for traceability, performs the remediation, and verifies the pods are healthy."

---

### Act 4: Closed-Loop (2 minutes)

#### Talking Points

> "But we're not done yet. A true closed-loop automation acknowledges the problem back in Dynatrace."

#### Show: Problem Comment/Closure

If using real Dynatrace:
1. Open Dynatrace
2. Navigate to the problem
3. Show the comment added by Ansible

> "The playbook added a comment to the Dynatrace problem indicating remediation was performed. When using the closed-loop rulebook, the problem is also closed automatically."

---

### Act 5: Different Problem Types (2 minutes)

#### Talking Points

> "Let's quickly show that this works for different problem types."

```bash
# Trigger a pod crash scenario
./demo/scripts/send_problem.sh pod_crash
```

1. Show different job template being triggered
2. Point out the conditional logic in the rulebook

> "See how the rulebook matched a different condition and triggered the pod crash remediation playbook instead."

---

### Act 6: Wrap Up (1 minute)

#### Key Takeaways

> "To summarize what we've seen:
>
> 1. **Real-time Response**: Events flow from Dynatrace to automation in seconds
> 2. **Config as Code**: All configuration lives in Git for version control and GitOps
> 3. **Intelligent Routing**: Rulebooks route different problems to appropriate remediation
> 4. **Closed-Loop**: Automation reports back to Dynatrace for full observability
> 5. **Scalable**: Add new problem types and remediations without code changes"

#### Call to Action

> "Check out the GitHub repository for all the code. The README includes everything you need to set this up in your environment."

---

## Advanced: Full Closed-Loop Demo

For a true end-to-end demo with Dynatrace problem closure:

### Prerequisites

1. **Dynatrace OneAgent** monitoring your OpenShift cluster (see DYNATRACE_SETUP.md)
2. **Dynatrace API Token** with `problems.read` and `problems.write` permissions
3. **Closed-Loop Rulebook** enabled instead of the standard handler

### Switch to Closed-Loop Rulebook

In EDA Controller:
1. Disable "Dynatrace Problem Handler" activation
2. Enable "Dynatrace Closed-Loop Handler" activation

Or via Config as Code, edit `config/eda/rulebook_activations/rulebook_activations.yml`:
- Set first activation `state: "disabled"`
- Set second activation `state: "enabled"`

### Trigger Real Problems

Instead of using the webhook simulator, generate actual problems:

#### High CPU (Will trigger CPU remediation)
```bash
oc run stress-test -n demo-app --restart=Never \
  --image=polinux/stress \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"stress-test","image":"polinux/stress","command":["stress"],"args":["--cpu","4","--timeout","120s"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'
```

#### Memory Exhaustion
```bash
oc run memory-stress -n demo-app --restart=Never \
  --image=polinux/stress \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"memory-stress","image":"polinux/stress","command":["stress"],"args":["--vm","2","--vm-bytes","512M","--timeout","120s"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'
```

### Demo Flow for Closed-Loop

1. Trigger a real problem (stress test or scale down)
2. Wait for Dynatrace to detect (2-5 minutes)
3. Watch EDA Controller receive the event
4. Watch AAP Controller run the job template
5. At the end of the job, see the Dynatrace API call that adds a remediation comment
6. Show the problem in Dynatrace with the automation comment
7. Wait for Dynatrace to auto-detect resolution and close the problem

> **Note:** The closed-loop rulebook passes `close_problem: true` to the job templates, which adds a comment to the Dynatrace problem. Dynatrace automatically closes the problem when it detects the issue is resolved.

---

## Backup Scenarios

### If Event Stream Not Working

Use the simulated remediation playbooks that don't require real OpenShift:

```bash
# Modify payload to not require real cluster
# Playbooks will log actions without executing
```

### If Timing is Tight

Skip Act 4 (Closed-Loop) and focus on the core event-to-remediation flow.

### If Questions About Security

> "Event Streams support multiple authentication methods including tokens, HMAC signatures, and mTLS. For production, we recommend using the strongest authentication your environment supports."

---

## Common Questions & Answers

**Q: How fast is the response time?**
> "Sub-second for the EDA processing. End-to-end including playbook execution is typically under 30 seconds for simple remediations."

**Q: Can this scale to handle many problems?**
> "Yes, EDA Controller can handle high event volumes. For very high scale, you can run multiple rulebook activations and use event filtering."

**Q: What if the remediation fails?**
> "The playbooks include error handling and can trigger escalation workflows. You can also set up notifications for failed remediations."

**Q: Can I customize the problem matching?**
> "Absolutely. The rulebook conditions use Jinja2 expressions. You can match on any field in the Dynatrace payload including tags, severity, and entity types."

---

## Terminal Commands Quick Reference

```bash
# Send high CPU problem
./demo/scripts/send_problem.sh high_cpu

# Send memory problem
./demo/scripts/send_problem.sh memory

# Send pod crash problem
./demo/scripts/send_problem.sh pod_crash

# Send resolved notification
./demo/scripts/send_problem.sh resolved
```

---

## Post-Demo Resources

Share with attendees:
- GitHub Repository URL
- Dynatrace documentation for webhooks
- Ansible EDA documentation
- Red Hat AAP documentation
