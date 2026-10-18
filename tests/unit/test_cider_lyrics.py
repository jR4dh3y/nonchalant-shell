"""Exercise exact-recording selection and Cider TTML normalization."""

import os
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

from scripts import cider_lyrics as cider
from scripts import lyrics


TTML = '''<tt xmlns="http://www.w3.org/ns/ttml"><body><div>
<p begin="00:01.000" end="3s"><span begin="1s" end="1.5s">Hello</span> <span begin="1.5s" end="3s">world &amp; friends</span></p>
</div></body></tt>'''


class CiderLyricsTests(unittest.TestCase):
    def test_ttml_keeps_word_times_spacing_and_entities(self):
        result = cider.parse_ttml(TTML)
        self.assertTrue(result["synced"])
        self.assertEqual(result["source"], "cider")
        self.assertEqual(result["lines"], [{
            "t": 1.0, "end": 3.0, "text": "Hello world & friends",
            "words": [
                {"t": 1.0, "end": 1.5, "start": 0, "length": 5},
                {"t": 1.5, "end": 3.0, "start": 6, "length": 15},
            ],
        }])

    def test_unicode_offsets_use_utf16_and_syllables_keep_no_added_spaces(self):
        ttml = '''<tt xmlns="http://www.w3.org/ns/ttml"><body><p begin="1" end="4">
<span begin="1" end="2">🎵你</span><span begin="2" end="3">好</span> <span begin="3" end="4">世界</span></p></body></tt>'''
        line = cider.parse_ttml(ttml)["lines"][0]
        self.assertEqual(line["text"], " 🎵你好 世界")
        self.assertEqual([(w["start"], w["length"]) for w in line["words"]], [(1, 3), (4, 1), (6, 2)])

    def test_nested_background_vocals_keep_their_own_word_times(self):
        ttml = '''<tt xmlns="http://www.w3.org/ns/ttml"><p begin="1" end="3"><span begin="1" end="2">Main</span> <span><span begin="1.8" end="3">(echo)</span></span></p></tt>'''
        line = cider.parse_ttml(ttml)["lines"][0]
        self.assertEqual(line["text"], "Main (echo)")
        self.assertEqual([w["t"] for w in line["words"]], [1, 1.8])

    def test_line_only_and_static_lyrics_do_not_invent_word_timing(self):
        timed = cider.parse_ttml('<tt xmlns="http://www.w3.org/ns/ttml"><p begin="2" end="4">Line</p></tt>')
        plain = cider.parse_ttml('<tt xmlns="http://www.w3.org/ns/ttml"><p>Plain &lt;text&gt;</p></tt>')
        self.assertEqual(timed["lines"], [{"t": 2, "end": 4, "text": "Line"}])
        self.assertEqual(plain["lines"], [{"t": -1, "text": "Plain <text>"}])
        self.assertFalse(plain["synced"])

    def test_interlude_paragraph_with_empty_text_is_preserved(self):
        ttml = '<tt xmlns="http://www.w3.org/ns/ttml"><body><p begin="0" end="15"></p><p begin="15" end="18">Words</p></body></tt>'
        result = cider.parse_ttml(ttml)
        self.assertEqual(result["lines"], [
            {"t": 0.0, "end": 15.0, "text": ""},
            {"t": 15.0, "end": 18.0, "text": "Words"},
        ])
        self.assertTrue(result["synced"])

    def test_timed_whitespace_has_no_word_ranges_after_normalization(self):
        result = cider.parse_ttml('<tt xmlns="http://www.w3.org/ns/ttml"><p begin="0" end="2"><span begin="0" end="2"> </span></p></tt>')
        self.assertEqual(result["lines"], [{"t": 0.0, "end": 2.0, "text": ""}])

    def test_invalid_times_and_empty_documents(self):
        for value in ("nan", "-1", "00:00:00:01"):
            with self.assertRaises(ValueError):
                cider.parse_ttml(f'<tt xmlns="http://www.w3.org/ns/ttml"><p begin="{value}">Text</p></tt>')
        self.assertIsNone(cider.parse_ttml('<tt xmlns="http://www.w3.org/ns/ttml"><p> </p></tt>'))
        self.assertEqual(cider.timestamp("1500ms"), 1.5)

    def responses(self, ttml=TTML):
        return [
            {"info": {"name": "Title", "artistName": "Artist", "playParams": {
                "id": "i.library", "catalogId": "123", "libraryId": "i.library"}}},
            {"data": {"developerToken": "test-developer", "userToken": "test-user", "storefront": "us"}},
            {"data": [{"attributes": {"ttml": ttml}}]},
        ]

    def test_library_id_resolves_to_exact_catalog_recording(self):
        with patch.object(cider, "request_json", side_effect=self.responses()) as request:
            result = cider.report("Artist", "Title", "i.library")
        self.assertTrue(result["synced"])
        self.assertEqual(request.call_args_list[-1].args[0],
                         "https://amp-api.music.apple.com/v1/catalog/us/songs/123/syllable-lyrics")

    def test_cider_mpris_library_id_keeps_exact_lyrics_instead_of_falling_back(self):
        # Cider exports i.library as .../track/ilibrary on D-Bus.
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_STATE_HOME": directory}), \
                patch.object(cider, "request_json", side_effect=self.responses()) as request, \
                patch.object(lyrics, "lookup", return_value={"syncedLyrics": "[00:09]Different timing"}) as fallback:
            result = lyrics.report("Artist", "Title", "Album", 200, "", "ilibrary")
        self.assertEqual(result["source"], "cider")
        self.assertEqual(result["lines"][0]["t"], 1)
        fallback.assert_not_called()
        self.assertTrue(request.call_args_list[-1].args[0].endswith("/songs/123/syllable-lyrics"))

    def test_track_id_or_metadata_mismatch_does_not_use_the_open_cider_track(self):
        for artist, title, track in (("Artist", "Title", "999"), ("Other", "Title", "123"),
                                     ("Artist", "Other", "123")):
            with patch.object(cider, "request_json", side_effect=self.responses()) as request:
                self.assertIsNone(cider.report(artist, title, track))
                self.assertEqual(request.call_count, 1)

    def test_absent_word_lyrics_tries_line_lyrics(self):
        responses = self.responses()
        responses.insert(2, urllib.error.HTTPError("test", 404, "missing", {}, None))
        with patch.object(cider, "request_json", side_effect=responses) as request:
            self.assertTrue(cider.report("Artist", "Title", "123")["available"])
        self.assertTrue(request.call_args_list[-1].args[0].endswith("/lyrics"))

    def test_cider_failure_falls_back_to_existing_lookup(self):
        for error in (OSError("offline"), urllib.error.HTTPError("test", 403, "scoped", {}, None)):
            with patch.object(cider, "request_json", side_effect=error):
                self.assertIsNone(cider.report("Artist", "Title", "123"))
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_STATE_HOME": directory}), \
                patch.object(lyrics, "cider_report", return_value=None), \
                patch.object(lyrics, "lookup", return_value={"syncedLyrics": "[00:01]Fallback"}):
            result = lyrics.report("Artist", "Title", "Album", 200, "", "123")
            self.assertEqual(result["lines"], [{"t": 1.0, "text": "Fallback"}])

    def test_cider_precedes_lrclib_cache_and_other_players_skip_cider(self):
        with patch.object(lyrics, "cider_report", return_value={"available": True, "source": "cider"}) as provider, \
                patch.object(lyrics, "cache_dir") as cache:
            self.assertEqual(lyrics.report("Artist", "Title", "", 200, "", "123")["source"], "cider")
            cache.assert_not_called()
            provider.reset_mock()
            lyrics.report("", "", "", 0)
            provider.assert_not_called()

    def test_authentication_headers_are_cleared_after_fetch(self):
        headers = []
        responses = iter(self.responses())

        def request(url, credentials):
            headers.append(credentials)
            return next(responses)

        with patch.object(cider, "request_json", side_effect=request):
            self.assertIsNotNone(cider.report("Artist", "Title", "123"))
        self.assertTrue(all(not credentials for credentials in headers))

    def test_redirects_do_not_forward_credentials(self):
        self.assertIsNone(cider.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.test"))


if __name__ == "__main__":
    unittest.main()
