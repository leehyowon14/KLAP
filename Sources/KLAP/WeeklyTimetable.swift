import SwiftUI
import KLAPCore

struct WeeklyTimetable: View {
    let entries: [TimetableEntry]
    let select: (String) -> Void
    private var courseTones:[String:Double] { CourseTones.assign(entries.map(\.SubjectID)) }
    private var timed: [TimetableEntry] { entries.filter { !$0.Online && (1...7).contains($0.Weekday) && TimetableClock.minutes(period: $0.Period, span: max(1,$0.Span)) != nil } }
    private var days: Int { max(5, timed.map(\.Weekday).max() ?? 5) }
    private var start:Int { min(1,timed.map(\.Period).min() ?? 1) }
    private var end:Int { max(7,timed.map { min(12,$0.Period+max(1,$0.Span)) }.max() ?? 7) }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("").frame(width: 32)
                ForEach(1...days, id: \.self) { day in Text(["월","화","수","목","금","토","일"][day-1]).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            GeometryReader { geometry in
                let width = (geometry.size.width - 32) / CGFloat(days)
                let scale = geometry.size.height / CGFloat(end - start)
                ZStack(alignment: .topLeading) {
                    Path { path in
                        for day in 0...days { let x = 32 + CGFloat(day)*width; path.move(to: CGPoint(x:x,y:0));path.addLine(to:CGPoint(x:x,y:geometry.size.height)) }
                        for period in start...end { let y=CGFloat(period-start)*scale;path.move(to:CGPoint(x:32,y:y));path.addLine(to:CGPoint(x:geometry.size.width,y:y)) }
                    }.stroke(Theme.line, lineWidth: 0.75)
                    ForEach(start..<end, id: \.self) { period in
                        Text("\(period)").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary).offset(x:3,y:CGFloat(period-start)*scale+8)
                    }
                    ForEach(TimetableClock.placements(entries,byPeriod:true), id: \.index) { placement in
                        let entry = entries[placement.index]
                        let range = (start:placement.start,end:placement.end)
                        let lane = placement.lane
                        let laneWidth = width / CGFloat(placement.laneCount)
                        let inset:CGFloat = 4
                            Button { select(entry.SubjectName) } label: {
                                VStack(alignment:.leading,spacing:2) {
                                    Text(entry.SubjectName).font(.system(size:10,weight:.bold)).lineLimit(2)
                                    Text(entry.Room).font(.system(size:9)).lineLimit(1).opacity(0.8)
                                }.padding(4).frame(width:max(1,laneWidth-inset*2),height:max(18,CGFloat(range.end-range.start)*scale-inset*2),alignment:.topLeading)
                                    .foregroundStyle((courseTones[entry.SubjectID] ?? 50) < 30 ? Color(nsColor:Theme.tone(95)) : .white)
                                    .background(color(entry.SubjectID),in:RoundedRectangle(cornerRadius:8,style:.continuous))
                                    .clipped()
                            }.buttonStyle(.plain).help("\(entry.SubjectName) · \(entry.Room) · \(entry.Period)교시")
                                .offset(x:32+CGFloat(entry.Weekday-1)*width+CGFloat(lane)*laneWidth+inset,y:CGFloat(range.start-start)*scale+inset)
                    }
                    if entries.isEmpty { Text("시간표가 없습니다").font(.callout).foregroundStyle(.secondary).frame(width:geometry.size.width,height:geometry.size.height) }
                }
            }.frame(height:CGFloat(end-start) * 64)
            let untimed = entries.filter { $0.Online || !(1...7).contains($0.Weekday) || TimetableClock.minutes(period:$0.Period,span:max(1,$0.Span)) == nil }
            if !untimed.isEmpty {
                Text("온라인·시간 미정: " + untimed.map(\.SubjectName).joined(separator:" · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(2).help(untimed.map(\.SubjectName).joined(separator:"\n"))
            }
        }.padding(12)
            .background(Theme.surface,in:RoundedRectangle(cornerRadius:16,style:.continuous))
    }
    private func color(_ id: String) -> Color {
        Color(nsColor:Theme.tone(courseTones[id] ?? 50))
    }
}
