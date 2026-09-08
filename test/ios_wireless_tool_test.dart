import 'package:eagly/services/tools/ios_wireless_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IosWirelessTool.parseUsbmuxListOutput', () {
    test('parses lockdown short_info list with ConnectionType', () {
      const raw = '''
[
  {
    "UniqueDeviceID": "00008110-001A2B3C4D5E6F70",
    "DeviceName": "iPhone",
    "ProductType": "iPhone15,2",
    "ProductVersion": "17.5.1",
    "ConnectionType": "USB"
  },
  {
    "UniqueDeviceID": "00008120-AABBCCDDEEFF0011",
    "DeviceName": "iPad",
    "ConnectionType": "Network"
  }
]
''';
      final entries = IosWirelessTool.parseUsbmuxListOutput(raw);
      expect(entries, hasLength(2));
      expect(entries[0].udid, '00008110-001A2B3C4D5E6F70');
      expect(entries[0].isUsb, isTrue);
      expect(entries[0].isNetwork, isFalse);
      expect(entries[1].isNetwork, isTrue);
      expect(entries[1].deviceName, 'iPad');
    });

    test('ignores log noise before JSON array', () {
      const raw = '''
INFO: listing devices
[{"Identifier": "UDID-1", "ConnectionType": "Network"}]
''';
      final entries = IosWirelessTool.parseUsbmuxListOutput(raw);
      expect(entries, hasLength(1));
      expect(entries.single.udid, 'UDID-1');
      expect(entries.single.isNetwork, isTrue);
    });

    test('parses simple UDID lines as USB', () {
      const raw = 'ABCDEF12-34567890\nfedcba09-87654321\n';
      final entries = IosWirelessTool.parseUsbmuxListOutput(raw);
      expect(entries, hasLength(2));
      expect(entries.every((e) => e.isUsb), isTrue);
    });
  });
}
