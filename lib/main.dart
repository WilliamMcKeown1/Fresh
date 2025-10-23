import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const appColor = Color(0xff8b9a5b);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Fresh",
        theme: ThemeData(
          primaryColor: appColor,
          colorScheme: ColorScheme.fromSeed(seedColor: appColor),
          scaffoldBackgroundColor: const Color(0xfff5f5f5),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: appColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: appColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: appColor, width: 2)),
          ),
        ),
        home: const AuthGate(),
      );
}

class Folder {
  String name;
  Color color;
  List<FoodItem> foodItems;
  Folder({required this.name, required this.color, List<FoodItem>? foodItems})
      : foodItems = foodItems ?? [];
}

class FoodItem {
  String name;
  DateTime expirationDate;
  String timeRemaining;
  FoodItem(this.name, this.expirationDate, this.timeRemaining);
}

class FolderListPage extends StatefulWidget {
  @override
  State<FolderListPage> createState() => _FolderListPageState();
}

class _FolderListPageState extends State<FolderListPage> {
  List<Folder> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data();
    if (data == null || data['folders'] == null) return;

    final foldersMap = Map<String, dynamic>.from(data['folders']);

    setState(() {
      _folders = foldersMap.entries.map((entry) {
        final folderName = entry.key;
        final folderData = Map<String, dynamic>.from(entry.value);

        return Folder(
          name: folderName,
          color: Color(int.parse(folderData['color'] ?? '0xff8b9a5b')),
          foodItems: (folderData['foodItems'] as List<dynamic>? ?? [])
              .map((f) => FoodItem(
                    f['name'],
                    DateTime.parse(f['expirationDate']),
                    _timeLeft(DateTime.parse(f['expirationDate'])),
                  ))
              .toList(),
        );
      }).toList();
    });
  }

  String _timeLeft(DateTime exp) {
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) return "Expired";
    return "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  Future<void> _openCreateFolderPage() async {
    final newFolder = await Navigator.push<Folder>(
        context, MaterialPageRoute(builder: (_) => CreateFolderPage()));
    if (newFolder == null) return;

    if (_folders
        .any((f) => f.name.toLowerCase() == newFolder.name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder with that name already exists')),
      );
      return;
    }

    setState(() => _folders.add(newFolder));

    // Save the new folder to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set({
        'folders': {
          newFolder.name: {
            'color': newFolder.color.toARGB32().toString(),
            'foodItems': [],
          }
        }
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Folders'),
          backgroundColor: appColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _folders.isEmpty
              ? const Center(
                  child: Text('No folders yet. Add one below.',
                      style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView(
                  children: _folders
                      .map((folder) => FolderCard(folder, onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => MyHomePage(folder: folder)))
                              ..then((_) => _loadFolders()); // reload to update
                          }))
                      .toList(),
                ),
        ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: appColor,
            child: const Icon(Icons.create_new_folder),
            onPressed: _openCreateFolderPage),
      );
}

class FoodCard extends StatelessWidget {
  final FoodItem food;
  const FoodCard(this.food, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.fastfood,
              color:
                  food.timeRemaining == "Expired" ? Colors.red : Colors.black),
          title: Text(food.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              "Expires: ${food.expirationDate.toLocal().toString().split(' ')[0]}\n${food.timeRemaining}",
              style: TextStyle(
                  color: food.timeRemaining == "Expired"
                      ? Colors.red
                      : Colors.grey.shade700,
                  fontSize: 13)),
        ),
      );
}

class FolderCard extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  const FolderCard(this.folder, {required this.onTap, super.key});
  @override
  Widget build(BuildContext context) => Card(
        color: folder.color.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
            title: Text(folder.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text("${folder.foodItems.length} items"),
            onTap: onTap),
      );
}

class CreateFolderPage extends StatefulWidget {
  @override
  State<CreateFolderPage> createState() => _CreateFolderPageState();
}

class _CreateFolderPageState extends State<CreateFolderPage> {
  final _nameCtrl = TextEditingController();
  Color _selectedColor = Colors.green.shade700;
  final _presetColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.teal,
    Colors.pink,
    Colors.indigo
  ];

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder name cannot be empty')),
      );
      return;
    }

    Navigator.pop(context, Folder(name: name, color: _selectedColor));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Create Folder'),
          backgroundColor: appColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Folder Name'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Folder Color:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ColorPicker(
                  pickerColor: _selectedColor,
                  onColorChanged: (c) => setState(() => _selectedColor = c),
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                ),
                Wrap(
                  spacing: 10,
                  children: _presetColors
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => _selectedColor = c),
                            child: CircleAvatar(
                              backgroundColor: c,
                              radius: 20,
                              child: _selectedColor == c
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class MyHomePage extends StatefulWidget {
  final Folder folder;
  const MyHomePage({super.key, required this.folder});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _foodCtrl = TextEditingController(),
      _dateCtrl = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => widget.folder.foodItems
            .forEach((f) => f.timeRemaining = _timeLeft(f.expirationDate))));
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;

    final data = doc.data()?['folders'];
    if (data == null) return;

    final folderData = data[widget.folder.name];
    if (folderData == null) return;

    setState(() {
      widget.folder.foodItems.clear();
      for (var f in folderData) {
        final expDate = DateTime.parse(f['expirationDate']);
        widget.folder.foodItems.add(
          FoodItem(f['name'], expDate, _timeLeft(expDate)),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _foodCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  String _timeLeft(DateTime exp) {
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) return "Expired";
    return "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  void _addFood() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // must be logged in

    try {
      final exp = DateTime.parse(_dateCtrl.text.trim());
      final newFood = FoodItem(_foodCtrl.text.trim(), exp, _timeLeft(exp));

      // Add to local state
      setState(() => widget.folder.foodItems.add(newFood));
      _foodCtrl.clear();
      _dateCtrl.clear();

      // Save to Firestore (preserve color + update foodItems)
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userDoc.set({
        'folders': {
          widget.folder.name: {
            'color': widget.folder.color.value.toString(),
            'foodItems': widget.folder.foodItems
                .map((f) => {
                      'name': f.name,
                      'expirationDate': f.expirationDate.toIso8601String(),
                    })
                .toList(),
          }
        }
      }, SetOptions(merge: true)); // merge to keep other folders intact
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid date format')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.folder.name),
            backgroundColor: widget.folder.color),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                controller: _foodCtrl,
                decoration: const InputDecoration(labelText: 'Food Name')),
            const SizedBox(height: 12),
            TextField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                    labelText: 'Expiration Date (YYYY-MM-DD)'),
                keyboardType: TextInputType.datetime),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _addFood, child: const Text('Add Food')),
            const SizedBox(height: 20),
            Expanded(
              child: widget.folder.foodItems.isEmpty
                  ? const Center(
                      child: Text('No food added yet.',
                          style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : ListView(
                      children: widget.folder.foodItems
                          .map((f) => FoodCard(f))
                          .toList()),
            )
          ]),
        ),
      );
}
