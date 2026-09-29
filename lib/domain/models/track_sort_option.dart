import 'package:flutter/material.dart';
import 'track.dart';

enum TrackSortOption {
  recentlyAdded(
    label: 'Recently Added',
    subtitle: 'Latest files first',
    icon: Icons.access_time_rounded,
  ),
  mostPlayed(
    label: 'Most Played',
    subtitle: 'Number of times listened',
    icon: Icons.local_fire_department_rounded,
  ),
  titleAsc(
    label: 'Name (A to Z)',
    subtitle: 'Alphabetical song title',
    icon: Icons.sort_by_alpha_rounded,
  ),
  titleDesc(
    label: 'Name (Z to A)',
    subtitle: 'Reverse alphabetical',
    icon: Icons.sort_by_alpha_rounded,
  ),
  artistAsc(
    label: 'Artist (A to Z)',
    subtitle: 'Alphabetical artist name',
    icon: Icons.person_outline_rounded,
  ),
  durationDesc(
    label: 'Duration',
    subtitle: 'Longest songs first',
    icon: Icons.timer_outlined,
  );

  final String label;
  final String subtitle;
  final IconData icon;

  const TrackSortOption({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  List<Track> sortTracks(List<Track> tracks, {Map<String, int> playCounts = const {}}) {
    final list = List<Track>.from(tracks);
    switch (this) {
      case TrackSortOption.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case TrackSortOption.mostPlayed:
        list.sort((a, b) {
          final countA = playCounts[a.id] ?? 0;
          final countB = playCounts[b.id] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA); // Highest count first
          }
          return b.addedAt.compareTo(a.addedAt);
        });
        break;
      case TrackSortOption.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case TrackSortOption.titleDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case TrackSortOption.artistAsc:
        list.sort((a, b) {
          final artistCmp = a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
          if (artistCmp != 0) return artistCmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case TrackSortOption.durationDesc:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
    }
    return list;
  }
}
