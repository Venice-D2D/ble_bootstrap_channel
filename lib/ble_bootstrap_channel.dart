library ble_bootstrap_channel;

import 'dart:async';

import 'package:flutter/material.dart';
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

    showDialog(
      context: context,
      builder: (context) {
        List<String> devices = [];

        return StatefulBuilder(
          builder: (context, setState) {
            // simulate devices being discovered
            Timer.periodic(const Duration(seconds: 1), (timer) {
              setState(() {
                devices.add('new device');
              });
            });

            return AlertDialog(
              title: const Text("Looking for devices..."),
              content: Text(devices.length.toString()),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
