// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$liveSessionRepositoryHash() =>
    r'002748b22fb4347f69a1d3159eb902dae8c49124';

/// See also [liveSessionRepository].
@ProviderFor(liveSessionRepository)
final liveSessionRepositoryProvider = Provider<LiveSessionRepository>.internal(
  liveSessionRepository,
  name: r'liveSessionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$liveSessionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LiveSessionRepositoryRef = ProviderRef<LiveSessionRepository>;
String _$liveSessionHash() => r'18441112eeea00b6bc37f235e34401adbd089e43';

/// See also [LiveSession].
@ProviderFor(LiveSession)
final liveSessionProvider =
    AutoDisposeNotifierProvider<LiveSession, LiveSessionState>.internal(
  LiveSession.new,
  name: r'liveSessionProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$liveSessionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LiveSession = AutoDisposeNotifier<LiveSessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
