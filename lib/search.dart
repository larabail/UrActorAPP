// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uractor/common/item_container.dart';
import 'package:uractor/common/media_pair_membership.dart';
import 'package:uractor/common/widgets/scrolling_line.dart';
import 'package:uractor/l10n/l10n.dart';
import 'common/api/apiutils.dart';
import 'package:uractor/objects/movie.dart';
import 'package:uractor/objects/person.dart';
import 'package:uractor/objects/tv_show.dart';
import 'common/navigation/appbar.dart';
import 'person_result.dart';
import 'movie_result.dart';
import 'tvshow_result.dart';
import 'common/layout/breakpoints.dart';
import 'common/layout/responsive.dart';
import 'common/navigation/app_scaffold.dart';
import 'common/layout/two_pane.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchResultState();
}

class _SearchResultState extends State<Search> {
  /// Long enough to swallow the middle of a typed word, short enough that the
  /// results still feel like they follow the keystrokes.
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  /// How close to the bottom the list gets before the next page is requested.
  static const double _loadMoreThreshold = 400;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  /// Incremented for every new query. A response whose id no longer matches is
  /// from a query the user has already moved on from, and is discarded:
  /// without this a slow early request can land after a fast later one and
  /// replace the newer results with stale ones.
  int _requestId = 0;

  String _query = '';
  List<dynamic> _results = [];
  int _page = 1;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(value));
  }

  /// Runs a fresh search, replacing any results already on screen.
  Future<void> _search(String value) async {
    final String query = value.trim();
    final int id = ++_requestId;

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _page = 1;
        _totalPages = 0;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _query = query;
      _isLoading = true;
      _hasError = false;
    });

    try {
      final SearchResultPage result = await ApiUtils.searchMulti(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = ApiUtils.sortByRelevance(result.results, query);
        _page = result.page;
        _totalPages = result.totalPages;
        _isLoading = false;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Appends the next page of results. Each page is ranked on its own and then
  /// appended, rather than re-ranking everything, so that results already on
  /// screen do not jump around while the user is scrolling through them.
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _query.isEmpty) return;
    if (_page >= _totalPages) return;

    final int id = _requestId;
    setState(() => _isLoadingMore = true);

    try {
      final SearchResultPage result =
          await ApiUtils.searchMulti(_query, page: _page + 1);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = [
          ..._results,
          ...ApiUtils.sortByRelevance(result.results, _query),
        ];
        _page = result.page;
        _totalPages = result.totalPages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _handleTap(BuildContext context, Map item, String typeContainer) {
    if (item.containsKey("poster_path") &&
        item.containsKey("title") &&
        typeContainer == "media") {
      Movie tempMovie = Movie(
          id: item['id'].toString(),
          title: item['title'],
          coverPhoto: item['poster_path'] ?? "");
      openDetail(
          context,
          MovieResult(
            movie: tempMovie,
          ));
    } else if (item.containsKey("poster_path") &&
        item.containsKey("name") &&
        typeContainer == "media") {
      TVShow tempTvShow = TVShow(
          id: item['id'].toString(),
          title: item['name'],
          coverPhoto: item['poster_path'] ?? "");
      openDetail(
          context,
          TVShowResult(
            tvshow: tempTvShow,
          ));
    } else {
      Person personResult = Person(
          id: item["id"].toString(), name: item["name"].toString(), data: item);
      openDetail(
          context,
          PersonResult(
            personResult: personResult,
          ));
    }
  }

  Widget _buildItem(BuildContext context, Map item,
      {required double tileWidth}) {
    String typeContainer = "media";
    if (item.containsKey("poster_path") &&
        (item.containsKey("title") || item.containsKey("name"))) {
      item['poster_path'] = item['poster_path'];
    } else {
      typeContainer = "person";
      item['poster_path'] = item['profile_path'];
    }
    return GestureDetector(
      onTap: () => _handleTap(context, item, typeContainer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          getItemContainer(
            context,
            item,
            typeContainer,
            width: tileWidth,
            mediaPair: mediaPairForData(item, containerType: typeContainer),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: kPosterTileMarginLeft,
              right: kPosterTileMarginRight,
              top: kPosterLabelGap,
            ),
            child: SizedBox(
              width: tileWidth,
              // A title wider than a poster used to be clipped, in a scroll
              // box too fiddly to drag inside a scrolling grid of them.
              child: ScrollingLine(
                text: item['title'] ?? (item["name"] ?? S.of(context)!.unknown),
                style: const TextStyle(fontSize: 14),
                height: kPosterLabelHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(child: Text(S.of(context)!.errorFailedToLoadDetails));
    }
    if (_query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return Center(child: Text(S.of(context)!.noSearchResults));
    }

    final bool showFooter = _page < _totalPages;

    return ResponsiveRegion(
      builder: (context, size) {
        // The grid follows the width the results have, so a tablet or a
        // desktop window fills its rows instead of showing three stretched
        // tiles and a wide empty margin either side.
        final PosterGridMetrics grid = posterGridMetricsFor(
          LayoutScope.widthOf(context),
          targetTileWidth: context.posterWidth,
        );
        final int rowCount = (_results.length / grid.columns).ceil();

        return ListView.builder(
          controller: _scrollController,
          itemCount: rowCount + (showFooter ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= rowCount) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(grid.columns, (column) {
                final int itemIndex = index * grid.columns + column;
                if (itemIndex >= _results.length) {
                  return SizedBox(width: grid.cellWidth);
                }
                return _buildItem(context, _results[itemIndex] as Map,
                    tileWidth: grid.tileWidth);
              }),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      detailPlaceholder: DetailPanePlaceholder(
        message: S.of(context)!.detailPanePlaceholder,
      ),
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: S.of(context)!.searchBar,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: Color.fromARGB(250, 224, 190, 78)),
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (value) {
                _debounce?.cancel();
                _search(value);
              },
            ),
          ),
          Expanded(child: _buildResults(context)),
        ],
      ),
      selectedIndex: -1,
    );
  }
}
