import 'package:flutter/material.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint(
      'Database initialization failed: $error\n$stackTrace',
    );

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not open local storage. '
                'Restart the app and check the logs.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(
    DirectoryApp(helper: helper),
  );
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({
    super.key,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fall Festival Roster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        useMaterial3: true,
      ),
      home: DirectoryScreen(helper: helper),
    );
  }
}

class DirectoryScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const DirectoryScreen({
    super.key,
    required this.helper,
  });

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _count = 0;

  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;

  int? _selectedId;

  bool get _isEditing => _selectedId != null;

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _count = count;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Load failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            'Could not load guests. Please try Refresh.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    await _loadRows();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Enter a guest name.';
    }

    return null;
  }

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter an age.';
    }

    final age = int.tryParse(text);

    if (age == null) {
      return 'Age must be a whole number.';
    }

    if (age < 0 || age > 130) {
      return 'Age must be between 0 and 130.';
    }

    return null;
  }

  Future<void> _saveGuest() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());

    setState(() {
      _busy = true;
    });

    try {
      if (_selectedId == null) {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        _clearForm();

        try {
          final rows = await widget.helper.queryAllRows();
          final count = await widget.helper.queryRowCount();

          if (!mounted) return;

          setState(() {
            _rows = rows;
            _count = count;
          });

          _showMessage('Guest saved with ID $id.');
        } catch (error, stackTrace) {
          debugPrint(
            'Refresh after save failed: $error\n$stackTrace',
          );

          if (!mounted) return;

          _showMessage(
            'Saved, but refresh failed. Use Refresh to reload.',
          );
        }
      } else {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: _selectedId!,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });

        if (updated == 1) {
          _clearForm();

          try {
            final rows = await widget.helper.queryAllRows();
            final count = await widget.helper.queryRowCount();

            if (!mounted) return;

            setState(() {
              _rows = rows;
              _count = count;
            });

            _showMessage('Guest updated successfully.');
          } catch (error, stackTrace) {
            debugPrint(
              'Refresh after update failed: $error\n$stackTrace',
            );

            if (!mounted) return;

            _showMessage(
              'Updated, but refresh failed. Use Refresh to reload.',
            );
          }
        } else {
          _clearForm();

          await _loadRows();

          if (!mounted) return;

          _showMessage(
            'Guest was not found. The list was reloaded.',
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Save failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        'Could not save the guest. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) return;

    setState(() {
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text =
          row[DatabaseHelper.columnName].toString();
      _ageController.text =
          row[DatabaseHelper.columnAge].toString();
    });
  }

  void _cancelEdit() {
    if (_busy) return;

    _clearForm();
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();

    if (mounted) {
      setState(() {
        _selectedId = null;
      });
    }
  }

  Future<void> _deleteGuest(Map<String, dynamic> row) async {
    if (_busy) return;

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName].toString();
    final age = row[DatabaseHelper.columnAge];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete guest?'),
          content: Text(
            'Delete ID $id — $name, age $age?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      _showMessage('Deletion cancelled.');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final deleted = await widget.helper.delete(id);

      if (deleted == 1) {
        if (_selectedId == id) {
          _clearForm();
        }

        try {
          final rows = await widget.helper.queryAllRows();
          final count = await widget.helper.queryRowCount();

          if (!mounted) return;

          setState(() {
            _rows = rows;
            _count = count;
          });

          _showMessage('Guest ID $id deleted.');
        } catch (error, stackTrace) {
          debugPrint(
            'Refresh after delete failed: $error\n$stackTrace',
          );

          if (!mounted) return;

          _showMessage(
            'Deleted, but refresh failed. Use Refresh to reload.',
          );
        }
      } else {
        await _loadRows();

        if (!mounted) return;

        _showMessage(
          'Guest ID $id was not found. The list was reloaded.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Delete failed: $error\n$stackTrace',
      );

      if (!mounted) return;

      _showMessage(
        'Could not delete the guest. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildForm(),
            _buildRosterHeader(),
            Expanded(
              child: _buildRoster(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Guest name',
                  border: OutlineInputBorder(),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                validator: _validateAge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _saveGuest,
                      child: Text(
                        _isEditing ? 'Save' : 'Add',
                      ),
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancelEdit,
                        child: const Text('Cancel Edit'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          Text(
            'Guests: $_count',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoster() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'No festival guests yet.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];

        final id = row[DatabaseHelper.columnId] as int;
        final name = row[DatabaseHelper.columnName].toString();
        final age = row[DatabaseHelper.columnAge];

        return Card(
          child: ListTile(
            title: Text(name),
            subtitle: Text(
              'ID: $id   •   Age: $age',
            ),
            leading: CircleAvatar(
              child: Text('$id'),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: _busy
                      ? null
                      : () => _startEdit(row),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _busy
                      ? null
                      : () => _deleteGuest(row),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}