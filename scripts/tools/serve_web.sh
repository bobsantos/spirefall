#!/usr/bin/env bash
# Serve the Godot HTML5 export locally with proper headers.
# Usage: ./scripts/tools/serve_web.sh [port]

PORT="${1:-8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$(cd "$SCRIPT_DIR/../../../../artifacts/test/web" 2>/dev/null && pwd)"

if [ ! -d "$WEB_DIR" ]; then
    echo "Error: artifact/web/ not found. Export the project for Web first."
    echo "  Godot > Project > Export > Web > Export Project"
    exit 1
fi

if ! [ -f "$WEB_DIR/index.html" ]; then
    echo "Error: index.html not found in $WEB_DIR"
    exit 1
fi

echo "Serving $WEB_DIR on http://localhost:$PORT"
echo "Press Ctrl+C to stop."

python3 -c "
import http.server, functools, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

handler = functools.partial(Handler, directory='$WEB_DIR')
server = http.server.HTTPServer(('0.0.0.0', $PORT), handler)
print('Ready — open http://localhost:$PORT in your browser')
try:
    server.serve_forever()
except KeyboardInterrupt:
    print('\nStopped.')
"
