import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/primary_button.dart';

class AddBookPage extends StatefulWidget {
  final Map<String, dynamic>? book; // null = add mode, filled = edit mode

  const AddBookPage({super.key, this.book});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _isbnController;
  late TextEditingController _ratingController;

  late String _selectedGenre;
  late String _selectedCondition;
  late String _selectedLanguage;

  final _client = Supabase.instance.client;
  bool _loading = false;

  final List<String> _genres = [
    'Fiction',
    'Science Fiction',
    'Fantasy',
    'Mystery',
    'Thriller',
    'Horror',
    'History',
    'Biography',
    'Self-Help',
    'Science',
    'Business',
    'Poetry',
    'Romance',
    'Adventure',
    'Children',
    'Other',
  ];

  final List<String> _conditions = ['excellent', 'good', 'fair', 'poor'];
  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Hindi',
    'Mandarin',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      // Edit mode - populate with existing data
      _titleController = TextEditingController(text: widget.book!['title']);
      _authorController = TextEditingController(
        text: widget.book!['author'] ?? '',
      );
      _isbnController = TextEditingController(text: widget.book!['isbn'] ?? '');
      _ratingController = TextEditingController(
        text: (widget.book!['rating'] ?? '').toString(),
      );
      _selectedGenre = widget.book!['genre'] ?? 'Fiction';
      _selectedCondition = widget.book!['condition'] ?? 'good';
      _selectedLanguage = widget.book!['language'] ?? 'English';
    } else {
      // Add mode - empty controllers
      _titleController = TextEditingController();
      _authorController = TextEditingController();
      _isbnController = TextEditingController();
      _ratingController = TextEditingController();
      _selectedGenre = 'Fiction';
      _selectedCondition = 'good';
      _selectedLanguage = 'English';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _saveBook() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    setState(() => _loading = true);

    try {
      final bookData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'isbn': _isbnController.text.trim(),
        'genre': _selectedGenre,
        'condition': _selectedCondition,
        'language': _selectedLanguage,
        'rating': _ratingController.text.isEmpty
            ? 0
            : double.tryParse(_ratingController.text) ?? 0,
      };

      if (widget.book != null) {
        // Edit mode
        await _client
            .from('books')
            .update(bookData)
            .eq('id', widget.book!['id']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book updated successfully')),
        );
      } else {
        // Add mode
        final userId = _client.auth.currentUser!.id;
        bookData['owner_id'] = userId;

        await _client.from('books').insert(bookData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book added successfully')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.book != null;

    return AppScaffold(
      title: isEditMode ? 'Edit Book' : 'Add Book',
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Title (required)
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title *',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Author
            TextField(
              controller: _authorController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Author',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ISBN
            TextField(
              controller: _isbnController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ISBN',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Genre Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedGenre,
              items: _genres.map((genre) {
                return DropdownMenuItem(value: genre, child: Text(genre));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGenre = value ?? 'Fiction');
              },
              decoration: InputDecoration(
                labelText: 'Genre',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
              dropdownColor: const Color(0xFF1e293b),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Condition Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCondition,
              items: _conditions.map((condition) {
                return DropdownMenuItem(
                  value: condition,
                  child: Text(
                    condition[0].toUpperCase() + condition.substring(1),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCondition = value ?? 'good');
              },
              decoration: InputDecoration(
                labelText: 'Condition',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
              dropdownColor: const Color(0xFF1e293b),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Language Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              items: _languages.map((language) {
                return DropdownMenuItem(value: language, child: Text(language));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedLanguage = value ?? 'English');
              },
              decoration: InputDecoration(
                labelText: 'Language',
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
              dropdownColor: const Color(0xFF1e293b),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Rating (optional)
            TextField(
              controller: _ratingController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Rating (0-5)',
                labelStyle: const TextStyle(color: Colors.white),
                hintText: 'e.g., 4.5',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            PrimaryButton(
              text: isEditMode ? 'Update Book' : 'Add Book',
              loading: _loading,
              onPressed: _saveBook,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
