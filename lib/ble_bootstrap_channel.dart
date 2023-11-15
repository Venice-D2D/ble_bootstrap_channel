// ignore_for_file: use_build_context_synchronously

library ble_bootstrap_channel;

import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:venice_core/channels/abstractions/bootstrap_channel.dart';
import 'package:venice_core/channels/channel_metadata.dart';
import 'package:venice_core/file/file_metadata.dart';

class BleBootstrapChannel extends BootstrapChannel {
  final BuildContext context;
  PeripheralManager get peripheralManager => PeripheralManager.instance;
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
        Set<String> seen = {};

        return StatefulBuilder(
          builder: (context, setState) {
            // Start devices discovery
            var subscription = FlutterBluePlus.scanResults.listen(
              (results) {
                for (ScanResult r in results) {
                  if (seen.contains(r.device.advName) == false) {
                    print(
                        '${r.device.remoteId}: "${r.advertisementData.localName}" found! rssi: ${r.rssi}');
                    setState(() {
                      seen.add(r.device.advName);
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
  Future<void> initSender() async {
    await peripheralManager.clearServices();
    final service = GattService(
      uuid: UUID.short(100),
      characteristics: [
        GattCharacteristic(
          uuid: UUID.short(200),
          properties: [
            GattCharacteristicProperty.read,
          ],
          descriptors: [],
        ),
        GattCharacteristic(
          uuid: UUID.short(201),
          properties: [
            GattCharacteristicProperty.read,
            GattCharacteristicProperty.write,
            GattCharacteristicProperty.writeWithoutResponse,
          ],
          descriptors: [],
        ),
        GattCharacteristic(
          uuid: UUID.short(202),
          properties: [
            GattCharacteristicProperty.notify,
            GattCharacteristicProperty.indicate,
          ],
          descriptors: [],
        ),
      ],
    );
    await peripheralManager.addService(service);
    final advertisement = Advertisement(
      name: 'venice',
      manufacturerSpecificData: ManufacturerSpecificData(
        id: 0x2e19,
        data: Uint8List.fromList([0x01, 0x02, 0x03]),
      ),
    );
    await peripheralManager.startAdvertising(advertisement);
  }

  @override
  Future<void> sendChannelMetadata(ChannelMetadata data) async {
    await peripheralManager.setUp();
    initSender();
  }

  @override
  Future<void> sendFileMetadata(FileMetadata data) {
    // TODO: implement sendFileMetadata
    throw UnimplementedError();
  }
}
