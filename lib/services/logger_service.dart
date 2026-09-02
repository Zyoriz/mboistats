import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mboistats/config/supabase_config.dart';

/// Service Pelacakan Aktivitas Pengguna (User Tracking Engine) - MBOISSTATS+ PKL
/// Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)
class LoggerService {
  static String? _deviceId;
  static bool _isInitialized = false;

  /// Toggle apakah log dikirim langsung ke Supabase (true) atau hanya dicatat lokal di console/cache (false).
  /// Saat pengujian awal / offline testing, dapat di-set ke false agar hemat kuota.
  static bool enableRemoteSync = true;

  /// Pemetaan nama sektor ke Category ID resmi Supabase (1 s.d. 7)
  static const Map<String, int> sectorToIdMap = {
    'perekonomian': 1,
    'ekonomi': 1,
    'kemiskinan': 2,
    'ketenagakerjaan': 3,
    'tenaga_kerja': 3,
    'ipm': 4,
    'kependudukan': 5,
    'pertanian': 6,
    'kesejahteraan': 7,
  };

  /// Inisialisasi Supabase client. Dipanggil sekali saat app startup (`main.dart`).
  static Future<void> init() async {
    if (_isInitialized) return;

    if (SupabaseConfig.url == 'YOUR_SUPABASE_URL' ||
        SupabaseConfig.anonKey == 'YOUR_SUPABASE_ANON_KEY') {
      print('[LoggerService] Warning: Supabase credentials are not set. Logging will run in local mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _isInitialized = true;
      print('[LoggerService] Supabase client initialized successfully.');
    } catch (e) {
      print('[LoggerService] Error initializing Supabase: $e');
    }
  }

  /// Mengambil Unique Device ID secara aman untuk Android, iOS, dan Web/Desktop.
  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor;
      } else {
        _deviceId = 'desktop_or_web';
      }
    } catch (e) {
      _deviceId = 'device_${e.toString().hashCode.abs().toRadixString(16)}';
    }
    return _deviceId ?? 'unknown_device';
  }

  /// Mengembalikan category_id integer berdasarkan nama sektor (contoh: 'perekonomian' -> 1)
  static int? getCategoryIdForSector(String? sector) {
    if (sector == null || sector.isEmpty) return null;
    final key = sector.toLowerCase().trim();
    return sectorToIdMap[key];
  }

  /// Mengirimkan log aktivitas pengguna ke tabel `activity_logs` Supabase secara non-blocking.
  /// Mendukung parameter skema baru DDL Supabase & kompatibel dengan pemanggilan legacy.
  static Future<void> logActivity({
    required String actionType,
    String? title,
    String? itemName,
    String? sectorCategory,
    int? categoryId,
    String? contentsIdContent,
    int? youtubeStreamsIdStreams,
    String moduleName = 'fitur',
    String? userId,
    String? coverUrl,
    String? contentUrl,
  }) async {
    final effectiveTitle = title ?? itemName ?? 'Aktivitas Pengguna';
    final effectiveSector = sectorCategory ?? classifySector(effectiveTitle);
    final effectiveCategoryId = categoryId ?? getCategoryIdForSector(effectiveSector);

    final deviceId = await getDeviceId();
    final platformName = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');
    
    // Identifikasi pengguna (User ID auth jika login, atau device ID jika anonim)
    String activeUserId = deviceId;
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      activeUserId = userId ?? currentUser?.email ?? currentUser?.id ?? deviceId;
    } catch (_) {
      activeUserId = userId ?? deviceId;
    }

    // Selalu cetak log lokal untuk keperluan debugging & tracking
    print('[Activity Log] [$platformName] User: $activeUserId | Action: $actionType | CategoryID: $effectiveCategoryId ($effectiveSector) | Title: "$effectiveTitle" | Module: $moduleName');

    if (!_isInitialized || !enableRemoteSync) {
      return;
    }

    // Payload data yang 100% selaras dengan skema DDL Supabase tabel `activity_logs`
    final logPayload = <String, dynamic>{
      'action_type': actionType,
      'title': effectiveTitle,
      'platform': platformName,
      'user_id': activeUserId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'module_name': moduleName,
    };

    if (effectiveCategoryId != null) {
      logPayload['category_id'] = effectiveCategoryId;
    }
    if (contentsIdContent != null && contentsIdContent.isNotEmpty) {
      logPayload['contents_id_content'] = contentsIdContent;
    }
    if (youtubeStreamsIdStreams != null) {
      logPayload['youtube_streams_id_streams'] = youtubeStreamsIdStreams;
    }

    // Kirim asinkron (non-blocking) ke Supabase
    Supabase.instance.client
        .from('activity_logs')
        .insert(logPayload)
        .then((_) {
      // Sukses tersinkronisasi
    }).catchError((error) {
      print('[LoggerService] Gagal sync log ke Supabase: $error');
    });
  }

  /// Mengklasifikasikan sektor secara otomatis berdasarkan judul/nama item.
  static String classifySector(String title) {
    final text = title.toLowerCase();
    // PEREKONOMIAN (1)
    if (text.contains('inflasi') || text.contains('pdrb') || text.contains('ekonomi') ||
        text.contains('hotel') || text.contains('penghunian') || text.contains('tpk') ||
        text.contains('pariwisata') || text.contains('wisatawan') || text.contains('industri') ||
        text.contains('perusahaan') || text.contains('usaha') || text.contains('perdagangan') ||
        text.contains('ekspor') || text.contains('impor') || text.contains('konstruksi') ||
        text.contains('transportasi') || text.contains('laju pertumbuhan')) {
      return 'perekonomian';
    }
    // KEMISKINAN (2)
    if (text.contains('kemiskinan') || text.contains('miskin')) return 'kemiskinan';
    // KETENAGAKERJAAN (3)
    if (text.contains('kerja') || text.contains('pengangguran') || text.contains('tpt') ||
        text.contains('tenaga') || text.contains('upah') || text.contains('buruh')) {
      return 'ketenagakerjaan';
    }
    // IPM (4)
    if (text.contains('ipm') || text.contains('pembangunan manusia') ||
        text.contains('sekolah') || text.contains('harapan hidup') ||
        text.contains('melek huruf') || text.contains('pendidikan') ||
        text.contains('gender') || text.contains('ketimpangan')) {
      return 'ipm';
    }
    // KEPENDUDUKAN (5)
    if (text.contains('penduduk') || text.contains('kecamatan') || text.contains('dalam angka') ||
        text.contains('demografi') || text.contains('kelahiran') || text.contains('kematian') ||
        text.contains('migrasi') || text.contains('sensus') || text.contains('potensi desa') ||
        text.contains('statistik daerah')) {
      return 'kependudukan';
    }
    // PERTANIAN (6)
    if (text.contains('panen') || text.contains('padi') || text.contains('beras') ||
        text.contains('pertanian') || text.contains('tanaman') || text.contains('ternak') ||
        text.contains('perikanan') || text.contains('hortikultura')) {
      return 'pertanian';
    }
    // KESEJAHTERAAN (7)
    if (text.contains('pengeluaran') || text.contains('kesejahteraan') || text.contains('gini') ||
        text.contains('konsumsi') || text.contains('sosial') || text.contains('rumah tangga') ||
        text.contains('susenas')) {
      return 'kesejahteraan';
    }
    return 'berita';
  }
}
