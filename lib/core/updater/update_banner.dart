import 'package:flutter/material.dart';
import 'package:Vista/core/updater/in_app_updater.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  final InAppUpdater _updater = InAppUpdater();
  UpdateInfo? _updateInfo;
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadedFilePath;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final info = await _updater.checkForUpdate();
    if (info.updateAvailable && mounted) {
      setState(() {
        _updateInfo = info;
        _isVisible = true;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_updateInfo?.downloadUrl == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    final path = await _updater.downloadApk(
      _updateInfo!.downloadUrl!,
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      if (path != null) {
        setState(() {
          _downloadedFilePath = path;
          _progress = 1.0;
          _isDownloading = false;
        });
      } else {
        setState(() {
          _isDownloading = false;
          _isVisible = false;
        });
      }
    }
  }

  void _installUpdate() {
    if (_downloadedFilePath != null) {
      _updater.installApk(_downloadedFilePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isReadyToInstall = _downloadedFilePath != null;
    final buttonText = isReadyToInstall
        ? "نصب آپدیت جدید"
        : _isDownloading
            ? "در حال دانلود: ${(_progress * 100).toStringAsFixed(0)}%"
            : "نسخه جدید منتشر شد - کلیک برای دانلود";

    return Container(
      width: double.infinity,
      color: isReadyToInstall ? Colors.green.shade600 : Colors.blue.shade600,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isReadyToInstall) {
              _installUpdate();
            } else if (!_isDownloading) {
              _startDownload();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isDownloading && !isReadyToInstall)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _progress,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily:
                        'Vazirmatn', // Assuming Vazirmatn is used, very common in Persian apps
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
