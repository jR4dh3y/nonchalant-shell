import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "claude_usage", Path(__file__).resolve().parents[2] / "scripts" / "desktop" / "claude_usage.py"
)
claude_usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(claude_usage)


class ClaudeUsageTests(unittest.TestCase):
    def test_cache_reads_count_and_peak_week_checks_each_hour(self):
        with tempfile.TemporaryDirectory() as directory:
            projects = Path(directory) / "projects"
            projects.mkdir()
            transcript = projects / "session.jsonl"
            records = [
                (0, {"input_tokens": 1}),
                (11, {"cache_read_input_tokens": 100}),
                (178, {"output_tokens": 100}),
                (180, {"cache_read_input_tokens": 7}),
            ]
            transcript.write_text("".join(
                json.dumps({
                    "type": "assistant",
                    "timestamp": datetime.fromtimestamp(hour * 3600, timezone.utc).isoformat(),
                    "message": {"usage": usage},
                }) + "\n"
                for hour, usage in records
            ), encoding="utf-8")
            cache_path = Path(directory) / "cache.json"
            cache_path.write_text(json.dumps({
                "files": {
                    str(transcript): {
                        "offset": transcript.stat().st_size,
                        "mtime": transcript.stat().st_mtime,
                        "buckets": {"11": [0, 1]},
                    }
                }
            }), encoding="utf-8")
            with patch.object(claude_usage, "TRANSCRIPTS", projects), \
                    patch.object(claude_usage.time, "time", return_value=180 * 3600):
                report = claude_usage.transcript_report(cache_path)

        self.assertEqual(report["blockTokens"], 107)
        self.assertEqual(report["weekTokens"], 107)
        self.assertEqual(report["peakWeekTokens"], 200)


if __name__ == "__main__":
    unittest.main()
