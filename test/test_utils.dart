import 'package:firmware_updater/fwupd_notifier.dart';
import 'package:firmware_updater/fwupd_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwupd/fwupd.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'test_utils.mocks.dart';

FwupdDevice testDevice({
  required String id,
  String? name,
  String? summary,
  String? icon,
  List<String>? guid,
  String? vendor,
  String? version,
  String? versionLowest,
  String? checksum,
  Set<FwupdDeviceFlag>? flags,
}) {
  return FwupdDevice(
    deviceId: id,
    name: name ?? '',
    summary: summary,
    icon: icon != null ? [icon] : [],
    guid: guid ?? [],
    vendor: vendor,
    version: version,
    versionLowest: versionLowest,
    checksum: checksum,
    plugin: '',
    flags: flags ?? {FwupdDeviceFlag.updatable},
  );
}

@GenerateMocks([FwupdService])
MockFwupdService mockService({
  List<FwupdDevice>? devices,
  Map<String, List<FwupdRelease>>? releases,
}) {
  final service = MockFwupdService();
  when(service.getDevices()).thenAnswer((_) async => devices ?? []);
  when(service.getReleases(any)).thenAnswer((i) async {
    final device = i.positionalArguments[0] as FwupdDevice;
    final value = releases?[device.deviceId];
    if (value == null) throw const FwupdNothingToDoException();
    return value;
  });
  when(service.deviceAdded).thenAnswer((_) => const Stream.empty());
  when(service.deviceChanged).thenAnswer((_) => const Stream.empty());
  when(service.deviceRemoved).thenAnswer((_) => const Stream.empty());
  when(service.deviceRequest).thenAnswer((_) => const Stream.empty());
  when(service.propertiesChanged).thenAnswer((_) => const Stream.empty());
  when(service.onBattery).thenAnswer((_) => false);
  return service;
}

@GenerateMocks([FwupdNotifier])
MockFwupdNotifier mockNotifier({
  FwupdStatus? status,
  int? percentage,
  String? version,
  bool? onBattery,
}) {
  final notifier = MockFwupdNotifier();
  when(notifier.status).thenReturn(status ?? FwupdStatus.idle);
  when(notifier.percentage).thenReturn(percentage ?? 0);
  when(notifier.version).thenReturn(version ?? 'v1.2.3');
  when(notifier.onBattery).thenReturn(onBattery ?? false);
  return notifier;
}

extension WidgetTesterX on WidgetTester {
  BuildContext get context => element(find.byType(Scaffold).first);
  AppLocalizations get lang => AppLocalizations.of(context);
  ThemeData get theme => Theme.of(context);

  Future<void> pumpApp(WidgetBuilder builder,
      {Size size = const Size(700, 850)}) {
    binding.window.devicePixelRatioTestValue = 1;
    binding.window.physicalSizeTestValue = size;
    return pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(builder: builder),
    ));
  }

  Future<void> pumpUntil(
    Finder finder, [
    Duration timeout = const Duration(seconds: 30),
  ]) async {
    assert(timeout.inMilliseconds >= 250);
    const delay = Duration(milliseconds: 250);

    if (this.any(finder)) return;

    return Future.doWhile(() async {
      if (this.any(finder)) return false;
      await pump(delay);
      return true;
    }).timeout(
      timeout,
      onTimeout: () => debugPrint(
          '\nWARNING: A call to pumpUntil() with finder "$finder" did not complete within the specified timeout $timeout.\n${StackTrace.current}'),
    );
  }
}
