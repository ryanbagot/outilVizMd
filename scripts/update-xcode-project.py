#!/usr/bin/env python3
"""Reconstruit le projet Xcode depuis les sources, sans dépendance externe ni réseau."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent.parent
objects = {}


def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def ref(name):
    return ident(name)


def obj(key, isa, **fields):
    objects[ident(key)] = dict(isa=isa, **fields)
    return ident(key)


def quote(value):
    return json.dumps(value, ensure_ascii=False)


def emit(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (level + 1) + quote(k) + " = " + emit(v, level + 1) + ";\n" for k, v in value.items()) + "\t" * level + "}"
    if isinstance(value, list):
        return "(\n" + "".join("\t" * (level + 1) + emit(v, level + 1) + ",\n" for v in value) + "\t" * level + ")"
    if isinstance(value, int):
        return str(value)
    return quote(value)


targets = [("outilVizMd", "application", "app"), ("outilVizMdTests", "bundle.unit-test", "xctest"), ("outilVizMdUITests", "bundle.ui-testing", "xctest")]
groups = []
products = []
for name, product_type, extension in targets:
    source_refs, sources, resources = [], [], []
    folder = ROOT / name
    if name == "outilVizMdTests" and (folder / "Fixtures").exists():
        fixture_ref = obj("fixtures-folder", "PBXFileReference", lastKnownFileType="folder", path="Fixtures", sourceTree="<group>")
        source_refs.append(fixture_ref)
        resources.append(obj("fixtures-build", "PBXBuildFile", fileRef=fixture_ref))
    for p in sorted(folder.rglob("*")):
        if not p.is_file() or p.name.startswith("."):
            continue
        if name == "outilVizMdTests" and p.relative_to(folder).parts[0] == "Fixtures":
            continue
        rel = p.relative_to(ROOT).as_posix()
        file_type = {".swift": "sourcecode.swift", ".entitlements": "text.plist.entitlements", ".md": "net.daringfireball.markdown", ".json": "text.json", ".css": "text.css", ".txt": "text", ".png": "image.png", ".jpg": "image.jpeg", ".gif": "image.gif"}.get(p.suffix, "file")
        source_refs.append(obj("file:" + rel, "PBXFileReference", lastKnownFileType=file_type, path=p.relative_to(folder).as_posix(), sourceTree="<group>"))
        if p.suffix == ".swift":
            sources.append(obj("build:" + rel, "PBXBuildFile", fileRef=ref("file:" + rel)))
        elif p.suffix != ".entitlements":
            resources.append(obj("build:" + rel, "PBXBuildFile", fileRef=ref("file:" + rel)))
    groups.append(obj("group:" + name, "PBXGroup", children=source_refs, path=name, sourceTree="<group>"))
    product = obj("product:" + name, "PBXFileReference", explicitFileType="wrapper.application" if extension == "app" else "wrapper.cfbundle", includeInIndex=0, path=name + "." + extension, sourceTree="BUILT_PRODUCTS_DIR")
    products.append(product)
    phases = [obj("sources:" + name, "PBXSourcesBuildPhase", buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0), obj("frameworks:" + name, "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0), obj("resources:" + name, "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0)]
    configs = []
    for config in ["Debug", "Release"]:
        settings = dict(PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.outilvizmd." + name, GENERATE_INFOPLIST_FILE="YES", CODE_SIGN_IDENTITY="-", CODE_SIGN_STYLE="Manual", SWIFT_VERSION="5.0", SWIFT_STRICT_CONCURRENCY="complete", MACOSX_DEPLOYMENT_TARGET="14.0", LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"])
        if name == "outilVizMd":
            settings.update(CODE_SIGN_ENTITLEMENTS="outilVizMd/outilVizMd.entitlements", ENABLE_APP_SANDBOX="YES", ENABLE_USER_SELECTED_FILES="readonly", INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.productivity", INFOPLIST_KEY_CFBundleDisplayName="outilVizMd", MARKETING_VERSION="0.1.0", CURRENT_PROJECT_VERSION="1", ENABLE_HARDENED_RUNTIME="YES", CODE_SIGN_INJECT_BASE_ENTITLEMENTS="YES" if config == "Debug" else "NO")
        elif name == "outilVizMdTests":
            settings.update(TEST_HOST="$(BUILT_PRODUCTS_DIR)/outilVizMd.app/Contents/MacOS/outilVizMd", BUNDLE_LOADER="$(TEST_HOST)")
        else:
            settings.update(TEST_TARGET_NAME="outilVizMd")
        configs.append(obj("config:" + name + ":" + config, "XCBuildConfiguration", buildSettings=settings, name=config))
    config_list = obj("configs:" + name, "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    dependencies = []
    if name != "outilVizMd":
        proxy = obj("proxy:" + name, "PBXContainerItemProxy", containerPortal=ref("project"), proxyType=1, remoteGlobalIDString=ref("target:outilVizMd"), remoteInfo="outilVizMd")
        dependencies.append(obj("dependency:" + name, "PBXTargetDependency", target=ref("target:outilVizMd"), targetProxy=proxy))
    obj("target:" + name, "PBXNativeTarget", buildConfigurationList=config_list, buildPhases=phases, buildRules=[], dependencies=dependencies, name=name, productName=name, productReference=product, productType="com.apple.product-type." + product_type)

package_marker = ROOT / "scripts" / "markdown-package.json"
if package_marker.exists():
    package = json.loads(package_marker.read_text())
    obj("markdown-package", "XCRemoteSwiftPackageReference", repositoryURL=package["url"], requirement=dict(kind="exactVersion", version=package["version"]))
    obj("markdown-product", "XCSwiftPackageProductDependency", package=ref("markdown-package"), productName="Markdown")
    obj("markdown-framework", "PBXBuildFile", productRef=ref("markdown-product"))
    objects[ref("frameworks:outilVizMd")]["files"].append(ref("markdown-framework"))
    objects[ref("target:outilVizMd")]["packageProductDependencies"] = [ref("markdown-product")]

group_products = obj("products", "PBXGroup", children=products, name="Products", sourceTree="<group>")
main = obj("main-group", "PBXGroup", children=groups + [group_products], sourceTree="<group>")
configs = []
for config in ["Debug", "Release"]:
    settings = dict(SDKROOT="macosx", ARCHS="$(ARCHS_STANDARD)", MACOSX_DEPLOYMENT_TARGET="14.0", SWIFT_VERSION="5.0", SWIFT_STRICT_CONCURRENCY="complete", CLANG_ENABLE_MODULES="YES", ENABLE_TESTABILITY="YES" if config == "Debug" else "NO", SWIFT_OPTIMIZATION_LEVEL="-Onone" if config == "Debug" else "-O", DEBUG_INFORMATION_FORMAT="dwarf" if config == "Debug" else "dwarf-with-dsym", ONLY_ACTIVE_ARCH="YES" if config == "Debug" else "NO")
    configs.append(obj("project-config:" + config, "XCBuildConfiguration", buildSettings=settings, name=config))
project_configs = obj("project-configs", "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
obj("project", "PBXProject", attributes=dict(BuildIndependentTargetsInParallel="YES", LastUpgradeCheck="1600", TargetAttributes={ref("target:" + name): dict(CreatedOnToolsVersion="16.0", **({"TestTargetID": ref("target:outilVizMd")} if name != "outilVizMd" else {})) for name, _, _ in targets}), buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="fr", hasScannedForEncodings=0, knownRegions=["fr", "en", "Base"], mainGroup=main, productRefGroup=group_products, projectDirPath="", projectRoot="", targets=[ref("target:" + name) for name, _, _ in targets], packageReferences=[ref("markdown-package")] if package_marker.exists() else [])
project_dir = ROOT / "outilVizMd.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n" + emit(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=ref("project"))) + "\n")

scheme_dir = project_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)


def build_ref(name, extension):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref("target:" + name)}" BuildableName="{name}.{extension}" BlueprintName="{name}" ReferencedContainer="container:outilVizMd.xcodeproj"/>'


scheme = '<?xml version="1.0" encoding="UTF-8"?>\n<Scheme LastUpgradeVersion="1600" version="1.3">\n'
scheme += '<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>'
for name, _, extension in targets:
    flag = "YES" if name == "outilVizMd" else "NO"
    scheme += f'<BuildActionEntry buildForTesting="YES" buildForRunning="{flag}" buildForProfiling="{flag}" buildForArchiving="{flag}" buildForAnalyzing="YES">{build_ref(name, extension)}</BuildActionEntry>'
scheme += '</BuildActionEntries></BuildAction>\n<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'
for name, _, extension in targets[1:]:
    # Un runner XCUITest vide demande inutilement l’activation de l’automatisation macOS.
    # L’ajout du premier parcours UI l’active automatiquement à la régénération du projet.
    has_ui_tests = name != "outilVizMdUITests" or any(
        re.search(r"\bfunc\s+test\w*\s*\(", p.read_text())
        for p in (ROOT / name).rglob("*.swift")
    )
    skipped = "NO" if has_ui_tests else "YES"
    scheme += f'<TestableReference skipped="{skipped}">{build_ref(name, extension)}</TestableReference>'
scheme += '</Testables></TestAction>\n<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="NO" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">' + build_ref("outilVizMd", "app") + '</BuildableProductRunnable></LaunchAction>\n'
scheme += '<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="NO"><BuildableProductRunnable runnableDebuggingMode="0">' + build_ref("outilVizMd", "app") + '</BuildableProductRunnable></ProfileAction>\n<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>\n</Scheme>\n'
(scheme_dir / "outilVizMd.xcscheme").write_text(scheme)
print(f"Projet mis à jour : {len(objects)} objets, {len(targets)} cibles")
