class ImagePickerSettings {
  final double maxWidth;
  final double maxHeight;
  final int quality;

  ImagePickerSettings({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });

  static ImagePickerSettings get avatar =>
      ImagePickerSettings(maxWidth: 1024, maxHeight: 1024, quality: 90);

  static ImagePickerSettings get background =>
      ImagePickerSettings(maxWidth: 1920, maxHeight: 1080, quality: 85);
}
