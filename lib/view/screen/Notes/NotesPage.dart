import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../provider/provider.dart';
import '../../../util/widgets.dart';
import 'AddNoteScreen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsyncValue = ref.watch(notesProvider);
    final getprofile = ref.watch(profileProvider);
    final currentcolor = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vista Notes"),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).push(createSearchPageRoute());
          },
          icon: const Icon(Icons.search),
        ),
      ),
      endDrawer: CustomDrawer(getprofile, currentcolor, context, ref),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: notesAsyncValue.when(
          data: (notes) {
            final pinnedNotes = notes.where((note) => note.isPinned).toList();
            final otherNotes = notes.where((note) => !note.isPinned).toList();

            pinnedNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            otherNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return RefreshIndicator(
              onRefresh: () async {
                ref.refresh(notesProvider);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView(
                  children: [
                    if (pinnedNotes.isNotEmpty) ...[
                      const Text(
                        'پین شده ها:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      NoteGridWidget(notes: pinnedNotes, ref: ref),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'سایر یادداشت‌ها:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    NoteGridWidget(notes: otherNotes, ref: ref),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('دسترسی به اینترنت قطع است :('),
              IconButton(
                iconSize: 50,
                splashColor: Colors.transparent,
                color: Colors.white,
                onPressed: () {
                  ref.refresh(notesProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          )),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.edit),
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddNoteScreen()));
        },
      ),
    );
  }
}
