class Track {
  final String title;
  final String artist;
  final String? url;
  final int? duration;
  final bool isCurrent;
  final DateTime playedAt;

  Track({
    required this.title,
    required this.artist,
    this.url,
    this.duration,
    required this.isCurrent,
    required this.playedAt,
  });

  factory Track.fromJson(dynamic json) {
    try {
      // Convert to Map if it's a JS object
      Map<String, dynamic> data;
      if (json is Map<String, dynamic>) {
        data = json;
      } else {
        // Handle JS object by converting to Map
        data = Map<String, dynamic>.from(json);
      }
      
      return Track(
        title: data['title']?.toString() ?? '',
        artist: data['artist']?.toString() ?? '',
        url: data['url']?.toString(),
        duration: (data['duration'] as num?)?.toInt(),
        isCurrent: data['isCurrent'] == true,
        playedAt: DateTime.tryParse(data['playedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      // Fallback for any parsing errors
      return Track(
        title: 'Unknown Track',
        artist: 'Unknown Artist',
        duration: null,
        isCurrent: false,
        playedAt: DateTime.now(),
      );
    }
  }
}