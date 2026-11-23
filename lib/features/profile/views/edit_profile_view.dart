import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:faunawatch/core/constants/app_assets.dart';
import 'package:faunawatch/core/constants/app_colors.dart';
import 'package:faunawatch/core/theme/app_palette_colors.dart';
import 'package:faunawatch/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:faunawatch/features/profile/views/widgets/edit_profile_avatar_sheet.dart';
import 'package:faunawatch/features/profile_customization/models/profile_setup_state.dart';

/// Non-scrollable single-screen profile appearance editor for avatar,
/// username, bio, and profile banner.
class EditProfileView extends ConsumerStatefulWidget {
  const EditProfileView({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  late final String _initialUsername;
  late final String _initialBio;
  late final String? _initialAvatarUrl;
  late final String? _initialPresetAvatar;
  late final String? _initialCustomImagePath;
  late final String? _initialBanner;
  late final int? _initialColorValue;

  String? _selectedAvatar;
  String? _customImagePath;
  bool _avatarChanged = false;
  String? _selectedBanner;
  int? _selectedColorValue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileViewModelProvider).requireValue;
    _initialUsername = profile.username;
    _initialBio = profile.bio;
    _initialAvatarUrl = profile.avatarUrl;
    _initialPresetAvatar = profile.presetAvatar;
    _initialCustomImagePath = profile.customImagePath;
    _initialBanner = profile.bannerAsset;
    _initialColorValue = profile.bannerColorValue;

    _usernameController = TextEditingController(text: profile.username)
      ..addListener(_onTextChanged);
    _bioController = TextEditingController(text: profile.bio)
      ..addListener(_onTextChanged);
    _selectedAvatar = profile.presetAvatar;
    _customImagePath = profile.customImagePath;
    _selectedBanner = profile.bannerAsset;
    _selectedColorValue = profile.bannerColorValue;
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_onTextChanged)
      ..dispose();
    _bioController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasChanges {
    final usernameChanged =
        _usernameController.text.trim() != _initialUsername.trim();
    final bioChanged = _bioController.text.trim() != _initialBio.trim();
    final avatarChanged =
        _selectedAvatar != _initialPresetAvatar ||
        _customImagePath != _initialCustomImagePath;
    final bannerChanged =
        _selectedBanner != _initialBanner ||
        _selectedColorValue != _initialColorValue;
    return usernameChanged || bioChanged || avatarChanged || bannerChanged;
  }

  bool get _canSave =>
      _hasChanges && _usernameController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _openAvatarPicker() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileAvatarSheet(selectedAvatar: _selectedAvatar),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedAvatar = picked;
      _customImagePath = null;
      _avatarChanged =
          _selectedAvatar != _initialPresetAvatar ||
          _customImagePath != _initialCustomImagePath;
    });
  }

  Future<void> _handleUploadImage() async {
    FocusScope.of(context).unfocus();
    final pickedPath = await ref
        .read(profileViewModelProvider.notifier)
        .pickCustomAvatar();
    if (!mounted || pickedPath == null) return;
    setState(() {
      _customImagePath = pickedPath;
      _selectedAvatar = null;
      _avatarChanged = true;
    });
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;
    final previous = ref.read(profileViewModelProvider).asData?.value;
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    ref
        .read(profileViewModelProvider.notifier)
        .updateProfile(
          username: username,
          bio: bio,
          presetAvatar: _avatarChanged ? _selectedAvatar : null,
          customImagePath: _avatarChanged ? _customImagePath : null,
          clearPreset: _avatarChanged && _selectedAvatar == null,
          clearCustom: _avatarChanged && _customImagePath == null,
          bannerAsset: _selectedBanner,
          bannerColorValue: _selectedColorValue,
          clearBanner: _selectedBanner == null,
          clearColor: _selectedColorValue == null,
        );

    setState(() => _isSaving = true);
    final success = await ref.read(profileViewModelProvider.notifier).save();

    if (!success && previous != null) {
      ref.read(profileViewModelProvider.notifier).restoreProfile(previous);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save profile. Please try again.'),
        ),
      );
    }
  }

  Widget _buildAvatarPreview() {
    if (_customImagePath != null && _customImagePath!.isNotEmpty && !kIsWeb) {
      return Image.file(
        File(_customImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    if (_selectedAvatar != null && _selectedAvatar!.isNotEmpty) {
      return Image.asset(
        _selectedAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    if (!_avatarChanged && _initialAvatarUrl != null) {
      return Image.network(
        _initialAvatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Image.asset(AppAssets.avatarTweety, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPaletteColors.of(context);
    final surfaceColor = palette.resolve(Colors.white, scheme.surface);
    final titleColor = isDark ? scheme.primary : palette.navLabelBlue;
    final backColor = isDark ? scheme.primary : palette.shellHeaderBlue;
    final dividerColor = isDark
        ? AppColors.darkBorder
        : AppColors.profileDivider;
    final hintColor = isDark
        ? scheme.onSurfaceVariant
        : AppColors.editProfileHintBlue;
    final fieldFillColor = isDark
        ? scheme.surfaceContainerLow
        : AppColors.editProfileFieldBackground;
    final fieldBorderColor = isDark
        ? AppColors.darkBorder
        : AppColors.editProfileFieldBorder;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 50,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: 'Back',
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.chevron_left_rounded, color: backColor, size: 30),
          ),
        ),
        title: Text(
          'Profile Appearance',
          style: GoogleFonts.dmSans(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final isCompact = h < 600;
            final avatarSize = (h * 0.175).clamp(72.0, 118.0);
            final sectionGap = isCompact ? 10.0 : 16.0;
            final innerGap = isCompact ? 8.0 : 12.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isCompact ? 4 : 12),
                  // Avatar Preview
                  Center(
                    child: SizedBox.square(
                      dimension: avatarSize,
                      child: ClipOval(child: _buildAvatarPreview()),
                    ),
                  ),
                  SizedBox(height: isCompact ? 10 : 16),
                  // Avatar Action Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionPillButton(
                        label: 'Choose Avatar',
                        compact: isCompact,
                        onTap: _openAvatarPicker,
                      ),
                      const SizedBox(width: 12),
                      _ActionPillButton(
                        label: 'Upload Image',
                        compact: isCompact,
                        onTap: _handleUploadImage,
                      ),
                    ],
                  ),
                  SizedBox(height: sectionGap),
                  Container(height: 1, color: dividerColor),
                  SizedBox(height: innerGap),
                  // Editable Username & Bio
                  Text(
                    'Click to edit',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Text(
                        '${_usernameController.text.length}/${ProfileSetupState.maxUsernameLength} characters',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    key: const ValueKey('edit_profile_username_field'),
                    controller: _usernameController,
                    maxLength: ProfileSetupState.maxUsernameLength,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                    style: GoogleFonts.dmSans(
                      fontSize: isCompact ? 19 : 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.3,
                    ),
                    decoration: _inputDecoration(
                      hintText: 'username',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: isCompact ? 19 : 22,
                        fontWeight: FontWeight.w700,
                        color: hintColor.withValues(alpha: 0.7),
                      ),
                      fillColor: fieldFillColor,
                      borderColor: fieldBorderColor,
                      focusedColor: backColor,
                      borderRadius: 12,
                      verticalPadding: isCompact ? 8 : 11,
                    ),
                  ),
                  SizedBox(height: isCompact ? 6 : 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Text(
                        '${_bioController.text.length}/${ProfileSetupState.maxBioLength} characters',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    key: const ValueKey('edit_profile_bio_field'),
                    controller: _bioController,
                    maxLength: ProfileSetupState.maxBioLength,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                    style: GoogleFonts.dmSans(
                      fontSize: isCompact ? 12.5 : 13.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                    decoration: _inputDecoration(
                      hintText: 'bio',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: isCompact ? 12.5 : 13.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: hintColor.withValues(alpha: 0.75),
                      ),
                      fillColor: fieldFillColor,
                      borderColor: fieldBorderColor,
                      focusedColor: backColor,
                      borderRadius: 10,
                      verticalPadding: isCompact ? 6 : 8,
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  Container(height: 1, color: dividerColor),
                  SizedBox(height: innerGap),
                  // Profile Banner Heading
                  Text(
                    'Profile Banner',
                    style: GoogleFonts.dmSans(
                      fontSize: isCompact ? 14.5 : 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                  // 2x2 Grid: 3 Preset Banners + 2x3 Color Swatches
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, gridConstraints) {
                        const colGap = 16.0;
                        final rowGap = isCompact ? 10.0 : 14.0;
                        final bottomPad = isCompact ? 8.0 : 16.0;
                        final availH = math.max(
                          0.0,
                          gridConstraints.maxHeight - bottomPad,
                        );
                        final colW = math.max(
                          0.0,
                          (gridConstraints.maxWidth - colGap) / 2,
                        );
                        final idealRowH = (colW * 0.62).clamp(60.0, 118.0);
                        final gridH = math.min(availH, idealRowH * 2 + rowGap);
                        final rowH = math.max(0.0, (gridH - rowGap) / 2);

                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: gridH,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: rowH,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildBannerTile(
                                          AppAssets.presetBanners[0],
                                          0,
                                        ),
                                      ),
                                      const SizedBox(width: colGap),
                                      Expanded(
                                        child: _buildBannerTile(
                                          AppAssets.presetBanners[1],
                                          1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: rowGap),
                                SizedBox(
                                  height: rowH,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildBannerTile(
                                          AppAssets.presetBanners[2],
                                          2,
                                        ),
                                      ),
                                      const SizedBox(width: colGap),
                                      Expanded(
                                        child: _buildColorGrid(
                                          maxWidth: colW,
                                          maxHeight: rowH,
                                          surfaceColor: surfaceColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _SaveChangesBar(
        enabled: _canSave,
        isSaving: _isSaving,
        onTap: _canSave ? _handleSave : null,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required TextStyle hintStyle,
    required Color fillColor,
    required Color borderColor,
    required Color focusedColor,
    required double borderRadius,
    required double verticalPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      filled: true,
      fillColor: fillColor,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: verticalPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: focusedColor, width: 1.6),
      ),
    );
  }

  Widget _buildBannerTile(String bannerAsset, int index) {
    final isSelected = _selectedBanner == bannerAsset;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Banner ${index + 1}',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedBanner = bannerAsset;
            _selectedColorValue = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: AppColors.profileSelectedOrange, width: 4.5)
                : null,
          ),
          child: Image.asset(
            bannerAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildColorGrid({
    required double maxWidth,
    required double maxHeight,
    required Color surfaceColor,
  }) {
    final circleSize = math
        .min((maxHeight - 8) / 2, (maxWidth - 16) / 3)
        .clamp(22.0, 40.0);

    Widget buildSwatch(int index) {
      final color = AppColors.bannerColors[index];
      final colorValue = color.toARGB32();
      final isSelected = _selectedColorValue == colorValue;
      return Semantics(
        button: true,
        selected: isSelected,
        label: 'Banner color ${index + 1}',
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedColorValue = colorValue;
              _selectedBanner = null;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? surfaceColor : color,
              border: isSelected
                  ? Border.all(
                      color: AppColors.profileSelectedOrange,
                      width: 3.5,
                    )
                  : null,
            ),
            padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: isSelected
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [buildSwatch(0), buildSwatch(1), buildSwatch(2)],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [buildSwatch(3), buildSwatch(4), buildSwatch(5)],
        ),
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.editProfileActionTeal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 20,
              vertical: compact ? 8 : 10,
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: AppColors.editProfileSaveActiveBackground,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveChangesBar extends StatelessWidget {
  const _SaveChangesBar({
    required this.enabled,
    required this.isSaving,
    required this.onTap,
  });

  final bool enabled;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? AppColors.editProfileSaveActiveBackground
        : AppColors.editProfileSaveInactiveBackground;
    final foregroundColor = enabled
        ? AppColors.editProfileSaveActiveText
        : AppColors.editProfileSaveInactiveText;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Save Changes',
      child: AnimatedContainer(
        key: const ValueKey('edit_profile_save_bar'),
        duration: const Duration(milliseconds: 150),
        color: backgroundColor,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Center(
                  child: isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: foregroundColor,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.dmSans(
                            color: foregroundColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
