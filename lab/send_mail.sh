#!/bin/bash
# Steady outbound traffic: N msgs/min to M365-routed domain and to a non-M365 partner domain.
while true; do
  for i in 1 2 3 4; do echo "test $(date)" | mail -s "order $RANDOM" -r app@demo.local user$i@contoso.example; done
  echo "test $(date)" | mail -s "notice $RANDOM" -r app@demo.local ops@partner.example
  sleep 15
done
