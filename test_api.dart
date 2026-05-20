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
  final request = await client.getUrl(Uri.parse('$url/rest/v1/restaurants?limit=1'));
  request.headers.add('apikey', key);
  request.headers.add('Authorization', 'Bearer $key');
  
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print(responseBody);
}
