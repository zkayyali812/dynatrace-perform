# Operator Installation

This directory contains YAML definitions for installing AAP and Dynatrace operators on OpenShift.

## Prerequisites

- OpenShift 4.12+
- Cluster admin access
- `oc` CLI configured

## AAP (Ansible Automation Platform)

### Install Operator

```bash
# Create namespace and operator group
oc apply -f operators/aap/namespace.yml
oc apply -f operators/aap/operator-group.yml

# Install the operator
oc apply -f operators/aap/subscription.yml

# Wait for operator to be ready
oc get csv -n aap -w
```

### Deploy AAP (Unified)

AAP 2.5+ uses a single `AnsibleAutomationPlatform` resource that deploys Controller, EDA, and Hub together.

```bash
# Deploy AAP (Controller + EDA + Hub)
oc apply -f operators/aap/aap.yml

# Wait for deployment (10-15 minutes)
oc get ansibleautomationplatform -n aap -w

# Watch pods come up
oc get pods -n aap -w
```

### Get Admin Password

```bash
# AAP admin password
oc get secret aap-admin-password -n aap -o jsonpath='{.data.password}' | base64 -d
```

### Get Routes

```bash
# Get all AAP routes
oc get routes -n aap

# Controller URL
oc get route aap -n aap -o jsonpath='https://{.spec.host}'

# EDA URL
oc get route aap-eda -n aap -o jsonpath='https://{.spec.host}'

# Hub URL
oc get route aap-hub -n aap -o jsonpath='https://{.spec.host}'
```

## Dynatrace

### Install Operator

```bash
# Create namespace and operator group
oc apply -f operators/dynatrace/namespace.yml
oc apply -f operators/dynatrace/operator-group.yml

# Install the operator
oc apply -f operators/dynatrace/subscription.yml

# Wait for operator to be ready
oc get csv -n dynatrace -w
```

### Create Tokens Secret

1. Log into your Dynatrace environment
2. Generate API Token: Settings > Integration > Dynatrace API
   - Required scopes: `DataExport`, `entities.read`, `settings.read`, `activeGates.read`
3. Generate Data Ingest Token: Settings > Integration > Dynatrace API
   - Required scopes: `metrics.ingest`, `logs.ingest`

4. Edit `operators/dynatrace/secret.yml` with your tokens
5. Apply the secret:

```bash
oc apply -f operators/dynatrace/secret.yml
```

### Deploy DynaKube

1. Edit `operators/dynatrace/dynakube.yml` and update:
   - `apiUrl`: Your Dynatrace environment URL

2. Apply the DynaKube:

```bash
# Cloud-native full stack (recommended)
oc apply -f operators/dynatrace/dynakube.yml

# OR classic full stack (if cloud-native doesn't work)
oc apply -f operators/dynatrace/dynakube-classicfullstack.yml
```

3. Verify deployment:

```bash
# Check DynaKube status
oc get dynakube -n dynatrace

# Check OneAgent pods (one per node)
oc get pods -n dynatrace -l app.kubernetes.io/name=oneagent

# Check ActiveGate pods
oc get pods -n dynatrace -l app.kubernetes.io/name=activegate
```

## Verification

### AAP

```bash
# Check all pods are running
oc get pods -n aap

# Check AAP status
oc get ansibleautomationplatform -n aap

# Access URLs
echo "Controller: https://$(oc get route aap -n aap -o jsonpath='{.spec.host}')"
echo "EDA: https://$(oc get route aap-eda -n aap -o jsonpath='{.spec.host}')"
echo "Hub: https://$(oc get route aap-hub -n aap -o jsonpath='{.spec.host}')"
```

### Dynatrace

```bash
# Check all components
oc get dynakube -n dynatrace -o yaml

# Verify hosts appear in Dynatrace
# Go to Dynatrace UI > Infrastructure > Hosts
```

## Cleanup

```bash
# Remove AAP
oc delete -f operators/aap/aap.yml
oc delete -f operators/aap/subscription.yml
oc delete -f operators/aap/operator-group.yml
oc delete -f operators/aap/namespace.yml

# Remove Dynatrace
oc delete -f operators/dynatrace/dynakube.yml
oc delete -f operators/dynatrace/secret.yml
oc delete -f operators/dynatrace/subscription.yml
oc delete -f operators/dynatrace/operator-group.yml
oc delete -f operators/dynatrace/namespace.yml
```
