import '../services/app_install_service.dart';
import '../features/logs/services/log_file_service.dart';

String formatAppInstallMessage(AppInstallResult result) {
  return result.error ??
      result.message ??
      (result.fileName == null
          ? '应用安装成功。'
          : '已安装 ${result.fileName}。');
}

String formatExportLogsMessage(LogExportResult result) {
  return result.error ??
      (result.fileName == null
          ? '日志导出成功。'
          : '日志已导出至 ${result.fileName}。');
}
