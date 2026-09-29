import AppKit
MainActor.assumeIsolated {
    let home=URL(fileURLWithPath:"/Users/test")
    for (path,expected) in [("/Applications/KLAP.app",true),("/Applications/Utilities/KLAP.app",true),("/Users/test/Applications/KLAP-Dev.app",true),("/Applications-fake/KLAP.app",false),("/Users/test/Downloads/KLAP.app",false),("/Volumes/KLAP/KLAP.app",false),("/Applications/../tmp/KLAP.app",false)] {
        precondition(InstallationNotice.isInstalled(URL(fileURLWithPath:path),home:home)==expected,path)
    }
    print("Installation location boundary checks passed")
}
