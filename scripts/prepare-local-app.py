#!/usr/bin/env python3
"""Prépare une Release locale validée, sans installer ni modifier les documents."""
import argparse
import base64
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import unicodedata

ROOT = Path(__file__).resolve().parent.parent
SOURCE_NAME = 'Icône Markdown personnalisable en couches.png'
SOURCE_HASH = '2f568a19b834a308bce6c9ec56194f6c1e4090a69e5d6381ac3a6c350ce05be7'
ICON_SIZES = {f'icon_{n}x{n}{"@2x" if scale == 2 else ""}.png': n*scale for n in (16,32,128,256,512) for scale in (1,2)}
RIGHTS = {k: True for k in ('com.apple.security.app-sandbox','com.apple.security.files.user-selected.read-only','com.apple.security.network.client')}
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')

class PreparationError(Exception):
    def __init__(self, code, message): self.code=code; super().__init__(message)

class Parser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(64, f'Arguments invalides : {message}\n')

def parser():
    p=Parser(description='Préparer outilVizMd sous build/local, sans installation.')
    p.add_argument('--offline',action='store_true',help='Exiger un cache complet, sans téléchargement.')
    p.add_argument('--package-cache',type=Path,default=ROOT/'build/SourcePackages')
    return p

def run(args):
    result=subprocess.run([str(a) for a in args],env=ENV,capture_output=True,timeout=900)
    if result.returncode:
        raise PreparationError(6, f'Échec de {args[0]} :\n{result.stderr.decode(errors="replace")}\n{result.stdout.decode(errors="replace")}')
    return result.stdout

def sha(data): return hashlib.sha256(data).hexdigest()

def validate_source(root):
    matches=[p for p in root.iterdir() if unicodedata.normalize('NFC',p.name)==SOURCE_NAME]
    if len(matches)!=1: raise PreparationError(4,'Image source absente ou ambiguë ; rétablir l’original identifié.')
    p=matches[0]
    try: data=p.read_bytes()
    except OSError as e: raise PreparationError(5,f'Image inaccessible : {e}') from e
    if p.is_symlink() or len(data)<24 or data[:8]!=b'\x89PNG\r\n\x1a\n' or struct.unpack('>II',data[16:24])!=(1254,1254) or sha(data)!=SOURCE_HASH:
        raise PreparationError(4,'Image différente ou invalide ; rétablir le PNG original 1254 × 1254.')
    return p

def validate_icon(path):
    data=path.read_bytes()
    if data[:4]!=b'icns' or len(data)<8 or int.from_bytes(data[4:8],'big')!=len(data):
        raise PreparationError(6,'ICNS absent ou invalide ; relancer la préparation depuis l’image originale.')
    with tempfile.TemporaryDirectory(prefix='outilvizmd-icon-check-') as tmp:
        out=Path(tmp)/'check.iconset'
        run(['/usr/bin/iconutil','-c','iconset',path,'-o',out])
        for name, size in ICON_SIZES.items():
            image=out/name
            if not image.is_file(): raise PreparationError(6,f'Représentation ICNS manquante : {name}')
            values=run(['/usr/bin/sips','-g','pixelWidth','-g','pixelHeight',image]).decode()
            if f'pixelWidth: {size}' not in values or f'pixelHeight: {size}' not in values:
                raise PreparationError(6,f'Taille ICNS incorrecte : {name}')

def generate_icon(root):
    source=validate_source(root)
    with tempfile.TemporaryDirectory(prefix='outilvizmd-icon-') as tmp:
        iconset=Path(tmp)/'AppIcon.iconset'; iconset.mkdir()
        for name,size in ICON_SIZES.items():
            run(['/usr/bin/sips','-z',size,size,source,'--out',iconset/name])
        icon=Path(tmp)/'AppIcon.icns'
        run(['/usr/bin/iconutil','-c','icns',iconset,'-o',icon])
        validate_icon(icon); validate_source(root)
        destination=root/'outilVizMd/Resources/AppIcon.icns'
        # Le dérivé est remplaçable ; l’original n’est jamais ouvert en écriture.
        with tempfile.NamedTemporaryFile(dir=destination.parent,delete=False) as f:
            temporary=Path(f.name); f.write(icon.read_bytes())
        os.replace(temporary,destination)
    return destination

def bundle_digest(bundle):
    rows=[]; real=bundle.resolve()
    for p in sorted(bundle.rglob('*'),key=lambda p:unicodedata.normalize('NFC',p.relative_to(bundle).as_posix()).encode()):
        mode=p.lstat().st_mode; relative=unicodedata.normalize('NFC',p.relative_to(bundle).as_posix())
        name=base64.b64encode(relative.encode()).decode()
        if stat.S_ISLNK(mode):
            target=p.resolve()
            if target!=real and real not in target.parents:
                raise PreparationError(4,f'Lien sortant du bundle : {relative}')
            kind='L'; executable=0; content=base64.b64encode(unicodedata.normalize('NFC',os.readlink(p)).encode()).decode()
        elif stat.S_ISDIR(mode): kind='D'; executable=0; content=''
        elif stat.S_ISREG(mode): kind='F'; executable=mode & 0o111; content=sha(p.read_bytes())
        else: raise PreparationError(4,f'Objet spécial interdit : {relative}')
        rows.append(f'{name}\t{kind}\t{executable}\t{content}\n')
    return sha(''.join(rows).encode())

def validate_cache(root,cache):
    pins=json.loads((root/'outilVizMd.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())['pins']
    # Toute absence est détectée avant de lancer Xcode.
    if not (cache/'workspace-state.json').is_file() or any(not (cache/'checkouts'/p['identity']/'Package.swift').is_file() for p in pins):
        raise PreparationError(6,'Cache hors ligne incomplet ; préparer les dépendances sans --offline puis réessayer.')
    for pin in pins:
        checkout=cache/'checkouts'/pin['identity']
        revision=run(['/usr/bin/git','-C',checkout,'rev-parse','HEAD']).decode().strip()
        if revision!=pin['state']['revision']: raise PreparationError(6,f'Cache non verrouillé : {pin["identity"]}')

def validate_bundle(bundle,source_hash=SOURCE_HASH):
    if bundle.is_symlink() or not bundle.is_dir(): raise PreparationError(4,'Bundle réel .app attendu.')
    info=plistlib.loads((bundle/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier')!='com.outilvizmd.outilVizMd' or info.get('CFBundlePackageType')!='APPL' or info.get('CFBundleIconFile')!='AppIcon.icns' or info.get('LSMinimumSystemVersion')!='14.0':
        raise PreparationError(6,'Identité, minimum système ou icône du bundle non conforme.')
    name=info.get('CFBundleExecutable','')
    if not name or '/' in name: raise PreparationError(6,'Exécutable déclaré invalide.')
    binary=bundle/'Contents/MacOS'/name
    if not binary.is_file() or not os.access(binary,os.X_OK): raise PreparationError(6,'Exécutable absent ou non exécutable.')
    architectures=sorted(run(['/usr/bin/lipo','-archs',binary]).decode().split())
    if architectures!=['arm64','x86_64']: raise PreparationError(6,'Release universelle arm64 + x86_64 requise.')
    commands=run(['/usr/bin/otool','-l',binary]).decode()
    minima=re.findall(r'^\s*minos\s+(\S+)',commands,re.M)
    if len(minima)!=2 or any(tuple(map(int,value.split('.')))[:2]>(14,0) for value in minima):
        raise PreparationError(6,'Minimum système des exécutables incompatible avec macOS 14.')
    for rpath in re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset',commands):
        if not rpath.startswith(('/usr/lib/','/System/Library/','@executable_path/','@loader_path/')):
            raise PreparationError(6,f'Chemin dynamique non autonome : {rpath}')
        if rpath.startswith('@'):
            resolved=(binary.parent/rpath.split('/',1)[1]).resolve()
            if bundle.resolve() not in resolved.parents: raise PreparationError(6,f'Chemin dynamique sortant du bundle : {rpath}')
    run(['/usr/bin/codesign','--verify','--deep','--strict',bundle])
    signature=subprocess.run(['/usr/bin/codesign','-d','--verbose=4',str(bundle)],capture_output=True,env=ENV)
    detail=signature.stderr.decode()
    if signature.returncode or 'Signature=adhoc' not in detail or 'runtime' not in detail: raise PreparationError(6,'Signature ad hoc avec Hardened Runtime requise.')
    rights=plistlib.loads(run(['/usr/bin/codesign','-d','--entitlements',':-',bundle]))
    if rights!=RIGHTS: raise PreparationError(6,'Droits effectifs différents des trois droits autorisés.')
    resources=bundle/'Contents/Resources'; icon=resources/'AppIcon.icns'; validate_icon(icon)
    for name in ('ReaderBase.css','NetworkBlockRules.json','Aide.md','ThirdPartyNotices.txt'):
        if not (resources/name).is_file(): raise PreparationError(6,f'Ressource absente : {name}')
    for path in bundle.rglob('*'):
        if path.suffix=='.xctest': raise PreparationError(6,'Bundle de tests interdit dans la Release.')
        if not path.is_file() or path.is_symlink(): continue
        with path.open('rb') as f: magic=f.read(4)
        if magic not in (b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'): continue
        listing=run(['/usr/bin/otool','-L',path]).decode()
        for line in listing.splitlines():
            if not line.startswith('\t'): continue
            dependency=line.strip().split(' (')[0]
            if not dependency.startswith(('/System/Library/','/usr/lib/','@rpath/','@loader_path/','@executable_path/')):
                raise PreparationError(6,f'Dépendance non autonome : {dependency}')
    return dict(schemaVersion=1,bundleIdentifier=info['CFBundleIdentifier'],version=info['CFBundleShortVersionString'],build=info['CFBundleVersion'],architectures=architectures,minimumOS='14.0',sourceSHA256=source_hash,iconSHA256=sha(icon.read_bytes()),bundleDigest=bundle_digest(bundle))

def atomic_rename(source,target,flags):
    libc=ctypes.CDLL(None,use_errno=True)
    if libc.renamex_np(os.fsencode(source),os.fsencode(target),flags)!=0:
        code=ctypes.get_errno(); raise OSError(code,os.strerror(code))

def publish(stage,destination):
    # Le Bureau synchronisé ajoute FinderInfo aux .app. Le produit reste donc dans
    # un dossier privé temporaire ; seul son accès local est publié dans le dépôt.
    pointer=destination.parent / ('.prepared-pointer-' + stage.parent.name)
    pointer.symlink_to(stage, target_is_directory=True)
    try:
        atomic_rename(pointer,destination,2 if os.path.lexists(destination) else 4)
    finally:
        # Après échange, pointer est l’ancien accès. Ne jamais suivre sa cible ici.
        if pointer.is_symlink(): pointer.unlink()
        elif pointer.exists():
            print(f'Ancienne sortie conservée : {pointer}. Inspecter avant nettoyage.',file=sys.stderr)


def sign_prepared_bundle(bundle):
    # Finder/File Provider peut ajouter ces métadonnées au produit de construction.
    # Ne retirer que celles interdites par codesign, jamais la quarantaine.
    for path in [bundle, *bundle.rglob('*')]:
        attributes=run(['/usr/bin/xattr','-s',path]).decode().splitlines()
        for attribute in ('com.apple.FinderInfo','com.apple.ResourceFork'):
            if attribute in attributes:
                run(['/usr/bin/xattr','-s','-d',attribute,path])
    run(['/usr/bin/codesign','--force','--sign','-','--options','runtime','--entitlements',ROOT/'outilVizMd/outilVizMd.entitlements',bundle])


def prepare(args):
    validate_source(ROOT)
    cache=args.package_cache.resolve()
    if args.offline: validate_cache(ROOT,cache)
    generate_icon(ROOT)
    run([sys.executable,ROOT/'scripts/update-xcode-project.py'])
    build=ROOT/'build'; build.mkdir(exist_ok=True)
    tmp=Path(tempfile.mkdtemp(prefix='outilVizMd-prepared-'))
    published=False
    try:
        stage=tmp/'local'; stage.mkdir()
        command=['/usr/bin/xcodebuild','-quiet','-project',ROOT/'outilVizMd.xcodeproj','-scheme','outilVizMd','-configuration','Release','-destination','generic/platform=macOS','-derivedDataPath',build/'LocalDerivedData','-clonedSourcePackagesDirPath',cache,'-onlyUsePackageVersionsFromResolvedFile','-disableAutomaticPackageResolution','-skipPackageUpdates','ARCHS=arm64 x86_64','ONLY_ACTIVE_ARCH=NO','build']
        run(command)
        run(['/usr/bin/ditto',build/'LocalDerivedData/Build/Products/Release/outilVizMd.app',stage/'outilVizMd.app'])
        sign_prepared_bundle(stage/'outilVizMd.app')
        manifest=validate_bundle(stage/'outilVizMd.app')
        run(['/usr/bin/swift','build','--package-path',ROOT/'tools/LocalDeployment','--configuration','release','--scratch-path',build/'LocalDeployment'])
        binpath=run(['/usr/bin/swift','build','--package-path',ROOT/'tools/LocalDeployment','--configuration','release','--scratch-path',build/'LocalDeployment','--show-bin-path']).decode().strip()
        shutil.copy2(Path(binpath)/'install-local-app',stage/'install-local-app')
        (stage/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        validate_source(ROOT)
        publish(stage,build/'local')
        published=True
    finally:
        if not published: shutil.rmtree(tmp)
    print(f'Release {manifest["version"]} prête : {build / "local/outilVizMd.app"}\nManifeste et outil : {build / "local"}\nAucune installation effectuée.')

def main():
    try: prepare(parser().parse_args())
    except PreparationError as e: print(str(e),file=sys.stderr); return e.code
    except OSError as e: print(f'Accès/espace : {e}. Corriger les droits ou libérer de l’espace puis réessayer.',file=sys.stderr); return 5
    except (subprocess.TimeoutExpired,ValueError,KeyError) as e: print(f'Préparation échouée : {e}. Vérifier outils/cache et relancer.',file=sys.stderr); return 6
    return 0

if __name__=='__main__': sys.exit(main())
