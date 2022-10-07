import 'dart:math';
// import 'dart:ffi';
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
  bool DataReceivedFlag = false; //用于标记是否收到了第一个数据
  bool ShowGraph = false;

  double t_start = 0; //用于记录第一个数据的时间，并以此为时间基点
  double _currentData = 0;
  double _currentTime = 0;
  List<Data> _dataStream = [];

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  double range = 1;
  double position = 1;

  TextEditingController textEditingController = TextEditingController(text: "untitled");

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

    super.dispose();
  }

  // Main body
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text("Collected Data")),
        body: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                const Divider(),
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
                Container(
                  height: 10,
                ),
                Expanded(
                    child: ListView(
                  children: [
                    ShowGraph
                        ? Column(
                            children: [
                              Container(
                                height: MediaQuery.of(context).size.width <
                                        MediaQuery.of(context).size.height
                                    ? 150
                                    : 140,
                                child: DataReceivedFlag
                                    ? LineChart(_dataStream.sublist(
                                        _dataStream.length - 100 > 0
                                            ? _dataStream.length - 100
                                            : 0,
                                        _dataStream.length))
                                    : const Center(
                                        child: Text(
                                          "Not connected yet",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 25,
                                              fontFamily: 'Times New Roman'),
                                        ),
                                      ),
                              ),
                              MediaQuery.of(context).size.width >
                                      MediaQuery.of(context).size.height
                                  ? Row(
                                      // height: 30,
                                      // width: 50,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            ShowGraph = !ShowGraph;
                                          },
                                          child: const Text(
                                            "Back",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                        ),
                                        const Text('             '),
                                      ],
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        ShowGraph = !ShowGraph;
                                      },
                                      child: const Text(
                                        "Back",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            fontFamily: 'Times New Roman'),
                                      ),
                                    ),
                            ],
                          )
                        : InkWell(
                            onTap: () {
                              ShowGraph = !ShowGraph;
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.only(left: 90, right: 90),
                              //设置 child 居中
                              alignment: AlignmentDirectional.center,
                              height: MediaQuery.of(context).size.width <
                                      MediaQuery.of(context).size.height
                                  ? 150
                                  : 100,
                              width: 50,
                              //边框设置
                              decoration: const BoxDecoration(
                                //背景
                                color: Color.fromARGB(255, 131, 193, 243),
                                // color: Colors.blue,
                                //设置四周圆角 角度
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10.0)),
                                //设置四周边框
                                // border: new Border.all(width: 1, color: Colors.red),
                              ),
                              child: Center(
                                child: MediaQuery.of(context).size.width <
                                        MediaQuery.of(context).size.height
                                    ? Column(
                                        children: [
                                          const Text(
                                            "",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          const Text(
                                            "Current Time(s)",
                                            style: TextStyle(
                                                // color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          Text(
                                            _currentTime.toStringAsFixed(2),
                                            style: const TextStyle(
                                                // color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 30,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          const Text(
                                            "Current Value",
                                            style: TextStyle(
                                                // color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          Text(
                                            _currentData.toStringAsFixed(6),
                                            style: const TextStyle(
                                                // color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 30,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          const Text(
                                            "                  ",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 30,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          Column(
                                            children: [
                                              const Text(
                                                "",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                              const Text(
                                                "Current Time(s)",
                                                style: TextStyle(
                                                    // color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                              Text(
                                                _currentTime.toStringAsFixed(2),
                                                style: const TextStyle(
                                                    // color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 30,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                            ],
                                          ),
                                          const Text(
                                            "                  ",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                fontFamily: 'Times New Roman'),
                                          ),
                                          Column(
                                            children: [
                                              const Text(
                                                "",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                              const Text(
                                                "Current Value",
                                                style: TextStyle(
                                                    // color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                              Text(
                                                _currentData.toStringAsFixed(6),
                                                style: const TextStyle(
                                                    // color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 30,
                                                    fontFamily:
                                                        'Times New Roman'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          )
                  ],
                ))
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 5,
              child: Center(
                child: Column(
                  children: const [
                    Text(
                      "©Ren's Group,",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Times New Roman'),
                    ),
                    Text(
                      "School of Integrated Circuits, Tsinghua University",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Times New Roman'),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),

        // body: ListView(
        //   children: <Widget>[
        //     const Divider(),

        //     // A container to place LineChart
        // Container(
        //   height: 150,
        //   child: DataReceivedFlag
        //       ? LineChart(_dataStream.sublist(
        //           _dataStream.length - 100 > 0
        //               ? _dataStream.length - 100
        //               : 0,
        //           _dataStream.length))
        //       : const Center(
        //           child: Text(
        //             "Not connected yet",
        //             style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 25,
        //                 fontFamily: 'Times New Roman'),
        //           ),
        //         ),
        // ),

        //     SliderTheme(
        //       data: SliderTheme.of(context).copyWith(
        //         trackHeight: 2.0,
        //       ),
        //       child: Slider(
        //         value: range,
        //         min: 0.0,
        //         max: 2.0,
        //         onChanged: (val) => setState(() => range = val),
        //       ),
        //     ),

        //     // Slider(
        //     //   value: position,
        //     //   min: 0.0,
        //     //   max: 1.0,
        //     //   // activeColor: Colors.deepPurple,
        //     //   // inactiveColor: Colors.grey,
        //     //   // divisions: 1000,
        //     //   label: 'Current Label = $position',
        //     //   onChanged: (val) => setState(() => position = val),
        //     // ),

        //   ],
        // ),
      ),
      onWillPop: () async => await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Are you sure you want to quit?\n Your data will be saved as "AutoSaved.csv".',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Times New Roman'),
          ),
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
        // charts.SlidingViewport(),
        // charts.SelectionModel(),
        // charts.PanAndZoomBehavior(),
        charts.ChartTitle('Time(s)',
            behaviorPosition: charts.BehaviorPosition.bottom,
            titleOutsideJustification:
                charts.OutsideJustification.middleDrawArea),
        // charts.ChartTitle('Data',
        //     behaviorPosition: charts.BehaviorPosition.start,
        //     titleOutsideJustification:
        //         charts.OutsideJustification.middleDrawArea),
      ],

      //配置初始状态展示个数
      domainAxis: charts.NumericAxisSpec(
        showAxisLine: true,
        tickProviderSpec: const charts.BasicNumericTickProviderSpec(
            zeroBound: false,
            dataIsInWholeNumbers: false,
            desiredMinTickCount: 8),
        viewport: charts.NumericExtents(
            DATALIST[0].time, DATALIST[DATALIST.length - 1].time>10?DATALIST[DATALIST.length - 1].time:10),
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
            if (!DataReceivedFlag) {
              _currentData = double.parse(DATA);
              _currentTime = 0;
              t_start = double.parse(TIME) / 1000.0;
              DataReceivedFlag = true;
            } else {
              _currentData = double.parse(DATA);
              _currentTime = double.parse(TIME) / 1000.0 - t_start;
            }
            _dataStream.add(
              Data(
                _currentTime,
                _currentData,
              ),
            );
          } catch (e) {
            // 非具体类型
            print('Something Wrong, skipped: $e');
          }
        },
      );
    }
  }

  createCSVFile(String FileName) async {
    if(FileName=='') FileName = 'untitled';
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
            title: const Text("Info."),
            content: const Text("Your Data has been saved."),
            actions: [
              TextButton(
                  child: const Text("OK"),
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

// /进度条内容自定义
class LineSliderTickMarkShape extends SliderTickMarkShape {
  const LineSliderTickMarkShape(
      {this.tickMarkRadius = 0.0, this.strokeWidth = 1.0});

  ///圆角
  final double tickMarkRadius;

  ///竖条宽度
  final double strokeWidth;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    assert(sliderTheme != null);
    assert(sliderTheme.trackHeight != null);
    assert(isEnabled != null);
    return Size.fromRadius(tickMarkRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    Color? beginColor;
    Color? endColor;

    ///左右滑动颜色变更
    switch (textDirection) {
      case TextDirection.ltr:
        final bool isTickMarkRightOfThumb = center.dx > thumbCenter.dx;
        beginColor = isTickMarkRightOfThumb
            ? sliderTheme.disabledInactiveTickMarkColor
            : sliderTheme.disabledActiveTickMarkColor;
        endColor = isTickMarkRightOfThumb
            ? sliderTheme.inactiveTickMarkColor
            : sliderTheme.activeTickMarkColor;
        break;
      case TextDirection.rtl:
        final bool isTickMarkLeftOfThumb = center.dx < thumbCenter.dx;
        beginColor = isTickMarkLeftOfThumb
            ? sliderTheme.disabledInactiveTickMarkColor
            : sliderTheme.disabledActiveTickMarkColor;
        endColor = isTickMarkLeftOfThumb
            ? sliderTheme.inactiveTickMarkColor
            : sliderTheme.activeTickMarkColor;
        break;
    }

    ///进度条样式、动画设置
    final Paint paint = Paint()
      ..color = ColorTween(begin: beginColor, end: endColor)
          .evaluate(enableAnimation)!
      ..style = PaintingStyle.fill
      ..strokeWidth = strokeWidth;

    ///进度条画布
    context.canvas.drawLine(Offset(center.dx, center.dy - 5),
        Offset(center.dx, center.dy + 5), paint);
  }
}
