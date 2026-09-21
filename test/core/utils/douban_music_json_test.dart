import 'package:core/models/audio_item.dart';
import 'package:core/models/audio_kind.dart';
import 'package:core/models/audio_track.dart';
import 'package:core/models/data_source.dart';
import 'package:core/utils/douban_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from live responses. The search row is the thin `target` of a
/// `/api/v2/search/music` item; the record is what `/api/v2/music/{id}`
/// answers, and is the only shape carrying `songs`, `singer` and `pubdate`.
Map<String, dynamic> searchRow() => <String, dynamic>{
      'id': '26812952',
      'title': '周杰伦的床边故事',
      'card_subtitle': '周杰伦 / 2016',
      'cover_url':
          'https://img9.doubanio.com/view/subject/s/public/s28836865.jpg',
      'rating': <String, dynamic>{'count': 31037, 'max': 10, 'value': 8.1},
      'uri': 'douban://douban.com/music/26812952',
      'abstract': '',
    };

Map<String, dynamic> record() => <String, dynamic>{
      'id': '26812952',
      'title': '周杰伦的床边故事',
      'card_subtitle': '周杰伦 / 2016',
      'cover_url':
          'https://img9.doubanio.com/view/subject/m/public/s28836865.jpg',
      'genres': <String>['流行'],
      'intro': '夜深了\n猫头鹰出没',
      'pubdate': <String>['2016'],
      'publisher': <String>['杰威尔音乐'],
      'media': <String>['CD'],
      'discs': <String>['1'],
      'singer': <Map<String, dynamic>>[
        <String, dynamic>{'name': '周杰伦'},
      ],
      'rating': <String, dynamic>{'count': 31037, 'max': 10, 'value': 8.1},
      'songs': <Map<String, dynamic>>[
        <String, dynamic>{
          'track_number': 1,
          'title': '床边故事',
          'duration': 0,
          'artist_names': <String>[],
        },
        <String, dynamic>{
          'track_number': 2,
          'title': '说走就走',
          'duration': 0,
          'artist_names': <String>[],
        },
      ],
      'url': 'https://music.douban.com/subject/26812952/',
    };

void main() {
  group('AudioItem.fromDouban', () {
    test('reads a search row into the app model', () {
      final AudioItem album = AudioItem.fromDouban(searchRow());

      expect(album.id, 26812952);
      expect(album.source, DataSource.douban);
      expect(album.kind, AudioKind.album);
      expect(album.nativeId, '26812952');
      expect(album.title, '周杰伦的床边故事');
      expect(album.artists, <String>['周杰伦']);
      expect(album.releaseYear, 2016);
      expect(album.firstReleaseDate, '2016');
      expect(album.rating, 8.1);
      expect(album.ratingCount, 31037);
      expect(album.externalUrl, 'https://music.douban.com/subject/26812952/');
      // Neither is on a search row; both arrive with the detail call.
      expect(album.trackCount, isNull);
      expect(album.label, isNull);
    });

    test('reads the full record with its list, label and medium', () {
      final AudioItem album = AudioItem.fromDouban(record());

      expect(album.genres, <String>['流行']);
      expect(album.description, '夜深了\n猫头鹰出没');
      expect(album.label, '杰威尔音乐');
      expect(album.format, 'CD');
      expect(album.discCount, 1);
      expect(album.trackCount, 2);
    });

    test('never reads the subtitle year as a genre', () {
      // The film helper reads a genre off `card_subtitle`; for music that line
      // is "artist / year", so a shared helper would have answered ['2016'].
      expect(doubanMusicGenres(searchRow()), isEmpty);
      expect(AudioItem.fromDouban(searchRow()).genres, isEmpty);
    });

    test('leaves the album artist out of the subtitle when it is absent', () {
      final Map<String, dynamic> row = searchRow();
      row['card_subtitle'] = '2016';

      expect(AudioItem.fromDouban(row).artists, isEmpty);
    });
  });

  group('AudioTrack.fromDoubanSong', () {
    test('numbers across the release on a single disc', () {
      final AudioItem album = AudioItem.fromDouban(record());
      final List<AudioTrack> tracks = <AudioTrack>[
        for (final Map<String, dynamic> song in doubanMusicSongs(record()))
          AudioTrack.fromDoubanSong(song, audioId: album.id),
      ];

      expect(tracks, hasLength(2));
      expect(tracks.first.position, 1);
      expect(tracks.first.title, '床边故事');
      expect(tracks.first.discNumber, 1);
      expect(tracks.first.source, DataSource.douban);
      // Douban answers `duration: 0` on every row, so nothing may be invented.
      expect(tracks.first.lengthMs, isNull);
    });

    test('takes the length off the title when one is spelled there', () {
      final AudioTrack track = AudioTrack.fromDoubanSong(
        <String, dynamic>{
          'track_number': 3,
          'title': '熙笃修道会赞美诗：《万福，光耀海星 》        2:15',
          'duration': 0,
        },
        audioId: 1,
      );

      expect(track.position, 3);
      expect(track.title, '熙笃修道会赞美诗：《万福，光耀海星 》');
      expect(track.lengthMs, 135000);
    });
  });

  group('doubanMusicSongs', () {
    test('drops the section headers of a user-built compilation', () {
      // A real 169-row compilation opens with "全套曲目", "CD1", "早期音乐" and
      // a total-time line, none of which carries a track number.
      final Map<String, dynamic> json = record();
      json['songs'] = <Map<String, dynamic>>[
        <String, dynamic>{'title': '全套曲目', 'track_number': null},
        <String, dynamic>{'title': 'CD1', 'track_number': null},
        <String, dynamic>{'title': '格里高利圣咏', 'track_number': 1},
        <String, dynamic>{'title': '总时间：70分钟', 'track_number': null},
        <String, dynamic>{'title': '宾根的希德嘉尔德', 'track_number': 2},
      ];

      final List<Map<String, dynamic>> songs = doubanMusicSongs(json);

      expect(songs, hasLength(2));
      expect(songs.map((Map<String, dynamic> s) => s['track_number']), <int>[1, 2]);
    });
  });

  group('doubanTrackTitleAndLength', () {
    test('splits a trailing length in minutes and seconds', () {
      final ({String title, int? lengthMs}) parsed =
          doubanTrackTitleAndLength('孤独摇滚    24:00');

      expect(parsed.title, '孤独摇滚');
      expect(parsed.lengthMs, 1440000);
    });

    test('leaves a title with no trailing length untouched', () {
      final ({String title, int? lengthMs}) parsed =
          doubanTrackTitleAndLength('床边故事');

      expect(parsed.title, '床边故事');
      expect(parsed.lengthMs, isNull);
    });

    test('does not read a colon inside a title as a length', () {
      final ({String title, int? lengthMs}) parsed =
          doubanTrackTitleAndLength('第2章:30 之後');

      expect(parsed.title, '第2章:30 之後');
      expect(parsed.lengthMs, isNull);
    });
  });
}
