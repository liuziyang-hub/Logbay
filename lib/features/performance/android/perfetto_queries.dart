class PerfettoQuery {
  const PerfettoQuery({required this.id, required this.sql});

  final String id;
  final String sql;
}

/// Fixed, reviewable PerfettoSQL used by the in-app analyzer.
abstract final class PerfettoQueries {
  static List<PerfettoQuery> forApplication(String applicationId) {
    final app = applicationId.trim();
    if (!RegExp(r'^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+$').hasMatch(app)) {
      throw ArgumentError.value(applicationId, 'applicationId', '应用包名格式无效');
    }
    final quoted = "'$app'";
    return [
      PerfettoQuery(
        id: 'frames',
        sql:
            'SELECT ts, dur, jank_type, present_type, layer_name '
            'FROM actual_frame_timeline_slice JOIN process USING (upid) '
            'WHERE process.name = $quoted ORDER BY ts;',
      ),
      PerfettoQuery(
        id: 'cpu',
        sql:
            'SELECT CAST(s.ts / 1000000000 AS INT) * 1000000000 AS ts, '
            'SUM(s.dur) / 10000000.0 AS value '
            'FROM sched s JOIN thread t USING (utid) '
            'JOIN process p USING (upid) WHERE p.name = $quoted '
            'GROUP BY 1 ORDER BY 1;',
      ),
      PerfettoQuery(
        id: 'memory',
        sql:
            'SELECT c.ts, c.value, t.name FROM counter c '
            'JOIN process_counter_track t ON c.track_id = t.id '
            'JOIN process p USING (upid) WHERE p.name = $quoted '
            "AND t.name IN ('mem.rss', 'mem.swap', 'mem.virt') ORDER BY c.ts;",
      ),
      PerfettoQuery(
        id: 'network',
        sql:
            'INCLUDE PERFETTO MODULE android.network_packets; '
            'SELECT ts, direction, SUM(packet_length) AS bytes '
            'FROM android_network_packets WHERE package_name = $quoted '
            'GROUP BY ts, direction ORDER BY ts;',
      ),
      const PerfettoQuery(
        id: 'power',
        sql:
            'SELECT c.ts, c.value, t.name FROM counter c '
            'JOIN counter_track t ON c.track_id = t.id '
            "WHERE t.name LIKE '%power%' OR t.name LIKE '%energy%' "
            'ORDER BY c.ts;',
      ),
      PerfettoQuery(
        id: 'slices',
        sql:
            'SELECT s.ts, s.dur, s.name, th.name AS thread_name '
            'FROM slice s JOIN thread_track tt ON s.track_id = tt.id '
            'JOIN thread th USING (utid) JOIN process p USING (upid) '
            'WHERE p.name = $quoted AND s.dur > 0 ORDER BY s.ts;',
      ),
    ];
  }
}
