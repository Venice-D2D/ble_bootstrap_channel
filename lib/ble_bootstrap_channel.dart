// ignore_for_file: use_build_context_synchronously

library ble_bootstrap_channel;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:venice_core/channels/abstractions/bootstrap_channel.dart';
import 'package:venice_core/channels/channel_metadata.dart';
import 'package:venice_core/file/file_metadata.dart';

class BleBootstrapChannel extends BootstrapChannel {
  final BuildContext context;
  BleBootstrapChannel(this.context);

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<void> initReceiver() async {
    bool selectedDevice = false;

    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      throw UnsupportedError('Bluetooth not supported by this device');
    }

    // Setup listener
    bool ready = false;
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        ready = true;
      }
    });

    // Wait for Bluetooth activation
    while (!ready) {
      debugPrint("Waiting for Bluetooth to be ready...");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<DeviceIdentifier> seen = {};

        return StatefulBuilder(
          builder: (context, setState) {
            // Start devices discovery
            var subscription = FlutterBluePlus.scanResults.listen(
              (results) {
                debugPrint("${results.length}");
                for (ScanResult r in results) {
                  if (seen.contains(r.device.remoteId) == false) {
                    print(
                        '${r.device.remoteId}: "${r.advertisementData.localName}" found! rssi: ${r.rssi}');
                    setState(() {
                      seen.add(r.device.remoteId);
                    });
                  }
                }
              },
            );

            // Start scanning
            FlutterBluePlus.startScan();

            return AlertDialog(
              title: const Text("Looking for devices..."),
              content: Text(seen.toString()),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    subscription.cancel();
                    FlutterBluePlus.stopScan();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );

    while (!selectedDevice) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("Waiting for device selection...");
    }
  }

  @override
  Future<void> initSender() {
    // TODO: implement initSender
    throw UnimplementedError();
  }

  @override
  Future<void> sendChannelMetadata(ChannelMetadata data) {
    // TODO: implement sendChannelMetadata
    throw UnimplementedError();
  }

  @override
  Future<void> sendFileMetadata(FileMetadata data) {
    // TODO: implement sendFileMetadata
    throw UnimplementedError();
  }
}
