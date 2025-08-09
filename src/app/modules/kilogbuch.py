from pathlib import Path
class KiLogbuch:
    def capture(self):
        Path("session/logs").mkdir(parents=True, exist_ok=True)
        (Path("session/logs")/"kilogbuch.log").write_text("capture-ok\n")
