from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class IconProjectTests(unittest.TestCase):
    def test_generated_project_embeds_icon_and_keeps_three_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name in ('scripts','outilVizMd','outilVizMdTests','outilVizMdUITests'):
                shutil.copytree(ROOT/name,root/name)
            (root/'outilVizMd/Resources/AppIcon.icns').write_bytes(b'fixture')
            subprocess.run(['python3',str(root/'scripts/update-xcode-project.py')],check=True,capture_output=True)
            data=subprocess.check_output(['plutil','-convert','xml1','-o','-',str(root/'outilVizMd.xcodeproj/project.pbxproj')])
            objects=plistlib.loads(data)['objects'].values()
            self.assertEqual(len([o for o in objects if o['isa']=='PBXNativeTarget']),3)
            refs=[o for o in objects if o.get('path')=='Resources/AppIcon.icns']
            self.assertEqual(len(refs),1); self.assertEqual(refs[0]['lastKnownFileType'],'image.icns')
            configs=[o['buildSettings'] for o in objects if o.get('buildSettings',{}).get('PRODUCT_BUNDLE_IDENTIFIER')=='com.outilvizmd.outilVizMd']
            self.assertEqual(len(configs),2)
            for settings in configs:
                self.assertEqual(settings['INFOPLIST_KEY_CFBundleIconFile'],'AppIcon.icns')
                self.assertEqual(settings['ENABLE_USER_SELECTED_FILES'],'readonly')
                self.assertEqual(settings['MARKETING_VERSION'],'0.1.0')
                self.assertEqual(settings['ENABLE_HARDENED_RUNTIME'],'YES')
