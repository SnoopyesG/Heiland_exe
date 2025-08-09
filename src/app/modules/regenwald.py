from pathlib import Path
class Regenwald:
    def ingest(self):
        Path("session/tmp").mkdir(parents=True, exist_ok=True)
        (Path("session/tmp")/"ingest.ok").write_text("ingested\n")
