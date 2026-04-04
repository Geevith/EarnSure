import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum PolicyStatus { active, expired, cancelled, none }
enum DisruptionStatus { none, pending, approved, softFlagged }

class PolicyDetails {
  const PolicyDetails({
    required this.policyId,
    required this.weeklyPremiumInr,
    required this.maxPayoutInr,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.h3Index,
    required this.city,
    required this.streakDiscountApplied,
    required this.consecutiveWeeks,
  });

  final String       policyId;
  final double       weeklyPremiumInr;
  final double       maxPayoutInr;
  final PolicyStatus status;
  final DateTime     startDate;
  final DateTime     endDate;
  final String       h3Index;
  final String       city;
  final bool         streakDiscountApplied;
  final int          consecutiveWeeks;

  bool get isActive => status == PolicyStatus.active;

  factory PolicyDetails.mock() => PolicyDetails(
        policyId:             'pol-mock-c3f2a1b0-2024',
        weeklyPremiumInr:     98.0,
        maxPayoutInr:         450.0,
        status:               PolicyStatus.active,
        startDate:            DateTime.now().subtract(const Duration(days: 2)),
        endDate:              DateTime.now().add(const Duration(days: 5)),
        h3Index:              '882a1072b3fffff',
        city:                 'Chennai',
        streakDiscountApplied: true,
        consecutiveWeeks:     5,
      );

  factory PolicyDetails.fromJson(Map<String, dynamic> json) => PolicyDetails(
        policyId:             json['id'] as String,
        weeklyPremiumInr:     (json['weekly_premium_inr'] as num).toDouble(),
        maxPayoutInr:         (json['max_payout_inr'] as num).toDouble(),
        status:               _parseStatus(json['status'] as String),
        startDate:            DateTime.parse(json['start_date'] as String),
        endDate:              DateTime.parse(json['end_date'] as String),
        h3Index:              json['hex_zone']?['h3_index'] as String? ?? '',
        city:                 json['hex_zone']?['city'] as String? ?? '',
        streakDiscountApplied: json['streak_discount_applied'] as bool? ?? false,
        consecutiveWeeks:     0,
      );

  static PolicyStatus _parseStatus(String s) => switch (s) {
        'active'    => PolicyStatus.active,
        'expired'   => PolicyStatus.expired,
        'cancelled' => PolicyStatus.cancelled,
        _           => PolicyStatus.none,
      };
}

class RiskProfile {
  const RiskProfile({
    required this.riskScore,
    required this.disruptionProbability,
    required this.zoneRisk,
    required this.weeklyPremiumInr,
    required this.streakDiscountApplied,
    required this.streakDiscountPct,
    required this.historicalClaimsFactor,
  });

  final double riskScore;
  final double disruptionProbability;
  final double zoneRisk;
  final double weeklyPremiumInr;
  final bool   streakDiscountApplied;
  final double streakDiscountPct;
  final double historicalClaimsFactor;

  factory RiskProfile.mock() => const RiskProfile(
        riskScore:             7.2,
        disruptionProbability: 0.38,
        zoneRisk:              0.82,
        weeklyPremiumInr:      98.0,
        streakDiscountApplied: true,
        streakDiscountPct:     15.0,
        historicalClaimsFactor: 1.05,
      );

  factory RiskProfile.fromJson(Map<String, dynamic> json) => RiskProfile(
        riskScore:             (json['risk_score'] as num).toDouble(),
        disruptionProbability: (json['disruption_probability'] as num).toDouble(),
        zoneRisk:              (json['zone_risk'] as num).toDouble(),
        weeklyPremiumInr:      (json['weekly_premium_inr'] as num).toDouble(),
        streakDiscountApplied: json['streak_discount_applied'] as bool? ?? false,
        streakDiscountPct:     (json['streak_discount_pct'] as num?)?.toDouble() ?? 0,
        historicalClaimsFactor:(json['historical_claims_factor'] as num?)?.toDouble() ?? 1.0,
      );
}

class DisruptionAlert {
  const DisruptionAlert({
    required this.eventId,
    required this.disruption_type,
    required this.status,
    required this.payoutAmountInr,
    required this.triggeredAt,
    required this.h3Index,
  });

  final String            eventId;
  final String            disruption_type;
  final DisruptionStatus  status;
  final double            payoutAmountInr;
  final DateTime          triggeredAt;
  final String            h3Index;

  factory DisruptionAlert.mock() => DisruptionAlert(
        eventId:          'evt-mock-monsoon-2024',
        disruption_type:  'monsoon',
        status:           DisruptionStatus.approved,
        payoutAmountInr:  450.0,
        triggeredAt:      DateTime.now().subtract(const Duration(minutes: 8)),
        h3Index:          '882a1072b3fffff',
      );
}

// ── Insurance State ───────────────────────────────────────────────────────────

class InsuranceState {
  const InsuranceState({
    this.policy,
    this.riskProfile,
    this.activeAlert,
    this.isPolicyActive = false,
    this.isLoading      = false,
    this.error,
  });

  final PolicyDetails?    policy;
  final RiskProfile?      riskProfile;
  final DisruptionAlert?  activeAlert;
  final bool              isPolicyActive;
  final bool              isLoading;
  final String?           error;

  InsuranceState copyWith({
    PolicyDetails?   policy,
    RiskProfile?     riskProfile,
    DisruptionAlert? activeAlert,
    bool?            isPolicyActive,
    bool?            isLoading,
    String?          error,
    bool             clearAlert = false,
    bool             clearError = false,
  }) =>
      InsuranceState(
        policy:          policy         ?? this.policy,
        riskProfile:     riskProfile    ?? this.riskProfile,
        activeAlert:     clearAlert ? null : (activeAlert ?? this.activeAlert),
        isPolicyActive:  isPolicyActive ?? this.isPolicyActive,
        isLoading:       isLoading      ?? this.isLoading,
        error:           clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class InsuranceNotifier extends StateNotifier<InsuranceState> {
  InsuranceNotifier(this._ref) : super(const InsuranceState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _fetchRiskProfile();
      await _fetchActivePolicy();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _fetchRiskProfile() async {
    // Production: GET /v1/policies/quote/{rider_id}?h3_index=...
    // MVP: use mock
    await Future.delayed(const Duration(milliseconds: 400));
    final profile = RiskProfile.mock();
    state = state.copyWith(riskProfile: profile);
  }

  Future<void> _fetchActivePolicy() async {
    final session = _ref.read(authProvider).value;
    if (session == null) return;

    try {
      // Production path ───────────────────────────────────────────────────────
      // final dio = _ref.read(apiClientProvider);
      // final resp = await dio.get('/policies/active/${session.riderId}');
      // final data = resp.data as Map<String, dynamic>;
      // if (data['has_active_policy'] == true) {
      //   state = state.copyWith(
      //     policy:         PolicyDetails.fromJson(data['policy']),
      //     isPolicyActive: true,
      //     isLoading:      false,
      //   );
      //   return;
      // }

      // MVP mock path ─────────────────────────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        policy:         PolicyDetails.mock(),
        isPolicyActive: true,
        isLoading:      false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(isPolicyActive: false, isLoading: false);
      } else {
        rethrow;
      }
    }
  }

  /// Activates a new weekly policy via the backend.
  Future<void> activatePolicy(String h3Index, Map<String, dynamic> sensorPayload) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = _ref.read(authProvider).value!;

      // Production path ───────────────────────────────────────────────────────
      // final dio = _ref.read(apiClientProvider);
      // final resp = await dio.post('/policies/purchase', data: {
      //   'rider_id':          session.riderId,
      //   'h3_index':          h3Index,
      //   'platform':          session.platform.toLowerCase(),
      //   'device_fingerprint': sensorPayload,
      // });
      // final policy = PolicyDetails.fromJson(resp.data);

      // MVP mock path ─────────────────────────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 900));
      final policy = PolicyDetails.mock();

      state = state.copyWith(
        policy:         policy,
        isPolicyActive: true,
        isLoading:      false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Activation failed: $e');
    }
  }

  /// Simulates a live disruption alert arriving (triggered via backend webhook).
  Future<void> simulateDisruptionAlert() async {
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(activeAlert: DisruptionAlert.mock());
  }

  void dismissAlert() => state = state.copyWith(clearAlert: true);

  Future<void> refresh() => _init();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final insuranceProvider =
    StateNotifierProvider<InsuranceNotifier, InsuranceState>(
  (ref) => InsuranceNotifier(ref),
);