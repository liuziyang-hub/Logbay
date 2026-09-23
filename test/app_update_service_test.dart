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

  test('Windows updater waits, installs silently, and removes itself', () {
    const script = AppUpdateService.windowsUpdaterScript;

    expect(script, contains(r'[int]$AppProcessId'));
    expect(script, contains(r'while (Get-Process -Id $AppProcessId'));
    expect(script, contains(r'Start-Process -FilePath $InstallerPath'));
    expect(script, contains('/VERYSILENT'));
    expect(script, contains('/LANG=chinesesimplified'));
    expect(script, contains(r'Remove-Item -LiteralPath $PSCommandPath'));
  });

  test('Windows updater preserves paths with spaces as named arguments', () {
    final arguments = AppUpdateService.windowsUpdaterArguments(
      scriptPath: r'C:\Temp\Logbay Updater.ps1',
      appProcessId: 12345,
      installerPath: r'C:\Users\Tester\Downloads\Logbay Setup.exe',
    );

    expect(arguments, containsAllInOrder(['-ExecutionPolicy', 'Bypass']));
    expect(
      arguments,
      containsAllInOrder([
        '-File',
        r'C:\Temp\Logbay Updater.ps1',
        '-AppProcessId',
        '12345',
        '-InstallerPath',
        r'C:\Users\Tester\Downloads\Logbay Setup.exe',
      ]),
    );
  });
}
