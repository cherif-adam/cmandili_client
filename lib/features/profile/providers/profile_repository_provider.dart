import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';

/// Shared by the profile screens' controllers (edit profile, phone gate).
final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());
