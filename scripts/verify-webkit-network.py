import datetime
import http.client
import json
from pathlib import Path
import socketserver
import subprocess
import threading

PROJECT = Path(__file__).resolve().parent.parent


class ProbeServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, *args):
        self.count = 0
        self.payloads = []
        self.lock = threading.Lock()
        super().__init__(*args)

    def get_request(self):
        request = super().get_request()
        with self.lock:
            self.count += 1
        return request


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(2)
        try:
            payload = self.request.recv(4096)
            with self.server.lock:
                self.server.payloads.append(payload[:120].hex())
            self.request.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK')
        except (OSError, TimeoutError):
            pass


with ProbeServer(('127.0.0.1', 49183), Handler) as server:
    threading.Thread(target=server.serve_forever, daemon=True).start()
    control = http.client.HTTPConnection('127.0.0.1', 49183, timeout=2)
    control.request('GET', '/positive-control')
    response = control.getresponse()
    assert response.status == 200 and response.read() == b'OK'
    control.close()
    with server.lock:
        positive_count = server.count
        assert positive_count == 1
        server.count = 0
        server.payloads.clear()
    command = ['env', 'DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer', 'xcodebuild', '-quiet', '-project', 'outilVizMd.xcodeproj', '-scheme', 'outilVizMd', '-configuration', 'Debug', '-destination', 'platform=macOS,arch=arm64', '-derivedDataPath', '/tmp/outilVizMd-derived', '-only-testing:outilVizMdTests/WebKitFeasibilityTests/testRemoteSubresourcesRemainBlockedOnLocalPageWithClientEntitlement', '-only-testing:outilVizMdTests/NoAutomaticNetworkTests', 'test']
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=180)
    server.shutdown()
    with server.lock:
        accepted = server.count
    record = {
        'date_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'listener': '127.0.0.1:49183',
        'positive_control_connections': positive_count,
        'connections_during_webkit_tests': accepted,
        'xcodebuild_exit_code': result.returncode,
        'tested': ['local-page HTTP/HTTPS images, CSS and iframe rejection', 'production renderer/controller hostile page with opaque links'],
        'received_payloads_hex': server.payloads,
        'scope': 'Un test d’affichage local ; ne certifie pas encore tous les parcours US6 ni toutes les tentatives DNS/connexions des services système.'
    }
    output = PROJECT / 'specs/001-visualiser-markdown-local/validation/network-probe.json'
    output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False, indent=2))
    if result.returncode:
        print((result.stdout + result.stderr)[-5000:])
    if result.returncode or accepted:
        raise SystemExit(1)
