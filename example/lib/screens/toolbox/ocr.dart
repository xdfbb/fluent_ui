import 'dart:convert';
import 'package:example/models/record_datasource.dart';
import 'package:flutter/material.dart' as material;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:example/widgets/page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> with PageMixin {
  final DataGridController _dataGridController = DataGridController();
  String? selectedOCRType = "examRD";
  Uint8List _croppedData = Uint8List(0);
  PlatformFile? _selectedFile;
  String? _base64Data;
  late RecordDataSource recordDataSource;
  var _jsonData;
  bool imgAval = false;
  bool extractAval = false;
  bool DBloaded = false;
  List<Record> _records = [];

  final Map<String, String> ocrTypes = {
    '医疗发票识别': "0",
    '医疗费用明细识别': "1",
    '医疗费用结算单识别': "2",
    '医疗检验报告单识别': "examRD",
    '医疗诊断报告单识别': "3",
    '病案首页识别': "4",
    '出院小结识别': "5",
    '入院小结识别': "6",
    '诊断证明识别': "7",
    '门诊病历识别': "8",
    '处方笺识别': "9",
    '手术记录识别': "10"
  };
  late Map<String, double> columnWidths = {
    'id': double.nan,
    'type': double.nan,
    'string_id': double.nan,
  };

  @override
  void initState() {
    super.initState();
    _loadDBRecords().then((value) {
      setState(() {
        DBloaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Some useful OCR tools')),
      children: [
        subtitle(content: const Text('Tool introduction')),
        Card(
          child: Column(
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
                Text(
                  '*',
                ),
                const SizedBox(width: 6.0),
                ComboBox<String>(
                  isExpanded: false,
                  value: selectedOCRType,
                  items: ocrTypes.entries.map((e) {
                    return ComboBoxItem(
                      value: e.value,
                      child: Text(e.key),
                    );
                  }).toList(),
                  onChanged: (ocrType) {
                    setState(() => selectedOCRType = ocrType);
                  },
                ),
                const SizedBox(width: 6.0),
                Text(
                  '- Please select the document type for OCR:',
                ),
              ]),
              const SizedBox(height: 10.0),
              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: [
                Text(
                  '*',
                ),
                const SizedBox(width: 6.0),
                Button(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      withData: true,
                      type: FileType.image,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp'],
                    );
                    if (result != null) {
                      PlatformFile file = result.files.first;
                      _selectedFile = file;
                      createCorpDialog(context, file.bytes!);
                    }
                  },
                  child: const Text('Browse...'),
                ),
                const SizedBox(width: 6.0),
                Text(
                  '- Please select the image File:',
                ),
                const SizedBox(width: 6.0),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 6.0),
        Card(
            child: DBloaded
                ? SfDataGrid(
                    source: recordDataSource,
                    allowColumnsResizing: true,
                    columnWidthMode: ColumnWidthMode.fill,
                    controller: _dataGridController,
                    onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
                      setState(() {
                        columnWidths[details.column.columnName] = details.width;
                      });
                      return true;
                    },
                    onSelectionChanged: (List<DataGridRow> addedRows, List<DataGridRow> removedRows) async {
                      final index = recordDataSource.rows.indexOf(addedRows.last);
                      debugPrint("selected record with ID:" + _records[index].id.toString());
                      List<Map> result = await _queryRecordWithID(_records[index].id);
                      if (result.length > 0) {
                        setState(() {
                          _croppedData = result.first['bin_value'];
                          _jsonData = json.decode(result.first['string_value']);
                          _base64Data = result.first['content'];
                          imgAval = true;
                          extractAval = true;
                        });
                        debugPrint(result.first['string_value']);
                      }
                    },
                    selectionMode: SelectionMode.single,
                    columns: <GridColumn>[
                      GridColumn(
                          columnName: 'id',
                          width: 80,
                          label: Container(
                              padding: EdgeInsets.all(16.0),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'ID',
                              ))),
                      GridColumn(
                          columnName: 'type',
                          width: 150,
                          label: Container(
                              padding: EdgeInsets.all(16.0), alignment: Alignment.centerLeft, child: Text('Type'))),
                      GridColumn(
                          columnName: 'string_id',
                          label: Container(
                              padding: EdgeInsets.all(16.0),
                              alignment: Alignment.centerLeft,
                              child: Text('String ID'))),
                    ],
                  )
                : Text("loading data...")),
        const SizedBox(height: 6.0),
        Card(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FilledButton(
              onPressed: () async {
                await callBaidumedicalReportDetection();
                await _insertRecord();
                await _loadDBRecords();
                //debugPrint
                setState(() {
                  extractAval = true;
                });
              },
              child: const Text('Scan the document >>'),
            ),
            SizedBox(width: 10.0),
          ]),
        ),
        const SizedBox(height: 6.0),
        Card(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                flex: 4,
                child: imgAval
                    ? Button(
                        child: Image.memory(_croppedData),
                        onPressed: () {
                          createImgDialog(context, _croppedData);
                        },
                      )
                    : Center(child: Text("Image preview..."))),
            SizedBox(height: 10.0),
            Expanded(
                flex: 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  FilledButton(
                    onPressed: () async {
                      createJsonViewDialog(context, _jsonData);
                    },
                    child: const Text('>> Json viewer'),
                  ),
                  SizedBox(height: 10.0),
                  FilledButton(
                    onPressed: () async {
                      createDataTableDialog(context);
                    },
                    child: const Text('>> Data tables'),
                  ),
                ]))
          ]),
        ),
        const SizedBox(height: 6.0),
      ],
    );
  }

  Future<void> _loadDBRecords() async {
    var db = await openDatabase('toolbox_db.db');
    var list = await db.query('Record', columns: ['id', 'type', 'string_id'], orderBy: 'id desc');
    list.forEach((element) {
      _records.add(
          new Record(int.parse(element['id'].toString()), element['type'].toString(), element['string_id'].toString()));
    });
    recordDataSource = RecordDataSource(records: _records);
  }

  Future<List<Map>> _queryRecordWithID(int id) async {
    var db = await openDatabase('toolbox_db.db');
    List<Map> maps = await db.query('Record',
        columns: ['id', 'type', 'content', 'string_id', 'string_value', 'bin_value'], where: 'id = ?', whereArgs: [id]);
    return maps;
  }

  Future<void> _insertRecord() async {
    var db = await openDatabase('toolbox_db.db');
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    await db.insert('Record', {
      'type': 'OCR_EXTRACT',
      'content': _base64Data,
      'string_id': _selectedFile?.path,
      'string_value': encoder.convert(_jsonData),
      'bin_value': _croppedData,
    });
  }

  Future<void> callBaidumedicalReportDetection() async {
    //get token
    Map<String, String> tokenParameters = {
      'grant_type': 'client_credentials',
      'client_id': '8lZ7wCBog9VlRvkGuyFhVr8z',
      'client_secret': 'f9K8X7j3znWZ0v1B92fZASdeNzPpWNnO'
    };
    Map<String, String> tokenHeaders = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    var tokenUrl = Uri.https('aip.baidubce.com', '/oauth/2.0/token', tokenParameters);
    debugPrint('tokenUrl: ${tokenUrl}');
    var tokenResponse = await http.post(tokenUrl, headers: tokenHeaders);
    debugPrint('Response status: ${tokenResponse.statusCode}');
    debugPrint('Response body: ${tokenResponse.body}');
    String token = json.decode(tokenResponse.body)['access_token'];
    debugPrint('token: ${token}');

    //extract data
    var extractionUrl = Uri.https('aip.baidubce.com', 'rest/2.0/ocr/v1/medical_report_detection?access_token=' + token);
    Map<String, String> extractionHeaders = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json'
    };
    Map<String, String> extractionBody = {'location': 'false', 'probability': 'false', 'image': _base64Data!};
    var extractionResponse = await http.post(extractionUrl, headers: extractionHeaders, body: extractionBody);
    debugPrint('Response status: ${extractionResponse.statusCode}');
    debugPrint('Response body: ${extractionResponse.body}');
    debugPrint('Response status: ${extractionResponse.statusCode}');
    debugPrint('payload: ${utf8.decode(extractionResponse.bodyBytes)}');
    _jsonData = await json.decode(utf8.decode(extractionResponse.bodyBytes));
  }

  void createCorpDialog(BuildContext context, Uint8List imageData) async {
    CropController controller = CropController();

    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('please review & crop your image'),
        content: Column(
          children: [
            const Text(
              'Image data is base64 encoded and then urlencoded. The size after base64 encoding and urlencode is required to be no more than 4M, with the shortest side at least 15px and the longest side up to 4096px. jpg/jpeg/png/bmp formats are supported. ',
            ),
            const SizedBox(height: 8.0),
            Expanded(
                child: Crop(
              image: imageData,
              controller: controller,
              onCropped: (corpImage) {
                _croppedData = corpImage;
                _base64Data = uint8ListTob64(_croppedData!, _selectedFile!.extension!);
                Navigator.pop(context, 'finished crop');
                setState(() {
                  imgAval = true;
                });
                debugPrint(_base64Data);
              },
              cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.warningPrimaryColor),
              interactive: false,
            )),
          ],
        ),
        actions: [
          FilledButton(
            child: const Text('Crop'),
            onPressed: () {
              debugPrint("click crop");
              controller.crop();
            },
          ),
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, 'User canceled dialog'),
          ),
        ],
        constraints: BoxConstraints.expand(),
      ),
    );
    setState(() {});
  }

  void createImgDialog(BuildContext context, Uint8List imageData) async {
    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Image View'),
        content: ScaffoldPage.scrollable(children: [
          Image.memory(imageData),
        ]),
        actions: [
          FilledButton(child: const Text('Close'), onPressed: () => Navigator.pop(context, 'User canceled dialog'))
        ],
        constraints: BoxConstraints.expand(),
      ),
    );
    setState(() {});
  }

  void createJsonViewDialog(BuildContext context, var jsonData) async {
    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Json viewer'),
        content: Column(
          children: [
            const Text(
              'Image data is base64 encoded and then urlencoded. The size after base64 encoding and urlencode is required to be no more than 4M, with the shortest side at least 15px and the longest side up to 4096px. jpg/jpeg/png/bmp formats are supported. ',
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: JsonView.map(jsonData),
            )
          ],
        ),
        actions: [
          Button(
            child: const Text('close'),
            onPressed: () => Navigator.pop(context, 'User canceled dialog'),
          ),
        ],
        constraints: BoxConstraints.expand(),
      ),
    );
    setState(() {});
  }

  String checkEmptyValue(var value) {
    if (value.isEmpty) {
      return "不详";
    }
    return value;
  }

  void createDataTableDialog(BuildContext context) async {
    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Document content (structured)'),
        content: GridView.count(
          primary: false,
          padding: const EdgeInsets.all(20),
          mainAxisSpacing: 1,
          crossAxisCount: 1,
          children: [
            material.DataTable(
              showBottomBorder: false,
              columns: const <material.DataColumn>[
                material.DataColumn(
                  label: Expanded(
                    child: Text(
                      '字段名称',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                material.DataColumn(
                  label: Expanded(
                    child: Text(
                      '字段值',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
              rows: generateCommonDataRows(),
            ),
            material.DataTable(
              columns: getDatacolumns(),
              rows: generateValueDataRows(),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('close'),
            onPressed: () => Navigator.pop(context, 'User canceled dialog'),
          ),
        ],
        constraints: BoxConstraints.expand(),
      ),
    );
    setState(() {});
  }

  List<material.DataColumn> getDatacolumns() {
    List dataValues = _jsonData['words_result']['Item'][0];
    List<material.DataColumn> colums = [];
    for (int i = 0; i < dataValues.length; i++) {
      material.DataColumn oneColum = new material.DataColumn(
        label: Expanded(
          child: Text(
            dataValues[i]['word_name'],
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
      colums.add(oneColum);
    }
    return colums;
  }

  List<material.DataRow> generateCommonDataRows() {
    List commonData = _jsonData['words_result']['CommonData'];
    List<material.DataRow> rows = [];
    for (int i = 0; i < commonData.length; i++) {
      material.DataRow oneRow = new material.DataRow(
        cells: <material.DataCell>[
          material.DataCell(Text(commonData[i]['word_name'] + ' :')),
          material.DataCell(Text(commonData[i]['word'].toString().isEmpty ? '暂缺' : commonData[i]['word']))
        ],
      );
      rows.add(oneRow);
    }
    return rows;
  }

  List<material.DataRow> generateValueDataRows() {
    List dataValues = _jsonData['words_result']['Item'];
    List<material.DataRow> rows = [];
    List<material.DataCell> cells = [];
    for (int i = 0; i < dataValues.length; i++) {
      List cellValues = dataValues[i];
      for (int j = 0; j < cellValues.length; j++) {
        debugPrint(cellValues[j]['word']);
        material.DataCell oneCell = material.DataCell(Text(cellValues[j]['word']));
        cells.add(oneCell);
      }
      material.DataRow oneRow = new material.DataRow(
        cells: cells,
      );
      if (cells.length != 8) {}
      cells = [];
      rows.add(oneRow);
    }
    return rows;
  }

  String uint8ListTob64(Uint8List uint8list, String imageType) {
    String base64String = base64Encode(uint8list);
    String header = "data:image/" + imageType + ";base64,";
    return header + base64String;
  }
}
