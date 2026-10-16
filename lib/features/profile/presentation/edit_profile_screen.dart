import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import 'widgets/editable_avatar.dart';
import 'widgets/profile_text_field.dart';

/// "Modifier le profil": EditableAvatar, then name, e-mail (read-only),
/// phone and bio (ProfileTextField), then "Enregistrer".
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileRepository().getUserProfile();
    if (!mounted || profile == null) return;
    setState(() {
      if ((profile['full_name'] as String?)?.isNotEmpty ?? false) {
        _nameController.text = profile['full_name'] as String;
      }
      _phoneController.text = profile['phone'] as String? ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ProfileRepository();

    // Upload new avatar if selected
    if (_imageFile != null) {
      await repo.uploadProfilePicture(_imageFile!);
    }

    final success = await repo.updateProfile(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? AppLocalizations.of(context)!.profileUpdated : AppLocalizations.of(context)!.failedToUpdateProfile),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(size.width * 0.05),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              EditableAvatar(imageFile: _imageFile, onPick: _pickImage),
              SizedBox(height: size.height * 0.04),
              
              ProfileTextField(
                controller: _nameController,
                label: AppLocalizations.of(context)!.fullName,
                icon: Icons.person_outline,
                validator: (value) => value!.isEmpty ? AppLocalizations.of(context)!.pleaseEnterName : null,
              ),
              SizedBox(height: size.height * 0.02),

              ProfileTextField(
                controller: _emailController,
                label: AppLocalizations.of(context)!.email,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: false, // Email usually not editable directly
              ),
              SizedBox(height: size.height * 0.02),

              ProfileTextField(
                controller: _phoneController,
                label: AppLocalizations.of(context)!.phoneNumberLabel,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: size.height * 0.02),

              ProfileTextField(
                controller: _bioController,
                label: AppLocalizations.of(context)!.bio,
                icon: Icons.info_outline,
                maxLines: 3,
              ),
              
              SizedBox(height: size.height * 0.05),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.saveChanges,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
