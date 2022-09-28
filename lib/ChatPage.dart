import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  String time_stamp;
  String data;

  _Message(this.time_stamp, this.data);
}

class _ChatPage extends State<ChatPage> {
  double Points = 1;
  _Message message = _Message('1','sss');
  var data = [
    LinearSales(0, 0),
  ];

  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();    

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      // connection!.input!.listen((data) {
      //   print('Data incoming: ${ascii.decode(data)}');

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final List<Row> list = messages.map((_message) {
    //   return Row(
    //     children: <Widget>[
    //       Container(
    //         child: Text(
    //             (text) {
    //               // print(_message.text.trim());
    //               return text == '/shrug' ? '¯\\_(ツ)_/¯' : text;
    //             }(_message.text.trim()),
    //             style: TextStyle(color: Colors.white)),
    //         padding: EdgeInsets.all(12.0),
    //         margin: EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
    //         width: 222.0,
    //         decoration: BoxDecoration(
    //             color:
    //                 _message.whom == clientID ? Colors.blueAccent : Colors.grey,
    //             borderRadius: BorderRadius.circular(7.0)),
    //       ),
    //     ],
    //     mainAxisAlignment: _message.whom == clientID
    //         ? MainAxisAlignment.end
    //         : MainAxisAlignment.start,
    //   );
    // }).toList();

    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting chat to ' + serverName + '...')
              : isConnected
                  ? Text('Live chat with ' + serverName)
                  : Text('Chat log with ' + serverName))),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Divider(),
            ListTile(
              leading: const Icon(Icons.brightness_7),
              title: const Text('Temperatures'),
              subtitle: const Text('In Celsius'),
            ),

            Container(
              
              height: 150,
              child: _simpleLine(),
            ),

            // Flexible(
            //   child: ListView(
            //       padding: const EdgeInsets.all(12.0),
            //       controller: listScrollController,
            //       children: list),
            // ),

            // Row(
            //   children: <Widget>[
            //     Flexible(
            //       child: Container(
            //         margin: const EdgeInsets.only(left: 16.0),
            //         child: TextField(
            //           style: const TextStyle(fontSize: 15.0),
            //           controller: textEditingController,
            //           decoration: InputDecoration.collapsed(
            //             hintText: isConnecting
            //                 ? 'Wait until connected...'
            //                 : isConnected
            //                     ? 'Type your message...'
            //                     : 'Chat got disconnected',
            //             hintStyle: const TextStyle(color: Colors.grey),
            //           ),
            //           enabled: isConnected,
            //         ),
            //       ),
            //     ),
            //     Container(
            //       margin: const EdgeInsets.all(8.0),
            //       child: IconButton(
            //           icon: const Icon(Icons.send),
            //           onPressed: isConnected
            //               ? () => _sendMessage(textEditingController.text)
            //               : null),
            //     ),
            //   ],
            // )
          ],
        ),
      ),
    );
  }

    Widget _simpleLine() {
    var random = Random();
    // print(messages.length);
    Points>1 ? data.add(LinearSales(Points, double.parse(message.data))) : null;
    // data.add(LinearSales(Points, random.nextInt(100)));
    // print(data);

    var seriesList = [
      charts.Series<LinearSales, double>(
        id: 'Sales',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.year,
        measureFn: (LinearSales sales, _) => sales.sales,
        data: data,
      )
    ];

    return charts.LineChart(
      seriesList,
      animate: false,
      defaultRenderer: charts.LineRendererConfig(
        // 圆点大小
        radiusPx: 2.0,
        stacked: false,
        // 线的宽度
        strokeWidthPx: 2.0,
        // 是否显示线
        includeLine: true,
        // 是否显示圆点
        includePoints: true,
        // 是否显示包含区域
        includeArea: true,
        // 区域颜色透明度 0.0-1.0
        areaOpacity: 0.2,
      ),
      behaviors: [
        new charts.SlidingViewport(),
        new charts.PanAndZoomBehavior(),
        new charts.ChartTitle('Time(s)',
            behaviorPosition: charts.BehaviorPosition.bottom,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        new charts.ChartTitle('Temp.(℃)',
            behaviorPosition: charts.BehaviorPosition.start,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
      ],
      //配置初始状态展示个数
      domainAxis: new charts.NumericAxisSpec(
          viewport: new charts.NumericExtents(0, 100)),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        // messages.add(
        //   _Message(
        //     1,
        //     backspacesCounter > 0
        //         ? _messageBuffer.substring(
        //             0, _messageBuffer.length - backspacesCounter)
        //         : _messageBuffer + dataString.substring(0, index),
        //   ),
        // );
        Points += 1;
        message = 
          _Message(
              '1',
              backspacesCounter > 0
                  ? _messageBuffer.substring(
                      0, _messageBuffer.length - backspacesCounter)
                  : _messageBuffer + dataString.substring(0, index),
            );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  // void _sendMessage(String text) async {
  //   text = text.trim();
  //   textEditingController.clear();

  //   if (text.length > 0) {
  //     try {
  //       connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
  //       await connection!.output.allSent;

  //       setState(() {
  //         messages.add(_Message(clientID, text));
  //       });

  //       Future.delayed(Duration(milliseconds: 333)).then((_) {
  //         listScrollController.animateTo(
  //             listScrollController.position.maxScrollExtent,
  //             duration: Duration(milliseconds: 333),
  //             curve: Curves.easeOut);
  //       });
  //     } catch (e) {
  //       // Ignore error, but notify state
  //       setState(() {});
  //     }
  //   }
  // }
}

class LinearSales {
  final double year;
  final double sales;

  LinearSales(this.year, this.sales);
}