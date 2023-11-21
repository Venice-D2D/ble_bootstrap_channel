// ignore_for_file: use_build_context_synchronously

library ble_bootstrap_channel;

import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:venice_core/channels/abstractions/bootstrap_channel.dart';
import 'package:venice_core/channels/channel_metadata.dart';
import 'package:venice_core/file/file_metadata.dart';

class BleBootstrapChannel extends BootstrapChannel {
  final BuildContext context;
  final UUID veniceUuid = UUID.short(100);
  final UUID veniceCharUuid = UUID.short(200);
  CentralManager get centralManager => CentralManager.instance;
  PeripheralManager get peripheralManager => PeripheralManager.instance;
  BleBootstrapChannel(this.context);

  @override
  Future<void> close() {
    // TODO: implement close
    throw UnimplementedError();
  }

  @override
  Future<void> initReceiver() async {
    Peripheral? selectedDevice;
    await centralManager.setUp();

    while (centralManager.state != BluetoothLowEnergyState.poweredOn) {
      debugPrint("Waiting for Bluetooth to be ready...");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<String> seen = {};
        Map<Advertisement, Peripheral> compatibles = {};

        return StatefulBuilder(
          builder: (context, setState) {
            centralManager.discovered.listen((event) async {
              String? advName = event.advertisement.name;
              if (seen.contains(advName)) {
                return;
              }

              // Do not visit same devices twice
              if (advName != null) {
                seen.add(advName);
              }

              // TODO remove this check maybe?
              if (advName != "venice") {
                return;
              }

              debugPrint("==> VENICE DEVICE FOUND");
              await centralManager.stopDiscovery();

              // Connect to distant device
              await centralManager.connect(event.peripheral);
              debugPrint("==> CONNECTED TO VENICE DEVICE");

              // Retrieve venice service
              List<GattService> services = await centralManager.discoverGATT(event.peripheral);
              List<GattService> matchingServices = services.where((element) => element.uuid == veniceUuid).toList();
              if (matchingServices.isEmpty) {
                debugPrint("==> VENICE SERVICE NOT FOUND");
                return;
              }
              debugPrint("==> FOUND VENICE SERVICE");

              // Retrieve data from characteristics
              Uint8List value = await centralManager.readCharacteristic(matchingServices.first.characteristics.first);
              debugPrint("$value");
            });

            // Start devices discovery
            centralManager.startDiscovery();

            return AlertDialog(
              title: const Text("Looking for devices..."),
              content: compatibles.isEmpty ? const Text("Searching...") : Column(
                mainAxisSize: MainAxisSize.min,
                children: compatibles.entries.map((e) => ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(e.key.name!),
                  subtitle: Text(e.value.uuid.toString()),
                  onTap: () {
                    selectedDevice = e.value;
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
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

    while (selectedDevice == null) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("Waiting for device selection...");
    }

    debugPrint("==> DEVICE SELECTED: ${selectedDevice!.uuid}");
  }

  @override
  Future<void> initSender() async {
    await peripheralManager.clearServices();
    final service = GattService(
      uuid: veniceUuid,
      characteristics: [
        GattCharacteristic(
            uuid: veniceCharUuid,
            properties: [
              GattCharacteristicProperty.read,
            ],
            descriptors: []
        )
      ],
    );

    // Setup answer listeners
    peripheralManager.readCharacteristicCommandReceived.listen((eventArgs) async {
      final central = eventArgs.central;
      final characteristic = eventArgs.characteristic;
      final id = eventArgs.id;
      final offset = eventArgs.offset;

      const status = true;
      final value = Uint8List.fromList([0x01, 0x02, 0x03]);
      await peripheralManager.sendReadCharacteristicReply(
        central,
        characteristic: characteristic,
        id: id,
        offset: offset,
        status: status,
        value: value,
      );
    });

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
