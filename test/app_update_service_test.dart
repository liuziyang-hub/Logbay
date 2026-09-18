import 'package:flutter_test/flutter_test.dart';
import 'package:eagly/services/app_update_service.dart';

void main() {
  test('Windows asset name matches Inno output pattern', () {
    expect(
      AppUpdateService.assetFileName('1.2.9'),
      anyOf(
        'Logbay-1.2.9-windows-setup.exe',
        'Logbay-1.2.9-macos.dmg',
        'Logbay-1.2.9-linux.deb',
      ),
    );
  });

  test('Windows updater executes its wait and install statements', () {
    final command = AppUpdateService.windowsInstallerCommand;

    expect(command, startsWith(r'param([int]$appProcessId'));
    expect(command, contains(r'); while (Get-Process'));
    expect(command, contains(r'Start-Process -FilePath $installerPath'));
    expect(command, contains('/LANG=chinesesimplified'));
    expect(command, isNot(contains(r'$installerPath) {')));
  });
}
