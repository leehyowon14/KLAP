import SwiftUI

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
            Picker(title,selection:selection) {
                Text("새로 만들기 · \(newName)").tag("")
                ForEach(options,id:\.self) { Text($0).tag($0) }
            }.labelsHidden().pickerStyle(.menu).controlSize(.large).frame(maxWidth:.infinity)
        }.frame(minHeight:54)
    }
}

struct DestinationSettings: View {
    @ObservedObject var model:AppModel
    @ObservedObject var setup:SetupModel
    @ViewState<Bool> private var saved=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if setup.ready {
                DestinationFields(setup:setup).disabled(model.busy)
                HStack {
                    if saved { Label("등록 위치를 저장했습니다",systemImage:"checkmark.circle").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("저장") { Task { saved=await model.saveDestinations() } }
                        .buttonStyle(FormButtonStyle(prominent:true,compact:true)).disabled(model.busy)
                }
            } else {
                Button(setup.loading ? "불러오는 중…" : "캘린더·목록 불러오기") { Task { await setup.requestAccess() } }
                    .disabled(setup.loading || model.busy)
            }
            if let error=setup.error ?? model.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .onChange(of:setup.timetable) { _ in saved=false }
        .onChange(of:setup.academic) { _ in saved=false }
        .onChange(of:setup.reminder) { _ in saved=false }
    }
}
