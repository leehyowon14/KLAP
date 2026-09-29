import SwiftUI

struct AttendanceHeader:View {
    @Binding var cdp:Bool
    let showsPicker:Bool
    let loading:Bool
    let onBack:()->Void
    var body:some View {
        HStack(spacing:12) {
            Button(action:onBack) {
                HStack(spacing:8) {
                    Image(systemName:"chevron.left").font(.headline)
                    Text("출석 조회").font(.title2.bold()).fixedSize()
                }.frame(minHeight:44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("출석 조회, 뒤로")
            Spacer(minLength:0)
            if showsPicker {
                Picker("출석 구분",selection:$cdp) {
                    Text("과목별 출석").tag(false)
                    Text("CDP 출석").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width:190).disabled(loading)
            }
        }
    }
}
