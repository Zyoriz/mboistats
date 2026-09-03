import 'package:flutter/material.dart';
import 'package:mboistats/services/logger_service.dart';

/// Observer Navigasi Otomatis untuk Pelacakan Aktivitas Pengguna - MBOISSTATS+ PKL
/// Lead: Orang 1 (Data Architecture, Time Decay & User Tracking Lead)
class ActivityLoggingObserver extends NavigatorObserver {
  // Pemetaan rute (route name) ke Category ID, Sektor, dan Judul Fitur
  // Category IDs (sesuai tabel `categories` live di Supabase):
  // 1: Perekonomian, 2: Tenaga Kerja, 3: IPM, 4: Kemiskinan, 5: Kependudukan, 6: Pertanian, 7: Kesejahteraan
  static const Map<String, Map<String, dynamic>> _routeLogs = {
    // IPM (ID: 3)
    '/PendudukBekerja': {'categoryId': 3, 'sector': 'ipm', 'title': 'Penduduk Bekerja (IPM)'},
    '/UsiaHarapanHidup': {'categoryId': 3, 'sector': 'ipm', 'title': 'Usia Harapan Hidup'},
    '/HarapanLamaSekolah': {'categoryId': 3, 'sector': 'ipm', 'title': 'Harapan Lama Sekolah'},
    '/RataRataLamaSekolah': {'categoryId': 3, 'sector': 'ipm', 'title': 'Rata-Rata Lama Sekolah'},
    '/DayaBeli': {'categoryId': 3, 'sector': 'ipm', 'title': 'Daya Beli'},

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

    // Kemiskinan (ID: 4)
    '/TingkatKemiskinan': {'categoryId': 4, 'sector': 'kemiskinan', 'title': 'Tingkat Kemiskinan'},
    '/IndeksKedalamanKemiskinan': {'categoryId': 4, 'sector': 'kemiskinan', 'title': 'Indeks Kedalaman Kemiskinan'},
    '/IndeksKeparahanKemiskinan': {'categoryId': 4, 'sector': 'kemiskinan', 'title': 'Indeks Keparahan Kemiskinan'},
    '/GarisKemiskinan': {'categoryId': 4, 'sector': 'kemiskinan', 'title': 'Garis Kemiskinan'},

    // Ketenagakerjaan (ID: 2)
    '/AKMenurutPendidikan': {'categoryId': 2, 'sector': 'ketenagakerjaan', 'title': 'Angkatan Kerja Menurut Pendidikan'},
    '/PartisipasiAngkatanKerja': {'categoryId': 2, 'sector': 'ketenagakerjaan', 'title': 'Tingkat Partisipasi Angkatan Kerja'},
    '/TingkatPengangguran': {'categoryId': 2, 'sector': 'ketenagakerjaan', 'title': 'Tingkat Pengangguran'},
    '/PengangguranMenurutPendidikan': {'categoryId': 2, 'sector': 'ketenagakerjaan', 'title': 'Pengangguran Menurut Pendidikan'},

    // Kesejahteraan (ID: 7)
    '/GiniRasio': {'categoryId': 7, 'sector': 'kesejahteraan', 'title': 'Gini Rasio'},
    '/PengeluaranPerkapita': {'categoryId': 7, 'sector': 'kesejahteraan', 'title': 'Pengeluaran Perkapita'},

    // Pertanian (ID: 6)
    '/LuasPanenPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Luas Panen Padi'},
    '/ProduksiPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produksi Padi'},
    '/ProduktivitasPadi': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produktivitas Padi'},
    '/ProduksiBeras': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Produksi Beras'},
    
    // Sektor Katalog Menu Level-1
    '/ekonomi': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Katalog Perekonomian'},
    '/Ekonomi': {'categoryId': 1, 'sector': 'perekonomian', 'title': 'Katalog Perekonomian'},
    '/ketenagakerjaan': {'categoryId': 2, 'sector': 'ketenagakerjaan', 'title': 'Katalog Ketenagakerjaan'},
    '/ipm': {'categoryId': 3, 'sector': 'ipm', 'title': 'Katalog IPM'},
    '/kemiskinan': {'categoryId': 4, 'sector': 'kemiskinan', 'title': 'Katalog Kemiskinan'},
    '/kependudukan': {'categoryId': 5, 'sector': 'kependudukan', 'title': 'Katalog Kependudukan'},
    '/pertanian': {'categoryId': 6, 'sector': 'pertanian', 'title': 'Katalog Pertanian'},
    '/kesejahteraan': {'categoryId': 7, 'sector': 'kesejahteraan', 'title': 'Katalog Kesejahteraan'},

    // Fitur Tambahan & Halaman Menu Utama
    '/contact': {'categoryId': null, 'sector': 'layanan', 'title': 'Halaman Kontak Layanan'},
    '/berita': {'categoryId': null, 'sector': 'brs', 'title': 'Katalog Berita Resmi Statistik'},
    '/brs': {'categoryId': null, 'sector': 'brs', 'title': 'Katalog Berita Resmi Statistik'},
    '/publikasi': {'categoryId': null, 'sector': 'publikasi', 'title': 'Katalog Publikasi BPS'},
    '/publikasi_full': {'categoryId': null, 'sector': 'publikasi', 'title': 'Katalog Publikasi Lengkap'},
    '/infografis': {'categoryId': null, 'sector': 'infografis', 'title': 'Katalog Infografis Statistik'},
    '/infografis_full': {'categoryId': null, 'sector': 'infografis', 'title': 'Katalog Infografis Lengkap'},
    '/youtube': {'categoryId': null, 'sector': 'streaming', 'title': 'Arsip Live Streaming YouTube'},
    '/youtube_archive': {'categoryId': null, 'sector': 'streaming', 'title': 'Arsip Live Streaming YouTube'},
    '/search': {'categoryId': null, 'sector': 'pencarian', 'title': 'Halaman Pencarian Konten'},
    '/data': {'categoryId': null, 'sector': 'fitur', 'title': 'Halaman Data Statistik'},
    '/profil': {'categoryId': null, 'sector': 'profil', 'title': 'Halaman Profil Pengguna'},
    '/edit_profil': {'categoryId': null, 'sector': 'profil', 'title': 'Halaman Edit Profil Pengguna'},
    '/login': {'categoryId': null, 'sector': 'auth', 'title': 'Halaman Login'},
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
