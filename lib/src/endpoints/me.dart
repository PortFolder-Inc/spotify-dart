// Copyright (c) 2019, chances, rinukkusu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of spotify;

abstract class _MeEndpointBase extends EndpointPaging {
  @override
  String get _path => 'v1/me';

  _MeEndpointBase(SpotifyApiBase api) : super(api);
}

/// Endpoint for authenticated users `v1/me/*`
class Me extends _MeEndpointBase {
  late PlayerEndpoint _player;

  Me(SpotifyApiBase api, PlayerEndpoint player) : super(api) {
    _player = player;
  }

  Future<User> get() async {
    final jsonString = await _api._get(_path);
    final map = json.decode(jsonString);

    return User.fromJson(map);
  }

  /// Endpoint `/v1/me/following` only supports [FollowingType.artist]
  /// at the moment.
  ///
  /// Needs `user-follow-read` scope
  CursorPages<Artist> following(FollowingType type) {
    assert(
        type == FollowingType.artist,
        'Only [FollowingType.artist] supported for now. Check the spotify documentation: '
        'https://developer.spotify.com/documentation/web-api/reference/get-followed');
    // since 'artists' is the container, there is no
    // containerParse necessary. Adding json to make the
    // CursorPages-Object happy.
    return _getCursorPages('$_path/following?type=${type._key}',
        (json) => Artist.fromJson(json), 'artists', (json) => json);
  }

  /// Check to see if the current user is following one or more artists or
  /// other Spotify users. The output [bool] list
  /// is in the same order as the provided artist-id list
  @Deprecated('Use [spotify.me.checkFollowing(type, ids)] instead')
  Future<List<bool>> isFollowing(FollowingType type, List<String> ids) async =>
      (await checkFollowing(type, ids)).values.toList();

  /// Check if current user follow the provided [FollowingType.artist]s or
  /// [FollowingType.user]s.
  ///
  /// Returns the list of [ids] mapped with the response whether it has been
  /// followed or not
  Future<Map<String, bool>> checkFollowing(
      FollowingType type, List<String> ids) async {
    assert(ids.isNotEmpty, 'No user/artist id was provided');

    final jsonString = await _api._get('$_path/following/contains?' +
        _buildQuery({
          'type': type._key,
          'ids': ids.join(','),
        }));
    final list = List.castFrom<dynamic, bool>(json.decode(jsonString));
    return Map.fromIterables(ids, list);
  }

  /// Follow provided users/artists\
  /// [type] - Type of Follow\
  /// [ids] - user/artist
  Future<void> follow(FollowingType type, List<String> ids) async {
    assert(ids.isNotEmpty, 'No user/artist id was provided');
    await _api._put("$_path/following?type=${type._key}&ids=${ids.join(",")}");
  }

  /// Unfollow already following users/artists\
  /// [type] - Type of Follow\
  /// [ids] - user/artist
  Future<void> unfollow(FollowingType type, List<String> ids) async {
    assert(ids.isNotEmpty, 'No user/artist id was provided');
    await _api
        ._delete("$_path/following?type=${type._key}&ids=${ids.join(",")}");
  }

  /// Get the object currently being played on the user’s Spotify account.
  @Deprecated('Use [spotify.player.currentlyPlaying()]')
  Future<PlaybackState> currentlyPlaying() async => _player.currentlyPlaying();

  // Get the currently playing as well as the queued objects.
  @Deprecated('Use [spotify.player.queue()]')
  Future<Queue> queue() async => _player.queue();

  // Add an object to the queue with a trackId.
  @Deprecated('Use [spotify.player.addToQueue()]')
  Future<void> addToQueue(String trackId) async => _player.addToQueue(trackId);

  /// Get tracks from the current user’s recently played tracks.
  /// Note: Currently doesn’t support podcast episodes.
  CursorPages<PlayHistory> recentlyPlayed(
      {int? limit, DateTime? after, DateTime? before}) {
    assert(after == null || before == null,
        'Cannot specify both after and before.');

    return _getCursorPages(
        '$_path/player/recently-played?' +
            _buildQuery({
              'limit': limit,
              'after': after?.millisecondsSinceEpoch,
              'before': before?.millisecondsSinceEpoch
            }),
        (json) => PlayHistory.fromJson(json));
  }

  /// Toggle Shuffle For User's Playback.
  ///
  /// Use [state] to toggle the shuffle. `true` to turn shuffle on and `false`
  /// to turn it off respectively.
  /// Returns the current player state by making another request.
  /// See [player];
  @Deprecated('Use [spotify.player.shuffle()]')
  Future<PlaybackState?> shuffle(bool state, [String? deviceId]) async =>
      _player.shuffle(state, deviceId: deviceId);

  @Deprecated('Use [spotify.player.playbackState()]')
  Future<PlaybackState> player([String? market]) async =>
      _player.playbackState(Market.values.asNameMap()[market]);

  /// Get the current user's top tracks, spanning over a [timeRange].
  /// The [timeRange]'s default is [TimeRange.mediumTerm].
  Pages<Track> topTracks({TimeRange timeRange = TimeRange.mediumTerm}) =>
      _top(_TopItemsType.tracks, (item) => Track.fromJson(item), timeRange);

  /// Get the current user's top artists, spanning over a [timeRange].
  /// The [timeRange]'s default is [TimeRange.mediumTerm].
  Pages<Artist> topArtists({TimeRange timeRange = TimeRange.mediumTerm}) =>
      _top(_TopItemsType.artists, (item) => Artist.fromJson(item), timeRange);

  Pages<T> _top<T>(
          _TopItemsType type, T Function(dynamic) parser, TimeRange range) =>
      _getPages(
          '$_path/top/${type.name}?' +
              _buildQuery({
                'time_range': range._key,
              }),
          parser);

  /// Get information about a user’s available devices.
  @Deprecated('Use [spotify.player.devices()]')
  Future<Iterable<Device>> devices() async => _player.devices();

  /// Get a list of shows saved in the current Spotify user’s library.
  Pages<Show> savedShows() {
    return _getPages('$_path/shows', (json) => Show.fromJson(json['show']));
  }

  /// Save shows for the current user. It requires the `user-library-modify`
  /// scope.
  /// [ids] - the ids of the shows to save
  Future<void> saveShows(List<String> ids) async {
    assert(ids.isNotEmpty, 'No show ids were provided for saving');
    await _api._put('$_path/shows?' + _buildQuery({'ids': ids.join(',')}));
  }

  /// Removes shows for the current user. It requires the `user-library-modify`
  /// scope.
  /// [ids] - the ids of the shows to remove
  /// [market] - An ISO 3166-1 alpha-2 country code. If a country code is
  /// specified, only content that is available in that market will be returned.
  Future<void> removeShows(List<String> ids, [Market? market]) async {
    assert(ids.isNotEmpty, 'No show ids were provided for removing');
    var queryMap = {
      'ids': ids.join(','),
      'market': market?.name,
    };
    await _api._delete('$_path/shows?' + _buildQuery(queryMap));
  }

  /// Check if passed albums (ids) are saved by current user.
  /// [ids] - list of id's to check
  /// Returns the list of id's mapped with the response whether it has been saved
  Future<Map<String, bool>> containsSavedShows(List<String> ids) async {
    assert(
        ids.isNotEmpty, 'No show ids were provided for checking saved shows');
    var query = _buildQuery({'ids': ids.join(',')});
    var jsonString = await _api._get('$_path/shows/contains?' + query);
    var response = List.castFrom<dynamic, bool>(jsonDecode(jsonString));

    return Map.fromIterables(ids, response);
  }

  /// gets current user's saved albums in pages
  Pages<AlbumSimple> savedAlbums() {
    return _getPages('$_path/albums', (json) => Album.fromJson(json['album']));
  }

  /// Save albums for the current-user. It requires the
  /// `user-library-modify` scope of Spotify WebSDK\
  /// [ids] - the ids of the albums
  Future<void> saveAlbums(List<String> ids) async {
    assert(ids.isNotEmpty, 'No album ids were provided for saving');
    await _api._put('$_path/albums?ids=${ids.join(",")}');
  }

  /// Remove albums for the current-user. It requires the
  /// `user-library-modify` scope of Spotify WebSDK\
  /// [ids] - the ids of the albums
  Future<void> removeAlbums(List<String> ids) async {
    assert(ids.isNotEmpty, 'No album ids were provided for removing');
    await _api._delete('$_path/albums?ids=${ids.join(",")}');
  }

  /// Check if passed albums (ids) are saved by current user. The output
  /// [bool] list is in the same order as the provided album ids list
  @Deprecated('Use [containsSavedAbums(ids)]')
  Future<List<bool>> isSavedAlbums(List<String> ids) async {
    final result = await containsSavedAlbums(ids);
    return result.values.toList();
  }

  /// Check if passed albums (ids) are saved by current user.
  /// Returns the list of id's mapped with the response whether it has been saved
  Future<Map<String, bool>> containsSavedAlbums(List<String> ids) async {
    assert(ids.isNotEmpty, 'No album ids were provided for checking');
    final jsonString =
        await _api._get('$_path/albums/contains?ids=${ids.join(",")}');
    final result = List.castFrom<dynamic, bool>(json.decode(jsonString));

    return Map.fromIterables(ids, result);
  }

  /// Returns the current user's saved episodes. Requires the `user-library-read`
  /// scope.
  Pages<EpisodeFull> savedEpisodes() => _getPages(
      '$_path/episodes', (json) => EpisodeFull.fromJson(json['episode']));

  /// Saves episodes for the current user. Requires the `user-library-modify`
  /// scope.
  /// [ids] - the ids of the episodes
  Future<void> saveEpisodes(List<String> ids) async {
    assert(ids.isNotEmpty, 'No episode ids were provided for saving');
    await _api._put('$_path/episodes?' + _buildQuery({'ids': ids.join(',')}));
  }

  /// Removes episodes for the current user. Requires the `user-library-modify`
  /// scope.
  /// [ids] - the ids of the episodes
  Future<void> removeEpisodes(List<String> ids) async {
    assert(ids.isNotEmpty, 'No episode ids were provided for removing');
    await _api
        ._delete('$_path/episodes?' + _buildQuery({'ids': ids.join(',')}));
  }

  /// Check if passed episode [ids] are saved by current user.
  /// Returns the list of id's mapped with the response whether it has been saved
  Future<Map<String, bool>> containsSavedEpisodes(List<String> ids) async {
    assert(ids.isNotEmpty, 'No episode ids were provided for checking');
    final jsonString = await _api._get(
        '$_path/episodes/contains?' + _buildQuery({'ids': ids.join(',')}));
    final result = List.castFrom<dynamic, bool>(json.decode(jsonString));

    return Map.fromIterables(ids, result);
  }
}

enum FollowingType {
  artist(key: 'artist'),
  user(key: 'user');

  const FollowingType({required String key}) : _key = key;

  final String _key;
}

enum TimeRange {
  /// Consists of several years of data and including all new data as it becomes available
  longTerm(key: 'long_term'),

  /// Consists of approximately last 6 months
  mediumTerm(key: 'medium_term'),

  /// Consists of approximately last 4 weeks
  shortTerm(key: 'short_term');

  const TimeRange({required String key}) : _key = key;

  final String _key;
}

enum _TopItemsType { artists, tracks }
