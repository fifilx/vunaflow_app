import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL of the VunaFlow backend.
/// - Android emulator: use http://10.0.2.2:4000
/// - iOS simulator / web / desktop: use http://localhost:4000
/// - Physical device: use your machine's LAN IP, e.g. http://192.168.1.10:4000
class ApiConfig {
  static const String _envUrl = String.fromEnvironment('API_BASE_URL');
  static String? _customUrl;

  static String get baseUrl {
    if (_customUrl != null && _customUrl!.isNotEmpty) return _customUrl!;
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kIsWeb) return 'http://localhost:4001';
    // For native Android (physical device & emulator on LAN):
    return 'http://192.168.100.68:4001';
  }

  static void setCustomUrl(String url) {
    _customUrl = url;
  }

  /// Builds the full URL to an uploaded document, given the file_path
  /// returned by the API (e.g. "uploads/16123-abc.pdf").
  static String fileUrl(String filePath) => '$baseUrl/$filePath';
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin wrapper around http calls: attaches the JWT, decodes JSON,
/// and throws ApiException with the backend's error message on failure.
class ApiService {
  static const _tokenKey = 'vunaflow_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    // body may be a Map or a List; only try map-access for error messages if it's a Map
    final Map<String, dynamic>? errorBody = (body is Map<String, dynamic>) ? body : null;
    final message = errorBody?['error'] ??
        (errorBody?['errors'] is List && (errorBody!['errors'] as List).isNotEmpty
            ? errorBody['errors'][0]['msg']
            : 'Something went wrong (${res.statusCode})');
    throw ApiException(message.toString(), statusCode: res.statusCode);
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    Map<String, String>? cleanQuery;
    if (query != null) {
      cleanQuery = {};
      query.forEach((k, v) {
        if (v != null) cleanQuery![k] = v.toString();
      });
    }
    // Ensure that when baseUrl is empty (web), we don't introduce a leading slash duplication.
    final fullPath = ApiConfig.baseUrl.isEmpty ? path : '${ApiConfig.baseUrl}$path';
    return Uri.parse(fullPath).replace(
      queryParameters: (cleanQuery != null && cleanQuery.isNotEmpty) ? cleanQuery : null,
    );
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _decode(res);
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  static Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await http.put(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  static Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final res = await http.patch(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {}));
    return _decode(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(_uri(path), headers: await _headers());
    return _decode(res);
  }

  /// Multipart upload for documents (supports both bytes for Web and File for Native).
  static Future<dynamic> uploadFile(
    String path, {
    List<int>? bytes,
    String? filename,
    File? file,
    required Map<String, String> fields,
    String fileField = 'file',
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);

    if (bytes != null && filename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
      ));
    } else if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    } else {
      throw ApiException('No file content provided');
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }
}
