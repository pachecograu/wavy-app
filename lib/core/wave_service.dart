class Wave {
  final String id;
  final String name;
  final String djName;
  final bool isOnline;
  final int listenersCount;

  Wave({
    required this.id,
    required this.name,
    required this.djName,
    required this.isOnline,
    required this.listenersCount,
  });

  factory Wave.fromJson(Map<String, dynamic> json) {
    return Wave(
      id: json['_id'],
      name: json['name'],
      djName: json['djName'],
      isOnline: json['isOnline'],
      listenersCount: json['listenersCount'],
    );
  }
}

class WaveService {
  static const String baseUrl = 'http://10.0.2.2:3001/api';
  
  Future<List<Wave>> getWaves() async {
    // Simulate API call - replace with actual HTTP request
    await Future.delayed(const Duration(milliseconds: 500));
    
    return [
      Wave(
        id: '1',
        name: 'Chill Vibes 🌙',
        djName: 'DJ Luna',
        isOnline: true,
        listenersCount: 42,
      ),
      Wave(
        id: '2',
        name: 'Rock Classics 🎸',
        djName: 'RockMaster',
        isOnline: true,
        listenersCount: 128,
      ),
    ];
  }
}