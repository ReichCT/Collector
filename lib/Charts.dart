import 'dart:math';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/services.dart';

class LinearSales {
  final double time;
  final double data;

  LinearSales(this.time, this.data);
}

class _Message {
  String time_stamp;
  String data;

  _Message(this.time_stamp, this.data);
}

class DataCollectionPage extends StatefulWidget {
  // const DataCollectionPage({Key? key}) : super(key: key);
  final BluetoothDevice server;

  const DataCollectionPage({required this.server});
  @override
  
  State<DataCollectionPage> createState() => _DataCollectionPage();
}

class _DataCollectionPage extends State<DataCollectionPage> {

  // Global Varibles
  double Points = 1;
  _Message message = _Message('...','...');
  var data = [
    LinearSales(0, 0),
  ];

  BluetoothConnection? connection;
  String _messageBuffer = '';
  final TextEditingController textEditingController =
      new TextEditingController();
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;


  // Initialization, make sure this page will turn horizontal.
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

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight, //全屏时旋转方向，左边
    ]);

    
  }

  
  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }
    // When get out of this page, turn back to vertical
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  // Main body
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Collected Data")),

        body: ListView(
          children: <Widget>[
            Divider(),

            ListTile(
              leading: const Icon(Icons.brightness_7),
              title: const Text('Temperatures'),
              subtitle: const Text('In Celsius'),
            ),
            
            // A container to place LineChart
            Container(
              height: 150,
              child: LineChart(),
            ),

            // To be replaced
            // ElevatedButton(
            //     onPressed: () {
            //       setState(() {
            //         Points += 1;
            //         print(Points);
            //         // _simpleLine();
            //       });
            //     },
            //     child: Text('add point')),
            Center(child: Text("©Ren's Group,",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18,fontFamily: 'Times New Roman'),),),
            Center(child: Text("School of Integrated Circuits, Tsinghua University",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15,fontFamily: 'Times New Roman'),),),
            // Center(child: Text("",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15),),),
          ],
        ),
        
      );
  }

  // Draw the LineChart
  Widget LineChart() {
    var random = Random();

    Points>1?data.add(LinearSales(Points, random.nextDouble())):null;
    // print(data);

    var seriesList = [
      charts.Series<LinearSales, double>(
        id: 'Sales',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.time,
        measureFn: (LinearSales sales, _) => sales.data,
        data: data,
      )
    ];

    return charts.LineChart(
      seriesList,
      animate: false,
      defaultRenderer: charts.LineRendererConfig(
        radiusPx: 2.0,// 圆点大小
        stacked: false,
        strokeWidthPx: 2.0,// 线的宽度
        includeLine: true,// 是否显示线
        includePoints: true,// 是否显示圆点
        includeArea: true,// 是否显示包含区域
        areaOpacity: 0.2,// 区域颜色透明度 0.0-1.0
      ),
      behaviors: [
        charts.SlidingViewport(),
        charts.PanAndZoomBehavior(),
        charts.ChartTitle('Time(s)',
            behaviorPosition: charts.BehaviorPosition.bottom,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        charts.ChartTitle('Temp.(℃)',
            behaviorPosition: charts.BehaviorPosition.start,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
      ],
      //配置初始状态展示个数
      domainAxis: const charts.NumericAxisSpec(
          viewport: charts.NumericExtents(0, 50)),
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

}


