import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:
          'LIBU - Your personal, home-friendly buying list 😄', // Renamed the app title
      theme: ThemeData.dark(), // Set the app theme to dark mode
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  Database? db;
  List<Map<String, dynamic>> items = [];
  TabController? _tabController;
  bool isDbInitialized = false; // Add this line

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
    _initDatabase();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}com.com.com.libu.db';
    db = await openDatabase(path,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
    setState(() {
      isDbInitialized = true; // Set this to true after db initialization
    });
    _loadItems();
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY,
        item_name TEXT,
        date TEXT,
        is_picked INTEGER,
        completed_timestamp TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE items ADD COLUMN completed_timestamp TEXT");
    }
  }

  _loadItems() async {
    List<Map<String, dynamic>> items = await db!.query('items');
    setState(() {
      this.items = items;
    });
  }

  _addItem(String name) async {
    String date = DateFormat('M/d/yyyy').format(DateTime.now());
    await db!.insert('items', {
      'item_name': name,
      'date': date,
      'is_picked': 0,
    });
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIBU - Your personal, home-friendly buying list 😄',
            style: TextStyle(fontFamily: 'Roboto')), // Added a stylish font
      ),
      bottomNavigationBar: Material(
        // Added a bottom navigation bar for tabs
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodayTab() {
    // Filter items for Today tab
    var todayItems = items.where((item) => item['is_picked'] == 0).toList();

    return Column(
      children: [
        Container(
          // Stylish header for the date in the Today tab
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8.0),
          ),
          margin: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('EEEE, y MMMM d').format(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto'),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _completeTasks,
                child: const Text("Complete"),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: todayItems.length,
            itemBuilder: (context, index) {
              var item = todayItems[index];
              return ListTile(
                title: Text(item['item_name'],
                    style: const TextStyle(fontFamily: 'Roboto')),
                trailing: Checkbox(
                  value: item['is_picked'] == 1,
                  onChanged: (val) {
                    var updatedItem = Map<String, dynamic>.from(item);
                    updatedItem['is_picked'] = val! ? 1 : 0;
                    if (val && item['completed_timestamp'] == null) {
                      updatedItem['completed_timestamp'] =
                          DateTime.now().millisecondsSinceEpoch.toString();
                    }
                    db!.update('items', updatedItem,
                        where: 'id = ?', whereArgs: [updatedItem['id']]);
                    _loadItems();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _completeTasks() {
    for (var item in items) {
      var updatedItem = Map<String, dynamic>.from(item);
      updatedItem['is_picked'] = 1;
      if (item['completed_timestamp'] == null) {
        updatedItem['completed_timestamp'] =
            DateTime.now().millisecondsSinceEpoch.toString();
      }
      db!.update('items', updatedItem,
          where: 'id = ?', whereArgs: [updatedItem['id']]);
    }
    if (kDebugMode) {
      print("Completed all tasks");
    }
    _loadItems();
  }

  // This will return tasks grouped by date
  Future<Map<String, List<Map<String, dynamic>>>> _fetchCompletedTasks() async {
    if (!isDbInitialized) {
      return {}; // Return an empty map if db is not initialized
    }

    var result = await db!.query('items',
        where: 'is_picked = ?',
        whereArgs: [1],
        orderBy: 'date DESC, completed_timestamp DESC');
    Map<String, List<Map<String, dynamic>>> groupedTasks = {};

    for (var task in result) {
      String formattedDate = DateFormat('M/d/yyyy')
          .format(DateFormat('M/d/yyyy').parse(task['date'] as String));
      if (!groupedTasks.containsKey(formattedDate)) {
        groupedTasks[formattedDate] = [];
      }
      groupedTasks[formattedDate]?.add(task);
    }

    // Sort tasks within each date in descending order based on their completion timestamp
    for (var key in groupedTasks.keys) {
      groupedTasks[key]?.sort((a, b) {
        int timestampA = int.tryParse(a['completed_timestamp'] ?? "0") ?? 0;
        int timestampB = int.tryParse(b['completed_timestamp'] ?? "0") ?? 0;
        return timestampB.compareTo(timestampA);
      });
    }

    if (kDebugMode) {
      print("Grouped tasks: $groupedTasks");
    }

    return groupedTasks;
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _fetchCompletedTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("No completed tasks",
                  style: TextStyle(fontFamily: 'Roboto')));
        }
        var dates = snapshot.data!.keys.toList();
        return ListView.builder(
          itemCount: dates.length,
          itemBuilder: (context, index) {
            var date = dates[index];
            var tasksForDate = snapshot.data![date]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  // Stylish header for the date in History tab
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  margin: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      DateFormat('EEEE, y MMMM d')
                          .format(DateFormat('M/d/yyyy').parse(date)),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto'),
                    ),
                  ),
                ),
                ...tasksForDate.map((task) => ListTile(
                    title: Text(task['item_name'] as String,
                        style: const TextStyle(fontFamily: 'Roboto'))))
              ],
            );
          },
        );
      },
    );
  }

  _showAddItemDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Item Name'),
            autofocus: true,
            onSubmitted: (value) {
              FocusScope.of(context)
                  .unfocus(); // Ensure the TextField loses focus
              _addItem(value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addItem(controller.text);
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
