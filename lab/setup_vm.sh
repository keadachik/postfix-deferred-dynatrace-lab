#!/bin/bash
set -e
install -m755 fake_smtp.py /usr/local/bin/fake_smtp.py
install -m755 queue_snapshot.sh /usr/local/bin/postfix_queue_snapshot.sh
install -m755 send_mail.sh /usr/local/bin/postfix_send_mail.sh
mkdir -p /etc/fakesmtp; echo ok > /etc/fakesmtp/exo.mode; echo ok > /etc/fakesmtp/partner.mode
for n in exo:2525 partner:2526; do
cat > /etc/systemd/system/fakesmtp-${n%%:*}.service <<U
[Unit]
Description=fake upstream SMTP ${n%%:*}
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/fake_smtp.py ${n%%:*} ${n##*:}
Restart=always
[Install]
WantedBy=multi-user.target
U
done
cat > /etc/systemd/system/mailgen.service <<U
[Unit]
Description=demo outbound mail generator
[Service]
ExecStart=/usr/local/bin/postfix_send_mail.sh
[Install]
WantedBy=multi-user.target
U
grep -q mx.partner.example /etc/hosts || echo "127.0.0.1 contoso-example.mail.protection.outlook.com mx.partner.example" >> /etc/hosts
# route: contoso.example -> "Exchange Online" smarthost; partner.example -> other relay
cat > /etc/postfix/transport <<T
contoso.example   smtp:[contoso-example.mail.protection.outlook.com]:2525
partner.example   smtp:[mx.partner.example]:2526
T
postmap /etc/postfix/transport
postconf -e myhostname=mail.demo.local inet_interfaces=loopback-only \
  transport_maps=hash:/etc/postfix/transport smtp_tls_security_level=none \
  queue_run_delay=60s minimal_backoff_time=60s maximal_backoff_time=300s \
  smtp_host_lookup=native default_destination_concurrency_limit=5
touch /var/log/postfix-queue.log; chmod 644 /var/log/postfix-queue.log
echo '* * * * * root /usr/local/bin/postfix_queue_snapshot.sh' > /etc/cron.d/postfix-queue-snapshot
systemctl daemon-reload
systemctl enable --now fakesmtp-exo fakesmtp-partner mailgen
systemctl restart postfix
