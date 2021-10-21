import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fwupd/fwupd.dart';
import 'package:path/path.dart' as p;

class FwupdModel extends ChangeNotifier {
  FwupdModel(this._client) {
    _client.propertiesChanged.listen((_) => notifyListeners());
  }

  final FwupdClient _client;
  var _devices = <FwupdDevice>[];
  final _upgrades = <String, List<FwupdRelease>>{};
  var _remotes = <String, FwupdRemote>{};

  bool get isBusy => status.index > FwupdStatus.idle.index;
  FwupdStatus get status => _client.status;
  int get percentage => _client.percentage;
  String get daemonVersion => _client.daemonVersion;

  List<FwupdDevice> get devices => _devices;
  List<FwupdRelease> upgrades(FwupdDevice device) => _upgrades[device.id] ?? [];

  Future<void> init() => _client.connect().then((_) => refresh());

  Future<void> refresh() => Future.wait([_fetchDevices(), _fetchRemotes()]);

  Future<void> upgrade(FwupdDevice device, FwupdRelease upgrade) {
    assert(upgrade.locations.isNotEmpty);
    // TODO: handle different types of remotes (local, download, directory, ...)
    final remote = _remotes[upgrade.remoteId];
    final cache = p.dirname(remote?.filenameCache ?? '');
    final file = File(p.join(cache, upgrade.locations.first));
    return _client.install(
      device.id,
      ResourceHandle.fromFile(file.openSync()),
    );
  }

  Future<void> activate(FwupdDevice device) => _client.activate(device.id);
  Future<void> clearResults(FwupdDevice device) =>
      _client.clearResults(device.id);
  Future<void> unlock(FwupdDevice device) => _client.activate(device.id);
  Future<void> verify(FwupdDevice device) => _client.verify(device.id);
  Future<void> verifyUpdate(FwupdDevice device) =>
      _client.verifyUpdate(device.id);

  Future<void> _fetchDevices() async {
    var devices = <FwupdDevice>[];
    try {
      devices = await _client.getDevices().then((devices) {
        return devices.where((device) {
          if (!device.isUpdatable) return false;
          _fetchUpgrades(device);
          return true;
        }).toList();
      });
    } on FwupdException catch (_) {}
    _devices = devices;
    notifyListeners();
  }

  Future<void> _fetchUpgrades(FwupdDevice device) async {
    var upgrades = <FwupdRelease>[];
    try {
      upgrades = await _client.getUpgrades(device.id);
    } on FwupdException catch (_) {}
    _upgrades[device.id] = upgrades;
    notifyListeners();
  }

  Future<void> _fetchRemotes() async {
    var remotes = <FwupdRemote>[];
    try {
      remotes = await _client.getRemotes();
    } on FwupdException catch (_) {}
    _remotes = {
      for (final remote in remotes) remote.id: remote,
    };
    notifyListeners();
  }
}

extension FwupdDeviceX on FwupdDevice {
  String get id => deviceId;
  bool get canVerify => flags.contains(FwupdDeviceFlag.canVerify);
  bool get isUpdatable =>
      flags.contains(FwupdDeviceFlag.updatable) ||
      flags.contains(FwupdDeviceFlag.updatableHidden);
}