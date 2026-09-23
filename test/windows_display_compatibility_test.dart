import 'package:eagly/services/windows_display_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects Oray and common virtual display descriptions', () {
    expect(
      WindowsDisplayCompatibility.containsVirtualDisplay([
        'Intel(R) UHD Graphics 770',
        'OrayIddDriver Device',
      ]),
      isTrue,
    );
    expect(
      WindowsDisplayCompatibility.containsVirtualDisplay([
        'Parsec Virtual Display Adapter',
      ]),
      isTrue,
    );
  });

  test('does not classify ordinary physical adapters as virtual', () {
    expect(
      WindowsDisplayCompatibility.containsVirtualDisplay([
        'Intel(R) UHD Graphics 770',
        'NVIDIA GeForce RTX 4060',
      ]),
      isFalse,
    );
  });
}
