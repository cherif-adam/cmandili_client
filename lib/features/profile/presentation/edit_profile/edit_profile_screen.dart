import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'edit_profile_controller.dart';
import 'widgets/editable_avatar.dart';
import 'widgets/profile_text_field.dart';

/// "Modifier le profil": EditableAvatar, then name, e-mail (read-only),
/// phone and bio (ProfileTextField), then "Enregistrer".
///
/// UI only: loading and saving the profile, the picked avatar and the name
/// rule live in [EditProfileController]; the text fields and the image
/// picker stay here.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  /// This screen's own controller (see [editProfileControllerProvider]).
  late final _provider = editProfileControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(_provider.notifier).initialValues();
    _nameController = TextEditingController(text: initial.name);
    _emailController = TextEditingController(text: initial.email);
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageFile = ref.watch(_provider);

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
              EditableAvatar(imageFile: imageFile, onPick: _pickImage),
              SizedBox(height: size.height * 0.04),
              _ProfileFields(
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                bioController: _bioController,
              ),
              SizedBox(height: size.height * 0.05),
              _SaveButton(onPressed: _saveProfile),
            ],
          ),
        ),
      ),
    );
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final profile = await ref.read(_provider.notifier).loadProfile();
    if (!mounted || profile == null) return;
    setState(() {
      if (profile.name != null) _nameController.text = profile.name!;
      _phoneController.text = profile.phone;
    });
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final controller = ref.read(_provider.notifier);
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      controller.setAvatar(File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(_provider.notifier).save(
          name: _nameController.text,
          phone: _phoneController.text,
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
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Name, e-mail (read-only), phone and bio.
class _ProfileFields extends StatelessWidget {
  const _ProfileFields({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController bioController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileTextField(
          controller: nameController,
          label: AppLocalizations.of(context)!.fullName,
          icon: Icons.person_outline,
          validator: (value) => EditProfileController.isNameMissing(value)
              ? AppLocalizations.of(context)!.pleaseEnterName
              : null,
        ),
        SizedBox(height: size.height * 0.02),

        ProfileTextField(
          controller: emailController,
          label: AppLocalizations.of(context)!.email,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: false, // Email usually not editable directly
        ),
        SizedBox(height: size.height * 0.02),

        ProfileTextField(
          controller: phoneController,
          label: AppLocalizations.of(context)!.phoneNumberLabel,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: size.height * 0.02),

        ProfileTextField(
          controller: bioController,
          label: AppLocalizations.of(context)!.bio,
          icon: Icons.info_outline,
          maxLines: 3,
        ),
      ],
    );
  }
}

/// The wide "Enregistrer les modifications" button.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
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
    );
  }
}
