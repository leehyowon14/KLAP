import SwiftUI
import KLAPCore

struct PeriodInfoView: View {
    let entries:[TimetableEntry]
    private func clock(_ minutes:Int) -> String { String(format:"%02d:%02d",minutes/60,minutes%60) }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:10) {
                Text("교시별 시간").font(.headline)
                ForEach(0..<12,id:\.self) { period in
                    if let range=TimetableClock.minutes(period:period,span:1) {
                        HStack { Text("\(period)교시");Spacer();Text("\(clock(range.start))–\(clock(range.end))").monospacedDigit() }
                    }
                }
                let extended=entries.filter { !$0.Online && $0.Span > 1 }
                if !extended.isEmpty {
                    Divider()
                    Text("연강 시간").font(.headline)
                    Text("연강은 별도 시간표가 적용될 수 있습니다.").font(.caption).foregroundStyle(.secondary)
                    ForEach(extended) { entry in
                        if let range=TimetableClock.minutes(period:entry.Period,span:entry.Span) {
                            VStack(alignment:.leading,spacing:3) {
                                Text(entry.SubjectName).font(.caption.bold())
                                Text("\(entry.Period)교시부터 · \(clock(range.start))–\(clock(range.end))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.padding(16)
        }.frame(width:280,height:440)
    }
}
