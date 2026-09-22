# Log memory design

## Goal

Keep long, high-volume Android and iOS log sessions responsive without losing
the complete captured session.

## Design

- Keep a bounded recent window in memory. The configured line limit remains a
  user-facing ceiling, while a byte ceiling prevents long messages from using
  disproportionate memory.
- Remove the filter-driven capacity expansion. Filtering changes visibility,
  not retention.
- Append every live entry to a temporary newline-delimited archive before it
  can be evicted. Imported files remain read-only and do not create archives.
- Export from the archive when it exists, so evicted entries are included.
- Build normalized searchable text only while a raw-text filter needs it;
  entries no longer permanently retain a second lower-cased copy.
- Keep the existing virtualized viewer and 300 ms update cadence, but limit a
  UI flush to 1,000 entries and leave excess entries queued for later ticks.
- Delete the temporary archive when its log controller is disposed. Starting a
  new capture or clearing logs replaces it with an empty archive.

## Failure handling

Archive creation and appends are best effort. A disk error must not interrupt
live capture; the UI continues with the bounded in-memory window and reports
the archive as unavailable for full-session export.

## Tests

- Buffer retention never expands when filters are active.
- Byte pressure evicts old entries while retaining the newest entry.
- Raw filtering does not leave a permanent normalized-string cache.
- Pending logs flush in bounded batches.
- Archive round-trips entries, survives memory eviction for export, clears,
  and deletes its temporary file on dispose.

