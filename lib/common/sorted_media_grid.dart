import 'package:flutter/material.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/layout/breakpoints.dart';
import 'package:uractor/common/layout/responsive.dart';
import 'package:uractor/l10n/l10n.dart';
import 'package:uractor/objects/media.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/tv_show.dart';

import '../movie_result.dart';
import '../tvshow_result.dart';
import 'firebase/settings_service.dart';
import 'media_sort.dart';
import 'media_sort_loader.dart';
import 'utils.dart';
import 'layout/two_pane.dart';

/// The settings key holding the chosen sort, shared by every media grid so
/// that the choice follows the user between the Seen, Watchlist, Favorites and
/// playlist screens rather than being set separately on each.
const String kMediaSortSettingsKey = 'mediaSort';

/// Converts a type-specific id list into the `[type, id]` pairs used by the
/// shared media sorting pipeline.
List<dynamic> mediaItemsForType(List<dynamic> ids, String type) {
  return [
    for (final id in ids) [type, id],
  ];
}

class SortedMediaGrid extends StatefulWidget {
  final List<dynamic> items;
  final bool showFavoriteBadge;
  final bool showWatchlistBadge;

  const SortedMediaGrid({
    super.key,
    required this.items,
    this.showFavoriteBadge = true,
    this.showWatchlistBadge = true,
  });

  @override
  State<SortedMediaGrid> createState() => _SortedMediaGridState();
}

class _SortedMediaGridState extends State<SortedMediaGrid> {
  late MediaSort _sort;
  Map<String, MediaSortMetadata> _metadata = {};
  bool _isLoadingMetadata = false;

  @override
  void initState() {
    super.initState();
    _sort = MediaSort.fromStorage(
      SettingsService.read<dynamic>(kMediaSortSettingsKey, null),
    );
    if (_sort.needsMetadata) {
      _loadMetadata();
    }
  }

  @override
  void didUpdateWidget(covariant SortedMediaGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length && _sort.needsMetadata) {
      _loadMetadata();
    }
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoadingMetadata = true);
    final metadata = await MediaSortLoader.load(
      widget.items,
      includeImdbRating: _sort.needsImdbRating,
    );
    if (!mounted) return;
    setState(() {
      _metadata = metadata;
      _isLoadingMetadata = false;
    });
  }

  Future<void> _changeSort(MediaSort sort) async {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    if (sort.needsMetadata) {
      await _loadMetadata();
    }
    await SettingsService.update(kMediaSortSettingsKey, sort.storageValue);
  }

  String _labelFor(MediaSortKey key, BuildContext context) {
    switch (key) {
      case MediaSortKey.added:
        return S.of(context)!.sortByAdded;
      case MediaSortKey.title:
        return S.of(context)!.sortByTitle;
      case MediaSortKey.releaseDate:
        return S.of(context)!.sortByReleaseDate;
      case MediaSortKey.myRating:
        return S.of(context)!.sortByMyRating;
      case MediaSortKey.imdbRating:
        return S.of(context)!.sortByImdbRating;
    }
  }

  Widget _buildSortBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.sort, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 8),
          DropdownButton<MediaSortKey>(
            value: _sort.key,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            dropdownColor: Colors.grey[900],
            onChanged: (key) {
              if (key == null) return;
              _changeSort(MediaSort(key, descending: _sort.descending));
            },
            items: MediaSortKey.values
                .map(
                  (key) => DropdownMenuItem(
                    value: key,
                    child: Text(_labelFor(key, context)),
                  ),
                )
                .toList(),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _sort.descending
                ? S.of(context)!.sortDescending
                : S.of(context)!.sortAscending,
            icon: Icon(
              _sort.descending ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
            ),
            onPressed: () => _changeSort(
              MediaSort(_sort.key, descending: !_sort.descending),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = sortMediaItems(widget.items, _sort, _metadata);

    return Column(
      children: [
        _buildSortBar(context),
        if (_isLoadingMetadata)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: ResponsiveRegion(
            builder: (context, size) {
              // The grid is sized from the width it has been given, not from
              // the window: inside a two pane layout the grid occupies a
              // fraction of a wide window, and sizing it to the window would
              // run its rows off the edge of the pane.
              final PosterGridMetrics grid = posterGridMetricsFor(
                LayoutScope.widthOf(context),
                targetTileWidth: context.posterWidth,
              );

              return ListView.builder(
                itemCount: (items.length / grid.columns).ceil(),
                itemBuilder: (context, index) {
                  return Row(
                    // Rows are packed from the leading edge so that a partial
                    // last row lines up with the rows above it. Spreading them
                    // out instead left the final one or two tiles drifting to
                    // the middle of a wide window.
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(grid.columns, (i) {
                      final itemIndex = index * grid.columns + i;
                      if (itemIndex < items.length) {
                        return ItemCard(
                          item: items[itemIndex],
                          tileWidth: grid.tileWidth,
                          showFavoriteBadge: widget.showFavoriteBadge,
                          showWatchlistBadge: widget.showWatchlistBadge,
                        );
                      }
                      return SizedBox(width: grid.cellWidth);
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ItemCard extends StatefulWidget {
  final List<dynamic> item;
  final bool showFavoriteBadge;
  final bool showWatchlistBadge;

  /// The width the grid has worked out for its tiles. Null falls back to the
  /// size class's own width, for the callers that draw a tile outside a grid.
  final double? tileWidth;

  const ItemCard({
    super.key,
    required this.item,
    this.tileWidth,
    this.showFavoriteBadge = true,
    this.showWatchlistBadge = true,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getData(widget.item[1], widget.item[0]),
      builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
        if (snapshot.hasData) {
          return GestureDetector(
            onTap: () async {
              MediaItem tempMediaItem;
              if (snapshot.data!['type'] == 'Movies') {
                tempMediaItem = Movie(
                  id: snapshot.data!['id'].toString(),
                  title: snapshot.data!['title'],
                  coverPhoto: snapshot.data!['poster_path'] ?? '',
                );
              } else {
                tempMediaItem = TVShow(
                  id: snapshot.data!['id'].toString(),
                  title: snapshot.data!['title'],
                  coverPhoto: snapshot.data!['poster_path'] ?? '',
                );
              }
              await openDetail(
                  context,
                  snapshot.data!['type'] == 'Movies'
                      ? MovieResult(movie: tempMediaItem as Movie)
                      : TVShowResult(tvshow: tempMediaItem as TVShow));
              if (mounted) {
                setState(() {});
              }
            },
            child: getItemContainer(
              context,
              snapshot.data,
              'media',
              width: widget.tileWidth,
              mediaPair: widget.item,
              showFavoriteBadge: widget.showFavoriteBadge,
              showWatchlistBadge: widget.showWatchlistBadge,
            ),
          );
        } else if (snapshot.hasError) {
          return PosterPlaceholder(
            width: widget.tileWidth,
            child: Text(S.of(context)!.errorFailedToLoadDetails),
          );
        } else {
          return PosterPlaceholder(
            width: widget.tileWidth,
            child: const CircularProgressIndicator(),
          );
        }
      },
    );
  }
}

List<Map<String, dynamic>> movies = [];

Future<Map<String, dynamic>> getData(dynamic id, String type) async {
  return Utils.fetchMediaData(id, type, movies);
}
