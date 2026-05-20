import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/core/config/supabase_config.dart';
void main() async {
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  final res = await Supabase.instance.client.from('restaurants').select('name, image_url');
  print(res);
}
