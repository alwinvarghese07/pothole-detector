class Pothole {
  final double latitude;
  final double longitude;
  final String type; // Changed from 'size' to 'type' (Pothole, Flooded Roads, etc.)
  final String? notes; // Optional notes
  final String? imagePath; // Path to photo, if taken

  Pothole({
    required this.latitude,
    required this.longitude,
    required this.type,
    this.notes,
    this.imagePath,
  });
}