// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import '/controller/requirement_state_controller.dart';
import 'package:get/get.dart';

import 'package:permission_handler/permission_handler.dart';

class TabScanning extends StatefulWidget {
  const TabScanning({super.key});

  @override
  TabScanningState createState() => TabScanningState();
}

class TabScanningState extends State<TabScanning> {
  StreamSubscription<RangingResult>? _streamRanging;
  final _regionBeacons = <Region, List<Beacon>>{};
  final _beacons = <Beacon>[];
  final controller = Get.find<RequirementStateController>();

  @override
  void initState() {
    super.initState();

    controller.startStream.listen((flag) {
      if (flag == true) {
        initScanBeacon();
      }
    });

    controller.pauseStream.listen((flag) {
      if (flag == true) {
        pauseScanBeacon();
      }
    });
  }

  initScanBeacon() async {
    // iOS에서 권한과 서비스 상태를 확실히 체크하는 로직 추가
    // initializeScanning 전에 권한을 확인하고, 권한이 없을 경우 사용자에게 요청합니다.
    if (!controller.authorizationStatusOk ||
        !controller.locationServiceEnabled ||
        !controller.bluetoothEnabled) {
      print('권한 또는 서비스 상태가 불충분하여 스캔을 시작할 수 없습니다. 권한 요청을 시도합니다.');
      
      // 권한을 요청합니다.
      final locationStatus = await Permission.locationAlways.request();
      final bluetoothStatus = await Permission.bluetoothScan.request();

      if (locationStatus.isGranted && bluetoothStatus.isGranted) {
        print('권한 요청이 성공했습니다. 스캔을 다시 시도합니다.');
        // 권한이 부여되면 다시 스캔을 시작합니다.
        initScanBeacon();
      } else {
        print('권한이 거부되었습니다. 스캔을 시작할 수 없습니다.');
        return;
      }
      return;
    }

    await flutterBeacon.initializeScanning;

    await flutterBeacon.setScanPeriod(1000);
    await flutterBeacon.setBetweenScanPeriod(500);
    await flutterBeacon.setUseTrackingCache(true);
    await flutterBeacon.setMaxTrackingAge(10000);

    await flutterBeacon.setBackgroundScanPeriod(1000);
    await flutterBeacon.setBackgroundBetweenScanPeriod(500);

    //await flutterBeacon.setEnableScheduledScanJobs(true);
    /*
    await flutterBeacon.initializeScanning;
    if (!controller.authorizationStatusOk ||
        !controller.locationServiceEnabled ||
        !controller.bluetoothEnabled) {
      print(
          'RETURNED, authorizationStatusOk=${controller.authorizationStatusOk}, '
          'locationServiceEnabled=${controller.locationServiceEnabled}, '
          'bluetoothEnabled=${controller.bluetoothEnabled}');
      return;
    }*/
    var regions = <Region>[];
    if (Platform.isIOS) {
      regions = <Region>[
        Region(
          identifier: 'Cubeacon',
          proximityUUID: 'CB10023F-A318-3394-4199-A8730C7C1AEC',
        ),
        Region(
          identifier: 'BeaconType2',
          proximityUUID: '6a84c716-0f2a-1ce9-f210-6a63bd873dd9',
        ),
        Region(
          identifier: 'BlueUp',
          proximityUUID: 'acfd065e-c3c0-11e3-9bbe-1a514932ac01',
        ),
        Region(
          identifier: 'BlueUp Maxi',
          proximityUUID: '909C3CF9-FC5C-4841-B695-380958A51A5A',
        ),
      ];
    } else {
      regions = [
        Region(
          identifier: 'all-beacons',
        ),
      ];
    }

    if (_streamRanging != null) {
      if (_streamRanging!.isPaused) {
        _streamRanging?.resume();
        return;
      }
    }

    _streamRanging =
        flutterBeacon.ranging(regions).listen((RangingResult result) {
      print(result);
      if (mounted) {
        setState(() {
          _regionBeacons[result.region] = result.beacons;
          _beacons.clear();
          for (var list in _regionBeacons.values) {
            _beacons.addAll(list);
          }
          _beacons.sort(_compareParameters);
        });
      }
    });
  }

  pauseScanBeacon() async {
    _streamRanging?.pause();
    if (_beacons.isNotEmpty) {
      setState(() {
        _beacons.clear();
      });
    }
  }

  int _compareParameters(Beacon a, Beacon b) {
    int compare = a.proximityUUID.compareTo(b.proximityUUID);

    if (compare == 0) {
      compare = a.major.compareTo(b.major);
    }

    if (compare == 0) {
      compare = a.minor.compareTo(b.minor);
    }

    return compare;
  }

  @override
  void dispose() {
    _streamRanging?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _beacons.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: ListTile.divideTiles(
                context: context,
                tiles: _beacons.map(
                  (beacon) {
                    return ListTile(
                      title: Text(
                        beacon.proximityUUID,
                        style: const TextStyle(fontSize: 15.0),
                      ),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Flexible(
                            flex: 1,
                            fit: FlexFit.tight,
                            child: Text(
                              'Major: ${beacon.major}\nMinor: ${beacon.minor}',
                              style: const TextStyle(fontSize: 13.0),
                            ),
                          ),
                          Flexible(
                            flex: 2,
                            fit: FlexFit.tight,
                            child: Text(
                              'Accuracy: ${beacon.accuracy}m\nRSSI: ${beacon.rssi}',
                              style: const TextStyle(fontSize: 13.0),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ).toList(),
            ),
    );
  }
}
