from pathlib import Path
import json
class MorphischesFeld:
    def link(self):
        Path("session").mkdir(parents=True, exist_ok=True)
        (Path("session")/"graph.json").write_text(json.dumps({"linked": True})+"\n")
