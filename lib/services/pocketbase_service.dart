import 'package:pocketbase/pocketbase.dart';
import '../core/app_globals.dart';

// A singleton service for interacting with the PocketBase backend.
//
// This class centralizes all database operations, providing a single point of
// access to the PocketBase instance and abstracting away the collection name.
class PocketBaseService {
  // The singleton instance of this service.
  static final PocketBaseService _instance = PocketBaseService._internal();

  // The PocketBase client instance.
  late final PocketBase _pb;

  // Private internal constructor for the singleton pattern.
  PocketBaseService._internal() {
    _pb = PocketBase(AppGlobals.pocketbaseUrl);
  }

  // Provides access to the singleton instance.
  factory PocketBaseService() {
    return _instance;
  }

  // Returns the underlying PocketBase client instance.
  PocketBase get client => _pb;

  // Returns a reference to the primary game session collection.
  RecordService get sessions => _pb.collection(AppGlobals.pocketbaseCollection);

  // Fetches a single game session record by its unique code.
  //
  // Returns the [RecordModel] if found, otherwise `null`.
  Future<RecordModel?> getSessionByCode(String code) async {
    try {
      final result = await sessions.getList(filter: 'code = "$code"', perPage: 1);
      return result.items.isNotEmpty ? result.items.first : null;
    } catch (e) {
      AppGlobals.debugPrint('Error fetching session by code "$code": $e');
      return null;
    }
  }
}
