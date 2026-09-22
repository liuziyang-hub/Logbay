# Log memory optimization implementation plan

- [ ] Add byte-aware eviction to `LogBuffer` and remove filtered expansion.
- [ ] Make searchable normalization transient instead of per-entry cached.
- [ ] Add a standard-library NDJSON temporary session archive.
- [ ] Wire live capture, clear, export, and disposal to the archive.
- [ ] Bound each pending UI flush to 1,000 entries.
- [ ] Add focused buffer, archive, and controller tests.
- [ ] Format, analyze, run focused tests, then run the full test suite.

