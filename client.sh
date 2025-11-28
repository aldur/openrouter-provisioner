#!/usr/bin/env bash
set -euo pipefail

curl -s -X POST "http://$1/" | jq -r .api_key
