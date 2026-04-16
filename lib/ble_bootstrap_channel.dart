// ignore_for_file: use_build_context_synchronously

library ble_bootstrap_channel;

import 'dart:async';
import 'dart:convert';
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
  final Uint8List channelNullValue = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

  // Sender values
  late Uint8List fileValue;
  late Uint8List channelValue;
  bool isSetUp = false;
  bool discoveryStarted = false;
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
    //await centralManager.setUp(); removed in 6.x

    while (centralManager.state != BluetoothLowEnergyState.poweredOn) {
      debugPrint("[BleBootstrapChannel::initReceiver] Waiting for Bluetooth to be ready...");
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint("[BleBootstrapChannel::initReceiver] Waiting for Bluetooth to be ready 2...");
    }

    showDialog(
      context: context,
      builder: (context) {
        Set<UUID> seen = {};
        Map<DiscoveredEventArgs, ConnectionData> compatibles = {};

        return StatefulBuilder(
          builder: (context, setState) {
            centralManager.discovered.listen((event) async {
              UUID foundDeviceUuid = event.peripheral.uuid;
              if (seen.contains(foundDeviceUuid)) {
                return;
              }

              // Do not visit same devices twice
              seen.add(foundDeviceUuid);


              if(!event.advertisement.serviceUUIDs.contains(veniceUuid)){
                debugPrint("[BleBootstrapChannel::initReceiver] ==> NOT A VENICE DEVICE -- Looking for ${veniceUuid.toString()}");
                return;
              }

              debugPrint("[BleBootstrapChannel::initReceiver] ==> VENICE DEVICE FOUND");


              // Connect to distant device
              try {
                //event.peripheral.addServicesUUID(veniceUuid);
                await centralManager.connect(event.peripheral);
              } catch(e){
                debugPrint("[BleBootstrapChannel::initReceiver] Error connecting to device: $e");
              }
              debugPrint("[BleBootstrapChannel::initReceiver] ==> CONNECTED TO VENICE DEVICE");

              // Retrieve venice service
              List<GATTService> services = await centralManager.discoverGATT(event.peripheral);
              debugPrint("[BleBootstrapChannel::initReceiver]==> Services retrieved !");
              debugPrint("[BleBootstrapChannel::initReceiver] Looking for venice Service ${veniceUuid.toString()}");
              List<GATTService> matchingServices = services.where((element) => element.uuid == veniceUuid).toList();
              if (matchingServices.isEmpty) {
                debugPrint("[BleBootstrapChannel::initReceiver] ==> VENICE SERVICE NOT FOUND");
                return;
              }
              debugPrint("[BleBootstrapChannel::initReceiver] ==> FOUND VENICE SERVICE");
              await centralManager.stopDiscovery();

              // Retrieve file data
              GATTCharacteristic distantFileCharacteristic =
                matchingServices.first.characteristics
                    .firstWhere((element) => element.uuid == veniceFileCharacteristicUuid,
                orElse: () => throw RangeError("File characteristic not found."));
              Uint8List fValue = fileNullValue;
              while (fValue.toString() == fileNullValue.toString() || fValue.isEmpty) {
                debugPrint("[BleBootstrapChannel::initReceiver] ==> FETCHING FILE VALUE");
                fValue = await centralManager.readCharacteristic(event.peripheral, distantFileCharacteristic);
                await Future.delayed(const Duration(seconds: 1));
              }
              debugPrint("[BleBootstrapChannel::initReceiver] ==> FILE CHARACTERISTIC OK");
              debugPrint("[BleBootstrapChannel::initReceiver] ==> RECEIVED: ${utf8.decode(fValue)}");
              List<String> words = utf8.decode(fValue).split(';');
              debugPrint("[BleBootstrapChannel::initReceiver] ==> RECEIVED size: ${words.length.toString()}");
              debugPrint("[BleBootstrapChannel::initReceiver] ==> RECEIVED List content: ${words.join(" ")}");
              debugPrint("[BleBootstrapChannel::initReceiver] ==> RECEIVED List first: ${words[0]}");
              FileMetadata fileMetadata = FileMetadata(words[0].trim(), int.parse(words[1].trim()), int.parse(words[2].trim()));

              // Retrieve channel data
              GATTCharacteristic distantChannelCharacteristic =
                matchingServices.first.characteristics
                    .firstWhere((element) => element.uuid == veniceChannelCharacteristicUuid,
                    orElse: () => throw RangeError("Channel characteristic not found."));
              Uint8List cValue = channelNullValue;
              do {
                debugPrint("[BleBootstrapChannel::initReceiver] ==> FETCHING CHANNEL VALUE");
                cValue = await centralManager.readCharacteristic(event.peripheral, distantChannelCharacteristic);
                await Future.delayed(const Duration(seconds: 1));
              } while (cValue.toString() == channelNullValue.toString() || cValue.isEmpty);
              debugPrint("[BleBootstrapChannel::initReceiver] ==> CHANNEL CHARACTERISTIC OK");
              debugPrint("[BleBootstrapChannel::initReceiver] ==> RECEIVED: ${utf8.decode(cValue)}");
              words = utf8.decode(cValue).split(";");
              ChannelMetadata channelMetadata = ChannelMetadata(words[0].trim(), words[1].trim(), words[2].trim(), words[3].trim(), int.parse(words[4].trim())); //TODO [0] CONTAINS THE DATACHANNEL TYPE TO PICK THE CORRECT ONE ???

              setState(() {
                compatibles.putIfAbsent(event, () => ConnectionData(
                    fileData: fileMetadata,
                    channelData: channelMetadata));
              });
            });

            // Start devices discovery
            if(!discoveryStarted) {
              debugPrint(
                  "[BleBootstrapChannel::initReceiver] Starting discovery...");
              centralManager.startDiscovery(serviceUUIDs: [veniceUuid]);
              discoveryStarted = true;
            }

            return AlertDialog(
              title: const Text("Looking for devices..."),
              content: compatibles.isEmpty ? const Text("Searching...") : Column(
                mainAxisSize: MainAxisSize.min,
                children: compatibles.entries.map((e) => ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(e.key.advertisement.name!),
                  subtitle: Text(e.key.peripheral.uuid.toString()),
                  onTap: () {
                    connectionData = e.value;
                    distantDevice = e.key.peripheral;
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

    while (connectionData == null) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint("[BleBootstrapChannel::initReceiver] Waiting for device selection...");
    }

    on(BootstrapChannelEvent.fileMetadata, connectionData!.fileData);
    on(BootstrapChannelEvent.channelMetadata, connectionData!.channelData);
    debugPrint("[BleBootstrapChannel::initReceiver] ==> ALL DONE!");
  }

  @override
  Future<void> initSender(FileMetadata fileData, ChannelMetadata channelData) async {
    if (isSetUp) {
      return;
    }
    isSetUp = true;

    while (peripheralManager.state != BluetoothLowEnergyState.poweredOn) {
      debugPrint("[BleBootstrapChannel::initSender] Waiting for Bluetooth to be ready...");
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint("[BleBootstrapChannel::initSender] Waiting for Bluetooth to be ready 2...");
    }

    debugPrint("[BleBootstrapChannel::initSender] Bluetooth ready ...");
    await peripheralManager.removeAllServices(); //clearServices(); TODO not required ?

    debugPrint("[BleBootstrapChannel::initSender] Services removed ...");

    // Initialize both values
    fileValue = Uint8List.fromList(fileData.toString().codeUnits);
    channelValue = Uint8List.fromList(channelData.toString().codeUnits);

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
      characteristics: [
        channelCharacteristic,
        fileCharacteristic
      ],
      includedServices: [],
      isPrimary: true, //TODO To check it is ok
    );

    // Setup answer listeners
    characteristicReadSubscription = peripheralManager.characteristicReadRequested.listen((eventArgs) async {
      final central = eventArgs.central;
      final request = eventArgs.request;
      final characteristic = eventArgs.characteristic;

      // Throw if requested characteristic is not a Venice one
      if (![veniceChannelCharacteristicUuid, veniceFileCharacteristicUuid].contains(characteristic.uuid)) {
        throw ArgumentError("Tried to read a non-Venice characteristic.");
      }

      Uint8List value;
      if (characteristic.uuid == veniceChannelCharacteristicUuid) {
        value = channelValue;
        debugPrint("[BleBootstrapChannel::initSender] veniceChannelCharacteristicUuid selected !");
      } else if (characteristic.uuid == veniceFileCharacteristicUuid) {
        debugPrint("[BleBootstrapChannel::initSender] veniceFileCharacteristicUuid selected !");
        value = fileValue;
      } else {
        throw UnimplementedError();
      }

      debugPrint("[BleBootstrapChannel::initSender] Sending characteristic info");
      await peripheralManager.respondReadRequestWithValue(request, value: value);
    });

    debugPrint("[BleBootstrapChannel::initSender] Adding service ...");

    await peripheralManager.addService(service);
    final advertisement = Advertisement(
      name: 'venice',
      serviceUUIDs: [service.uuid],
    );
    debugPrint("[BleBootstrapChannel::initSender] Starting advertisement ...");

    peripheralManager.startAdvertising(advertisement);
    debugPrint("[BleBootstrapChannel::initSender] Advertisement done...");
  }

  @override
  Future<void> sendChannelMetadata(ChannelMetadata data) async {
    channelValue = Uint8List.fromList(data.toString().codeUnits);
  }

  @override
  Future<void> sendFileMetadata(FileMetadata data) async {
    fileValue = Uint8List.fromList(data.toString().codeUnits);
  }
}
