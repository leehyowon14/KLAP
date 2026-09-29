import SwiftUI

struct AttendanceCourseCard:View {
    let row:AttendanceCourseRow
    @ViewState<Bool> private var expanded:Bool
    init(row:AttendanceCourseRow,expanded:Bool=false) {
        self.row=row
        _expanded=ViewState(initialValue:expanded)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            Button {expanded.toggle()} label: {
                HStack(spacing:10) {
                    VStack(alignment:.leading,spacing:5) {
                        Text(row.Course.Name).font(.system(size:14,weight:.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        if !row.Course.Professor.isEmpty {Text(row.Course.Professor).font(.caption).foregroundStyle(.secondary)}
                        if !row.summary.isEmpty {Text(row.summary).font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)}
                    }
                    Spacer(minLength:8)
                    Image(systemName:expanded ? "chevron.up" : "chevron.down").font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(row.Course.Name), 출석 상세 \(expanded ? "접기" : "펼치기")")
            if expanded {
                Divider().padding(.horizontal,14)
                if !row.Error.isEmpty {Text(row.Error).font(.caption).foregroundStyle(.red).padding(14)}
                if row.days.isEmpty && row.Error.isEmpty {Text("등록된 출석 기록이 없습니다.").font(.caption).foregroundStyle(.secondary).padding(14)}
                VStack(spacing:0) {
                    ForEach(Array(row.days.enumerated()),id:\.offset) { index,day in
                        if index>0 {Divider().opacity(0.5)}
                        HStack(alignment:.center,spacing:10) {
                            Text("\(day.week)주").font(.system(size:11,weight:.medium)).foregroundStyle(.secondary).frame(width:28,alignment:.leading)
                            Text(day.dateLabel).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
                            Spacer(minLength:4)
                            VStack(alignment:.trailing,spacing:4) {
                                ForEach(Array(day.slots.enumerated()),id:\.offset) { _,slot in
                                    HStack(spacing:5) {
                                        if day.slots.count>1 {Text("\(slot.Index)차시").font(.system(size:10)).foregroundStyle(.secondary)}
                                        Text(slot.statusLabel).font(.system(size:11,weight:.medium))
                                            .foregroundStyle(color(slot.statusLabel))
                                            .padding(.horizontal,7).padding(.vertical,3)
                                            .background(color(slot.statusLabel).opacity(0.12),in:Capsule())
                                    }.accessibilityElement(children:.combine)
                                }
                            }
                        }.padding(.vertical,10)
                    }
                }.padding(.horizontal,14).padding(.bottom,4)
            }
        }.background(Theme.surface,in:RoundedRectangle(cornerRadius:12))
    }
    private func color(_ label:String)->Color {
        switch label {
        case "출석":return .green
        case "결석":return .red
        case "지각","조퇴":return .orange
        case "공결":return .blue
        default:return .secondary
        }
    }
}
