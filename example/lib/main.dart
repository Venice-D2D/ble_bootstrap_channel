import 'package:ble_bootstrap_channel/ble_bootstrap_channel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:venice_core/metadata/channel_metadata.dart';
import 'package:venice_core/channels/events/bootstrap_channel_event.dart';
import 'package:venice_core/metadata/file_metadata.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    BleBootstrapChannel channel = BleBootstrapChannel(context);
    FileMetadata data = FileMetadata("testName", 42000, 10);
    ChannelMetadata cData =
        ChannelMetadata("wifi_channel", "address", "apIdentifier", "password");

    channel.on = (BootstrapChannelEvent event, dynamic data) {
      Fluttertoast.showToast(
          msg: "Data received: $data",
          toastLength: Toast.LENGTH_LONG
      );
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('BLE bootstrap example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: () async {
                  await channel.initSender();
                  channel.sendFileMetadata(data);
                },
                child: const Text("Send file metadata")),
            ElevatedButton(
                onPressed: () async {
                  await channel.initSender();
                  channel.sendChannelMetadata(cData);
                },
                child: const Text("Send channel metadata")),
            Container(
              margin: const EdgeInsets.all(20),
              child: const Divider(thickness: 1),
            ),
            ElevatedButton(
                onPressed: () {
                  channel.initReceiver();
                },
                child: const Text("Receive metadata"))
          ],
        ),
      ),
    );
  }
}
