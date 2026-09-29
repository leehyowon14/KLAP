import SwiftUI

/// Give the editor itself padding; enlarging the native rounded bezel alone
/// leaves a thin input control floating inside a larger layout frame.
struct AccountFieldStyle: ViewModifier {
    @FocusState private var isFocused: Bool
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(size:14))
            .padding(.horizontal,12)
            .frame(height:44)
            .background(.background.opacity(0.65),in:RoundedRectangle(cornerRadius:9))
            .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(isFocused ? Color.accentColor : Color.primary.opacity(0.2),lineWidth:isFocused ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius:9))
            .onTapGesture { isFocused = true }
    }
}

struct FormButtonStyle: ButtonStyle {
    var prominent = false
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size:compact ? 12 : 14,weight:.medium))
            .padding(.horizontal,compact ? 12 : 16).frame(minWidth:compact ? 48 : 72,minHeight:compact ? 30 : 44)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? Color.accentColor : Color.primary.opacity(0.07),in:RoundedRectangle(cornerRadius:9))
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
    }
}
