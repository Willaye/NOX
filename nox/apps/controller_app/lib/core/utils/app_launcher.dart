import 'package:url_launcher/url_launcher.dart';

/// Opens real apps from admin device (WhatsApp, Instagram, Snapchat, Browser).
class AppLauncher {
  AppLauncher._();

  static Future<bool> _open(String uri, {String? fallback}) async {
    try {
      if (await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication)) return true;
    } catch (_) {}
    if (fallback != null) {
      try {
        return await launchUrl(Uri.parse(fallback), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    return false;
  }

  /// Open WhatsApp — optionally to a specific phone number
  static Future<bool> openWhatsApp({String? phone}) {
    if (phone != null && phone.isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
      return _open('whatsapp://send?phone=$clean', fallback: 'https://wa.me/$clean');
    }
    return _open('whatsapp://send', fallback: 'https://www.whatsapp.com');
  }

  /// Open Instagram — optionally to a specific username
  static Future<bool> openInstagram({String? username}) {
    if (username != null && username.isNotEmpty) {
      return _open('instagram://user?username=$username',
          fallback: 'https://www.instagram.com/$username');
    }
    return _open('instagram://app', fallback: 'https://www.instagram.com');
  }

  /// Open Snapchat — optionally to a specific username
  static Future<bool> openSnapchat({String? username}) {
    if (username != null && username.isNotEmpty) {
      return _open('snapchat://add/$username',
          fallback: 'https://www.snapchat.com/add/$username');
    }
    return _open('snapchat://', fallback: 'https://www.snapchat.com');
  }

  /// Open URL in default browser
  static Future<bool> openBrowser(String url) {
    final fixed = url.startsWith('http') ? url : 'https://$url';
    return _open(fixed);
  }
}
