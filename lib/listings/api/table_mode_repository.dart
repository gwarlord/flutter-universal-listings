import 'package:instaflutter/listings/model/table_mode_models.dart';

/// Abstract repository for Table Mode operations
abstract class TableModeRepository {
  // ========================================================================
  // TABLE MODE SETTINGS
  // ========================================================================

  /// Update Table Mode settings for a listing (Premium required)
  Future<void> setTableModeSettings({
    required String listingId,
    required bool tableModeEnabled,
    required int summonCooldownSeconds,
    required int sessionMaxMinutes,
  });

  /// Get Table Mode settings for a listing
  Future<TableModeSettings?> getTableModeSettings({
    required String listingId,
  });

  // ========================================================================
  // TABLES MANAGEMENT
  // ========================================================================

  /// Create or update a table (Premium required)
  Future<String> upsertTable({
    required String listingId,
    String? tableId,
    required String tableName,
    String? tableCodePublic,
  });

  /// Deactivate or activate a table (Premium required)
  Future<void> deactivateTable({
    required String listingId,
    required String tableId,
    required bool isActive,
  });

  /// Get all tables for a listing
  Future<List<TableModel>> getTables({
    required String listingId,
  });

  /// Stream tables for a listing
  Stream<List<TableModel>> streamTables({
    required String listingId,
  });

  /// Get a specific table
  Future<TableModel?> getTable({
    required String listingId,
    required String tableId,
  });

  // ========================================================================
  // TABLE SESSIONS
  // ========================================================================

  /// Create a table session (customer-initiated)
  Future<String> createTableSession({
    required String listingId,
    required String mode, // "QR" | "MANUAL"
    String? tableId,
    String? secret,
    String? tableCodePublic,
  });

  /// Assign waiter(s) to a session (staff only)
  Future<void> assignWaiterToSession({
    required String sessionId,
    required List<String> waiterUids,
  });

  /// Summon waiter (customer only, cooldown enforced)
  Future<void> summonWaiter({
    required String sessionId,
    required String purpose, // "ASSISTANCE"|"REFILL"|"QUESTION"|"OTHER"
  });

  /// Acknowledge summon (assigned staff or owner/collab)
  Future<void> acknowledgeSummon({
    required String sessionId,
  });

  /// Request bill (customer only)
  Future<void> requestBill({
    required String sessionId,
    required String paymentMethod, // "CASH"|"CARD"|"BANK_TRANSFER"
  });

  /// Close a table session
  Future<void> closeTableSession({
    required String sessionId,
  });

  /// Get a specific session
  Future<TableSessionModel?> getTableSession({
    required String sessionId,
  });

  /// Stream a specific session
  Stream<TableSessionModel> streamTableSession({
    required String sessionId,
  });

  /// Get sessions for a listing
  Future<List<TableSessionModel>> getListingSessions({
    required String listingId,
    String? status, // Filter by status if provided
    int limit = 50,
  });

  /// Stream sessions for a listing
  Stream<List<TableSessionModel>> streamListingSessions({
    required String listingId,
    String? status,
  });

  /// Get customer's active session for a listing
  Future<TableSessionModel?> getCustomerActiveSession({
    required String listingId,
    required String customerUid,
  });

  // ========================================================================
  // SESSION EVENTS
  // ========================================================================

  /// Get events for a session
  Future<List<SessionEventModel>> getSessionEvents({
    required String sessionId,
    int limit = 100,
  });

  /// Stream events for a session
  Stream<List<SessionEventModel>> streamSessionEvents({
    required String sessionId,
  });
}
