import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());

  Supabase.initialize(
    url: 'https://jcoxhpanjaynjwkrgedx.supabase.co',
    anonKey: dotenv.env['SUPABASE_API_KEY']!, 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Earnings Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 11, 235, 86)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Josh\'s custom Earnings Tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _timer;
  double _earnings = 0.0;
  double _hourlyRate = 0.0;
  int _secondsPassed = 0;
  bool _isRunning = false;
  String _userName = '';
  String _searchQuery = '';
  String _submissionStatus = '';
  List<Map<String, dynamic>> _searchResults = [];

  String formatElapsedTime(int seconds) {
    int days = seconds ~/ 86400;
    int hours = (seconds % 86400) ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${days}d ${hours}h ${minutes}m ${remainingSeconds}s';
  }

  void _startTimer() {
    if (_hourlyRate > 0 && !_isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _earnings += _hourlyRate / 3600;
          _secondsPassed++;
          _isRunning = true;
        });
      });
    } else if (_hourlyRate <= 0) {
      _showErrorDialog("Please enter hourly rate");
    }
  }

void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}


  void _pauseTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _isRunning = false;
    }
  }

  void _resetTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() {
        _earnings = 0.0;
        _secondsPassed = 0;
        _isRunning = false;
      });
    }
  }

void _finishAndSubmit() async {
  if (!_isRunning && _userName.isNotEmpty && _earnings > 0.0) {
    final int hourlyRateInt = (_hourlyRate).toInt();

    final response = await Supabase.instance.client
      .from('timesheets')
      .insert({
        'name': _userName,
        'hourly_rate': hourlyRateInt,
        'total_earnt': _earnings,
        'elapsedTime': formatElapsedTime(_secondsPassed),
      })
      .execute();

      if (response.error != null) {
        setState(() {
          _submissionStatus = 'Error in submitting data: ${response.error!.message}';
        });
      } else {
        setState(() {
          _submissionStatus = 'Timesheet submitted successfully';
          _resetTimer();
        });
      }
  } else {
    _showErrorDialog('Please complete the tracking before finishing.');
  }
}
void _performSearch() async {
  final response = await Supabase.instance.client
    .from('timesheets')
    .select()
    .like('name', '%$_searchQuery%')
    .execute();

  if (response.error != null) {
    print('Error in search: ${response.error!.message}');
  } else {
    setState(() {
      _searchResults = List<Map<String, dynamic>>.from(response.data);
    });
  }
}
SingleChildScrollView _buildSearchResultsTable() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Hourly Rate')),
        DataColumn(label: Text('Total Earned')),
        DataColumn(label: Text('Elapsed Time')),
      ],
      rows: _searchResults.map((result) {
        return DataRow(cells: [
          DataCell(Text(result['name'] ?? '')),
          DataCell(Text('${result['hourly_rate'] ?? ''}')),
          DataCell(Text('${result['total_earnt'] ?? ''}')),
          DataCell(Text(result['elapsedTime'] ?? '')),
        ]);
      }).toList(),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(widget.title),
    ),
    body: SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Image.asset(
                'images/timeismoney.png', 
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Divider(height: 50, thickness: 2),
            const Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text('Clock In Section', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: TextField(
                onChanged: (value) => _userName = value,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Your Name',
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Enter your hourly rate:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) => _hourlyRate = double.tryParse(value) ?? 0.0,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Hourly Rate',
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'You have earned: \n\$${_earnings.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: (Theme.of(context).textTheme.headlineMedium ?? TextStyle(fontSize: 24))
                  .copyWith(color: Colors.green),
            ),
            SizedBox(height: 10),
            Text(
              'Elapsed Time:',
              style: (Theme.of(context).textTheme.subtitle1 ?? TextStyle(fontSize: 14)),
            ),
            Text(
              formatElapsedTime(_secondsPassed),
              style: (Theme.of(context).textTheme.subtitle1 ?? TextStyle(fontSize: 14)),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? null : _startTimer,
                  child: const Text('Start'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _isRunning ? _pauseTimer : null,
                  child: const Text('Pause'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _resetTimer,
                  child: const Text('Reset'),
                ),
              ],
            ),
            SizedBox(width: 20),
            ElevatedButton(
              onPressed: _finishAndSubmit,
              child: const Text('Finish'),
            ),
            SizedBox(height: 10), 
            Text(_submissionStatus), 
            Divider(height: 50, thickness: 2), 
            const Text('Search Section', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              child: TextField(
                onChanged: (value) => _searchQuery = value,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Search Name',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Search'),
            ),
            _buildSearchResultsTable()
          ],
        ),
      ),
    ),
  );
}
}