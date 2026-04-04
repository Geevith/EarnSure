import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// ── Constants ────────────────────────────────────────────────────────────────
const String _baseUrl       = 'http://10.0.2.2:8000/api/v1';
const String _tokenKey      = 'earnsure_bearer_token';
const Duration _connectTimeout = Duration(seconds: 12);
const Duration _receiveTimeout = Duration(seconds: 20);

// ── Storage Provider ─────────────────────────────────────────────────────────
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

// ── Dio Provider ─────────────────────────────────────────────────────────────
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl:        _baseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept':        'application/json',
      },
    ),
  );

  // ── Auth Interceptor ────────────────────────────────────────────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Auto-logout on 401
        if (error.response?.statusCode == 401) {
          await storage.delete(key: _tokenKey);
        }
        handler.next(error);
      },
    ),
  );

  // ── Logger (debug only) ─────────────────────────────────────────────────────
  assert(() {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader:  true,
        requestBody:    true,
        responseBody:   true,
        responseHeader: false,
        compact:        false,
      ),
    );
    return true;
  }());

  return dio;
});

// ── Token Helpers ─────────────────────────────────────────────────────────────
final tokenHelperProvider = Provider<TokenHelper>((ref) {
  return TokenHelper(ref.read(secureStorageProvider));
});

class TokenHelper {
  const TokenHelper(this._storage);
  final FlutterSecureStorage _storage;

  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clear()           => _storage.delete(key: _tokenKey);
  Future<String?> read()         => _storage.read(key: _tokenKey);
  Future<bool> hasToken()        async => (await read()) != null;
}