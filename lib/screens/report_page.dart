import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';  // To format dates
import 'package:path_provider/path_provider.dart';  // To get the local storage path
import 'package:csv/csv.dart';  // For exporting data to CSV
import 'dart:io';
import '../models/transaction_db.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  double totalIncome = 0;
  double totalExpense = 0;
  String selectedChartType = 'Doughnut';
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = TransactionDB();
    final transactions = await db.getTransactions();

    double income = 0;
    double expense = 0;

    for (var transaction in transactions) {
      if (transaction['isIncome'] == 1) {
        income += transaction['amount'];
      } else {
        expense += transaction['amount'];
      }
    }

    setState(() {
      totalIncome = income;
      totalExpense = expense;
    });
  }

  Future<void> _selectDateRange() async {
    final selectedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now(),
        end: endDate ?? DateTime.now(),
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selectedDateRange != null) {
      setState(() {
        startDate = selectedDateRange.start;
        endDate = selectedDateRange.end;
      });

      // Reload data based on the selected date range
      _loadData(); // You may want to filter your data based on the selected dates here
    }
  }

  Future<void> _exportToCSV() async {
    final db = TransactionDB();
    final transactions = await db.getTransactions();

    List<List<String>> rows = [];
    rows.add(['Date', 'Description', 'Amount', 'Type']);  // Headers

    for (var transaction in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(DateTime.parse(transaction['date'])),
        transaction['description'],
        transaction['amount'].toString(),
        transaction['isIncome'] == 1 ? 'Income' : 'Expense',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/transactions_report.csv';
    final file = File(path);

    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Data exported to $path'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.file_copy),
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.blueGrey, width: 0.5),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * .75,
                width: MediaQuery.of(context).size.width * .90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Summary",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Divider(
                      color: Colors.grey,
                      thickness: 0.3,
                      endIndent: 10,
                      indent: 10,
                    ),
                    _buildSummary(),
                    const SizedBox(height: 20),
                    _buildChartTypeSelector(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildChart()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text(
                "Total Income",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "\$${totalIncome.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Column(
            children: [
              const Text(
                "Total Expense",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "\$${totalExpense.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return DropdownButton<String>(
      value: selectedChartType,
      onChanged: (value) {
        setState(() {
          selectedChartType = value!;
        });
      },
      items: const [
        DropdownMenuItem(
          value: 'Doughnut',
          child: Text('Doughnut Chart'),
        ),
        DropdownMenuItem(
          value: 'Line',
          child: Text('Line Chart'),
        ),
      ],
    );
  }

Widget _buildChart() {
  final data = [
    ChartData(Colors.greenAccent, 'Income', totalIncome),
    ChartData(Colors.redAccent, 'Expense', totalExpense),
  ];

  if (selectedChartType == 'Line') {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      title: ChartTitle(text: 'Income vs Expense'),
      legend: Legend(isVisible: true),
      series: <CartesianSeries>[
        LineSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.name,
          yValueMapper: (ChartData data, _) => data.value,
          color: Colors.blue,
        ),
      ],
    );
  } else {
    return SfCircularChart(
      legend: Legend(
        isVisible: true,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
      ),
      series: <CircularSeries>[
        DoughnutSeries<ChartData, String>(
          dataSource: data,
          pointColorMapper: (ChartData data, _) => data.color,
          xValueMapper: (ChartData data, _) => data.name,
          yValueMapper: (ChartData data, _) => data.value,
          radius: '70%',
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }
}

}

class ChartData {
  final Color color;
  final String name;
  final double value;

  ChartData(this.color, this.name, this.value);
}