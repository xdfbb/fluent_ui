import 'dart:convert';
import 'dart:typed_data';

import 'package:example/models/record_datasource.dart';
import 'package:example/widgets/page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class NlpPage extends StatefulWidget {
  const NlpPage({super.key});

  @override
  State<NlpPage> createState() => _NlpPageState();
}

class _NlpPageState extends State<NlpPage> with PageMixin {
  bool DBloaded = false;
  bool imgAval = false;
  bool extractAval = false;
  bool rowSelected = false;

  List<Record> _records = [];
  Uint8List _croppedData = Uint8List(0);
  String? _base64Data;
  var _jsonData;
  var _visionResponse;
  var _medicalResponse;
  var _uwResponse;

  late RecordDataSource recordDataSource;
  late int idSelected;

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
    final DataGridController _dataGridController = DataGridController();
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Some useful NLP tools')),
      children: [
        subtitle(
          content: const Text('Local datasets'),
        ),
        const SizedBox(height: 4.0),
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
                      idSelected = _records[index].id;

                      debugPrint("selected record with ID:" + idSelected.toString());

                      List<Map> result = await _queryRecordWithID(idSelected);
                      if (result.length > 0) {
                        setState(() {
                          _croppedData = result.first['bin_value'];
                          _jsonData = json.decode(result.first['string_value']);
                          _base64Data = result.first['content'];
                          _visionResponse = result.first['vision_response'];
                          _medicalResponse = result.first['medical_response'];
                          _uwResponse = result.first['uw_response'];

                          imgAval = true;
                          extractAval = true;
                          rowSelected = true;
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
                : Text("loading local dataset......")),
        Card(
          child: Row(children: [
            FilledButton(
              onPressed: !rowSelected
                  ? null
                  : () async {
                      if (_visionResponse.toString().isEmpty) {
                        await callOpenAIVision();
                        await _updateRecord(idSelected);
                      }
                      var visionMap = jsonDecode(_visionResponse) as Map<String, dynamic>;
                      createTextDialog(
                          context, 'Explain the image (OPENAI)', visionMap['choices'][0]['message']['content']);
                    },
              child: const Text('Explain the image (OPENAI)'),
            ),
            const SizedBox(width: 4.0),
            FilledButton(
              onPressed: !rowSelected ? null : () {},
              child: const Text('Get medical advise'),
            ),
            const SizedBox(width: 4.0),
            FilledButton(
              onPressed: !rowSelected ? null : () {},
              child: const Text('Get UW advise'),
            ),
            const Spacer(),
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
          ]),
        ),
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
        columns: [
          'id',
          'type',
          'content',
          'string_id',
          'string_value',
          'bin_value',
          'vision_response',
          'medical_response',
          'uw_response'
        ],
        where: 'id ='
            ' ?',
        whereArgs: [id]);
    return maps;
  }

  Future<void> callOpenAIVision() async {
    final String openAIkey = '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';

    // export OPENAI_API_KEY=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
    // export OPENAI_API_ORG=org-WhuzIDANHL0HnQvnBhOZUFRp

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': "Bearer $openAIkey"
    };

    //extract data
    var visionUrl = Uri.https('openai.lao-qian.com', '/v1/chat/completions');
    String prompt = "下面是一份医学相关的图像文件，你能告诉我它是有关什么的吗？假设你是一位全科医生，请根据图片上的信息进行进一步的医学评估。";
    String payload =
        "{\"model\": \"gpt-4-vision-preview\",\"messages\": [{\"role\": \"user\",\"content\": [{\"type\": \"text\","
        "\"text\":\"$prompt\" },"
        "{\"type\": \"image_url\",\"image_url\": {\"url\": \"$_base64Data\"}}]}],\"max_tokens"
        "\": 1200}";
    debugPrint('Sending request: $payload');
    var response = await http.post(visionUrl, headers: headers, body: payload);
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    _visionResponse = await json.decode(utf8.decode(response.bodyBytes));
    debugPrint('payload: $_visionResponse');
  }

  Future<void> _updateRecord(int id) async {
    var db = await openDatabase('toolbox_db.db');
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    await db.update(
        'Record',
        {
          'vision_response': encoder.convert(_visionResponse),
        },
        where: 'id = ?',
        whereArgs: [id]);
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

  void createTextDialog(BuildContext context, String title, String text) async {
    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: ScaffoldPage.scrollable(children: [Text(text)]),
        actions: [
          FilledButton(child: const Text('Close'), onPressed: () => Navigator.pop(context, 'User canceled dialog'))
        ],
        constraints: BoxConstraints.expand(),
      ),
    );
    setState(() {});
  }
}
