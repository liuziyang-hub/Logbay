# Implementation plan — Logbay debug productivity (phase C)

## Task 1: Log signal detector + Issues on LogController

- [ ] Add `lib/features/logs/data/models/log_issue.dart`
- [ ] Add `lib/features/logs/services/log_signal_detector.dart` + unit tests
- [ ] Wire scan into log ingest; `jumpToLogEntryId`; clear with buffer clear
- [ ] Issues tray UI in log feature view

## Task 2: Android screenshot / record without mirror

- [ ] Session helpers + home quick actions
- [ ] Mirror strip: allow capture when device connected even if mirror stopped
- [ ] CN toasts / file picker save

## Task 3: Subsystem / category columns

- [ ] `LogEntry` fields + ostrace parser
- [ ] `LogColumn` + viewer / filters / defaults for iOS
- [ ] Parser unit tests

## Task 4: Enable GitHub auto-update

- [ ] `isSupported = true`; Logbay asset filenames
- [ ] Confirm `AppUpdateChip` visible in chrome
- [ ] Document release asset naming in README snippet (short)

## Execution

Prefer inline implementation in order 1→4.
