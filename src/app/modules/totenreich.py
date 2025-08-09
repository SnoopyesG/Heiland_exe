from pathlib import Path
class Totenreich:
    def archive_snapshot(self):
        Path("session").mkdir(parents=True, exist_ok=True)
        (Path("session")/"archive.ok").write_text("snapshot\n")
