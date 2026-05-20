import 'dart:convert';
import 'dart:io';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String url = '';
  String key = '';
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.substring(13);
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.substring(18);
  }
  
  final client = HttpClient();
  
  // Create dummy restaurant using anon key (if RLS allows)
  final insertReq = await client.postUrl(Uri.parse('$url/rest/v1/restaurants'));
  insertReq.headers.add('apikey', key);
  insertReq.headers.add('Authorization', 'Bearer $key');
  insertReq.headers.contentType = ContentType.json;
  insertReq.headers.add('Prefer', 'return=representation');
  insertReq.write(jsonEncode({'name': 'Test Resto', 'is_open': true}));
  
  final insertRes = await insertReq.close();
  final insertBody = await insertRes.transform(utf8.decoder).join();
  print('Insert: \$insertBody');
}
