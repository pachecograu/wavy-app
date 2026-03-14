class Wave {
  final String id;
  final String name;
  final String djName;
  final String ownerId;
  final bool isOnline;
  final int listenersCount;
  final DateTime createdAt;
  final String genre;
  final String description;

  Wave({
    required this.id,
    required this.name,
    required this.djName,
    required this.ownerId,
    required this.isOnline,
    required this.listenersCount,
    required this.createdAt,
    this.genre = 'Sin información',
    this.description = 'Sin información',
  });

  Wave copyWith({
    String? id,
    String? name,
    String? djName,
    String? ownerId,
    bool? isOnline,
    int? listenersCount,
    DateTime? createdAt,
    String? genre,
    String? description,
  }) {
    return Wave(
      id: id ?? this.id,
      name: name ?? this.name,
      djName: djName ?? this.djName,
      ownerId: ownerId ?? this.ownerId,
      isOnline: isOnline ?? this.isOnline,
      listenersCount: listenersCount ?? this.listenersCount,
      createdAt: createdAt ?? this.createdAt,
      genre: genre ?? this.genre,
      description: description ?? this.description,
    );
  }

  factory Wave.fromJson(dynamic json) {
    try {
      Map<String, dynamic> data;
      if (json is Map<String, dynamic>) {
        data = json;
      } else {
        data = Map<String, dynamic>.from(json);
      }

      return Wave(
        id: data['waveId']?.toString() ?? data['_id']?.toString() ?? data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        djName: data['djName']?.toString() ?? '',
        ownerId: data['ownerId']?.toString() ?? '',
        isOnline: data['isOnline'] == true,
        listenersCount: (data['listenersCount'] as num?)?.toInt() ?? 0,
        createdAt: data['createdAt'] != null
            ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        genre: data['genre']?.toString() ?? 'Sin información',
        description: data['description']?.toString() ?? 'Sin información',
      );
    } catch (e) {
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
