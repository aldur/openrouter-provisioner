# OpenRouter API key provisioner

Serve it behind a VPN/authentication and use it to generate API keys expiring
after 24h. Then, fetch API keys with:

```bash
curl -X POST http://127.0.0.1:8000 | jq '.api_key'
```
