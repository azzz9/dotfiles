import os
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

import fetch


class RedirectHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/go":
            self.send_response(302)
            self.send_header("Location", "/docs/paper/")
            self.end_headers()
            return
        if self.path == "/docs/paper/":
            filler = "This page has enough text for the fetch floor. " * 40
            body = f'<html><body><p>{filler}</p><a href="refs.html">refs</a></body></html>'.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def log_message(self, *args):
        pass


class RedirectLinkTest(unittest.TestCase):
    def test_redirected_page_resolves_links_against_final_url(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), RedirectHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        old_allow = os.environ.get("IMOZURU_ALLOW_PRIVATE")
        old_ax = fetch.HAS_AX
        os.environ["IMOZURU_ALLOW_PRIVATE"] = "1"
        fetch.HAS_AX = False
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                sources = root / "work"
                destination = root / "sources"
                sources.mkdir()
                destination.mkdir()
                url = f"http://127.0.0.1:{server.server_port}/go"
                self.assertEqual(fetch.fetch_source(sources, "redirect", url, destination), 0)
                text = (destination / "redirect.md").read_text(encoding="utf-8")
                self.assertIn("/docs/paper/refs.html", text)
                self.assertNotIn(f"]({url.rsplit('/go', 1)[0]}/refs.html", text)
        finally:
            if old_allow is None:
                os.environ.pop("IMOZURU_ALLOW_PRIVATE", None)
            else:
                os.environ["IMOZURU_ALLOW_PRIVATE"] = old_allow
            fetch.HAS_AX = old_ax
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
