import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mboistats/config/api_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data Model Customer/User yang didapatkan dari API Buku Tamu & Supabase `user_all`
class CustomerProfileData {
  final String? idUser;
  final String? name;
  final String? email;
  final String? phone;
  final int? age;
  final String? gender;
  final String? typeUser;
  final int? majorId;
  final String? majorName;

  final int? workId;
  final int? educationId;
  final int? universityId;
  final int? institutionId;

  // Nama Asli Relasi Tabel (Pekerjaan, Pendidikan, Universitas, Instansi)
  final String? workName;
  final String? educationName;
  final String? universityName;
  final String? institutionName;

  CustomerProfileData({
    this.idUser,
    this.name,
    this.email,
    this.phone,
    this.age,
    this.gender,
    this.typeUser,
    this.majorId,
    this.majorName,
    this.workId,
    this.educationId,
    this.universityId,
    this.institutionId,
    this.workName,
    this.educationName,
    this.universityName,
    this.institutionName,
  });

  factory CustomerProfileData.fromJson(Map<String, dynamic> json) {
    return CustomerProfileData(
      idUser: json['id_user']?.toString(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse(json['age']?.toString() ?? ''),
      gender: json['gender'] as String?,
      typeUser: json['type_user'] as String?,
      majorId: json['major_id_major'] is int
          ? json['major_id_major'] as int
          : int.tryParse(json['major_id_major']?.toString() ?? ''),
      majorName: json['major_name'] ?? (json['major'] is Map ? json['major']['major'] : null),
      workId: json['work_id'] is int
          ? json['work_id'] as int
          : int.tryParse(json['work_id']?.toString() ?? ''),
      educationId: json['education_id'] is int
          ? json['education_id'] as int
          : int.tryParse(json['education_id']?.toString() ?? ''),
      universityId: json['university_id'] is int
          ? json['university_id'] as int
          : int.tryParse(json['university_id']?.toString() ?? ''),
      institutionId: json['institution_id'] is int
          ? json['institution_id'] as int
          : int.tryParse(json['institution_id']?.toString() ?? ''),

      // Ekstrak Nama Relasi (Mendukung Format Flat API maupun Nested Object Supabase)
      workName: json['work_name'] ?? (json['works'] is Map ? json['works']['name'] : null),
      educationName: json['education_name'] ?? (json['education'] is Map ? json['education']['name'] : null),
      universityName: json['university_name'] ?? (json['universities'] is Map ? json['universities']['name'] : null),
      institutionName: json['institution_name'] ?? (json['institutions'] is Map ? json['institutions']['name'] : null),
    );
  }
}

/// Service untuk menghubungkan Aplikasi Flutter dengan API Buku Tamu & Tabel Profil Supabase
class CustomerApiService {
  /// Mengambil data customer berdasarkan email dari API Endpoint Buku Tamu
  static Future<CustomerProfileData?> getCustomerByEmail(String email) async {
    try {
      final url = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.customerEndpoint}?email=${Uri.encodeComponent(email)}');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final dataJson = (body is Map<String, dynamic> && body.containsKey('data'))
            ? body['data']
            : body;

        if (dataJson != null && dataJson is Map<String, dynamic>) {
          return CustomerProfileData.fromJson(dataJson);
        }
      }
      return null;
    } catch (e) {
      print("[CustomerApiService] Error fetching from API endpoint: $e");
      return null;
    }
  }

  /// Mengambil data customer langsung dari Supabase Cloud (tabel users_buku_tamu)
  static Future<CustomerProfileData?> getCustomerFromSupabase(String email) async {
    try {
      final data = await Supabase.instance.client
          .from('users_buku_tamu')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (data != null) {
        return CustomerProfileData.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print("[CustomerApiService] getCustomerFromSupabase Error: $e");
      return null;
    }
  }

  /// Mengambil data profil pengguna dari tabel `user_all` Supabase
  static Future<CustomerProfileData?> getUserAllProfile(String identifier) async {
    try {
      final data = await Supabase.instance.client
          .from('user_all')
          .select('*, major(id_major, major)')
          .or('email.eq.$identifier,id_user.eq.$identifier')
          .maybeSingle();

      if (data != null) {
        return CustomerProfileData.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print("[CustomerApiService] getUserAllProfile Error: $e");
      return null;
    }
  }
}
