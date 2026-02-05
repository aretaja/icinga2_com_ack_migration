#!/usr/bin/env bash
# Export service comments and acknowledgements into file
set -euo pipefail

ICINGA_HOST="${ICINGA_HOST:-localhost}"
ICINGA_PORT="${ICINGA_PORT:-5665}"
ICINGA_USER="${ICINGA_USER:-apiuser}"
ICINGA_PASS="${ICINGA_PASS:-}"
OUTFILE="${OUTFILE:-services_acks_comments.json}"
SINCE="${SINCE:-}"

[[ -n "${ICINGA_PASS}" ]] || { read -rsp "Password for ${ICINGA_USER}@${ICINGA_HOST}: " ICINGA_PASS; echo; }
[[ -n "${SINCE}" ]] || { read -rp "Provide UNIX timestam of start time: " SINCE; echo; }

BASE="https://${ICINGA_HOST}:${ICINGA_PORT}/v1"
apiget() {
  curl -sS -k -u "${ICINGA_USER}:${ICINGA_PASS}" \
    -H 'Accept: application/json' \
    -H 'X-HTTP-Method-Override: GET' \
    -X POST "$1" -d "$2"
}

# temp files + cleanup
comments_tf="$(mktemp)"; svcs_tf="$(mktemp)"
svcmap_tf="$(mktemp)"; ack_comments_tf="$(mktemp)"
regular_comments_tf="$(mktemp)"; ack_enriched_tf="$(mktemp)"
trap 'rm -f "$comments_tf" "$svcs_tf" "$svcmap_tf" "$ack_comments_tf" "$regular_comments_tf" "$ack_enriched_tf"' EXIT

echo "Collecting SERVICE comments and ack states from ${ICINGA_HOST} ..."

# 1) Raw pulls → files
CPAYLOAD=$(cat <<EOF
{
  "attrs": ["author","text","entry_time","expire_time","entry_type",
            "host_name","service_name","persistent"
           ],
  "filter": "comment.entry_time>=${SINCE}"
}
EOF
)

apiget "${BASE}/objects/comments" "$CPAYLOAD" > "$comments_tf"

apiget "${BASE}/objects/services" $'{
  "attrs": ["host_name","name","acknowledgement","acknowledgement_expiry"],
  "filter": "service.acknowledgement>0"
}' > "$svcs_tf"

# 2) Build ACK map: {"host\0service": {sticky,expiry}, ...}
jq '
  .results
  | map({ key: (.attrs.host_name + "\u0000" + .attrs.name),
          value: { sticky: (.attrs.acknowledgement==2),
                   expiry: (.attrs.acknowledgement_expiry // 0) } })
  | from_entries
' "$svcs_tf" > "$svcmap_tf"

# 3) Split comments (SERVICES ONLY) → files
jq '
  .results | map(.attrs)
  | map(select((.service_name? // "") != ""))    # keep services only
  | map(select(.entry_type == 4))                # ack comments
  | sort_by(.entry_time)
  | group_by([.host_name, .service_name]) | map(last)
' "$comments_tf" > "$ack_comments_tf"

jq '
  .results | map(.attrs)
  | map(select((.service_name? // "") != ""))    # keep services only
  | map(select(.entry_type != 4))
' "$comments_tf" > "$regular_comments_tf"

# 4) Enrich ack comments with sticky/expiry
jq --slurpfile smap "$svcmap_tf" '
  ($smap[0] // {}) as $S
  | map(. + ( $S[(.host_name + "\u0000" + .service_name)] // {sticky:true,expiry:0} ))
' "$ack_comments_tf" > "$ack_enriched_tf"

# 5) Emit bundle
jq -n \
  --arg now "$(date -u +%FT%TZ)" \
  --arg host "${ICINGA_HOST}" \
  --slurpfile acks "$ack_enriched_tf" \
  --slurpfile comments "$regular_comments_tf" '
{
  kind: "services",
  schema_version: 1,
  generated_at_utc: $now,
  source_host: $host,
  ack_comments: $acks[0],
  comments: $comments[0]
}
' > "${OUTFILE}"

echo "Wrote $(wc -c <"${OUTFILE}") bytes to ${OUTFILE}"
