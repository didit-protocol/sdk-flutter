#!/usr/bin/env python3
"""A stand-in for the verification API, for tool/ios_bridge_test.sh.

It answers the workflow session request (POST /v1/session/unilink/<workflow id>/) the
way the API answers a person whose earlier session was declined and who has no retries
left, and answers 404 to anything else. It logs each request's method, path and status
to stderr, never its query or body.
"""

import argparse
import json
import socket
import ssl
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

UNILINK_PATH = "/v1/session/unilink/"


def retry_blocked_session(workflow_id):
    return {
        "session_id": "retry-blocked-session",
        "session_token": "retry-blocked-token",
        "url": "https://verify.didit.me/session/retry-blocked-token",
        "status": "Declined",
        "workflow_id": workflow_id,
        "workflow_label": "Bridge test",
        "requires_email": False,
        "is_existing_session": True,
        "can_retry": False,
        "retry_attempts_used": 3,
        "max_retry_attempts": 2,
        "retry_window_days": None,
        "retry_resets_at": None,
    }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        path = urlsplit(self.path).path
        if path.startswith(UNILINK_PATH):
            self.reply(200, retry_blocked_session(path[len(UNILINK_PATH):].strip("/")))
        else:
            self.reply(404, {"detail": "Not found."})

    def do_GET(self):
        self.reply(404, {"detail": "Not found."})

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_request(self, code="-", size="-"):
        sys.stderr.write(f"{self.command} {urlsplit(self.path).path} {code}\n")


class DualStackServer(ThreadingHTTPServer):
    # The API host points at both 127.0.0.1 and ::1, so listen on both.
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()

    def get_request(self):
        try:
            return super().get_request()
        except ssl.SSLError as error:
            sys.stderr.write(f"TLS handshake failed: {error}\n")
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=443)
    parser.add_argument("--cert", required=True, help="server certificate (PEM)")
    parser.add_argument("--key", required=True, help="server private key (PEM)")
    args = parser.parse_args()

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.cert, args.key)
    server = DualStackServer(("::", args.port), Handler)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
