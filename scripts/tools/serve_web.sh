#!/usr/bin/env bash
# Serve the Godot HTML5 export locally with proper headers.
# Generates a self-signed SSL cert so SharedArrayBuffer works on LAN devices.
# Usage: ./scripts/tools/serve_web.sh [port]

PORT="${1:-8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$(cd "$SCRIPT_DIR/../../../../artifacts/test/web" 2>/dev/null && pwd)"
CERT_DIR="$SCRIPT_DIR/.certs"

if [ ! -d "$WEB_DIR" ]; then
    echo "Error: artifact/web/ not found. Export the project for Web first."
    echo "  Godot > Project > Export > Web > Export Project"
    exit 1
fi

if ! [ -f "$WEB_DIR/index.html" ]; then
    echo "Error: index.html not found in $WEB_DIR"
    exit 1
fi

# Generate self-signed cert if missing
mkdir -p "$CERT_DIR"
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ]; then
    echo "Generating self-signed SSL certificate..."
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
    openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" \
        -days 365 -nodes -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1${LOCAL_IP:+,IP:$LOCAL_IP}" \
        2>/dev/null
    echo "Certificate created at $CERT_DIR/"
fi

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
echo "Serving $WEB_DIR on:"
echo "  https://localhost:$PORT"
[ -n "$LOCAL_IP" ] && echo "  https://$LOCAL_IP:$PORT  (LAN)"
echo ""
echo "NOTE: Accept the self-signed certificate warning in your browser."
echo "Press Ctrl+C to stop."

python3 -c "
import http.server, ssl, functools, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

handler = functools.partial(Handler, directory='$WEB_DIR')
server = http.server.HTTPServer(('0.0.0.0', $PORT), handler)

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('$CERT_DIR/cert.pem', '$CERT_DIR/key.pem')
server.socket = context.wrap_socket(server.socket, server_side=True)

print('Ready — open https://localhost:$PORT in your browser')
try:
    server.serve_forever()
except KeyboardInterrupt:
    print('\nStopped.')
"
