#!/usr/bin/env bash
# Import service comments and acknowledgements from file
set -euo pipefail

ICINGA_HOST="${ICINGA_HOST:-localhost}"
ICINGA_PORT="${ICINGA_PORT:-5665}"
ICINGA_USER="${ICINGA_USER:-apiuser}"
ICINGA_PASS="${ICINGA_PASS:-}"
INFILE="${INFILE:-hosts_acks_comments.json}"
MIGRATION_AUTHOR="${MIGRATION_AUTHOR:-migration-bot}"

[[ -n "${ICINGA_PASS}" ]] || { read -rsp "Password for ${ICINGA_USER}@${ICINGA_HOST}: " ICINGA_PASS; echo; }
[[ -s "${INFILE}" ]] || { echo "Input JSON ${INFILE} not found or empty" >&2; exit 1; }

BASE="https://${ICINGA_HOST}:${ICINGA_PORT}/v1"
apipost() {
  curl -sS -k -u "${ICINGA_USER}:${ICINGA_PASS}" \
    -H 'Accept: application/json' -H 'Content-Type: application/json' \
    -X POST "$1" -d "$2"
}

echo "Importing HOST acknowledgements ..."
jq -c '.ack_comments[]' "${INFILE}" | while read -r item; do
  HOST=$(jq -r '.host_name' <<<"$item")
  AUTHOR=$(jq -r '.author // empty' <<<"$item")
  TEXT=$(jq -r '.text // "migrated acknowledgement"' <<<"$item")
  STICKY=$(jq -r '.sticky // true' <<<"$item")
  EXP=$(jq -r '.expiry // 0' <<<"$item")

  PAYLOAD=$(jq -n \
    --arg author "${AUTHOR:-$MIGRATION_AUTHOR}" \
    --arg comment "${TEXT}" \
    --arg filter "host.name==\"${HOST}\"" \
    --argjson sticky "${STICKY}" --argjson expiry "${EXP}" '
    {
      type: "Host", filter: $filter,
      author: $author, comment: $comment,
      sticky: $sticky, notify: false
    } + (if $expiry>0 then {expiry:$expiry} else {} end)
  ')
  echo "ACK → Host ${HOST}"
  apipost "${BASE}/actions/acknowledge-problem" "${PAYLOAD}" >/dev/null
done

echo "Importing HOST comments ..."
jq -c '.comments[]' "${INFILE}" | while read -r item; do
  HOST=$(jq -r '.host_name' <<<"$item")
  AUTHOR=$(jq -r '.author // empty' <<<"$item")
  TEXT=$(jq -r '.text // "migrated comment"' <<<"$item")
  PERSIST=$(jq -r 'if .persistent==true then true else false end' <<<"$item")
  EXP=$(jq -r '.expire_time // 0' <<<"$item")

  PAYLOAD=$(jq -n \
    --arg author "${AUTHOR:-$MIGRATION_AUTHOR}" \
    --arg comment "${TEXT}" \
    --arg filter "host.name==\"${HOST}\"" \
    --argjson persistent "${PERSIST}" --argjson expiry "${EXP}" '
    {
      type: "Host", filter: $filter,
      author: $author, comment: $comment, persistent: $persistent
    } + (if $expiry>0 then {expiry:$expiry} else {} end)
  ')
  echo "COMMENT → Host ${HOST}"
  apipost "${BASE}/actions/add-comment" "${PAYLOAD}" >/dev/null
done

echo "Done."
