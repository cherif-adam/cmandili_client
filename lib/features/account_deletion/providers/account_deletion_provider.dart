import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_deletion_repository.dart';
import '../data/models/deletion_blocker.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepository(Supabase.instance.client),
);

/// Relu a chaque ouverture de l'ecran : une commande a pu arriver entre-temps.
final accountDeletionBlockersProvider =
    FutureProvider.autoDispose<List<DeletionBlocker>>(
  (ref) => ref.read(accountDeletionRepositoryProvider).fetchBlockers(),
);
