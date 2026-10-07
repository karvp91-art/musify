import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final bool isCollaborative;
  final bool isDownloaded;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.isCollaborative = false,
    this.isDownloaded = false,
    this.tracks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    bool? isCollaborative,
    bool? isDownloaded,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      isCollaborative: isCollaborative ?? this.isCollaborative,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'isCollaborative': isCollaborative,
      'isDownloaded': isDownloaded,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Untitled Playlist',
      description: map['description'] as String?,
      coverUrl: map['coverUrl'] as String?,
      isCollaborative: map['isCollaborative'] as bool? ?? false,
      isDownloaded: map['isDownloaded'] as bool? ?? false,
      tracks: (map['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
