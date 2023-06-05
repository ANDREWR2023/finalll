import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final databasePath = await sqflite.getDatabasesPath();
  sqflite.databaseFactory = sqflite.databaseFactoryFfi;
  final database = await sqflite.openDatabase(
    path.join(databasePath, 'app_store.db'),
    version: 1,
  );

  runApp(AppStoreApp(database));
}

class AppStoreApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Store',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<sqflite.Database> _openDatabase() async {
    final databasePath = await sqflite.getDatabasesPath();
    final database = await sqflite.openDatabase(
      path.join(databasePath, 'app_store.db'),
      onCreate: (db, version) {
        db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT,
          password TEXT
        )
      ''');
      },
      version: 1,
    );

    return database;
  }

  Future<void> _login(BuildContext context) async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    final database = await _openDatabase();

// Execute SQL query to check username and password
    final results = await database.rawQuery(
      'SELECT * FROM accounts WHERE username = ? AND password = ?',
      [username, password],
    );

    await database.close();

    bool isLoggedIn = results.isNotEmpty;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AppListPage(username),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Login Failed'),
            content: Text('Invalid username or password.'),
            actions: [
              FloatingActionButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
              ),
            ),
            SizedBox(height: 10.0),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            SizedBox(height: 20.0),
            FloatingActionButton(
              child: Text('Login'),
              onPressed: () {
                _login(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AppListPage extends StatefulWidget {
  final String username;

  AppListPage(this.username);

  @override
  _AppListPageState createState() => _AppListPageState();
}

class _AppListPageState extends State<AppListPage> {
  List<App> _appList = [];

  Future<sqflite.Database> _openDatabase() async {
    final databasePath = await sqflite.getDatabasesPath();
    final database = sqflite.openDatabase(
      path.join(databasePath, 'app_store.db'),
      onCreate: (db, version) {
        db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT,
          password TEXT
        )
      ''');
      },
      version: 1,
    );

    return database;
  }

  Future<void> _getApps() async {
    final database = await _openDatabase();
// Execute SQL query to retrieve app list
    final results = await database.rawQuery('SELECT * FROM apps');

    await database.close();

    List<App> apps = results.map((row) {
      return App(
        row['name'] as String,
        row['developer'] as String,
        row['link'] as String,
      );
    }).toList();

    setState(() {
      _appList = apps;
    });
  }

  Future<void> _removeApp(App app) async {
    final database = await _openDatabase();
    await database.rawDelete(
      'DELETE FROM apps WHERE name = ? AND developer = ?',
      [app.name, app.developer],
    );

    await database.close();

    setState(() {
      _appList.remove(app);
    });
  }

  @override
  void initState() {
    super.initState();
    _getApps();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App List'),
      ),
      body: ListView.builder(
        itemCount: _appList.length,
        itemBuilder: (context, index) {
          final app = _appList[index];
          return Card(
            child: ListTile(
              title: Text(app.name),
              subtitle: Text(app.developer),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(app.name),
                      content: Text(app.link),
                      actions: [
                        FloatingActionButton(
                          child: Text('Close'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              trailing: (widget.username == app.developer ||
                      widget.username == 'admin')
                  ? IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _removeApp(app);
                      },
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class App {
  final String name;
  final String developer;
  final String link;

  App(this.name, this.developer, this.link);
}
