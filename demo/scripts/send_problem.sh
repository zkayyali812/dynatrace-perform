#!/bin/bash
# =============================================================================
# Dynatrace Problem Webhook Simulator
# =============================================================================
# Simulates Dynatrace problem notifications for demo purposes
# Usage: ./send_problem.sh <problem_type> [event_stream_url]
#
# Problem types: high_cpu, memory, pod_crash
# =============================================================================

set -e

# Configuration
PROBLEM_TYPE="${1:-high_cpu}"
EVENT_STREAM_URL="${2:-${EDA_EVENT_STREAM_URL:-http://localhost:5000/api/eda/v1/external_event_stream/test/post/}}"
AUTH_TOKEN="${EDA_AUTH_TOKEN:-}"
PAYLOADS_DIR="$(dirname "$0")/../payloads"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Dynatrace Problem Webhook Simulator${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if payload file exists
PAYLOAD_FILE="${PAYLOADS_DIR}/${PROBLEM_TYPE}.json"

if [[ ! -f "$PAYLOAD_FILE" ]]; then
    echo -e "${RED}Error: Unknown problem type '${PROBLEM_TYPE}'${NC}"
    echo ""
    echo "Available problem types:"
    for f in "${PAYLOADS_DIR}"/*.json; do
        basename "$f" .json
    done
    exit 1
fi

# Generate unique problem ID
PROBLEM_ID="P-$(date +%Y%m%d%H%M%S)-$(( RANDOM % 1000 ))"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

echo -e "${YELLOW}Problem Type:${NC} ${PROBLEM_TYPE}"
echo -e "${YELLOW}Problem ID:${NC} ${PROBLEM_ID}"
echo -e "${YELLOW}Event Stream URL:${NC} ${EVENT_STREAM_URL}"
echo ""

# Read and customize payload
PAYLOAD=$(cat "$PAYLOAD_FILE" | \
    sed "s/\"ProblemID\": \".*\"/\"ProblemID\": \"${PROBLEM_ID}\"/" | \
    sed "s/\"StartTime\": .*,/\"StartTime\": $(date +%s000),/" | \
    sed "s/\"EndTime\": .*,/\"EndTime\": -1,/")

echo -e "${YELLOW}Sending payload:${NC}"
echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
echo ""

# Build curl command
# -k flag allows self-signed certificates (common in OpenShift test environments)
CURL_CMD="curl -k -s -w '\n%{http_code}' -X POST"
CURL_CMD="$CURL_CMD -H 'Content-Type: application/json'"

if [[ -n "$AUTH_TOKEN" ]]; then
    CURL_CMD="$CURL_CMD -H 'Authorization: Bearer ${AUTH_TOKEN}'"
fi

CURL_CMD="$CURL_CMD -d '${PAYLOAD}' '${EVENT_STREAM_URL}'"

echo -e "${YELLOW}Sending webhook...${NC}"
echo ""

# Execute request
RESPONSE=$(eval "$CURL_CMD")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    echo -e "${GREEN}Success! HTTP ${HTTP_CODE}${NC}"
    if [[ -n "$BODY" ]]; then
        echo "Response: $BODY"
    fi
else
    echo -e "${RED}Failed! HTTP ${HTTP_CODE}${NC}"
    if [[ -n "$BODY" ]]; then
        echo "Response: $BODY"
    fi
    exit 1
fi

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Problem notification sent successfully!${NC}"
echo ""
echo "Check EDA Controller for rulebook activation"
echo "Check AAP Controller for triggered job template"
echo -e "${BLUE}============================================${NC}"
