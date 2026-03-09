class Wave {
  final String id;
  final String name;
  final String djName;
  final String ownerId;
  final bool isOnline;
  final int listenersCount;
  final DateTime createdAt;

  Wave({
    required this.id,
    required this.name,
    required this.djName,
    required this.ownerId,
    required this.isOnline,
    required this.listenersCount,
    required this.createdAt,
  });

  factory Wave.fromJson(dynamic json) {
    try {
      // Convert to Map if it's a JS object
      Map<String, dynamic> data;
      if (json is Map<String, dynamic>) {
        data = json;
      } else {
        // Handle JS object by converting to Map
        data = Map<String, dynamic>.from(json);
      }
      
      return Wave(
        id: data['_id']?.toString() ?? data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        djName: data['djName']?.toString() ?? '',
        ownerId: data['ownerId']?.toString() ?? '',
        isOnline: data['isOnline'] == true,
        listenersCount: (data['listenersCount'] as num?)?.toInt() ?? 0,
        createdAt: data['createdAt'] != null 
            ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (e) {
      // Fallback for any parsing errors
      return Wave(
        id: '',
        name: 'Unknown Wave',
        djName: 'Unknown DJ',
        ownerId: '',
        isOnline: false,
        listenersCount: 0,
        createdAt: DateTime.now(),
      );
    }
  }
}