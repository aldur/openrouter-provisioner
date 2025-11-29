"""
OpenRouter API Key Provisioner

A simple REST API that creates OpenRouter API keys with 24-hour expiration.
Uses the OpenRouter Provisioning API.

Usage:
    1. Set the environment variable:
       export OPENROUTER_PROVISIONING_KEY="your-provisioning-key-here"
    2. Run the server: python openrouter_key_provisioner.py
    3. POST to http://localhost:8000/
    4. Optionally include "name" and "limit" in the request body
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timedelta, timezone
import json
import os
import urllib.request
import urllib.error

PROVISIONING_KEY = os.environ.get("OPENROUTER_PROVISIONING_KEY")


class KeyProvisionerHandler(BaseHTTPRequestHandler):
    def _send_json_response(self, status_code: int, data: dict):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_POST(self):
        if self.path != "/":
            self._send_json_response(404, {"error": "Not found"})
            return

        # Read and parse request body (optional)
        content_length = int(self.headers.get("Content-Length", 0))
        body = {}
        if content_length > 0:
            try:
                body = json.loads(self.rfile.read(content_length).decode("utf-8"))
            except json.JSONDecodeError:
                self._send_json_response(400, {"error": "Invalid JSON"})
                return

        # Optional parameters
        key_name = body.get(
            "name", f"temp-key-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}"
        )
        credit_limit = body.get("limit")  # Optional credit limit in dollars

        # Calculate expiration time (24 hours from now)
        expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )

        # Build request to OpenRouter Provisioning API
        openrouter_payload = {
            "name": key_name,
            "expires_at": expires_at,
        }

        if credit_limit is not None:
            openrouter_payload["limit"] = credit_limit

        # Make request to OpenRouter
        try:
            req = urllib.request.Request(
                "https://openrouter.ai/api/v1/keys",
                data=json.dumps(openrouter_payload).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {PROVISIONING_KEY}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )

            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode("utf-8"))

            # Extract the API key from the response
            api_key = result.get("key") or result.get("data", {}).get("key")

            self._send_json_response(
                200,
                {
                    "success": True,
                    "api_key": api_key,
                    "name": key_name,
                    "expires_at": expires_at,
                    "full_response": result,
                },
            )

        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            try:
                error_json = json.loads(error_body)
            except json.JSONDecodeError:
                error_json = {"raw": error_body}

            self._send_json_response(
                e.code,
                {
                    "success": False,
                    "error": f"OpenRouter API error: {e.code}",
                    "details": error_json,
                },
            )

        except urllib.error.URLError as e:
            self._send_json_response(
                502,
                {
                    "success": False,
                    "error": f"Failed to connect to OpenRouter: {str(e.reason)}",
                },
            )

        except Exception as e:
            self._send_json_response(
                500,
                {
                    "success": False,
                    "error": f"Internal error: {str(e)}",
                },
            )


def main():
    import os

    host = os.getenv("HOST") or "0.0.0.0"
    port = int(os.getenv("PORT") or 8000)

    if not PROVISIONING_KEY:
        print("ERROR: OPENROUTER_PROVISIONING_KEY environment variable is not set!")
        print()
        print("Set it before running the server:")
        print("  export OPENROUTER_PROVISIONING_KEY='your-provisioning-key-here'")
        exit(1)

    server = HTTPServer((host, port), KeyProvisionerHandler)
    print(f"OpenRouter Key Provisioner running on http://{host}:{port}")
    print()
    print("Usage:")
    print(f"  curl -X POST http://localhost:{port}/")
    print()
    print("With optional parameters:")
    print(f"  curl -X POST http://localhost:{port}/ \\")
    print('       -H "Content-Type: application/json" \\')
    print('       -d \'{"name": "my-key", "limit": 5.0}\'')
    print()
    print("Optional parameters in request body:")
    print('  - "name": Custom name for the key (default: auto-generated)')
    print('  - "limit": Credit limit in dollars (default: none)')
    print()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
