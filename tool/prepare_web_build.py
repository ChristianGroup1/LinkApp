"""Remove the unused dotenv asset from a web build using compiled settings."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1] / "build" / "web"
(root / "assets" / ".env").unlink(missing_ok=True)
worker = root / "flutter_service_worker.js"
source = worker.read_text()
match = re.search(r"const RESOURCES = (\{.*?\});", source, re.DOTALL)
if match is None:
    raise RuntimeError("Flutter service worker resource manifest not found")
resources = json.loads(match.group(1))
resources.pop("assets/.env", None)
worker.write_text(
    source[:match.start(1)]
    + json.dumps(resources, ensure_ascii=False, separators=(",", ":"))
    + source[match.end(1):]
)
