import SwiftUI
import KLAPCore

struct WeeklyTimetable: View {
    let entries: [TimetableEntry]
    let select: (String) -> Void
    private var timed: [TimetableEntry] { entries.filter { !$0.Online && (1...7).contains($0.Weekday) && TimetableClock.minutes(period: $0.Period, span: max(1,$0.Span)) != nil } }
    private var days: Int { max(5, timed.map(\.Weekday).max() ?? 5) }
    private var start: Int { min(540, timed.compactMap { TimetableClock.minutes(period: $0.Period, span: max(1,$0.Span))?.start }.min() ?? 540) }
    private var end: Int { max(1080, timed.compactMap { TimetableClock.minutes(period: $0.Period, span: max(1,$0.Span))?.end }.max() ?? 1080) }
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
                        for hour in stride(from: start/60, through: end/60, by: 1) { let y=CGFloat(hour*60-start)*scale;path.move(to:CGPoint(x:32,y:y));path.addLine(to:CGPoint(x:geometry.size.width,y:y)) }
                    }.stroke(Theme.line, lineWidth: 0.6)
                    ForEach(Array(stride(from: start/60, through: end/60, by: 2)), id: \.self) { hour in
                        Text(String(format:"%02d",hour)).font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary).offset(x:3,y:CGFloat(hour*60-start)*scale)
                    }
                    ForEach(TimetableClock.placements(entries), id: \.index) { placement in
                        let entry = entries[placement.index]
                        let range = (start:placement.start,end:placement.end)
                        let lane = placement.lane
                        let laneWidth = width / CGFloat(placement.laneCount)
                            Button { select(entry.SubjectName) } label: {
                                VStack(alignment:.leading,spacing:2) {
                                    Text(entry.SubjectName).font(.system(size:10,weight:.bold)).lineLimit(2)
                                    Text(entry.Room).font(.system(size:9)).lineLimit(1).opacity(0.8)
                                }.padding(5).frame(width:max(1,laneWidth-5),height:max(18,CGFloat(range.end-range.start)*scale-4),alignment:.topLeading)
                                    .foregroundStyle(.white)
                                    .background(color(entry.SubjectID),in:RoundedRectangle(cornerRadius:8,style:.continuous))
                                    .clipped()
                            }.buttonStyle(.plain).help("\(entry.SubjectName) · \(entry.Room) · \(entry.Period)교시")
                                .offset(x:33+CGFloat(entry.Weekday-1)*width+CGFloat(lane)*laneWidth,y:CGFloat(range.start-start)*scale+1)
                    }
                    if entries.isEmpty { Text("시간표가 없습니다").font(.callout).foregroundStyle(.secondary).frame(width:geometry.size.width,height:geometry.size.height) }
                }
            }.frame(height:CGFloat(end-start) * 0.85)
            let untimed = entries.filter { $0.Online || !(1...7).contains($0.Weekday) || TimetableClock.minutes(period:$0.Period,span:max(1,$0.Span)) == nil }
            if !untimed.isEmpty {
                Text("온라인·시간 미정: " + untimed.map(\.SubjectName).joined(separator:" · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(2).help(untimed.map(\.SubjectName).joined(separator:"\n"))
            }
        }.padding(12)
            .background(Theme.surface,in:RoundedRectangle(cornerRadius:16,style:.continuous))
    }
    private func color(_ id: String) -> Color {
        let colors = Theme.tones
        return colors[id.utf8.reduce(0) { ($0 + Int($1)) % colors.count }]
    }
}
