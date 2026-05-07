# BLE bootstrap channel

This repository holds an bootstrap channel implementation that uses [BLE](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy)
as a way to exchange file/channel metadata between two devices; sender exposes data in a BLE service, and
receiver gets them by accessing the service's characteristics.

#### Example app

The `example/` directory contains an example app that lets you play with the BLE channel.
