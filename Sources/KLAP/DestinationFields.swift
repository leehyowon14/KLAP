import SwiftUI
import AppKit

struct DestinationFields: View {
    @ObservedObject var setup:SetupModel
    var body:some View {
        VStack(spacing:0) {
            row("시간표",selection:$setup.timetable,options:setup.calendars,newName:setup.newTimetable)
            Divider()
            row("학사일정",selection:$setup.academic,options:setup.calendars,newName:setup.newAcademic)
            Divider()
            row("미리 알림",selection:$setup.reminder,options:setup.reminders,newName:setup.newReminder)
        }.padding(.horizontal,14).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
    private func row(_ title:String,selection:Binding<String>,options:[String],newName:String)->some View {
        HStack(spacing:16) {
            Text(title).font(.callout.weight(.medium)).frame(width:64,alignment:.leading)
            Spacer(minLength:0)
            DestinationPicker(selection:selection,options:[""]+options,titles:["새로 만들기 · " + newName]+options,label:title)
                .frame(width:240,height:36)
                .padding(.horizontal,8).background(Color.primary.opacity(0.06),in:RoundedRectangle(cornerRadius:10))

        }.frame(minHeight:54)
    }
}

struct DestinationSettings: View {
    @ObservedObject var model:AppModel
    @ObservedObject var setup:SetupModel
    @ViewState<Bool> private var saved=false
    @ViewState<String?> private var saveError=nil
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if setup.ready {
                DestinationFields(setup:setup).disabled(model.busy)
                HStack {
                    if saved { Label("등록 위치를 저장했습니다",systemImage:"checkmark.circle").font(.caption).foregroundStyle(.secondary) }
                    if !saved, let date=model.lastSync {
                        Text("마지막 동기화 \(date.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("저장") { Task { saved=await model.saveDestinations(); saveError = saved ? nil : model.error } }
                        .buttonStyle(FormButtonStyle(prominent:true,compact:true)).disabled(model.busy)
                }
            } else {
                Button(setup.loading ? "불러오는 중…" : "캘린더·목록 불러오기") { Task { await setup.requestAccess() } }
                    .disabled(setup.loading || model.busy)
            }
            if let error=setup.error ?? saveError { Text(error).font(.caption).foregroundStyle(.red) }
        }.frame(maxWidth:.infinity,alignment:.leading)
        .task { await setup.requestAccess() }
        .onChange(of:setup.timetable) { _ in saved=false }
        .onChange(of:setup.academic) { _ in saved=false }
        .onChange(of:setup.reminder) { _ in saved=false }
    }
}


private struct DestinationPicker: NSViewRepresentable {
    @Binding var selection:String
    let options:[String]
    let titles:[String]
    let label:String
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context:Context) -> NSPopUpButton {
        let button=NSPopUpButton(frame:.zero,pullsDown:false)
        button.controlSize = .large
        button.isBordered=false
        button.font = .systemFont(ofSize:13)
        button.setContentHuggingPriority(.defaultLow,for:.horizontal)
        button.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
        button.target=context.coordinator
        button.action=#selector(Coordinator.changed(_:))
        return button
    }
    func updateNSView(_ button:NSPopUpButton,context:Context) {
        context.coordinator.parent=self
        if button.itemTitles != titles { button.removeAllItems();button.addItems(withTitles:titles) }
        button.selectItem(at:options.firstIndex(of:selection) ?? 0)
        button.isEnabled=enabled
        button.contentTintColor = .labelColor
        button.setAccessibilityLabel(label)
    }
    final class Coordinator:NSObject {
        var parent:DestinationPicker
        init(_ parent:DestinationPicker) { self.parent=parent }
        @objc func changed(_ sender:NSPopUpButton) {
            guard parent.options.indices.contains(sender.indexOfSelectedItem) else { return }
            parent.selection=parent.options[sender.indexOfSelectedItem]
        }
    }
}
