import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "lyrics_backend", Path(__file__).resolve().parents[2] / "scripts" / "lyrics.py"
)
lyrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lyrics)


class LyricsTests(unittest.TestCase):
    def test_exact_recording_beats_other_artists_and_live_versions(self):
        original = {
            "trackName": "Home", "artistName": "The Original", "duration": 200,
            "plainLyrics": "The original words",
        }
        other_artist = {
            "trackName": "Home", "artistName": "Another Artist", "duration": 200,
            "syncedLyrics": "[00:01]Another artist's words",
        }
        live_version = {
            "trackName": "Home Live", "artistName": "The Original", "duration": 202,
            "syncedLyrics": "[00:01]The live version's words",
        }
        with patch.object(lyrics, "ask", side_effect=[original, [other_artist, live_version], []]):
            result = lyrics.lookup("The Original", "Home", "Album", 200)
        self.assertEqual(result["plainLyrics"], "The original words")

    def test_unrelated_timed_hit_does_not_stop_the_remaining_search(self):
        other_artist = {
            "trackName": "Home", "artistName": "Another Artist", "duration": 200,
            "syncedLyrics": "[00:01]Wrong words",
        }
        original = {
            "trackName": "Home", "artistName": "The Original", "duration": 200,
            "syncedLyrics": "[00:01]Right words",
        }
        with patch.object(lyrics, "ask", side_effect=[None, [other_artist], [original]]):
            result = lyrics.lookup("The Original", "Home", "Album", 200)
        self.assertEqual(result["syncedLyrics"], "[00:01]Right words")

    def test_unsearchable_title_does_not_match_arbitrary_results(self):
        with patch.object(lyrics, "ask") as ask:
            result = lyrics.lookup("The Original", "!!!", "Album", 200)
        self.assertIsNone(result)
        ask.assert_not_called()

    def test_multiple_timestamps_are_sorted_and_silent_lines_preserved(self):
        result = lyrics.parse({
            "syncedLyrics": "[00:20.00][00:40.50]Later\n[00:05.25]Earlier\n[00:10.00]",
        })
        self.assertEqual(result["lines"], [
            {"t": 5.25, "text": "Earlier"},
            {"t": 10.0, "text": ""},
            {"t": 20.0, "text": "Later"},
            {"t": 40.5, "text": "Later"},
        ])
        self.assertTrue(result["synced"])

    def test_plain_lyrics_keep_stanza_breaks_when_timed_text_has_no_timestamps(self):
        result = lyrics.parse({"syncedLyrics": "[ar:Artist]", "plainLyrics": "First\n\nLast"})
        self.assertEqual(result["lines"], [
            {"t": -1, "text": "First"}, {"t": -1, "text": ""}, {"t": -1, "text": "Last"},
        ])
        self.assertFalse(result["synced"])

    def test_instrumental_track_has_no_lyric_lines(self):
        self.assertEqual(lyrics.parse({"instrumental": True, "plainLyrics": "Ignored"}), {
            "available": True, "synced": False, "instrumental": True, "lines": [],
        })


if __name__ == "__main__":
    unittest.main()
