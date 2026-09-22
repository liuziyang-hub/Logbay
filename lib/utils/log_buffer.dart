import 'dart:collection';

class LogBuffer<T> {
  LogBuffer({
    required this.baseCapacity,
    this.maxBytes,
    int Function(T value)? sizeOf,
  }) : assert(baseCapacity > 0, 'baseCapacity must be positive'),
       assert(maxBytes == null || maxBytes > 0, 'maxBytes must be positive'),
       _sizeOf = sizeOf ?? _zeroSize;

  final int baseCapacity;
  final int? maxBytes;
  final int Function(T value) _sizeOf;
  final ListQueue<_BufferEntry<T>> _entries = ListQueue<_BufferEntry<T>>();
  int _bytes = 0;

  List<T> append(T value) {
    final bytes = _sizeOf(value);
    _entries.addLast(_BufferEntry(value, bytes));
    _bytes += bytes;
    return _trim();
  }

  List<T> getLogs() {
    return [for (final entry in _entries) entry.value];
  }

  List<T> search(bool Function(T log) predicate) {
    return [
      for (final entry in _entries)
        if (predicate(entry.value)) entry.value,
    ];
  }

  int get size => _entries.length;
  int get bytes => _bytes;
  int get capacity => baseCapacity;
  int get maxBufferedSize => baseCapacity;

  List<T> trimToCapacity() => _trim();

  void clear() {
    _entries.clear();
    _bytes = 0;
  }

  Map<String, dynamic> stats() => {
    'size': size,
    'bytes': bytes,
    'baseCapacity': baseCapacity,
    'maxBytes': maxBytes,
  };

  List<T> _trim() {
    final evicted = <T>[];
    while (_entries.length > baseCapacity ||
        (maxBytes != null && _bytes > maxBytes! && _entries.length > 1)) {
      final removed = _entries.removeFirst();
      _bytes -= removed.bytes;
      evicted.add(removed.value);
    }
    return evicted;
  }

  static int _zeroSize(Object? _) => 0;
}

class _BufferEntry<T> {
  const _BufferEntry(this.value, this.bytes);

  final T value;
  final int bytes;
}
