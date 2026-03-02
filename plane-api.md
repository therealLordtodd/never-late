# Plane API Reference

## Connection
- Base URL: `https://project.toddcowing.com`
- API Key: stored in `~/.claude/credentials.env` as `PLANE_API_KEY`
- Auth header: `X-API-Key: <key>`
- Workspace slug: `bang-and-co`

## This Project
- Project Name: `Never Late`
- Project ID: `e5ad798c-521a-414c-ab85-d63117e69664`
- Identifier: `NL`
- Workspace ID: `7d2c05a5-8b9d-450b-b297-85b7e407afe8`
- Code Review Module ID: `34a42192-f26f-4f9c-b56e-08aca222373d`

## States
> After creating your Plane project, query the states endpoint and fill in the IDs below.

| Name        | ID                       | Group     |
|-------------|--------------------------|-----------|
| Backlog     | `201842af-665f-425c-ada6-716566c111d3`     | backlog   |
| Todo        | `ce6b0b5e-96f4-44e9-aacd-24023bcc1478`        | unstarted |
| In Progress | `ee57b2d0-2f1e-4617-b880-4093c091554d` | started   |
| Done        | `91275231-49fc-44c6-9967-c9f12e6bdc05`        | completed |
| Cancelled   | `8fd8b304-cf31-41b2-a719-dbc44f551fd1`   | cancelled |

---

## Two API Stacks

| Route prefix | Auth method | Features |
|---|---|---|
| `/api/v1/` | `X-API-Key` header | Work items, cycles, modules, labels, states, projects, members |
| `/api/` | Session cookie (`session-id`) | Everything above + **Pages**, notifications, search, analytics |

**Pages are NOT available via `/api/v1/`.** You must use session auth for Pages.

---

## v1 API Endpoints (API Key Auth)

```bash
GET    /api/v1/users/me/
GET    /api/v1/workspaces/bang-and-co/projects/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/states/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/work-items/
POST   /api/v1/workspaces/bang-and-co/projects/{project_id}/work-items/
PATCH  /api/v1/workspaces/bang-and-co/projects/{project_id}/work-items/{work_item_id}/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/labels/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/cycles/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/modules/
GET    /api/v1/workspaces/bang-and-co/projects/{project_id}/modules/{module_id}/module-issues/
POST   /api/v1/workspaces/bang-and-co/projects/{project_id}/modules/{module_id}/module-issues/
```

### Work Item Fields (POST/PATCH)
- `name` (required): title
- `state`: state UUID
- `priority`: `"none"` | `"low"` | `"medium"` | `"high"` | `"urgent"`
- `description_html`: HTML content
- `label_ids`: array of label UUIDs
- `assignees`: array of user UUIDs
- `due_date`: `"YYYY-MM-DD"`
- `parent`: parent work item UUID (for sub-items)

### Attach Work Items to a Module

`module_ids` on work-item create is not reliable in this workspace. Attach explicitly:

```bash
curl -X POST "$PLANE_BASE_URL/api/v1/workspaces/bang-and-co/projects/$PROJECT_ID/modules/$MODULE_ID/module-issues/" \
  -H "X-API-Key: $PLANE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"issues": ["<work_item_id>"]}'
```

---

## Pages API (Session Auth Required)

Pages are only under `/api/` (Django session auth). **Do NOT use `/api/v1/` for Pages — it returns 404.**

**Do NOT insert pages directly into the database via SQL.** This bypasses validation and audit fields.

### Step 1: Generate a Session Key

```bash
SESSION_KEY=$(ssh todd@project.toddcowing.com "docker exec api python manage.py shell -c \"
from importlib import import_module
from django.conf import settings
from django.contrib.auth import get_user_model
engine = import_module(settings.SESSION_ENGINE)
User = get_user_model()
user = User.objects.get(email='toddshops@green-cat.org')
s = engine.SessionStore()
s['_auth_user_id'] = str(user.pk)
s['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
s['_auth_user_hash'] = user.get_session_auth_hash()
s.create()
print(s.session_key)
\"")
```

### Step 2: Use the Session Cookie

Cookie name is **`session-id`** (not `sessionid`). No CSRF token needed.

```bash
BASE_URL="https://project.toddcowing.com"
PROJECT_ID="e5ad798c-521a-414c-ab85-d63117e69664"
COOKIE="session-id=${SESSION_KEY}"
```

### Pages Endpoints

```bash
GET    /api/workspaces/bang-and-co/projects/{project_id}/pages/
POST   /api/workspaces/bang-and-co/projects/{project_id}/pages/
GET    /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/
PATCH  /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/
DELETE /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/
POST   /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/archive/
GET    /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/description/
PATCH  /api/workspaces/bang-and-co/projects/{project_id}/pages/{page_id}/description/
```

### Create a Page

```bash
curl -X POST "${BASE_URL}/api/workspaces/bang-and-co/projects/${PROJECT_ID}/pages/" \
  -H "Content-Type: application/json" \
  -H "Cookie: ${COOKIE}" \
  -d '{"name": "Page Title", "description_html": "<p>Content</p>"}'
```

### Session Details
- Sessions expire after **7 days**
- Generate a new session if you get 401/403
- User: `toddshops@green-cat.org` (ID: `846cc07d-69e3-4e80-b7b3-c15682cd2f0c`)
