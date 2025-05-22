import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../provider/channel_provider.dart';

class CreateChannelScreen extends ConsumerStatefulWidget {
  const CreateChannelScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateChannelScreen> createState() =>
      _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isPrivate = false;
  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _createChannel() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await ref.read(channelProvider.notifier).createChannel(
              name: _nameController.text,
              description: _descriptionController.text,
              username: _usernameController.text,
              isPrivate: _isPrivate,
              avatarFile: _selectedImage,
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کانال با موفقیت ایجاد شد')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ایجاد کانال: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ایجاد کانال جدید'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _selectImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? const Icon(Icons.add_photo_alternate, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'نام کانال',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'لطفاً نام کانال را وارد کنید';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'توضیحات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'نام کاربری کانال (اختیاری)',
                  border: OutlineInputBorder(),
                  prefix: Text('@'),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('کانال خصوصی'),
                subtitle: const Text(
                  'کانال‌های خصوصی فقط با دعوت قابل دسترسی هستند',
                ),
                value: _isPrivate,
                onChanged: (value) => setState(() => _isPrivate = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createChannel,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('ایجاد کانال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
