import 'dart:math';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async' show Future;
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'test.dart';
import './Dialog.dart';

class Data {
  double time;
  double data;
  Data(this.time, this.data);
}

class DataCollectionPage extends StatefulWidget {
  final BluetoothDevice server;

  const DataCollectionPage({required this.server});
  @override
  State<DataCollectionPage> createState() => _DataCollectionPage();
}

class _DataCollectionPage extends State<DataCollectionPage> {
  int DataReceivedFlag = 0; //用于标记是否为第一个数据点
  double t_start = 0; //用于记录第一个数据的时间，并以此为时间基点
  var _dataStream = [Data(0, 0)];

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  TextEditingController textEditingController = TextEditingController(text: "");

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

    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.landscapeRight, //全屏时旋转方向，左边
    // ]);
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
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    // ]);
    // save data to csv
    // createCSVFile('AutoSaved');
    super.dispose();
  }

  // Main body
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(title: Text("Collected Data")),
        body: ListView(
          children: <Widget>[
            Divider(),

            ListTile(
              leading: const Icon(Icons.mode_edit),
              title: TextField(
                style: const TextStyle(color: Colors.black87),
                controller: textEditingController,
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              subtitle: const Text("Input saving filename here"),
              trailing: ElevatedButton(
                child: const Text('save'),
                onPressed: () {
                  createCSVFile(textEditingController.text);
                  _FileSavedDialog();
                },
              ),
            ),

            // A container to place LineChart
            Container(
              height: 150,
              child: DataReceivedFlag == 1
                  ? LineChart(_dataStream)
                  : Center(
                      child: Text(
                        "Not connected yet",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                            fontFamily: 'Times New Roman'),
                      ),
                    ),
            ),
            // Container(
            //   height: 150,
            //   child: DataReceivedFlag == 1
            //       ? LineChart(_dataStream)
            //       : Center(
            //           child: Text(
            //             "Not connected yet",
            //             style: TextStyle(
            //                 fontWeight: FontWeight.bold,
            //                 fontSize: 25,
            //                 fontFamily: 'Times New Roman'),
            //           ),
            //         ),
            // ),

            
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Center(
                  child: Text(
                    "©Ren's Group,",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Times New Roman'),
                  ),
                ),
                const Center(
                  child: Text(
                    "School of Integrated Circuits, Tsinghua University",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Times New Roman'),
                  ),
                ),
              ],
            ),
            // Center(child: Text("",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 15),),),
          ],
        ),
      ),
      onWillPop: () async => await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
              'Are you sure you want to quit this page?\n Your data will be auto-saved with name "AutoSaved.csv".'),
          actions: <Widget>[
            TextButton(
              child: const Text('Not now'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
                child: const Text('Yes'),
                onPressed: () {
                  Navigator.pop(context, true);
                  createCSVFile('AutoSaved');
                  // dispose();
                }),
          ],
        ),
      ),
    );
  }

  // Draw the LineChart
  Widget LineChart(DATALIST) {
    var seriesList = [
      charts.Series<Data, double>(
        id: 'Sales',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (Data sales, _) => sales.time,
        measureFn: (Data sales, _) => sales.data,
        data: DATALIST,
      )
    ];

    return charts.LineChart(
      seriesList,
      animate: false,
      defaultRenderer: charts.LineRendererConfig(
        radiusPx: 2.0, // 圆点大小
        stacked: false,
        strokeWidthPx: 2.0, // 线的宽度
        includeLine: true, // 是否显示线
        includePoints: true, // 是否显示圆点
        includeArea: true, // 是否显示包含区域
        areaOpacity: 0.2, // 区域颜色透明度 0.0-1.0
      ),
      behaviors: [
        charts.SlidingViewport(),
        // charts.SelectionModel(),
        // charts.PanAndZoomBehavior(),
        charts.ChartTitle('Time(s)',
            behaviorPosition: charts.BehaviorPosition.bottom,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        charts.ChartTitle('Data',
            behaviorPosition: charts.BehaviorPosition.start,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        // charts.ChartTitle('Sensor Data',
        //     behaviorPosition: charts.BehaviorPosition.top,
        //     titleOutsideJustification:
        //         charts.OutsideJustification.middleDrawArea),
      ],
      //配置初始状态展示个数
      domainAxis: charts.NumericAxisSpec(
        viewport: charts.NumericExtents(
            _dataStream[_dataStream.length - 1].time - 10 > 0
                ? _dataStream[_dataStream.length - 1].time - 10
                : 0,
            _dataStream[_dataStream.length - 1].time > 10
                ? _dataStream[_dataStream.length - 1].time
                : 10),
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Create message if there is new line character
    String dataString = String.fromCharCodes(data);
    // print(dataString);
    while (dataString.length > 0) {
      String TIME = dataString.substring(
          dataString.indexOf('=') + 1, dataString.indexOf(','));
      dataString =
          dataString.substring(dataString.indexOf(',') + 1, dataString.length);
      String DATA = dataString.substring(
          dataString.indexOf('=') + 1, dataString.indexOf(';'));
      dataString =
          dataString.substring(dataString.indexOf(';') + 1, dataString.length);
      // print(TIME);
      // print(DATA);
      // print(dataString.length);
      setState(
        () {
          try {
            // print(message.time_stamp);
            if (DataReceivedFlag == 0) {
              _dataStream[0].data = double.parse(DATA);
              t_start = double.parse(TIME) / 1000.0;
              DataReceivedFlag = 1;
            } else {
              _dataStream.add(Data(
                  double.parse(TIME) / 1000.0 - t_start, double.parse(DATA)));
            }
          } catch (e) {
            // 非具体类型
            print('Something Wrong, skipped: $e');
          }
        },
      );
    }
  }

  createCSVFile(String FileName) async {
    List<List<dynamic>> rows = [];
    for (int i = 0; i < _dataStream.length; i++) {
      List<dynamic> row = [];
      row.add(_dataStream[i].time.toStringAsFixed(6));
      row.add(_dataStream[i].data.toStringAsFixed(6));
      rows.add(row);
    }

    //创建保存目录路径，如果有则跳过
    var FileFolder = Directory('/storage/emulated/0/DataCollector');
    try {
      bool exists = await FileFolder.exists();
      if (!exists) {
        await FileFolder.create();
      }
    } catch (e) {
      print(e);
    }

    File f = new File('/storage/emulated/0/DataCollector/' + FileName + '.csv');

    String csv = const ListToCsvConverter().convert(rows);
    f.writeAsString(csv);
    print("Path of the saved file is: ${f.path}");
  }

  loadCSVFile(File file) async {
    var data;
    // String myData = await rootBundle.loadString(file.path);
    String myData = await file.readAsString();
    print("myData=$myData");
    List<List<dynamic>> csvTable = CsvToListConverter().convert(myData);
    data = csvTable;
    print("Read data = $data");
    setState(() {});
  }

  _FileSavedDialog() async {
    var result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Info."),
            content: Text("Your Data has been saved."),
            actions: [
              TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    print("OK");
                    Navigator.pop(context, "OK");
                  })
            ],
          );
        });

    print(result);
  }
}
