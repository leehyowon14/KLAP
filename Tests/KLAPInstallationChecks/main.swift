import AppKit
MainActor.assumeIsolated {
    let home=URL(fileURLWithPath:"/Users/test")
    for (path,expected) in [("/Applications/KLAP.app",true),("/Applications/Utilities/KLAP.app",true),("/Users/test/Applications/KLAP-Dev.app",true),("/Applications-fake/KLAP.app",false),("/Users/test/Downloads/KLAP.app",false),("/Volumes/KLAP/KLAP.app",false),("/Applications/../tmp/KLAP.app",false)] {
        precondition(InstallationNotice.isInstalled(URL(fileURLWithPath:path),home:home)==expected,path)
    }
    let fm=FileManager.default
    let root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? fm.removeItem(at:root)}
    let source=root.appendingPathComponent("Source.app"),target=root.appendingPathComponent("Applications/KLAP.app")
    try! fm.createDirectory(at:source,withIntermediateDirectories:true)
    try! Data("new".utf8).write(to:source.appendingPathComponent("payload"))
    try! InstallationNotice.install(source:source,destination:target,replace:false)
    precondition(fm.fileExists(atPath:source.path))
    precondition(try! String(contentsOf:target.appendingPathComponent("payload"),encoding:.utf8) == "new")
    do {try InstallationNotice.install(source:source,destination:target,replace:false);preconditionFailure("Must reject collision")} catch {}
    do {try InstallationNotice.install(source:root.appendingPathComponent("missing.app"),destination:target,replace:true);preconditionFailure("Must reject missing source")} catch {}
    precondition(try! String(contentsOf:target.appendingPathComponent("payload"),encoding:.utf8) == "new")
    try! Data("replacement".utf8).write(to:source.appendingPathComponent("payload"))
    try! InstallationNotice.install(source:source,destination:target,replace:true)
    precondition(try! String(contentsOf:target.appendingPathComponent("payload"),encoding:.utf8) == "replacement")
    print("Installation location boundary checks passed")
}
