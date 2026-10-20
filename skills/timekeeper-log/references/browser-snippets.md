# Browser snippets for timekeeper-log

Run each snippet **inside the logged-in page**, using the browser tool's JavaScript/evaluate action.
Snippets return JSON strings. Keep each call well under the tool's timeout (about 45s).
Never return or log tokens.

The response shapes of SRM and Timekeeper are not documented here. On the first run, inspect one page of
results (keys only) before relying on field names, and note what you found in `history.md`.

## SRM — leave requests and holidays (on `srm.url`)

```js
(async () => {
  const api = 'https://srm-api.siliconstack.com.au';           // srm.api
  const token = localStorage.getItem('accessToken');           // srm.tokenLocalStorageKey
  if (!token) return JSON.stringify({ error: 'NOT_LOGGED_IN' });
  const h = { Authorization: 'Bearer ' + token };
  const requests = [];
  for (const status of [1, 2, 3]) {                            // 1 pending, 2/3 approved/processed
    for (let page = 1; page < 50; page++) {
      const r = await fetch(`${api}/srm/my-requests?page=${page}&pageSize=10&status=${status}&isAscSorting=false&Sort=updatedAt`, { headers: h });
      if (!r.ok) return JSON.stringify({ error: 'HTTP ' + r.status, status, page });
      const j = await r.json();
      const items = Array.isArray(j) ? j : (j.items || j.data || j.results || []);
      if (!items.length) break;
      requests.push(...items.map(x => ({ status, ...x })));
    }
  }
  const holidays = await (await fetch(`${api}/srm/common/holidays`, { headers: h })).json();
  return JSON.stringify({ requests, holidays });
})()
```
`pageSize` above 10 is capped by the server, so the snippet loops pages.
If the result is too large, return only the fields you need: type, from/to dates, half-day flag, status.

## Timekeeper — totals for a period (on `timekeeper.url`)

```js
(async () => {
  const start = '2026-09-01', end = '2026-09-30';
  const userId = 'YOUR-TIMEKEEPER-USER-GUID';                  // timekeeper.userId
  const uri = `reports/single-column?filterExp=(startDate Eq \`${start}\`)and(endDate Eq \`${end}\`)and(lstUsers In \`${userId}\`)and(isBillable Eq \`2\`)and(isOvertime Eq \`2\`)and(typeChart Eq \`column-chart\`)and(groupBy In \`CustomerName\`)`;
  const r = await fetch('/data/get?uri=' + encodeURIComponent(uri), { credentials: 'include' });
  return JSON.stringify({ status: r.status, body: await r.text() });
})()
```
Timekeeper authenticates with the **session cookie** from the Microsoft login, so `credentials: 'include'`
from inside the Timekeeper tab is enough. A 401/403 means the session expired: ask the user to log in again.

## Timekeeper — lookup lists (on `timekeeper.url`)

Use these to check codes, or when the user asks for another customer, reporting code or activity.

```js
(async () => {
  const get = async u => (await fetch('/data/get?uri=' + u, { credentials: 'include' })).json();
  const [activity, reporting, customer] = await Promise.all([get('activitycode'), get('reportingcode'), get('customer')]);
  return JSON.stringify({ activity, reporting, customer }).slice(0, 40000);
})()
```

## Timekeeper — post one chunk (on `timekeeper.url`)

Paste the content of `chunks/chunk-NN.json` as `entries`:

```js
(async () => {
  const entries = /* chunk-NN.json */ [];
  const ids = [];
  for (const e of entries) {
    const r = await fetch('/data/post?uri=entry', {
      method: 'POST', credentials: 'include',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(e)
    });
    ids.push(r.ok ? (await r.text()).trim() : `ERR ${r.status} ${e.date} ${e.description}`);
  }
  return JSON.stringify(ids);
})()
```
Each entry looks like `{"ticketNumber":"NTGRTN-87","reference":"","customerID":"44","reportingCodeID":"314","activityTypeID":"2","ticketLink":"…","description":"…","duration":8,"isBillable":false,"isOvertime":false,"startDateTime":"09/02/2026","endDateTime":"09/02/2026"}`.
The response body of each POST is the new entry id (e.g. `430133`). Any `ERR` stops the run: report it, and post nothing
more until it is understood.
