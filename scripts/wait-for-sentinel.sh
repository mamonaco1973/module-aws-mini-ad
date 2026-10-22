#!/bin/bash
# ==================================================================================================
# wait-for-sentinel.sh
# Purpose:
#   - Runs on the machine executing Terraform (local-exec), not on the DC.
#   - Polls the SSM status parameter until this instance reports ready or
#     failed, printing each status change so the apply shows progress.
#
# Environment:
#   PARAM        SSM parameter name
#   REGION       AWS region of the parameter
#   INSTANCE_ID  DC instance to wait for; other instances' values are ignored
#   TIMEOUT      seconds before giving up
# ==================================================================================================

set -uo pipefail

deadline=$((SECONDS + TIMEOUT))
last=""

echo "mini-ad: waiting for $INSTANCE_ID to report ready on $PARAM (timeout ${TIMEOUT}s)"

while [ "$SECONDS" -lt "$deadline" ]; do
  value="$(aws ssm get-parameter --region "$REGION" --name "$PARAM" \
    --query Parameter.Value --output text 2>/dev/null || true)"

  if [ "$value" != "$last" ]; then
    echo "mini-ad: [${SECONDS}s] status = ${value:-<unreadable>}"
    last="$value"
  fi

  case "$value" in
    "ready:$INSTANCE_ID")
      echo "mini-ad: domain controller ready after ${SECONDS}s"
      exit 0
      ;;
    "failed:$INSTANCE_ID:"*)
      echo "mini-ad: bootstrap FAILED on $INSTANCE_ID: ${value#"failed:$INSTANCE_ID:"}" >&2
      echo "mini-ad: full log: /root/userdata.log on the DC (SSM session)" >&2
      exit 1
      ;;
  esac

  sleep 10
done

echo "mini-ad: timed out after ${TIMEOUT}s; last status: ${last:-<none>}" >&2
echo "mini-ad: a failure before the AWS CLI install cannot be reported; check /root/userdata.log" >&2
exit 1
