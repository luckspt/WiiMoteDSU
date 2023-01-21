import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:wiimote_dsu/devices/device.dart';
import 'package:wiimote_dsu/server/acc_event.dart';
import 'package:wiimote_dsu/server/button_press.dart';
import 'package:wiimote_dsu/server/dsu_server.dart';
import 'package:wiimote_dsu/server/gyro_event.dart';

class ServerIsolate {
  static Future<SendPort> init() async {
    final server = DSUServer.make();

    Completer completer = Completer<SendPort>();
    final isolateToMainStream = ReceivePort();

    isolateToMainStream.listen((data) {
      if (data is SendPort) {
        final mainToIsolateStream = data;
        completer.complete(mainToIsolateStream);
      } else {
        print('[isolateToMainStream] $data');
      }
    });

    await Isolate.spawn(_serverIsolate, [isolateToMainStream.sendPort, server]);
    return completer.future;
  }

  static void _serverIsolate(List<dynamic> args) {
    SendPort isolateToMainStream = args[0];
    DSUServer server = args[1];

    server.init();

    final mainToIsolateStream = ReceivePort();
    isolateToMainStream.send(mainToIsolateStream.sendPort);

    mainToIsolateStream.listen((data) {
      if (data is Device) {
        server.registerDevice(0, data);
      } else if (data is GyroEvent) {
        server.slots[0].setGyro(data);
      } else if (data is AccEvent) {
        server.slots[0].setAcc(data);
      } else if (data is ButtonPress) {
        server.slots[0].setState(data.btnType, data.value);
        debugPrint(
            '[mainToIsolateStream] pressed ${data.btnType}, value: ${data.value}');
      } else {
        print('[mainToIsolateStream] $data');
      }
    });
  }
}
