# Zammad API Reference

## Connection
- Base URL: `https://support.toddcowing.com`
- API Key: stored in `~/.claude/credentials.env` as `ZAMMAD_API_KEY`
- Auth header: `Authorization: Token token=<key>`
- Intake email: `intake@toddcowing.com`

## Authentication

```bash
source ~/.claude/credentials.env
# Use in every request: -H "Authorization: Token token=$ZAMMAD_API_KEY"
```

---

## Core Endpoints

### List Open Tickets

```bash
curl -s "$ZAMMAD_BASE_URL/api/v1/tickets?state=open" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" | python3 -m json.tool
```

### Get a Single Ticket

```bash
curl -s "$ZAMMAD_BASE_URL/api/v1/tickets/{ticket_id}" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" | python3 -m json.tool
```

### Get Ticket Articles (messages and notes)

```bash
curl -s "$ZAMMAD_BASE_URL/api/v1/ticket_articles/by_ticket/{ticket_id}" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" | python3 -m json.tool
```

### Add an Internal Note

```bash
curl -X POST "$ZAMMAD_BASE_URL/api/v1/ticket_articles" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": {ticket_id},
    "subject": "Developer Note",
    "body": "Fixed in commit abc123. Deploying in next release.",
    "type": "note",
    "internal": true
  }'
```

### Update Ticket State (e.g. Close)

```bash
# Get available state IDs first
curl -s "$ZAMMAD_BASE_URL/api/v1/ticket_states" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY"

# Close a ticket (verify state_id from above)
curl -X PATCH "$ZAMMAD_BASE_URL/api/v1/tickets/{ticket_id}" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"state_id": 4}'
```

### Search Tickets

```bash
curl -s "$ZAMMAD_BASE_URL/api/v1/tickets/search?query=login+crash&limit=10" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" | python3 -m json.tool
```

---

## Ticket Fields

| Field | Description |
|-------|-------------|
| `id` | Ticket ID |
| `number` | Human-readable number (e.g. 1001) |
| `title` | Subject/title |
| `state_id` | State (open, closed, pending, etc.) |
| `priority_id` | Priority level |
| `customer_id` | Reporter user ID |
| `group_id` | Assigned group (1 = default intake group) |
| `created_at` | Creation timestamp |
| `updated_at` | Last update timestamp |

---

## Support Bot Flow

The `support-bot` on the support VM watches Zammad and auto-creates Plane issues:

1. User submits a bug via email to `intake@toddcowing.com` or web form
2. Zammad creates a ticket
3. `support-bot` reads the ticket via Zammad API
4. `support-bot` creates a Plane work item in the matching project (routed by `app` field)
5. Issue lands in Plane **Backlog**

**Check bot logs:**
```bash
ssh todd@support.toddcowing.com "tail -50 /var/log/support-bot.log"
```

**Bot config:** `/home/todd/support-bot.env` on the support VM

---

## Common Agent Workflows

### Review incoming bugs before starting work
```bash
source ~/.claude/credentials.env
curl -s "$ZAMMAD_BASE_URL/api/v1/tickets?state=open&per_page=10" \
  -H "Authorization: Token token=$ZAMMAD_API_KEY" \
  | python3 -c "import json,sys; [print(f\"#{t['number']}: {t['title']}\") for t in json.load(sys.stdin)]"
```

### After fixing a bug
1. Add internal note: `"Fixed in commit [hash]. Shipping in next release."`
2. Update state to closed.

### Find the Zammad ticket for a Plane issue
The support-bot includes the Zammad ticket number in the Plane issue body when it auto-creates it. Search the issue description for `#` followed by a number.
