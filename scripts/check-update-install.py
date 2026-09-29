#!/usr/bin/env python3
"""Local Sparkle installation check; creates only disposable test bundles and keys."""
import functools, http.server, os, pathlib, plistlib, shutil, subprocess, tempfile, threading, time, sys
repo=pathlib.Path(__file__).resolve().parent.parent
os.chdir(repo)
env=dict(os.environ,DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR','/Library/Developer/CommandLineTools'))
def run(*args, **kw):return subprocess.run(args,check=True,env=env,**kw)
with tempfile.TemporaryDirectory(prefix='klap-update-install-') as tmp:
    root=pathlib.Path(tmp).resolve()
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=tmp))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    base=f'http://127.0.0.1:{server.server_port}'
    gatekeeper='--gatekeeper' in sys.argv
    original=root/'Applications/KLAPUpdateInstallChecks.app'
    installed=pathlib.Path.home()/'Applications'/('KLAPGatekeeperCheck-'+root.name+'.app') if gatekeeper else original
    output=root/'result.txt'
    helper=root/'crypto.swift'
    helper.write_text('''import Foundation
import CryptoKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
if CommandLine.arguments.count == 2 {
let key=Curve25519.Signing.PrivateKey()
try key.rawRepresentation.write(to:root.appendingPathComponent("key"))
print(key.publicKey.rawRepresentation.base64EncodedString())
} else {
let key=try Curve25519.Signing.PrivateKey(rawRepresentation:Data(contentsOf:root.appendingPathComponent("key")))
print(try key.signature(for:Data(contentsOf:root.appendingPathComponent("update.zip"))).base64EncodedString())
}
''')
    key=run('swift',str(helper),tmp,capture_output=True,text=True).stdout.strip()
    original.joinpath('Contents/MacOS').mkdir(parents=True)
    framework=repo/'.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64'
    run('swiftc','-swift-version','5','-F',str(framework),'-framework','Sparkle','-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks','Sources/KLAP/InstallationNotice.swift','Sources/KLAP/UpdateTarget.swift','Tests/KLAPUpdateInstallChecks/main.swift','-o',str(original/'Contents/MacOS/Check'))
    info=dict(CFBundleIdentifier='dev.leehyowon.klap.installcheck.'+root.name.replace('_','-'),CFBundleExecutable='Check',CFBundleName='KLAPUpdateInstallChecks',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1.0',LSMinimumSystemVersion='13.0',SUPublicEDKey=key,SUFeedURL=base+'/appcast.xml',SUEnableAutomaticChecks=False,SUAutomaticallyUpdate=False,SUHasLaunchedBefore=True,TestOriginal=str(installed),TestResult=str(output),TestGatekeeper=gatekeeper,NSAppTransportSecurity={'NSAllowsArbitraryLoads':True})
    original.joinpath('Contents/Info.plist').write_bytes(plistlib.dumps(info))
    run('bash','scripts/embed-updater.sh',str(original))
    run('codesign','--force','--sign','-',str(original))
    source=root/'AppTranslocation/test/d/KLAPUpdateInstallChecks.app'
    shutil.copytree(original,source,symlinks=True)
    update=root/'new/KLAPUpdateInstallChecks.app'
    shutil.copytree(original,update,symlinks=True)
    info['CFBundleVersion']='2';info['CFBundleShortVersionString']='2.0'
    update.joinpath('Contents/Info.plist').write_bytes(plistlib.dumps(info))
    run('codesign','--force','--sign','-',str(update))
    run('ditto','-c','-k','--keepParent',str(update),str(root/'update.zip'))
    signature=run('swift',str(helper),tmp,'sign',capture_output=True,text=True).stdout.strip()
    root.joinpath('appcast.xml').write_text(f'''<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Local test</title><item><title>2.0</title><sparkle:version>2</sparkle:version><sparkle:shortVersionString>2.0</sparkle:shortVersionString><enclosure url="{base}/update.zip" length="{(root/'update.zip').stat().st_size}" type="application/octet-stream" sparkle:edSignature="{signature}"/></item></channel></rss>''')
    # Default tests a relocated path. --read-only additionally uses a mounted DMG.
    # OS origin lookup is separately checked against a genuinely translocated app.
    mount=None
    if gatekeeper:
        run('ditto','-c','-k','--keepParent',str(original),str(root/'gatekeeper-test.zip'))
        manifest=dict(download=base+'/gatekeeper-test.zip',installed=str(installed),result=str(output),root=str(root))
        (repo/'.build/gatekeeper-test.json').write_text(__import__('json').dumps(manifest))
        print('Browser download ready: '+manifest['download'],flush=True)
        print('Install destination: '+str(installed),flush=True)
        deadline=time.monotonic()+900
        while not installed.exists():
            if time.monotonic()>deadline:raise RuntimeError('Browser installation not completed')
            time.sleep(1)
        source=installed
        original=installed
    if '--read-only' in sys.argv:
        disk=root/'source.dmg'
        run('hdiutil','create','-srcfolder',str(source.parent),'-format','UDRO','-volname','KLAPUpdateCheck',str(disk),stdout=subprocess.DEVNULL)
        mount=root/'AppTranslocation/mounted';mount.mkdir()
        run('hdiutil','attach','-readonly','-nobrowse','-mountpoint',str(mount),str(disk),stdout=subprocess.DEVNULL)
        source=mount/source.name
    try:
        run('open','-n',str(source))
        deadline=time.monotonic()+(600 if gatekeeper else 100)
        while time.monotonic()<deadline:
            text=output.read_text() if output.exists() else ''
            if 'ERROR:' in text:raise RuntimeError(text)
            if 'PASS relaunched' in text:
                assert plistlib.loads(original.joinpath('Contents/Info.plist').read_bytes())['CFBundleVersion']=='2'
                assert any(line.startswith('launch 2 ') and pathlib.Path(line[len('launch 2 '):]).resolve()==original for line in text.splitlines()),text
                print(text);print('Signed local update replaced original bundle and relaunched build 2')
                if gatekeeper:(repo/'.build/gatekeeper-result.txt').write_text(text)
                break
            time.sleep(1)
        else:raise RuntimeError('Timed out: '+(output.read_text() if output.exists() else 'no launch'))
    finally:
        server.shutdown()
        # Only stop this harness, never KLAP or its helpers.
        subprocess.run(['pkill','-f',str(root)+'.*/Contents/MacOS/Check'],check=False)
        if mount:run('hdiutil','detach',str(mount),stdout=subprocess.DEVNULL)
