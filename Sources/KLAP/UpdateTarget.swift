import Foundation
import Security

@MainActor enum UpdateTarget {
    static let failure=NSError(domain:"KLAP.Update",code:2,userInfo:[NSLocalizedDescriptionKey:"업데이트할 원본 KLAP을 확인하지 못했습니다. 응용 프로그램 폴더의 앱을 확인한 뒤 다시 실행해 주세요."])

    static func resolve(running:Bundle, original:@MainActor (URL)->URL? = {InstallationNotice.originalURL($0)}, installed:@MainActor (URL)->Bool = {InstallationNotice.isInstalled($0)}) throws -> Bundle {
        guard running.bundleURL.pathComponents.contains("AppTranslocation") else {return running}
        guard let url=original(running.bundleURL),
              !url.resolvingSymlinksInPath().pathComponents.contains("AppTranslocation"),
              installed(url),let target=Bundle(url:url),matches(running,target) else {throw failure}
        return target
    }

    static func matches(_ running:Bundle,_ target:Bundle)->Bool {
        for key in ["CFBundleIdentifier","CFBundleVersion","CFBundleShortVersionString","SUPublicEDKey","SUFeedURL"] {
            guard let value=running.object(forInfoDictionaryKey:key) as? String,
                  !value.isEmpty,target.object(forInfoDictionaryKey:key) as? String == value else {return false}
        }
        guard let current=signature(running.bundleURL),let candidate=signature(target.bundleURL) else {return false}
        return current == candidate
    }

    // The code-directory hash also covers signed resources. Validate nested code before trusting it.
    private static func signature(_ url:URL)->Data? {
        var code:SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL,SecCSFlags(),&code)==errSecSuccess,let code else {return nil}
        let flags=SecCSFlags(rawValue:kSecCSStrictValidate | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures)
        guard SecStaticCodeCheckValidity(code,flags,nil)==errSecSuccess else {return nil}
        var information:CFDictionary?
        guard SecCodeCopySigningInformation(code,SecCSFlags(rawValue:kSecCSSigningInformation),&information)==errSecSuccess,
              let info=information as? [String:Any] else {return nil}
        return info[kSecCodeInfoUnique as String] as? Data
    }
}
