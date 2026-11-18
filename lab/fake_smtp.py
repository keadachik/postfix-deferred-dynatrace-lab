#!/usr/bin/env python3
"""Fake upstream SMTP (M365 Exchange Online / other relay) for the postfix deferred-queue lab.
Mode is read from /etc/fakesmtp/<name>.mode on every connection:
  ok        -> accept mail (250)
  busy      -> 451 4.7.500 Server busy (EXO-style throttling, temporary)
  tempfail  -> 421 4.3.2 Service not available (connection-level temp failure)
  slow      -> accept but sleep 20s before banner (latency)
  reject    -> 550 5.7.1 (permanent -> bounce, NOT deferred)
"""
import asyncio, sys, pathlib, time
name, port = sys.argv[1], int(sys.argv[2])
modefile = pathlib.Path(f"/etc/fakesmtp/{name}.mode")
host = "BN8NAM12FT012.mail.protection.outlook.com" if name == "exo" else "mx.partner.example"

def mode():
    try: return modefile.read_text().strip()
    except Exception: return "ok"

async def handle(r, w):
    m = mode()
    async def send(s): w.write((s + "\r\n").encode()); await w.drain()
    try:
        if m == "slow": await asyncio.sleep(20)
        if m == "tempfail":
            await send(f"421 4.3.2 Service not available, closing transmission channel [{host}]"); return
        await send(f"220 {host} Microsoft ESMTP MAIL Service ready" if name == "exo" else f"220 {host} ESMTP")
        while True:
            line = (await r.readline()).decode(errors="ignore").strip()
            if not line: return
            cmd = line.upper()
            if cmd.startswith(("EHLO", "HELO")): await send(f"250 {host} Hello")
            elif cmd.startswith("MAIL FROM"): await send("250 2.1.0 Sender OK")
            elif cmd.startswith("RCPT TO"):
                if m == "busy": await send(f"451 4.7.500 Server busy. Please try again later. [{host}]")
                elif m == "reject": await send("550 5.7.1 Service unavailable, Client host blocked")
                else: await send("250 2.1.5 Recipient OK")
            elif cmd == "DATA":
                await send("354 Start mail input; end with <CRLF>.<CRLF>")
                while (await r.readline()).decode(errors="ignore").rstrip("\r\n") != ".": pass
                await send(f"250 2.6.0 <{int(time.time()*1000)}@{host}> Queued mail for delivery")
            elif cmd == "RSET": await send("250 2.0.0 Resetting")
            elif cmd == "QUIT": await send("221 2.0.0 Service closing transmission channel"); return
            else: await send("250 OK")
    finally:
        w.close()

async def main():
    srv = await asyncio.start_server(handle, "127.0.0.1", port)
    async with srv: await srv.serve_forever()
asyncio.run(main())
