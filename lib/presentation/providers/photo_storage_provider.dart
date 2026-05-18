import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/photo_storage.dart';

final photoStorageProvider = Provider<PhotoStorage>((ref) {
  return PhotoStorage();
});
