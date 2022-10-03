import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/services.dart';

import './BackgroundCollectedPage.dart';
import './BackgroundCollectingTask.dart';
import './ChatPage.dart';
import './DiscoveryPage.dart';
import './SelectBondedDevicePage.dart';
import './Charts.dart';
import './test.dart';
import './Dialog.dart';

// import './helpers/LineChart.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  TextEditingController _vc = new TextEditingController(text: "");
  String _address = "...";
  String _name = "...";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BackgroundCollectingTask? _collectingTask;

  bool _autoAcceptPairingRequests = false;

  @override
  void initState() {
    super.initState();
    // 确保主屏幕不会倒转
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address!;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name!;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable mode is disabled when Bluetooth gets disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Data Cellector"),
      ),
      body: Container(
        child: ListView(
          children: <Widget>[
            Divider(),

            ListTile(
              title: const Text(
                'General',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            SwitchListTile(
              title: const Text('Enable Bluetooth'),
              value: _bluetoothState.isEnabled,
              onChanged: (bool value) {
                // Do the request and update with the true value then
                future() async {
                  // async lambda seems to not working
                  if (value)
                    await FlutterBluetoothSerial.instance.requestEnable();
                  else
                    await FlutterBluetoothSerial.instance.requestDisable();
                }

                future().then((_) {
                  setState(() {});
                });
              },
            ),

            ListTile(
              title: const Text('Bluetooth status'),
              subtitle: Text(_bluetoothState.toString()),
              trailing: ElevatedButton(
                child: const Text('Settings'),
                onPressed: () {
                  FlutterBluetoothSerial.instance.openSettings();
                },
              ),
            ),

            ListTile(
              title: const Text('Local adapter address'),
              subtitle: Text(_address),
            ),

            ListTile(
              title: const Text('Local adapter name'),
              subtitle: Text(_name),
              onLongPress: null,
            ),

            // ListTile(
            //   title: _discoverableTimeoutSecondsLeft == 0
            //       ? const Text("Discoverable")
            //       : Text(
            //           "Discoverable for ${_discoverableTimeoutSecondsLeft}s"),
            //   subtitle: const Text("PsychoX-Luna"),
            //   trailing: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Checkbox(
            //         value: _discoverableTimeoutSecondsLeft != 0,
            //         onChanged: null,
            //       ),
            //       IconButton(
            //         icon: const Icon(Icons.edit),
            //         onPressed: null,
            //       ),
            //       IconButton(
            //         icon: const Icon(Icons.refresh),
            //         onPressed: () async {
            //           print('Discoverable requested');
            //           final int timeout = (await FlutterBluetoothSerial.instance
            //               .requestDiscoverable(60))!;
            //           if (timeout < 0) {
            //             print('Discoverable mode denied');
            //           } else {
            //             print(
            //                 'Discoverable mode acquired for $timeout seconds');
            //           }
            //           setState(() {
            //             _discoverableTimeoutTimer?.cancel();
            //             _discoverableTimeoutSecondsLeft = timeout;
            //             _discoverableTimeoutTimer =
            //                 Timer.periodic(Duration(seconds: 1), (Timer timer) {
            //               setState(() {
            //                 if (_discoverableTimeoutSecondsLeft < 0) {
            //                   FlutterBluetoothSerial.instance.isDiscoverable
            //                       .then((isDiscoverable) {
            //                     if (isDiscoverable ?? false) {
            //                       print(
            //                           "Discoverable after timeout... might be infinity timeout :F");
            //                       _discoverableTimeoutSecondsLeft += 1;
            //                     }
            //                   });
            //                   timer.cancel();
            //                   _discoverableTimeoutSecondsLeft = 0;
            //                 } else {
            //                   _discoverableTimeoutSecondsLeft -= 1;
            //                 }
            //               });
            //             });
            //           });
            //         },
            //       )
            //     ],
            //   ),
            // ),

            Divider(),

            const ListTile(
              title: const Text(
                'Connections',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            SwitchListTile(
              title: const Text('Auto-try specific pin when pairing'),
              subtitle: const Text('Pin 1234'),
              value: _autoAcceptPairingRequests,
              onChanged: (bool value) {
                setState(() {
                  _autoAcceptPairingRequests = value;
                });
                if (value) {
                  FlutterBluetoothSerial.instance.setPairingRequestHandler(
                      (BluetoothPairingRequest request) {
                    print("Trying to auto-pair with Pin 1234");
                    if (request.pairingVariant == PairingVariant.Pin) {
                      return Future.value("1234");
                    }
                    return Future.value(null);
                  });
                } else {
                  FlutterBluetoothSerial.instance
                      .setPairingRequestHandler(null);
                }
              },
            ),

            ListTile(
              title: ElevatedButton(
                  child: const Text('Explore discovered devices'),
                  onPressed: () async {
                    final BluetoothDevice? selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return DiscoveryPage();
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      print('Discovery -> selected ' + selectedDevice.address);
                    } else {
                      print('Discovery -> no device selected');
                    }
                  }),
            ),

            ListTile(
              title: ElevatedButton(
                child: const Text('Connect to collect data through Bluetooth'),
                onPressed: () async {
                  final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: false);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    print('Connect -> selected ' + selectedDevice.address);
                    _startCollect(context, selectedDevice);
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),

            // ListTile(
            //   title: ElevatedButton(
            //       child: const Text('Show collected data in Table'),
            //       onPressed: () {
            //         Navigator.of(context).push(
            //           MaterialPageRoute(
            //             builder: (context) {
            //               return TableLayout();
            //             },
            //           ),
            //         );
            //       }),
            // ),

            // ListTile(
            //   title: ElevatedButton(
            //       child: const Text('Dialog'),
            //       onPressed: () {
            //         showDialog(
            //             barrierDismissible: false,
            //             context: context,
            //             builder: (context) {
            //               return RenameDialog(
            //                 contentWidget: RenameDialogContent(
            //                   title: "请输入新的家庭名称",
            //                   okBtnTap: () {
            //                     print(
            //                       "输入框中的文字为:${_vc.text}",
            //                     );
            //                   },
            //                   vc: _vc,
            //                   cancelBtnTap: () {},
            //                 ),
            //               );
            //             });
            //       }),
            // ),

            Center(
              child: Text(
                "©Ren's Group,",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Times New Roman'),
              ),
            ),
            Center(
              child: Text(
                "School of Integrated Circuits,",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Times New Roman'),
              ),
            ),
            Center(
              child: Text(
                "Tsinghua University",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Times New Roman'),
              ),
            ),

            // ListTile(
            //   title: ElevatedButton(
            //     child: ((_collectingTask?.inProgress ?? false)
            //         ? const Text('Disconnect and stop background collecting')
            //         : const Text('Connect to start background collecting')),
            //     onPressed: () async {
            //       if (_collectingTask?.inProgress ?? false) {
            //         await _collectingTask!.cancel();
            //         setState(() {
            //           /* Update for `_collectingTask.inProgress` */
            //         });
            //       } else {
            //         final BluetoothDevice? selectedDevice =
            //             await Navigator.of(context).push(
            //           MaterialPageRoute(
            //             builder: (context) {
            //               return SelectBondedDevicePage(
            //                   checkAvailability: false);
            //             },
            //           ),
            //         );

            //         if (selectedDevice != null) {
            //           await _startBackgroundTask(context, selectedDevice);
            //           setState(() {
            //             /* Update for `_collectingTask.inProgress` */
            //           });
            //         }
            //       }
            //     },
            //   ),
            // ),

            // ListTile(
            //   title: ElevatedButton(
            //     child: const Text('View background collected data'),
            //     onPressed: (_collectingTask != null)
            //         ? () {
            //             Navigator.of(context).push(
            //               MaterialPageRoute(
            //                 builder: (context) {
            //                   return ScopedModel<BackgroundCollectingTask>(
            //                     model: _collectingTask!,
            //                     // child: BackgroundCollectedPage(),
            //                     child: DataCollectionPage(server:selectedDevice),
            //                   );
            //                 },
            //               ),
            //             );
            //           }
            //         : null,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  void _startCollect(BuildContext context, BluetoothDevice server) {
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return DataCollectionPage(server: server);
        },
      ),
    );
  }

  // Future<void> _startBackgroundTask(
  //   BuildContext context,
  //   BluetoothDevice server,
  // ) async {
  //   try {
  //     _collectingTask = await BackgroundCollectingTask.connect(server);
  //     await _collectingTask!.start();
  //   } catch (ex) {
  //     _collectingTask?.cancel();
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: const Text('Error occured while connecting'),
  //           content: Text("${ex.toString()}"),
  //           actions: <Widget>[
  //             new TextButton(
  //               child: new Text("Close"),
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //               },
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //   }
  // }

  void showDialogFunction() async {
    bool? isSelect = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("温馨提示"),
          //title 的内边距，默认 left: 24.0,top: 24.0, right 24.0
          //默认底部边距 如果 content 不为null 则底部内边距为0
          //            如果 content 为 null 则底部内边距为20
          titlePadding: EdgeInsets.all(10),
          //标题文本样式
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 16),
          //中间显示的内容
          content: Text("您确定要删除吗?"),
          //中间显示的内容边距
          //默认 EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0)
          contentPadding: EdgeInsets.all(10),
          //中间显示内容的文本样式
          contentTextStyle: TextStyle(color: Colors.black54, fontSize: 14),
          //底部按钮区域
          actions: <Widget>[
            TextButton(
              child: Text("再考虑一下"),
              onPressed: () {
                //关闭 返回 false
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: Text("考虑好了"),
              onPressed: () {
                //关闭 返回true
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    // print("弹框关闭 $isSelect");
  }
}
