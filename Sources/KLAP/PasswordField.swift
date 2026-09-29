import AppKit
import SwiftUI
import Carbon

private final class RomanSecureField:NSSecureTextField {
    override func becomeFirstResponder() -> Bool {
        // Secure editors cannot compose Hangul. Select the user's ASCII keyboard
        // before editing so key presses are entered instead of silently ignored.
        if let source=TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue() {
            TISSelectInputSource(source)
        }
        return super.becomeFirstResponder()
    }
}

struct PasswordField:View {
    let placeholder:String
    @Binding var text:String
    var body:some View {
        SecureEditor(placeholder:placeholder,text:$text)
            .padding(.horizontal,12).frame(height:44)
            .background(Theme.surface,in:RoundedRectangle(cornerRadius:9))
            .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(Theme.line))
    }
}
private struct SecureEditor:NSViewRepresentable {
    let placeholder:String
    @Binding var text:String
    func makeCoordinator()->Coordinator { Coordinator(self) }
    func makeNSView(context:Context)->NSSecureTextField {
        let field=RomanSecureField()
        field.isBordered=false;field.drawsBackground=false
        field.font = .systemFont(ofSize:14)
        field.delegate=context.coordinator
        field.setContentHuggingPriority(.defaultLow,for:.horizontal)
        return field
    }
    func updateNSView(_ field:NSSecureTextField,context:Context) {
        context.coordinator.parent=self
        field.placeholderString=placeholder
        field.setAccessibilityLabel("비밀번호")
        if field.stringValue != text { field.stringValue=text }
    }
    final class Coordinator:NSObject,NSTextFieldDelegate {
        var parent:SecureEditor
        init(_ parent:SecureEditor) {self.parent=parent}
        func controlTextDidChange(_ notification:Notification) {
            guard let field=notification.object as? NSSecureTextField else {return}
            parent.text=field.stringValue
        }
        func controlTextDidBeginEditing(_ notification:Notification) {
            (notification.object as? NSSecureTextField)?.currentEditor()?.inputContext?.allowedInputSourceLocales=[NSAllRomanInputSourcesLocaleIdentifier]
        }
    }
}
