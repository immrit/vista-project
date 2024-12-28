import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/provider.dart';
import 'Notes/AddNoteScreen.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsyncValue = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'جستجوی یادداشت',
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'جستجو...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  enabledBorder: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ),
            Expanded(
              child: notesAsyncValue.when(
                data: (notes) {
                  // فیلتر کردن یادداشت‌ها بر اساس عبارت جستجو
                  final filteredNotes = searchQuery.isEmpty
                      ? notes
                      : notes
                          .where((note) =>
                              note.title.contains(searchQuery) ||
                              note.content.contains(searchQuery))
                          .toList();

                  if (filteredNotes.isEmpty) {
                    return const Center(
                      child: Text(
                        'نتیجه‌ای یافت نشد',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text(
                              note.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: () {
                              // باز کردن صفحه ویرایش یادداشت
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddNoteScreen(note: note),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    'خطا در بارگذاری: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
