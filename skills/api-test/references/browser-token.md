# Capturing the API token from a browser login

Every project stores its token differently, so `config_swagger.json` records it per environment:
`login.url` (page to open), `login.tokenFrom` (`localStorage` | `sessionStorage` | `header`) and
`login.tokenKey`. The legacy flat format uses `baseUrl_<env>_UI` as the login URL.

Run these snippets with the browser tool's JavaScript/evaluate action, **in the app's tab after the user
has logged in**:
- Claude app: built-in browser (`javascript_tool`)
- VS Code / Antigravity: Playwright MCP (`browser_evaluate`)

## 1. Detect where the token lives (first time only, returns NO values)

```js
(() => {
  const isJwt = v => typeof v === 'string' && /^eyJ[\w-]+\.[\w-]+\.[\w-]+$/.test(v.replace(/^Bearer /, ''));
  const found = [];
  for (const [store, s] of [['localStorage', localStorage], ['sessionStorage', sessionStorage]]) {
    for (let i = 0; i < s.length; i++) {
      const k = s.key(i), v = s.getItem(k);
      if (isJwt(v)) { found.push({ store, key: k }); continue; }
      try {
        const o = JSON.parse(v);
        for (const p of ['access_token', 'accessToken', 'token', 'secret'])
          if (o && isJwt(o[p])) found.push({ store, key: `${k}.${p}` });
      } catch { }
    }
  }
  return JSON.stringify(found);   // keys only — pick the access token (not id/refresh token)
})()
```

If several keys are found, prefer names containing `access`. Write the result into `login.tokenFrom` / `login.tokenKey`.
If nothing is found, the app keeps the token in memory. Use snippet 3 (`header`).

## 2. Read the token from storage

```js
(() => {
  const from = 'localStorage', key = 'accessToken';      // login.tokenFrom, login.tokenKey
  const s = from === 'sessionStorage' ? sessionStorage : localStorage;
  const dot = key.lastIndexOf('.');
  let v = s.getItem(key);
  if (v === null && dot > 0) {                          // "<storageKey>.<jsonProp>"
    try { v = JSON.parse(s.getItem(key.slice(0, dot)))[key.slice(dot + 1)]; } catch { v = null; }
  }
  return v ? v.replace(/^Bearer /, '') : 'NOT_FOUND';
})()
```

## 3. Capture from the Authorization header (`tokenFrom: header`)

Install the hook, then make the app call its API: click a menu item or change a filter. **Do not reload**,
because a reload removes the hook. Then read `window.__devflowToken`.

```js
(() => {
  if (window.__devflowHook) return 'HOOK_ALREADY_INSTALLED';
  window.__devflowHook = true;
  const keep = v => { if (v && v.startsWith('Bearer ')) window.__devflowToken = v.slice(7); };
  const f = window.fetch;
  window.fetch = function (input, init) {
    try {
      const h = (init && init.headers) || (input && input.headers);
      if (h) keep(new Headers(h).get('authorization'));
    } catch { }
    return f.apply(this, arguments);
  };
  const set = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function (n, v) {
    if (n && n.toLowerCase() === 'authorization') keep(v);
    return set.apply(this, arguments);
  };
  return 'HOOK_INSTALLED — now trigger an API call in the app';
})()
```
```js
window.__devflowToken || 'NOT_CAPTURED_YET'
```

## 4. Save it (never echo it)

```
pwsh -NoProfile -File "<plugin-root>/scripts/save-token.ps1" -Target <env> -Token "<value>"
```
The script prints only the expiry. Do not repeat the value in replies, logs, docs or commits. It is still
visible in this session's tool output, which is why it is only ever saved to the git-ignored personal config.

## Manual fallback (no browser tool)

The user opens DevTools on the app, pastes snippet 3, triggers an API call, runs
`copy(window.__devflowToken)` (DevTools copies it to the clipboard), and pastes it into the config field
named by `call-api.ps1`'s NO_TOKEN message. Not into the chat.
