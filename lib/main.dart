
import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'models/folder.dart';
import 'models/card_record.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  
try {
  await helper.init();
} catch (error, stackTrace) {

    debugPrint('Database initialization failed: $error\n$stackTrace');

    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Check the logs and restart.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    return;
  }

  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;

  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Catalogue',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: FolderScreen(helper: helper),
    );
  }
}

// ============================================================
// FOLDER SCREEN
// ============================================================

class FolderScreen extends StatefulWidget {
  final DatabaseHelper helper;

  const FolderScreen({super.key, required this.helper});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final _folderController = TextEditingController();

  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final folders = await widget.helper.getFolders();

      if (!mounted) return;

      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load folders. Please try again.';
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _addFolder() async {
    if (_busy) return;

    final name = _folderController.text.trim();

    if (name.isEmpty) {
      _message('Enter a folder name.');
      return;
    }

    setState(() => _busy = true);

    try {
      await widget.helper.createFolder(name);

      _folderController.clear();
      await _loadFolders();

      _message('Folder created.');
    } catch (error) {
      _message(
        'Could not create folder. The name may already exist.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" and all its cards?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final deleted =
          await widget.helper.deleteFolder(folder.id);

      await _loadFolders();

      _message(
        deleted == 1
            ? 'Folder and its cards deleted.'
            : 'Folder not found. The list was refreshed.',
      );
    } catch (error) {
      _message('Could not delete folder. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _folderController,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'New folder name',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addFolder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _addFolder,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _folders.isEmpty
                          ? const Center(
                              child: Text(
                                'No folders yet. Add one above.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: _folders.length,
                              itemBuilder: (context, index) {
                                final folder = _folders[index];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.folder_outlined,
                                    ),
                                    title: Text(folder.name),
                                    subtitle: Text(
                                      '${folder.cardCount} cards',
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CardScreen(
                                            helper: widget.helper,
                                            folder: folder,
                                          ),
                                        ),
                                      ).then((_) => _loadFolders());
                                    },
                                    trailing: IconButton(
                                      tooltip: 'Delete folder',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _deleteFolder(folder),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARD SCREEN
// ============================================================

class CardScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;

  const CardScreen({
    super.key,
    required this.helper,
    required this.folder,
  });

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  List<CardRecord> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cards =
          await widget.helper.getCards(widget.folder.id);

      if (!mounted) return;

      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load cards. Please try again.';
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _editCard([CardRecord? existing]) async {
    if (_busy) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CardFormDialog(
        helper: widget.helper,
        folderId: widget.folder.id,
        existing: existing,
      ),
    );

    if (result == true) {
      await _loadCards();
    }
  }

  Future<void> _deleteCard(CardRecord card) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete "${card.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      final deleted =
          await widget.helper.deleteCard(card.id);

      await _loadCards();

      _message(
        deleted == 1
            ? 'Card deleted.'
            : 'Card not found. The list was refreshed.',
      );
    } catch (error) {
      _message('Could not delete card. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _editCard(),
        icon: const Icon(Icons.add),
        label: const Text('Add card'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(child: Text(_error!))
              : _cards.isEmpty
                  ? const Center(
                      child: Text(
                        'No cards in this folder yet.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        final card = _cards[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          child: ListTile(
                            leading: Text(
                              card.suitSymbol,
                              style: const TextStyle(fontSize: 28),
                            ),
                            title: Text(card.title),
                            subtitle: Text(
                              '${card.suit} • ID: ${card.id}\n'
                              '${card.notes.isEmpty ? "No notes" : card.notes}',
                            ),
                            isThreeLine: true,
                            onTap: () => _editCard(card),
                            trailing: IconButton(
                              tooltip: 'Delete card',
                              icon: const Icon(
                                Icons.delete_outline,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _deleteCard(card),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ============================================================
// ADD / EDIT CARD DIALOG
// ============================================================

class CardFormDialog extends StatefulWidget {
  final DatabaseHelper helper;
  final int folderId;
  final CardRecord? existing;

  const CardFormDialog({
    super.key,
    required this.helper,
    required this.folderId,
    this.existing,
  });

  @override
  State<CardFormDialog> createState() =>
      _CardFormDialogState();
}

class _CardFormDialogState extends State<CardFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late String _suit;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );

    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );

    _suit = widget.existing?.suit ?? 'Hearts';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final existing = widget.existing;

      if (existing == null) {
        await widget.helper.createCard(
          title: _titleController.text,
          suit: _suit,
          folderId: widget.folderId,
          notes: _notesController.text,
        );
      } else {
        final updated = await widget.helper.updateCard(
          id: existing.id,
          title: _titleController.text,
          suit: _suit,
          folderId: widget.folderId,
          notes: _notesController.text,
          imageRef: existing.imageRef,
        );

        if (updated != 1) {
          throw StateError('The card was not found.');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not save the card. Check the title and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add card' : 'Edit card',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                validator: (value) =>
                    value?.trim().isNotEmpty == true
                        ? null
                        : 'Enter a title.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _suit,
                decoration: const InputDecoration(
                  labelText: 'Suit',
                ),
                items: DatabaseHelper.allowedSuits
                    .map(
                      (suit) => DropdownMenuItem(
                        value: suit,
                        child: Text(suit),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _suit = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
