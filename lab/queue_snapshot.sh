#!/bin/bash
# Every minute: postfix queue snapshot -> JSON lines in /var/log/postfix-queue.log (picked up by OneAgent log module)
NOW=$(date +%s)
postqueue -j 2>/dev/null | jq -s -c --argjson now "$NOW" '
  (map({q:.queue_name, d:(.recipients[0].address|split("@")[1]), age:($now-.arrival_time)})) as $m
  | ( ["incoming","active","deferred","hold"][] as $q
      | {ts:($now|todate), event:"postfix_queue_snapshot", queue:$q,
         messages:([ $m[]|select(.q==$q) ]|length),
         oldest_age_s:([ $m[]|select(.q==$q)|.age ]|max // 0)} ),
    ( $m | map(select(.q=="deferred")) | group_by(.d)[]
      | {ts:($now|todate), event:"postfix_queue_by_domain", queue:"deferred", dest_domain:.[0].d, messages:length} )
' >> /var/log/postfix-queue.log
