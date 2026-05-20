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
  
  final req = await client.patchUrl(Uri.parse('$url/rest/v1/restaurants?name=eq.Test Resto'));
  req.headers.add('apikey', key);
  req.headers.add('Authorization', 'Bearer $key');
  req.headers.contentType = ContentType.json;
  req.headers.add('Prefer', 'return=representation');
  req.write(jsonEncode({'image_url': 'https://google.com'}));
  
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print(body);
}
