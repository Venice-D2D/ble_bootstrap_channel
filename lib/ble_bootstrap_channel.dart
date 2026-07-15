// ignore_for_file: use_build_context_synchronously

library ble_bootstrap_channel;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:venice_core/channels/abstractions/bootstrap_channel.dart';
import 'package:venice_core/metadata/file_metadata.dart';
import 'package:venice_core/channels/events/bootstrap_channel_event.dart';
import 'package:venice_core/metadata/channel_metadata.dart';

class ConnectionData {
  final FileMetadata fileData;
  final ChannelMetadata channelData;
  ConnectionData({required this.fileData, required this.channelData});
}

class BleBootstrapChannel extends BootstrapChannel {
  final BuildContext context;
  final UUID veniceUuid = UUID.short(6157);
  final UUID veniceFileCharacteristicUuid = UUID.short(10793);
  final UUID veniceChannelCharacteristicUuid = UUID.short(10896);
  CentralManager get centralManager => CentralManager();
  PeripheralManager get peripheralManager => PeripheralManager();
  BleBootstrapChannel(this.context);

  // Service characteristics
  late GATTCharacteristic fileCharacteristic;
  late GATTCharacteristic channelCharacteristic;

  // Reference values
  final Uint8List fileNullValue = Uint8List.fromList([0x09, 0x08, 0x07, 0x06]);
  final Uint8List channelNullValue = Uint8List.fromList([
    0x00,
    0x01,
    0x02,
    0x03,
  ]);

  // Sender values
  late Uint8List fileValue;
  late Uint8List channelValue;
  bool isSetUp = false;
  StreamSubscription? characteristicReadSubscription;

  // Receiver values
  Peripheral? distantDevice;

  @override
  Future<void> close() async {
    // receiver
    if (distantDevice != null) {
      centralManager.disconnect(distantDevice!);
      centralManager.stopDiscovery();
    }

    // sender
    if (characteristicReadSubscription != null) {
      characteristicReadSubscription!.cancel();
      peripheralManager.stopAdvertising();
    }
  }

  @override
  Future<void> initReceiver() async {
    ConnectionData? connectionData;

    while (centralManager.state != BluetoothLowEnergyState.poweredOn) {
      debugPrint("Waiting for Bluetooth to be ready...");
      await Future.delayed(const Duration(milliseconds: 500));
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<String> seen = {};
        Map<DiscoveredEventArgs, ConnectionData> compatibles = {};

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

              // Connect to distant device
              await centralManager.connect(event.peripheral);
              debugPrint("==> CONNECTED TO VENICE DEVICE");

              // Retrieve venice service
              List<GATTService> services = await centralManager.discoverGATT(
                event.peripheral,
              );
              List<GATTService> matchingServices = services
                  .where((element) => element.uuid == veniceUuid)
                  .toList();
              if (matchingServices.isEmpty) {
                debugPrint("==> VENICE SERVICE NOT FOUND");
                return;
              }
              debugPrint("==> FOUND VENICE SERVICE");
              await centralManager.stopDiscovery();

              // Retrieve file data
              GATTCharacteristic distantFileCharacteristic = matchingServices
                  .first
                  .characteristics
                  .firstWhere(
                    (element) => element.uuid == veniceFileCharacteristicUuid,
                    orElse: () =>
                        throw RangeError("File characteristic not found."),
                  );
              Uint8List fValue = fileNullValue;
              while (fValue.toString() == fileNullValue.toString() ||
                  fValue.isEmpty) {
                debugPrint("==> FETCHING FILE VALUE");
                fValue = await centralManager.readCharacteristic(
                  event.peripheral,
                  distantFileCharacteristic,
                );
                await Future.delayed(const Duration(seconds: 1));
              }
              debugPrint("==> FILE CHARACTERISTIC OK");
              debugPrint("==> RECEIVED: ${utf8.decode(fValue)}");
              List<String> words = utf8.decode(fValue).split(';');
              FileMetadata fileMetadata = FileMetadata(
                words[0],
                int.parse(words[1]),
                int.parse(words[2]),
              );

              // Retrieve channel data
              GATTCharacteristic distantChannelCharacteristic = matchingServices
                  .first
                  .characteristics
                  .firstWhere(
                    (element) =>
                        element.uuid == veniceChannelCharacteristicUuid,
                    orElse: () =>
                        throw RangeError("Channel characteristic not found."),
                  );
              Uint8List cValue = channelNullValue;
              do {
                debugPrint("==> FETCHING CHANNEL VALUE");
                cValue = await centralManager.readCharacteristic(
                  event.peripheral,
                  distantChannelCharacteristic,
                );
                await Future.delayed(const Duration(seconds: 1));
              } while (cValue.toString() == channelNullValue.toString() ||
                  cValue.isEmpty);
              debugPrint("==> CHANNEL CHARACTERISTIC OK");
              debugPrint("==> RECEIVED: ${utf8.decode(cValue)}");
              words = utf8.decode(cValue).split(";");
              ChannelMetadata channelMetadata = ChannelMetadata(
                words[0].trim(),
                words[1].trim(),
                words[2].trim(),
                words[3].trim(),
                int.parse(words[4].trim()),
              );

              setState(() {
                compatibles.putIfAbsent(
                  event,
                  () => ConnectionData(
                    fileData: fileMetadata,
                    channelData: channelMetadata,
                  ),
                );
              });
            });

            // Start devices discovery
            centralManager.startDiscovery(serviceUUIDs: [veniceUuid]);

            return AlertDialog(
              title: const Text("Looking for devices..."),
              content: compatibles.isEmpty
                  ? const Text("Searching...")
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: compatibles.entries
                          .map(
                            (e) => ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(e.key.advertisement.name!),
                              subtitle: Text(e.key.peripheral.uuid.toString()),
                              onTap: () {
                                connectionData = e.value;
                                distantDevice = e.key.peripheral;
                                Navigator.pop(context);
                              },
                            ),
                          )
                          .toList(),
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

    while (connectionData == null) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("Waiting for device selection...");
    }

    on(BootstrapChannelEvent.fileMetadata, connectionData!.fileData);
    on(BootstrapChannelEvent.channelMetadata, connectionData!.channelData);
    debugPrint("==> ALL DONE!");
  }

  @override
  Future<void> initSender(
    FileMetadata fileData,
    ChannelMetadata channelData,
  ) async {
    if (isSetUp) {
      return;
    }
    isSetUp = true;

    if (Platform.isAndroid &&
        peripheralManager.state != BluetoothLowEnergyState.poweredOn) {
      await peripheralManager.authorize();
    }
    debugPrint(peripheralManager.state.toString());

    // Initialize both values to null values
    fileValue = fileNullValue;
    channelValue = channelNullValue;

    // Initialize service characteristics
    fileCharacteristic = GATTCharacteristic.immutable(
      uuid: veniceFileCharacteristicUuid,
      descriptors: [],
      value: fileValue,
    );
    channelCharacteristic = GATTCharacteristic.immutable(
      uuid: veniceChannelCharacteristicUuid,
      descriptors: [],
      value: channelValue,
    );

    final service = GATTService(
      uuid: veniceUuid,
      characteristics: [channelCharacteristic, fileCharacteristic],
      includedServices: [],
      isPrimary: true,
    );

    // Setup answer listeners
    characteristicReadSubscription = peripheralManager
        .characteristicReadRequested
        .listen((eventArgs) async {
          final request = eventArgs.request;
          final characteristic = eventArgs.characteristic;

          // Throw if requested characteristic is not a Venice one
          if (![
            veniceChannelCharacteristicUuid,
            veniceFileCharacteristicUuid,
          ].contains(characteristic.uuid)) {
            throw ArgumentError("Tried to read a non-Venice characteristic.");
          }

          Uint8List value;
          if (characteristic.uuid == veniceChannelCharacteristicUuid) {
            value = channelValue;
          } else if (characteristic.uuid == veniceFileCharacteristicUuid) {
            value = fileValue;
          } else {
            throw UnimplementedError();
          }

          await peripheralManager.respondReadRequestWithValue(
            request,
            value: value,
          );
        });

    await peripheralManager.addService(service);
    final advertisement = Advertisement(
      name: 'venice',
      serviceUUIDs: [service.uuid],
    );
    await peripheralManager.startAdvertising(advertisement);
  }

  @override
  Future<void> sendChannelMetadata(ChannelMetadata data) async {
    channelValue = utf8.encode(data.toString());
  }

  @override
  Future<void> sendFileMetadata(FileMetadata data) async {
    fileValue = utf8.encode(data.toString());
  }
}
