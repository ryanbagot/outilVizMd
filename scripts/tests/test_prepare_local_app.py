import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import plistlib
import os
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prepare_local_app', ROOT / 'scripts/prepare-local-app.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

class PreparationTests(unittest.TestCase):
    def test_original_source_is_identified_without_writing(self):
        source = prepare.validate_source(ROOT)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), prepare.SOURCE_HASH)

    def test_missing_changed_wrong_size_and_fake_image_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(prepare.PreparationError): prepare.validate_source(root)
            for data in (b'not png', b'\x89PNG\r\n\x1a\n' + bytes(100)):
                (root / prepare.SOURCE_NAME).write_bytes(data)
                with self.assertRaises(prepare.PreparationError): prepare.validate_source(root)
                self.assertEqual((root / prepare.SOURCE_NAME).read_bytes(), data)

    def test_ambiguous_normalized_name_is_refused(self):
        with patch.object(Path, 'iterdir', return_value=[Path(prepare.SOURCE_NAME), Path(prepare.SOURCE_NAME)]):
            with self.assertRaises(prepare.PreparationError): prepare.validate_source(Path('.'))

    def test_unreadable_source_is_reported(self):
        with patch.object(Path, 'read_bytes', side_effect=PermissionError('refus')):
            with self.assertRaises(prepare.PreparationError) as error: prepare.validate_source(ROOT)
            self.assertEqual(error.exception.code, 5)

    def test_ten_representations(self):
        self.assertEqual(len(prepare.ICON_SIZES), 10)
        self.assertEqual(sorted(set(prepare.ICON_SIZES.values())), [16,32,64,128,256,512,1024])

    def test_cache_missing_refuses_without_running_build(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(prepare, 'run') as run:
            with self.assertRaises(prepare.PreparationError): prepare.validate_cache(ROOT, Path(tmp))
            run.assert_not_called()

    def test_failed_publication_keeps_previous_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); old=root/'local'; new=root/'new'
            old.mkdir(); new.mkdir(); (old/'marker').write_text('old')
            with patch.object(prepare, 'atomic_rename', side_effect=OSError('injection')):
                with self.assertRaises(OSError): prepare.publish(new, old)
            self.assertEqual((old/'marker').read_text(),'old')

    def test_digest_ignores_dates_but_observes_bytes_execute_bits_and_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); f=root/'a'; f.write_bytes(b'a')
            first=prepare.bundle_digest(root)
            f.touch(); self.assertEqual(prepare.bundle_digest(root),first)
            f.chmod(0o755); self.assertNotEqual(prepare.bundle_digest(root),first)
            (root/'link').symlink_to('a'); second=prepare.bundle_digest(root)
            f.write_bytes(b'b'); self.assertNotEqual(prepare.bundle_digest(root),second)
            (root/'escape').symlink_to('/etc/passwd')
            with self.assertRaises(prepare.PreparationError): prepare.bundle_digest(root)

    def test_rejects_corrupt_bundle_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            app=Path(tmp)/'outilVizMd.app'; (app/'Contents').mkdir(parents=True)
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'foreign'}))
            with self.assertRaises(prepare.PreparationError): prepare.validate_bundle(app)

    def test_tool_error_does_not_publish(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); previous=root/'build/local'; previous.mkdir(parents=True)
            (previous/'marker').write_text('valid')
            args=prepare.parser().parse_args([])
            with patch.object(prepare,'ROOT',root), patch.object(prepare,'validate_source'), patch.object(prepare,'generate_icon'), patch.object(prepare,'run',side_effect=prepare.PreparationError(6,'échec outil')):
                with self.assertRaises(prepare.PreparationError): prepare.prepare(args)
            self.assertEqual((previous/'marker').read_text(),'valid')

    def test_minimum_signature_resources_and_architectures_are_verified(self):
        with tempfile.TemporaryDirectory() as tmp:
            app=Path(tmp)/'outilVizMd.app'; resources=app/'Contents/Resources'; resources.mkdir(parents=True)
            binary=app/'Contents/MacOS/outilVizMd'; binary.parent.mkdir(); binary.write_bytes(b'fake'); binary.chmod(0o755)
            info=dict(CFBundleIdentifier='com.outilvizmd.outilVizMd',CFBundlePackageType='APPL',CFBundleIconFile='AppIcon.icns',LSMinimumSystemVersion='14.0',CFBundleExecutable='outilVizMd',CFBundleShortVersionString='0.1.0',CFBundleVersion='1')
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
            for name in ['AppIcon.icns','ReaderBase.css','NetworkBlockRules.json','Aide.md','ThirdPartyNotices.txt']: (resources/name).write_bytes(b'fixture')
            def command(args):
                if args[0]=='/usr/bin/lipo': return b'arm64 x86_64'
                if args[0]=='/usr/bin/otool': return b'    minos 14.0\n    minos 14.0\n'
                if '--entitlements' in args: return plistlib.dumps(prepare.RIGHTS)
                return b''
            from types import SimpleNamespace
            with patch.object(prepare,'run',side_effect=command), patch.object(prepare,'validate_icon'), patch.object(prepare.subprocess,'run',return_value=SimpleNamespace(returncode=0,stderr=b'Signature=adhoc runtime')):
                self.assertEqual(prepare.validate_bundle(app)['architectures'],['arm64','x86_64'])
                (resources/'Aide.md').unlink()
                with self.assertRaises(prepare.PreparationError): prepare.validate_bundle(app)
            with patch.object(prepare,'run',return_value=b'arm64'):
                with self.assertRaises(prepare.PreparationError): prepare.validate_bundle(app)

    def test_invalid_usage_code(self):
        with self.assertRaises(SystemExit) as error: prepare.parser().parse_args(['--unknown'])
        self.assertEqual(error.exception.code,64)

if __name__ == '__main__': unittest.main()
