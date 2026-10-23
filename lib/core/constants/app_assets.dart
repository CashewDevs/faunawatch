/// Centralized asset path constants for images, icons, and animations.
///
/// Prevents hardcoded magic strings in views.
abstract final class AppAssets {
  // Base directories
  static const String imagesPath = 'assets/images';
  static const String iconsPath = 'assets/icons';
  static const String animationsPath = 'assets/animations';

  // Images (Add image asset paths here as assets are introduced)
  static const String welcomeBackground = '$imagesPath/welcbg.webp';
  static const String loginDesign = '$imagesPath/loginD.webp';
  static const String signUpDesign = '$imagesPath/signupD.webp';
  static const String introBackground = '$imagesPath/inBG.webp';

  // Icons (Add custom SVG / vector icon asset paths here)
  static const String appLogo = '$iconsPath/fwLogo.webp';
  static const String appWordmark = '$iconsPath/fwWM.webp';
  static const String usernameIcon = '$iconsPath/username.webp';
  static const String passwordIcon = '$iconsPath/pass.webp';
  static const String seePasswordIcon = '$iconsPath/seePass.webp';
  static const String hidePasswordIcon = '$iconsPath/hidePass.webp';
  static const String whoIcon = '$iconsPath/who.webp';
  static const String uploadIcon = '$iconsPath/up-load.webp';
  static const String whereIcon = '$iconsPath/where.webp';
  static const String backArrowIcon = '$iconsPath/left.webp';
  static const String addImageIcon = '$iconsPath/addIM.webp';
  static const String sendMessageIcon = '$iconsPath/sendM.webp';

  // Spotter Avatars
  static const String avatarPanda = '$imagesPath/panda.webp';
  static const String avatarBunny = '$imagesPath/bunny.webp';
  static const String avatarTweety = '$imagesPath/tweety.webp';
  static const String avatarGarfield = '$imagesPath/garfield.webp';
  static const String avatarIce = '$imagesPath/ice.webp';
  static const String avatarSnoop = '$imagesPath/snoop.webp';
  static const String avatarJerry = '$imagesPath/jerry.webp';
  static const String avatarPerry = '$imagesPath/perry.webp';
  static const String avatarGrizz = '$imagesPath/grizz.webp';

  static const List<String> spotterAvatars = [
    avatarPanda,
    avatarBunny,
    avatarTweety,
    avatarGarfield,
    avatarIce,
    avatarSnoop,
    avatarJerry,
    avatarPerry,
    avatarGrizz,
  ];

  // Profile Banners
  static const String bannerDay = '$imagesPath/day.webp';
  static const String bannerSunset = '$imagesPath/sunset.webp';
  static const String bannerNight = '$imagesPath/night.webp';

  static const List<String> presetBanners = [
    bannerDay,
    bannerSunset,
    bannerNight,
  ];

  // Actions
  static const String proceedButton = '$imagesPath/proceed.webp';
  static const String slideUpButton = '$iconsPath/slideUP.webp';
  static const String forwardButton = '$iconsPath/forward.webp';

  // Navigation Icons
  static const String navFeedUnpressed = '$iconsPath/feed1.webp';
  static const String navFeedPressed = '$iconsPath/feed2.webp';
  static const String navPhotosUnpressed = '$iconsPath/photos1.webp';
  static const String navPhotosPressed = '$iconsPath/photos2.webp';
  static const String navMapUnpressed = '$iconsPath/map1.webp';
  static const String navMapPressed = '$iconsPath/map2.webp';
  static const String navChatsUnpressed = '$iconsPath/chats1.webp';
  static const String navChatsPressed = '$iconsPath/chats2.webp';
  static const String navNotifsUnpressed = '$iconsPath/notifs1.webp';
  static const String navNotifsPressed = '$iconsPath/notifs2.webp';

  // Animations (Add Lottie / Rive animation paths here)
  // Example: static const String loadingSpinner = '$_animationsPath/loading.json';
}
