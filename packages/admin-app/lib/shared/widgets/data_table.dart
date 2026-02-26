import 'package:flutter/material.dart';

class AdminDataTable<T> extends StatelessWidget {
  final List<String> columns;
  final List<T> data;
  final List<DataCell> Function(T item) cellBuilder;
  final Function(T item)? onRowTap;
  final bool isLoading;
  final String emptyMessage;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.data,
    required this.cellBuilder,
    this.onRowTap,
    this.isLoading = false,
    this.emptyMessage = 'No data found',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((col) => DataColumn(
                  label: Text(
                    col,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ))
            .toList(),
        rows: data.map((item) {
          return DataRow(
            cells: cellBuilder(item),
            onSelectChanged: onRowTap != null ? (_) => onRowTap!(item) : null,
          );
        }).toList(),
        showCheckboxColumn: false,
      ),
    );
  }
}
