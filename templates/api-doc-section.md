## {{KEY}} — {{Ticket title}}

**Scope:** {{what this pass delivers}}.
**Not in this pass:** {{deferred / blocked items with ticket keys, or "nothing"}}.

**APIs this ticket needs:**

| # | Method | URL | When the FE calls it |
|---|---|---|---|
| 1 | GET | `/orders/{id}` | load the form |
| 2 | PUT | `/orders/{id}` | Save button |
| — | GET | `/lookups/...` | dropdowns — see the shared section "{{shared heading}}" |

### 1. GET `/orders/{id}?include=items`

**Request:** no body. Path: `id` (int). Query: `include` (optional, `items`; omitted = header only).

**Response 200:**
```jsonc
{ /* exact shape from a passing call in the API test log; long arrays trimmed, personal data anonymised */ }
```

**Errors:**
| Status | Exact condition |
|---|---|
| 404 | no order with this `id` visible to the caller |

**Notes for FE:**
- {{fields that only appear for one parameter value, nullable vs empty-array semantics, ...}}

### 2. PUT `/orders/{id}`

**Request body:**
```jsonc
{
  "customerName": "Jane Doe",   // required, max 200 chars
  "status": 1,                  // required, enum: 0=Draft, 1=Submitted, 2=Cancelled
  "deliveryDays": 7,            // optional, default 3; allowed: 1–30
  "items": []                   // full replace: items not sent are deleted
}
```

**Response 200:**
```jsonc
{ }
```

**Errors:**
| Status | Exact condition |
|---|---|
| 400 | `customerName` empty or > 200 chars — "<exact message>" |
| 409 | {{exact business-rule conflict}} — "<exact message>" |

**Notes for FE:**
- {{full-replace vs partial update per section, fields silently ignored, status changes living in another endpoint, ...}}

> Verified on {{envs}}, {{date}} — see {{API test log file(s)}}.

<!-- Revision entries for the same ticket go below, dated:
### Revised {{date}} — {{what changed}} (**breaking** if it is)
-->
