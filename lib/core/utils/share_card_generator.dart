import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareCardGenerator {
  /// Generates and copies/shares a deep link vote URL for a specific entry.
  static Future<void> shareEntry({
    required int entryId,
    required String userName,
    required String categoryName,
    required int currentRank,
  }) async {
    final String deepLinkUrl = 'https://sallahflex.ng/entry/$entryId';
    
    final String message = 
        '🌙 SallahFlex 2026 🌙\n\n'
        'Help me become the Sallah Champion! 🏆\n'
        'I am currently #$currentRank in Wankan Sallah category!\n\n'
        'Vote for me here 👇\n'
        '$deepLinkUrl';

    await Share.share(message, subject: 'Vote for my Sallah drip!');
  }

  /// Direct deep link launch for sharing via WhatsApp
  static Future<void> shareToWhatsApp(String phone, String text) async {
    final Uri url = Uri.parse('whatsapp://send?phone=$phone&text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to web link
      final Uri webUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
