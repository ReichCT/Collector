import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_ip_address/get_ip_address.dart';

class TableLayout extends StatefulWidget {
  @override
  _TableLayoutState createState() => _TableLayoutState();
}

class _TableLayoutState extends State<TableLayout> {
  List<List<dynamic>> data = [];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _requestPermission();
    // 加载本地csv文件并展示出来
    loadCSVFile(File('/storage/emulated/0/DataCollector/myReport.csv'));
  }

  _requestPermission() async {
    if (await Permission.contacts.request().isGranted) {
      // Either the permission was already granted before or the user just granted it.
    }

// You can request multiple permissions at once.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
    ].request();
    print(statuses[Permission.location]);
    print(statuses[Permission.storage]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.refresh),
          onPressed: () {
            // 生成csv文件
            // createCSVFile();
          }),
      appBar: AppBar(
        title: Text("Table Layout and CSV"),
      ),
      body: SingleChildScrollView(
        child: Table(
          // columnWidths: {
          //   0: FixedColumnWidth(100.0),
          //   1: FixedColumnWidth(100.0),
          // },
          border: TableBorder.all(width: 1.0),
          children: data.map((item) {
            return TableRow(
                children: item.map((row) {
              return Container(
                color:
                    row.toString().contains("NA") ? Colors.red : Colors.green,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    row.toString(),
                    style: TextStyle(fontSize: 20.0, color: Colors.white),
                  ),
                ),
              );
            }).toList());
          }).toList(),
        ),
      ),
    );
  }

  //读取csv文件（从Assets资源文件夹读取csv文件）
  loadCSVFormAssets() async {
    final myData = await rootBundle.loadString("assets/sales.csv");
    List<List<dynamic>> csvTable = CsvToListConverter().convert(myData);
    data = csvTable;
    print("loadCSVFileTest读取的数据data = $data");
    setState(() {});
  }

  createCSVFile() async {
    List rootAttendanceList = [
      ["name", "age"],
      ["zz", 28],
      ["wu", 27]
    ];
    List<List<dynamic>> rows = [];
    for (int i = 0; i < rootAttendanceList.length; i++) {
      List<dynamic> row = [];
      row.add(rootAttendanceList[i][0]);
      row.add(rootAttendanceList[i][1]);
      rows.add(row);
    }

    print("rows =======$rows");
    Directory documentsDir = (await getApplicationDocumentsDirectory());
    // 创建ble文件夹
    Directory desDir = await Directory('${documentsDir.path}/ble').create();
    print("desDir=${desDir.path}");
    String file = "${desDir.path}";
    File f = new File(file + "/myReport.csv");

    // 生成csv文件，csv文件路径：缓存目录下的 ble文件夹下
    String csv = const ListToCsvConverter().convert(rows);
    f.writeAsString(csv);
    print("生成csv文件路径=${f.path}");
  }

  //读取csv文件（从缓存目录中读取csv文件）
  loadCSVFile(File file) async {
    // String myData = await rootBundle.loadString(file.path);
    String myData = await file.readAsString();
    print("myData=$myData");
    List<List<dynamic>> csvTable = CsvToListConverter().convert(myData);
    data = csvTable;
    print("读取的数据data = $data");
    setState(() {});
  }

  // 压缩csv文件成zip文件
  _zipFiles() async {
    Directory documentsDir = (await getApplicationDocumentsDirectory());
    Directory desDir = await Directory('${documentsDir.path}/ble').create();
    String desPath = desDir.path;

    var encoder = ZipFileEncoder();
    encoder.zipDirectory(Directory(desDir.path),
        filename: desDir.path + ".zip");
    print("""生成zip文件路径=$desPath.zip""");
  }

  // 解压缩zip文件，释放出csv文件
  _unZipFiles() async {
    Directory documentsDir = (await getApplicationDocumentsDirectory());
    Directory desDir = Directory('${documentsDir.path}/ble');
    String zipFilePath = desDir.path + ".zip";
    print("压缩文件路径zipFilePath = $zipFilePath");

    // 从磁盘读取Zip文件。
    List<int> bytes = File(zipFilePath).readAsBytesSync();
    // 解码Zip文件
    Archive archive = ZipDecoder().decodeBytes(bytes);

    // 将Zip存档的内容解压缩到磁盘。
    for (ArchiveFile file in archive) {
      if (file.isFile) {
        List<int> tempData = file.content;
        File f = File(desDir.path + "/" + file.name)
          ..createSync(recursive: true)
          ..writeAsBytesSync(tempData);

        print("解压后的文件路径 = ${f.path}");
        Future.delayed(Duration(seconds: 2), () {
          //读取csv文件（从缓存目录中读取csv文件）
          loadCSVFile(f);
        });
      } else {
        Directory(desDir.path + "/" + file.name)..create(recursive: true);
      }
    }
    print("解压成功");
  }

// 删除文件夹及其下所有文件
  _deleteDirectory(Directory directory) {
    directory.delete(recursive: true);
  }
}

class WiFi_Communicator extends StatefulWidget {
  const WiFi_Communicator({super.key});

  @override
  State<WiFi_Communicator> createState() => _WiFi_CommunicatorState();
}

class _WiFi_CommunicatorState extends State<WiFi_Communicator> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ElevatedButton(
        child: Text("TCP"),
        onPressed: () {
          print(1);
          startServer();
        },
      ),
    );
  }

  void startServer() async {
    getIP();
    ServerSocket serverSocket =
        await ServerSocket.bind(InternetAddress.anyIPv4, 8888, shared: true);
    serverSocket.listen(handleClient);
    print(serverSocket.address);
  }
  void handleClient(Socket client) {
    print('some client connected');
  }
  void getIP() async {
    /// Initialize Ip Address
    var ipAddress = IpAddress();
    /// Get the IpAddress based on requestType.
    dynamic data = await ipAddress.getIpAddress();
    print(data.toString());
  }
}
