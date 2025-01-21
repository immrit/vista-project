// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:shamsi_date/shamsi_date.dart'; // اضافه شده
// import '/main.dart';
// import '/util/widgets.dart';
// import '/view/screen/homeScreen.dart';
// import '../../../model/NotesModel.dart';
// import '../../../provider/provider.dart';

// class AddNoteScreen extends ConsumerStatefulWidget {
//   final Note? note;
//   const AddNoteScreen({
//     super.key,
//     this.note,
//   });

//   @override
//   _AddNoteScreenState createState() => _AddNoteScreenState();
// }

// class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
//   TextEditingController titleController = TextEditingController();
//   TextEditingController contentController = TextEditingController();
//   bool isEditing = false;
//   bool isLoading = false;
//   String? lastEditedDate;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.note != null) {
//       isEditing = true;
//       titleController.text = widget.note!.title;
//       contentController.text = widget.note!.content;
//       lastEditedDate =
//           convertToJalali(widget.note!.createdAt); // تبدیل تاریخ به شمسی
//     }
//   }

//   String convertToJalali(DateTime date) {
//     final Jalali jalaliDate = Jalali.fromDateTime(date);
//     return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
//   }

//   Future<void> _saveNote() async {
//     if (isEditing) {
//       await _editNote();
//     } else {
//       await _addNote();
//     }

//     Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (context) => const HomeScreen()));
//   }

//   @override
//   void dispose() {
//     titleController.dispose();
//     contentController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentcolor = ref.watch(themeProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: isEditing == true
//             ? const Text('ویرایش')
//             : const Text('افزودن نوشته جدید'),
//         centerTitle: true,
//       ),
//       body: ListView(
//         children: [
//           Column(
//             children: [
//               addNotesTextFiels(
//                 'موضوع',
//                 1,
//                 titleController,
//                 18,
//                 FontWeight.bold,
//                 null,
//               ),
//               SizedBox(height: 5.h),
//               addNotesTextFiels('هرچه میخواهی بگو...', 50, contentController,
//                   18, FontWeight.normal, 1000),
//               const SizedBox(height: 16),
//             ],
//           ),
//         ],
//       ),
//       bottomNavigationBar: Padding(
//         padding: EdgeInsets.only(
//             bottom: MediaQuery.of(context).viewInsets.bottom + 20,
//             right: 10,
//             left: 10),
//         child: SizedBox(
//           height: 50,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               isEditing
//                   ? Align(
//                       alignment: Alignment.bottomLeft,
//                       child: Text(
//                         "آخرین ویرایش :  ${lastEditedDate ?? '---'}",
//                       ),
//                     )
//                   : Container(),
//               Align(
//                 alignment: Alignment.bottomRight,
//                 child: ElevatedButton(
//                   onPressed: isLoading ? null : _saveNote,
//                   style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(10, 50),
//                       backgroundColor:
//                           currentcolor.brightness == Brightness.dark
//                               ? Colors.white
//                               : Colors.black),
//                   child: isLoading
//                       ? const CircularProgressIndicator()
//                       : Text(
//                           isEditing ? "ویرایش" : "افزودن",
//                           style: TextStyle(
//                               color: currentcolor.brightness == Brightness.dark
//                                   ? Colors.black
//                                   : Colors.white,
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               fontFamily: 'Vazir'),
//                         ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _addNote() async {
//     final title = titleController.text;
//     final content = contentController.text;
//     setState(() {
//       isLoading = true;
//     });

//     await supabase.from('Notes').insert({
//       'title': title,
//       'content': content,
//       'user_id': Supabase.instance.client.auth.currentSession!.user.id,
//       'created_at': DateTime.now().toIso8601String(),
//     });

//     ref.invalidate(notesProvider);
//     if (mounted) {
//       setState(() {
//         isLoading = false;
//       });
//     }

//     Navigator.of(context).pop();
//   }

//   Future<void> _editNote() async {
//     final title = titleController.text;
//     final content = contentController.text;
//     setState(() {
//       isLoading = true;
//     });

//     await supabase.from('Notes').update({
//       'title': title,
//       'content': content,
//       'created_at': DateTime.now().toIso8601String(),
//     }).eq('id', widget.note!.id);

//     ref.invalidate(notesProvider);
//     if (mounted) {
//       setState(() {
//         isLoading = false;
//       });
//     }

//     Navigator.of(context).pop();
//   }
// }
