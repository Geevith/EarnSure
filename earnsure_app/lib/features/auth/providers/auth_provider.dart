import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class RiderSession {
  const RiderSession({
    required this.riderId,
    required this.name,
    required this.phone,
    required this.city,
    required this.platform,
    required this.token,
    required this.avgHourlyRateInr,
    required this.trustScore,
  });

  final String riderId;
  final String name;
  final String phone;
  final String city;
  final String platform;
  final String token;
  final double avgHourlyRateInr;
  final double trustScore;

  RiderSession copyWith({
    String? riderId,
    String? name,
    String? phone,
    String? city,
    String? platform,
    String? token,
    double? avgHourlyRateInr,
    double? trustScore,
  }) =>
      RiderSession(
        riderId:           riderId           ?? this.riderId,
        name:              name              ?? this.name,
        phone:             phone             ?? this.phone,
        city:              city              ?? this.city,
        platform:          platform          ?? this.platform,
        token:             token             ?? this.token,
        avgHourlyRateInr:  avgHourlyRateInr  ?? this.avgHourlyRateInr,
        trustScore:        trustScore        ?? this.trustScore,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<RiderSession?> {
  @override
  Future<RiderSession?> build() async {
    // Check for stored token on cold start
    final hasToken = await ref.read(tokenHelperProvider).hasToken();
    if (hasToken) {
      // In production: validate token with GET /auth/me
      // For MVP: restore a mock session
      return _mockSession();
    }
    return null;
  }

  /// Sends OTP — in production, calls POST /auth/otp/send
  Future<void> sendOtp(String phone) async {
    // Mock: always succeeds. Production endpoint: POST /v1/auth/otp/send
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Verifies OTP and logs in the rider.
  /// In production, calls POST /v1/auth/login with {phone, otp}.
  Future<void> verifyOtp(String phone, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // ── Production path ─────────────────────────────────────────────────────
      // final dio = ref.read(apiClientProvider);
      // final resp = await dio.post('/auth/login', data: {'phone': phone, 'otp': otp});
      // final token = resp.data['access_token'] as String;
      // await ref.read(tokenHelperProvider).save(token);
      // return RiderSession.fromJson(resp.data);

      // ── Mock path (MVP demo) ─────────────────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 800));
      if (otp.length != 6) throw Exception('Invalid OTP — use any 6 digits');
      final session = _mockSession();
      await ref.read(tokenHelperProvider).save('mock-bearer-token-${session.riderId}');
      return session;
    });
  }

  Future<void> logout() async {
    await ref.read(tokenHelperProvider).clear();
    state = const AsyncData(null);
  }

  RiderSession _mockSession() => const RiderSession(
        riderId:          'c3f2a1b0-demo-rider-chennai',
        name:             'Arjun Kumar',
        phone:            '+91 98765 43210',
        city:             'Chennai',
        platform:         'Zomato',
        token:            'mock-bearer-token',
        avgHourlyRateInr: 210.0,
        trustScore:       8.7,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────
final authProvider = AsyncNotifierProvider<AuthNotifier, RiderSession?>(
  AuthNotifier.new,
);