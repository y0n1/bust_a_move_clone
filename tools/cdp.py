"""Minimal Chrome DevTools Protocol client for the feedback loop.

Usage (from Python):
    from cdp import Cdp
    cdp = Cdp(ws_url)
    cdp.evaluate("document.title")
    cdp.mouse_move(100, 200)
    cdp.screenshot("/tmp/shot.png")

Or from CLI:
    python cdp.py <ws_url> <command> [args...]
    commands:
      eval <js>                 - evaluate JS, print result
      shot <path>               - screenshot to path
      move <x> <y>              - mouse move (page coords)
      down <x> <y>              - mouse down
      up <x> <y>                - mouse up
      click <x> <y>            - move + down + up
      size                      - print innerWidth/innerHeight
      wait <ms>                 - sleep
"""
import json
import sys
import time
import urllib.request
import base64

try:
    from websockets.sync.client import connect as ws_connect
except ImportError:
    sys.exit("need websockets>=12: pip install websockets")

class Cdp:
    def __init__(self, ws_url):
        self.ws = ws_connect(ws_url, max_size=None, open_timeout=10)
        self._id = 0

    def send(self, method, params=None, timeout=30):
        self._id += 1
        self.ws.send(json.dumps({"id": self._id, "method": method, "params": params or {}}))
        deadline = time.time() + timeout
        while True:
            msg = json.loads(self.ws.recv(timeout=max(0.1, deadline - time.time())))
            if msg.get("id") == self._id:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    # --- convenience -------------------------------------------------
    def evaluate(self, expression, await_promise=False):
        r = self.send("Runtime.evaluate", {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": await_promise,
        })
        if "exceptionDetails" in r:
            raise RuntimeError(f"JS exception: {r['exceptionDetails']}")
        return r.get("result", {}).get("value")

    def mouse_move(self, x, y, buttons=0):
        return self.send("Input.dispatchMouseEvent", {
            "type": "mouseMoved", "x": x, "y": y, "button": "none",
            "buttons": buttons, "pointerType": "mouse",
        })

    def mouse_down(self, x, y):
        return self.send("Input.dispatchMouseEvent", {
            "type": "mousePressed", "x": x, "y": y, "button": "left",
            "buttons": 1, "pointerType": "mouse",
        })

    def mouse_up(self, x, y):
        return self.send("Input.dispatchMouseEvent", {
            "type": "mouseReleased", "x": x, "y": y, "button": "left",
            "buttons": 0, "pointerType": "mouse",
        })

    def click(self, x, y, down_ms=40):
        self.mouse_move(x, y)
        time.sleep(0.02)
        self.mouse_down(x, y)
        time.sleep(down_ms / 1000.0)
        self.mouse_up(x, y)

    def screenshot(self, path=None):
        r = self.send("Page.captureScreenshot", {"format": "png"})
        data = base64.b64decode(r["data"])
        if path:
            with open(path, "wb") as f:
                f.write(data)
        return data

    def set_viewport(self, w, h):
        return self.send("Emulation.setDeviceMetricsOverride", {
            "width": w, "height": h, "deviceScaleFactor": 1, "mobile": False,
        })

def get_ws_url(http_url, target_url=None):
    """Find the websocket URL of the page target at http_url (or matching target_url)."""
    base = http_url.rstrip("/")
    r = urllib.request.urlopen(f"{base}/json/list")
    targets = json.loads(r.read())
    for t in targets:
        if t.get("type") == "page" and t.get("url") in ("", "about:blank") or (target_url and target_url in t.get("url", "")):
            return t["webSocketDebuggerUrl"], t
    # fall back to any page
    for t in targets:
        if t.get("type") == "page":
            return t["webSocketDebuggerUrl"], t
    raise RuntimeError("no page target found")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    ws_url = sys.argv[1]
    cmd = sys.argv[2] if len(sys.argv) > 2 else "help"
    cdp = Cdp(ws_url)
    cdp.send("Runtime.enable")
    cdp.send("Page.enable")
    if cmd == "eval":
        print(json.dumps(cdp.evaluate(sys.argv[3])))
    elif cmd == "shot":
        cdp.screenshot(sys.argv[3])
        print("saved", sys.argv[3])
    elif cmd == "move":
        cdp.mouse_move(float(sys.argv[3]), float(sys.argv[4]))
    elif cmd == "down":
        cdp.mouse_down(float(sys.argv[3]), float(sys.argv[4]))
    elif cmd == "up":
        cdp.mouse_up(float(sys.argv[3]), float(sys.argv[4]))
    elif cmd == "click":
        cdp.click(float(sys.argv[3]), float(sys.argv[4]))
    elif cmd == "size":
        print(cdp.evaluate("({w: innerWidth, h: innerHeight})"))
    elif cmd == "wait":
        time.sleep(int(sys.argv[3]) / 1000.0)
    elif cmd == "url":
        print(cdp.evaluate("location.href"))
    elif cmd == "title":
        print(cdp.evaluate("document.title"))
    return 0

if __name__ == "__main__":
    sys.exit(main())
