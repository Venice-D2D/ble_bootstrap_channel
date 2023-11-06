library ble_bootstrap_channel;

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
  Future<void> initReceiver() {
    // TODO: implement initReceiver
    throw UnimplementedError();
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
