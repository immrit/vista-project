import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:Vista/core/theme/app_theme.dart';

class InAppWebScreen extends StatefulWidget {
  final String url;
  final String title;

  /// When set, top-level navigations are restricted to this host. Any attempt
  /// to navigate elsewhere is blocked (defense-in-depth for scoped sessions).
  final String? restrictHost;

  /// When set (together with [restrictHost]), top-level navigations are further
  /// restricted to paths under this prefix, e.g. '/game'. Blocks the webview
  /// from leaving the allowed section even if a link points away from it.
  final String? allowedPathPrefix;

  /// Custom AppBar background color. Defaults to theme background.
  final Color? appBarColor;

  /// Custom AppBar foreground (icon + title) color. Defaults to theme text.
  final Color? appBarForegroundColor;

  /// Custom background color for the Scaffold and WebView. Defaults to [appBarColor] or theme background.
  final Color? backgroundColor;

  /// Use back arrow instead of close (×) icon.
  final bool useBackButton;

  const InAppWebScreen({
    super.key,
    required this.url,
    this.title = '',
    this.restrictHost,
    this.allowedPathPrefix,
    this.appBarColor,
    this.appBarForegroundColor,
    this.backgroundColor,
    this.useBackButton = false,
  });

  @override
  State<InAppWebScreen> createState() => _InAppWebScreenState();
}

class _InAppWebScreenState extends State<InAppWebScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _loadingProgress = p),
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) {
          setState(() => _isLoading = false);
          // Inject CSS to fix any black gaps caused by the web page's own styling
          _controller.runJavaScript('''
            try {
              var style = document.createElement('style');
              style.innerHTML = 'html, body { background-color: transparent !important; padding-top: 0 !important; margin-top: 0 !important; } #root, #__next, #app { padding-top: 0 !important; margin-top: 0 !important; }';
              document.head.appendChild(style);
            } catch(e) {}
          ''');
        },
        onNavigationRequest: (request) => _isNavigationAllowed(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // For scoped sessions (e.g. game), wipe any stale cookies first so a
    // previously stored full web session can never widen this webview's access.
    if (widget.restrictHost != null) {
      try {
        await WebViewCookieManager().clearCookies();
      } catch (_) {
        // Best-effort: if the platform has no cookies yet, ignore.
      }
    }
    if (!mounted) return;
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  /// Gate top-level navigations when a host/path restriction is configured.
  /// With no restriction set, all navigations are allowed (default behaviour).
  bool _isNavigationAllowed(String url) {
    if (widget.restrictHost == null) return true;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Allow non-http schemes that the engine uses internally.
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return uri.scheme == 'about' || uri.scheme == 'data';
    }

    if (uri.host.toLowerCase() != widget.restrictHost!.toLowerCase()) {
      return false;
    }

    final prefix = widget.allowedPathPrefix;
    if (prefix != null && prefix.isNotEmpty) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      if (path != prefix && !path.startsWith('$prefix/')) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = widget.appBarColor ??
        (isDark ? AppColors.darkBackground : AppColors.lightBackground);
    final fgColor = widget.appBarForegroundColor ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    // Status bar icons should be light on dark AppBar, dark on light AppBar.
    final statusIconBrightness = widget.appBarColor != null
        ? Brightness.light
        : (isDark ? Brightness.light : Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusIconBrightness,
        statusBarBrightness:
            statusIconBrightness == Brightness.light ? Brightness.dark : Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _controller.canGoBack()) {
            _controller.goBack();
          } else {
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        child: Scaffold(
          backgroundColor: widget.backgroundColor ??
              widget.appBarColor ??
              (isDark ? AppColors.darkBackground : AppColors.lightBackground),
          appBar: AppBar(
            backgroundColor: barBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: fgColor),
            leading: IconButton(
              icon: Icon(
                widget.useBackButton
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.close_rounded,
                color: fgColor,
              ),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  _controller.goBack();
                } else {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
            title: widget.title.isNotEmpty
                ? Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  )
                : null,
            bottom: _isLoading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(3),
                    child: LinearProgressIndicator(
                      value: _loadingProgress / 100,
                      backgroundColor: Colors.transparent,
                      color: widget.appBarColor != null
                          ? Colors.white38
                          : AppColors.primary,
                      minHeight: 3,
                    ),
                  )
                : null,
          ),
          body: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
