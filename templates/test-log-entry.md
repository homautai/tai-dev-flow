<!-- Labels follow language.workNotes. vi: Kết quả / Ghi chú / Kết luận. en: Result / Notes / Conclusion. -->
## {{YYYY-MM-DD}} — {{KEY}} ({{context: e.g. "self test after implement", "retest after deploy"}})

### Test — {{METHOD}} {{path}} ({{purpose / TC id}})

- **Method/URL:** `{{METHOD}} {{full url}}`
- **Body:** `{{json}}` _(or: none, GET)_
- **{{Result}}:** ✅ **{{status}}** — {{key fields from the response that prove the expectation}}
  _or_ ❌ **{{status}}**
  ```json
  {{trimmed error body}}
  ```
- **{{Notes}}:** {{retries, data used, ids created}}
- **{{Conclusion}}:** {{what this proves / root cause if failed}}
