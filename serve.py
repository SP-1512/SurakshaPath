import http.server
import socket
import os
import threading

PORT = 8080
DIRECTORY = r"C:\Users\pinni\.gemini\antigravity\scratch\surakshapath\build\web"

class WebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, request, client_address, server):
        super().__init__(request, client_address, server, directory=DIRECTORY)

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

class IPv6Server(http.server.HTTPServer):
    address_family = socket.AF_INET6

if __name__ == "__main__":
    os.chdir(DIRECTORY)
    s_v4 = http.server.HTTPServer(("127.0.0.1", PORT), WebHandler)
    t_v4 = threading.Thread(target=s_v4.serve_forever, daemon=True)
    t_v4.start()

    try:
        s_v6 = IPv6Server(("::1", PORT), WebHandler)
        print(f"Dual-listener running: http://127.0.0.1:{PORT} and http://[::1]:{PORT} (http://localhost:{PORT})", flush=True)
        s_v6.serve_forever()
    except Exception as e:
        print(f"IPv4 server running on http://127.0.0.1:{PORT} (IPv6 error: {e})", flush=True)
        s_v4.serve_forever()
