class Album {
  final String id;
  final String title;
  final String? artistId;
  final String artistName;
  final String? artworkUrl;
  final int? year;
  final String source;
  final String sourceId;
  final int trackCount;

  const Album({
    required this.id,
    required this.title,
    this.artistId,
    required this.artistName,
    this.artworkUrl,
    this.year,
    required this.source,
    required this.sourceId,
    this.trackCount = 0,
  });
}
