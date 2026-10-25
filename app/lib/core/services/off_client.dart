// Sends a user's product registration to Open Food Facts (OFF), so the next person who scans
// the package finds it. Only runs when the user taps "Share with Open Food Facts".
//
// Endpoint and required fields from the OFF API tutorial (checked 2026-10-14):
//   POST https://world.openfoodfacts.org/cgi/product_jqm2.pl   (staging: world.openfoodfacts.net)
//   code (barcode), user_id (account user name, not e-mail), password are required.
// Field names product_name, brands, quantity and the image upload endpoint
// (/cgi/product_image_upload.pl with imagefield and imgupload_<field>) follow the OFF
// documentation; test against staging first. Staging uses HTTP basic auth (see the OFF
// "API environment" docs for the current user name and password).
import 'dart:convert';
import 'dart:io';

class OffConfig {
  final String host; // world.openfoodfacts.net for testing, world.openfoodfacts.org for real
  final String userId;
  final String password;
  final String userAgent; // e.g. 'ZapWise/0.1 (contact e-mail)'
  final String? basicAuth; // 'user:password' for the staging server
  const OffConfig({required this.host, required this.userId, required this.password, required this.userAgent, this.basicAuth});
}

class OffClient {
  final OffConfig cfg;
  final HttpClient _http = HttpClient();
  OffClient(this.cfg);

  Map<String, String> productFields({required String code, required String name, required String brand, String? quantity, String? packagingText, String? preparationText}) => {
        'code': code,
        'user_id': cfg.userId,
        'password': cfg.password,
        'product_name': name,
        'brands': brand,
        if (quantity != null) 'quantity': quantity,
        if (packagingText != null) 'packaging_text_en': packagingText,
        if (preparationText != null) 'preparation_en': preparationText,
        'comment': 'Added from the ZapWise app (microwave packaging study)',
      };

  void _headers(HttpClientRequest r) {
    r.headers.set(HttpHeaders.userAgentHeader, cfg.userAgent);
    if (cfg.basicAuth != null) r.headers.set(HttpHeaders.authorizationHeader, 'Basic ${base64Encode(utf8.encode(cfg.basicAuth!))}');
  }

  /// Returns the decoded JSON response. OFF answers {"status": 1, "status_verbose": "fields saved"} on success.
  Future<Map<String, dynamic>> saveProduct(Map<String, String> fields) async {
    final req = await _http.postUrl(Uri.https(cfg.host, '/cgi/product_jqm2.pl'));
    _headers(req);
    req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    req.write(Uri(queryParameters: fields).query);
    final res = await req.close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  /// Uploads one photo. imageField: front, ingredients, nutrition or packaging.
  Future<Map<String, dynamic>> uploadImage({required String code, required String imageField, required File photo}) async {
    final boundary = 'zapwise${DateTime.now().microsecondsSinceEpoch}';
    final req = await _http.postUrl(Uri.https(cfg.host, '/cgi/product_image_upload.pl'));
    _headers(req);
    req.headers.contentType = ContentType('multipart', 'form-data', parameters: {'boundary': boundary});
    void field(String k, String v) => req.write('--$boundary\r\nContent-Disposition: form-data; name="$k"\r\n\r\n$v\r\n');
    field('code', code);
    field('imagefield', imageField);
    field('user_id', cfg.userId);
    field('password', cfg.password);
    req.write('--$boundary\r\nContent-Disposition: form-data; name="imgupload_$imageField"; filename="$imageField.jpg"\r\nContent-Type: image/jpeg\r\n\r\n');
    req.add(await photo.readAsBytes());
    req.write('\r\n--$boundary--\r\n');
    final res = await req.close();
    return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  void close() => _http.close();
}
