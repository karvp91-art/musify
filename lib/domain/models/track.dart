enum AudioSourceType {
  local,
  saavn,
  jamendo,
  fma,
  stream,
}

class Track {
  final String id; // e.g. "local:/storage/..." or "jamendo:12345"
  final String title;
  final String artistName;
  final String? albumTitle;
  final String? albumId;
  final String? artistId;
  final AudioSourceType source;
  final String sourceId;
  final int durationMs;
  final String? artworkUrl;
  final String audioUrl; // file path if local, remote stream URI if catalog
  final String? filePath;
  final int fileSizeBytes;
  final String codec;
  final int bitrate;
  final bool isLiked;
  final bool isDownloaded;
  final DateTime addedAt;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    this.albumTitle,
    this.albumId,
    this.artistId,
    required this.source,
    required this.sourceId,
    required this.durationMs,
    this.artworkUrl,
    required this.audioUrl,
    this.filePath,
    this.fileSizeBytes = 0,
    this.codec = 'mp3',
    this.bitrate = 320,
    this.isLiked = false,
    this.isDownloaded = false,
    required this.addedAt,
  });

  bool get isLocal => source == AudioSourceType.local;

  Track copyWith({
    String? id,
    String? title,
    String? artistName,
    String? albumTitle,
    String? albumId,
    String? artistId,
    AudioSourceType? source,
    String? sourceId,
    int? durationMs,
    String? artworkUrl,
    String? audioUrl,
    String? filePath,
    int? fileSizeBytes,
    String? codec,
    int? bitrate,
    bool? isLiked,
    bool? isDownloaded,
    DateTime? addedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      isLiked: isLiked ?? this.isLiked,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artistName': artistName,
      'albumTitle': albumTitle,
      'albumId': albumId,
      'artistId': artistId,
      'source': source.name,
      'sourceId': sourceId,
      'durationMs': durationMs,
      'artworkUrl': artworkUrl,
      'audioUrl': audioUrl,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'codec': codec,
      'bitrate': bitrate,
      'isLiked': isLiked ? 1 : 0,
      'isDownloaded': isDownloaded ? 1 : 0,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artistName: map['artistName'] as String,
      albumTitle: map['albumTitle'] as String?,
      albumId: map['albumId'] as String?,
      artistId: map['artistId'] as String?,
      source: AudioSourceType.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => AudioSourceType.local,
      ),
      sourceId: map['sourceId'] as String,
      durationMs: map['durationMs'] as int,
      artworkUrl: map['artworkUrl'] as String?,
      audioUrl: map['audioUrl'] as String,
      filePath: map['filePath'] as String?,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      codec: map['codec'] as String? ?? 'mp3',
      bitrate: map['bitrate'] as int? ?? 320,
      isLiked: (map['isLiked'] as int? ?? 0) == 1,
      isDownloaded: (map['isDownloaded'] as int? ?? 0) == 1,
      addedAt: DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
