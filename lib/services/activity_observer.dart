import 'package:flutter/material.dart';
import 'package:mboistats/services/logger_service.dart';

/// Observer Navigasi Otomatis untuk Pelacakan Aktivitas Pengguna - MBOISSTATS+ PKL
/// Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)
class ActivityLoggingObserver extends NavigatorObserver {
  // Pemetaan rute (route name) ke Category ID, Sektor, dan Judul Fitur
  // Category IDs: 1: Perekonomian, 2: Kemiskinan, 3: Ketenagakerjaan, 4: IPM, 5: Kependudukan, 6: Pertanian, 7: Kesejahteraan
  static const Map<String, Map<String, dynamic>> _routeLogs = {
    // IPM (ID: 4)
    '/PendudukBekerja': {'categoryId': 4, 'sector': 'ipm', 'title': 'Penduduk Bekerja (IPM)'},
    '/UsiaHarapanHidup': {'categoryId': 4, 'sector': 'ipm', 'title': 'Usia Harapan Hidup'},
    '/HarapanLamaSekolah': {'categoryId': 4, 'sector': 'ipm', 'title': 'Harapan Lama Sekolah'},
    '/RataRataLamaSekolah': {'categoryId': 4, 'sector': 'ipm', 'title': 'Rata-Rata Lama Sekolah'},
    '/DayaBeli': {'categoryId': 4, 'sector': 'ipm', 'title': 'Daya Beli'},

    // Kependudukan (ID: 5)
    '/PendudukJK': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Menurut Jenis Kelamin'},
    '/PendudukKec': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Menurut Kecamatan'},
    '/PKedungkandang': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Kedungkandang'},
    '/PSukun': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Sukun'},
    '/PKlojen': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Klojen'},
    '/PBlimbing': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Blimbing'},
    '/PLowokwaru': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Penduduk Lowokwaru'},

    // Perekonomian (ID: 1)
    '/LajuPertumbuhan': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Laju Pertumbuhan Ekonomi'},
    '/PDRB': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Produk Domestik Regional Bruto (PDRB)'},
    '/InflasiTahunKalender': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Inflasi Tahun Kalender'},
    '/InflasiBulanan': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Inflasi Bulanan'},
    '/DeteksiDiniInflasi': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Deteksi Dini Inflasi'},

    // Kemiskinan (ID: 2)
    '/TingkatKemiskinan': {'categoryId': 2, 'sector': 'kemiskinan', 'title': 'Tingkat Kemiskinan'},
    '/IndeksKedalamanKemiskinan': {'categoryId': 2, 'sector': 'kemiskinan', 'title': 'Indeks Kedalaman Kemiskinan'},
    '/IndeksKeparahanKemiskinan': {'categoryId': 2, 'sector': 'kemiskinan', 'title': 'Indeks Keparahan Kemiskinan'},
    '/GarisKemiskinan': {'categoryId': 2, 'sector': 'kemiskinan', 'title': 'Garis Kemiskinan'},

    // Ketenagakerjaan (ID: 3)
    '/AKMenurutPendidikan': {'categoryId': 3, 'sector': 'ketenagakerjaan', 'title': 'Angkatan Kerja Menurut Pendidikan'},
    '/PartisipasiAngkatanKerja': {'categoryId': 3, 'sector': 'ketenagakerjaan', 'title': 'Tingkat Partisipasi Angkatan Kerja'},
    '/TingkatPengangguran': {'categoryId': 3, 'sector': 'ketenagakerjaan', 'title': 'Tingkat Pengangguran'},
    '/PengangguranMenurutPendidikan': {'categoryId': 3, 'sector': 'ketenagakerjaan', 'title': 'Pengangguran Menurut Pendidikan'},

    // Kesejahteraan (ID: 7)
    '/GiniRasio': {'categoryId': 7, 'sector': 'kesejahteraan', 'title': 'Gini Rasio'},
    '/PengeluaranPerkapita': {'categoryId': 7, 'sector': 'kesejahteraan', 'title': 'Pengeluaran Perkapita'},

    // Pertanian (ID: 6)
    '/LuasPanenPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Luas Panen Padi'},
    '/ProduksiPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produksi Padi'},
    '/ProduktivitasPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produktivitas Padi'},
    '/ProduksiBeras': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produksi Beras'},
    
    // Fitur Tambahan & Halaman Menu Utama
    '/contact': {'categoryId': null, 'sector': 'layanan', 'title': 'Halaman Kontak Layanan'},
    '/brs': {'categoryId': null, 'sector': 'brs', 'title': 'Katalog Berita Resmi Statistik'},
    '/publikasi': {'categoryId': null, 'sector': 'publikasi', 'title': 'Katalog Publikasi BPS'},
    '/infografis': {'categoryId': null, 'sector': 'infografis', 'title': 'Katalog Infografis Statistik'},
    '/youtube': {'categoryId': null, 'sector': 'streaming', 'title': 'Arsip Live Streaming YouTube'},
    '/search': {'categoryId': null, 'sector': 'pencarian', 'title': 'Halaman Pencarian Konten'},
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoutePush(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRoutePush(newRoute);
    }
  }

  void _logRoutePush(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName != null && _routeLogs.containsKey(routeName)) {
      final logInfo = _routeLogs[routeName]!;
      LoggerService.logActivity(
        actionType: 'view_page',
        title: logInfo['title'] as String,
        categoryId: logInfo['categoryId'] as int?,
        sectorCategory: logInfo['sector'] as String?,
        moduleName: 'fitur',
      );
    }
  }
}
