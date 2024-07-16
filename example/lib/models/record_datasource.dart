import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class RecordDataSource extends DataGridSource {
  RecordDataSource({List<Record>? records}) {
    _records = records!
        .map<DataGridRow>((e) => DataGridRow(cells: [
              DataGridCell<int>(columnName: 'id', value: e.id),
              DataGridCell<String>(columnName: 'type', value: e.type),
              DataGridCell<String>(columnName: 'string_id', value: e.string_id),
            ]))
        .toList();
  }

  List<DataGridRow> _records = [];

  @override
  List<DataGridRow> get rows => _records;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((dataGridCell) {
      debugPrint(dataGridCell.value.toString());
      return Container(
        padding: EdgeInsets.all(16.0),
        child: Text(
          dataGridCell.value.toString(),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList());
  }
}

class Record {
  Record(
    this.id,
    this.type,
    this.string_id,
  );
  final int id;
  final String type;
  final String string_id;
}
