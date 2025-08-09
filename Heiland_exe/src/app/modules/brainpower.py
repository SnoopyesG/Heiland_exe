from pathlib import Path
class Brainpower:
    def build_model(self):
        Path("session/models").mkdir(parents=True, exist_ok=True)
        (Path("session/models")/"model.txt").write_text("brainpower-model-built\n")
