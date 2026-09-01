# MCP compatibility — TavoLink v1.0

Auto mode uses this order:

1. **MCP 2026-07-28 stateless HTTP** — request carries `MCP-Protocol-Version`, `Mcp-Method` and `_meta` client data. `Mcp-Name` is added for tool calls.
2. **Direct HTTP JSON-RPC** — no MCP protocol/session headers. This is included specifically for Tavo MCP deployments that expose a direct JSON-RPC endpoint.
3. **MCP 2025-11-25 session mode** — `initialize`, optional `Mcp-Session-Id`, then `notifications/initialized`.

Supported client operations in v1:

- `tools/list`
- `tools/call`
- `resources/list` (count/status UI)
- `prompts/list` (count/status UI)

Response handling:

- `application/json`
- request-scoped `text/event-stream` where JSON-RPC responses are carried in `data:` events

Transport not included in v1:

- stdio (not appropriate for a normal sandboxed iOS/Android client)
- legacy dedicated HTTP+SSE endpoint pair
- WebSocket-only private protocols

TavoLink does not hard-code Tavo tool names; the server's `tools/list` response is converted dynamically into model function definitions.
