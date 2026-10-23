import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile_customization/models/profile_setup_state.dart';

/// Screen allowing the user to edit their username, bio, avatar, and banner.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  String? _selectedAvatar;
  String? _selectedBanner;
  int? _selectedColorValue;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileViewModelProvider);
    _usernameController = TextEditingController(text: profile.username);
    _bioController = TextEditingController(text: profile.bio);
    _selectedAvatar = profile.presetAvatar;
    _selectedBanner = profile.bannerAsset;
    _selectedColorValue = profile.bannerColorValue;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username cannot be empty')));
      return;
    }

    ref
        .read(profileViewModelProvider.notifier)
        .updateProfile(
          username: username,
          bio: bio,
          presetAvatar: _selectedAvatar,
          bannerAsset: _selectedBanner,
          bannerColorValue: _selectedColorValue,
          clearBanner: _selectedBanner == null,
          clearColor: _selectedColorValue == null,
        );

    await ref.read(profileViewModelProvider.notifier).save();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.shellHeaderBlue,
              size: 32,
            ),
          ),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.dmSans(
            color: AppColors.shellHeaderBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(
              'Save',
              style: GoogleFonts.dmSans(
                color: AppColors.shellHeaderBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Choose Avatar
            Text(
              'Choose Avatar',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppAssets.spotterAvatars.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final avatar = AppAssets.spotterAvatars[index];
                  final isSelected = _selectedAvatar == avatar;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatar = avatar;
                      });
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.shellHeaderBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(avatar, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Choose Banner Color
            Text(
              'Choose Banner Preset',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildColorOption(0xFFBCE7B4),
                  _buildColorOption(0xFFC59296),
                  _buildColorOption(0xFFA4DDFF),
                  _buildColorOption(0xFFFFF2BD),
                  _buildColorOption(0xFFE2E8F0),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Username Field
            Text(
              'Username',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              maxLength: ProfileSetupState.maxUsernameLength,
              decoration: InputDecoration(
                hintText: 'Enter username',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.shellHeaderBlue,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bio Field
            Text(
              'Bio',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLength: ProfileSetupState.maxBioLength,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter bio',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.shellHeaderBlue,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(int colorValue) {
    final isSelected = _selectedColorValue == colorValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorValue = colorValue;
          _selectedBanner = null;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.shellHeaderBlue : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 24)
            : null,
      ),
    );
  }
}
