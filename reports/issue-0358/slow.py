import socket, sys, time
port, rate, secs = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
s = socket.create_connection(("127.0.0.1", port), timeout=5)
s.sendall(b"POST /api/validate HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/xml\r\nContent-Length: 20000000\r\n\r\n")
t0 = time.time(); end = None
try:
    while time.time() - t0 < secs:
        s.sendall(b"<" * rate); time.sleep(1)
        s.settimeout(0.01)
        try:
            d = s.recv(300)
            if d or d == b"": end = f"server answered/closed after {time.time()-t0:.0f}s: {d[:60]!r}"; break
        except socket.timeout: pass
        s.settimeout(5)
except Exception as e:
    end = f"dropped after {time.time()-t0:.0f}s ({type(e).__name__})"
print(f"{rate} B/s for up to {secs}s: {end or 'still open'}")
