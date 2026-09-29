class Artist {
  final String id;
  final String name;
  final String? imageUrl;
  final String source;
  final String sourceId;
  final List<String> genres;

  const Artist({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.source,
    required this.sourceId,
    this.genres = const [],
  });
}
