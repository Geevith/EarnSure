import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/edge_sensor_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum AntiSpoofingStatus { idle, validating, passed, softFlagged, hardBlocked }

class AntiSpoofingState {
  const AntiSpoofingState({
    this.status         = AntiSpoofingStatus.idle,
    this.fraudScore     = 0.0,
    this.trustLevel     = 'TRUSTED',
    this.isFlatSensor   = false,
    this.isAcAnomaly    = false,
    this.stdDevHz       = 0.0,
    this.isCharging     = false,
    this.batteryLevel   = 0,
    this.chargingType   = 'none',
    this.gyroscopeActive = false,
    this.samplesCollected = 0,
    this.lastValidatedAt,
    this.fingerprintPayload,
  });

  final AntiSpoofingStatus    status;
  final double                fraudScore;
  final String                trustLevel;
  final bool                  isFlatSensor;
  final bool                  isAcAnomaly;
  final double                stdDevHz;
  final bool                  isCharging;
  final int                   batteryLevel;
  final String                chargingType;
  final bool                  gyroscopeActive;
  final int                   samplesCollected;
  final DateTime?             lastValidatedAt;
  final Map<String, dynamic>? fingerprintPayload;

  bool get canProceed =>
      status == AntiSpoofingStatus.passed ||
      status == AntiSpoofingStatus.softFlagged;

  AntiSpoofingState copyWith({
    AntiSpoofingStatus?    status,
    double?                fraudScore,
    String?                trustLevel,
    bool?                  isFlatSensor,
    bool?                  isAcAnomaly,
    double?                stdDevHz,
    bool?                  isCharging,
    int?                   batteryLevel,
    String?                chargingType,
    bool?                  gyroscopeActive,
    int?                   samplesCollected,
    DateTime?              lastValidatedAt,
    Map<String, dynamic>?  fingerprintPayload,
  }) =>
      AntiSpoofingState(
        status:             status             ?? this.status,
        fraudScore:         fraudScore         ?? this.fraudScore,
        trustLevel:         trustLevel         ?? this.trustLevel,
        isFlatSensor:       isFlatSensor       ?? this.isFlatSensor,
        isAcAnomaly:        isAcAnomaly        ?? this.isAcAnomaly,
        stdDevHz:           stdDevHz           ?? this.stdDevHz,
        isCharging:         isCharging         ?? this.isCharging,
        batteryLevel:       batteryLevel       ?? this.batteryLevel,
        chargingType:       chargingType       ?? this.chargingType,
        gyroscopeActive:    gyroscopeActive    ?? this.gyroscopeActive,
        samplesCollected:   samplesCollected   ?? this.samplesCollected,
        lastValidatedAt:    lastValidatedAt    ?? this.lastValidatedAt,
        fingerprintPayload: fingerprintPayload ?? this.fingerprintPayload,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AntiSpoofingNotifier extends StateNotifier<AntiSpoofingState> {
  AntiSpoofingNotifier(this._ref) : super(const AntiSpoofingState()) {
    _subscribeToSensorStream();
  }

  final Ref _ref;

  void _subscribeToSensorStream() {
    _ref.listen<AsyncValue<SensorSnapshot>>(
      sensorSnapshotProvider,
      (_, next) {
        next.whenData((snap) {
          state = state.copyWith(
            stdDevHz:        snap.stdDevMagnitude,
            isFlatSensor:    snap.isFlatSensor,
            isAcAnomaly:     snap.isAcChargingAnomaly,
            fraudScore:      snap.quickFraudScore,
            trustLevel:      snap.trustLevel,
            isCharging:      snap.isCharging,
            batteryLevel:    snap.batteryLevel,
            chargingType:    snap.chargingType,
            gyroscopeActive: snap.gyroscopeActive,
            samplesCollected: snap.samplesCollected,
          );
        });
      },
    );
  }

  /// Run a full hardware validation pass before policy activation or claim.
  /// Requires at least 20 samples (≈1.6 seconds of data) to be reliable.
  Future<Map<String, dynamic>> validateAndPackage({
    double gpsLat         = 13.0827,
    double gpsLng         = 80.2707,
    double gpsAccuracy    = 12.0,
    String deviceId       = 'mvp-demo-device-001',
    String deviceModel    = 'Pixel 7',
  }) async {
    state = state.copyWith(status: AntiSpoofingStatus.validating);

    // Wait for enough samples if cold-starting
    if (state.samplesCollected < 20) {
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    final service = _ref.read(edgeSensorServiceProvider);
    final payload = service.toFingerprintPayload(
      gpsLat:            gpsLat,
      gpsLng:            gpsLng,
      gpsAccuracyMeters: gpsAccuracy,
      deviceId:          deviceId,
      deviceModel:       deviceModel,
    );

    // Production path ─────────────────────────────────────────────────────────
    // Submit to backend for server-side anti-spoofing cross-validation:
    // final dio = _ref.read(apiClientProvider);
    // final resp = await dio.post('/claims/verify', data: payload);
    // final serverFraudRisk = resp.data['fraud_risk_level'] as String;

    // Determine local status from sensor signals
    AntiSpoofingStatus result;
    if (state.fraudScore >= 0.60) {
      result = AntiSpoofingStatus.hardBlocked;
    } else if (state.fraudScore >= 0.30) {
      result = AntiSpoofingStatus.softFlagged;
    } else {
      result = AntiSpoofingStatus.passed;
    }

    state = state.copyWith(
      status:             result,
      lastValidatedAt:    DateTime.now(),
      fingerprintPayload: payload,
    );

    return payload;
  }

  void reset() => state = const AntiSpoofingState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final antiSpoofingProvider =
    StateNotifierProvider<AntiSpoofingNotifier, AntiSpoofingState>(
  (ref) => AntiSpoofingNotifier(ref),
);