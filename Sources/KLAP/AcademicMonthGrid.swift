import SwiftUI

struct AcademicMonthGrid:View {
    let month:Date
    @Binding var selected:Date
    let events:[AcademicEntry]
    var body:some View {
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:7),spacing:5) {
            ForEach(Array(["일","월","화","수","목","금","토"].enumerated()),id:\.offset) { index,label in
                Text(label).font(.system(size:11,weight:.medium)).foregroundStyle(index==0 ? .red : .secondary).frame(maxWidth:.infinity).padding(.bottom,5)
            }
            ForEach(Array(AcademicCalendar.days(month).enumerated()),id:\.offset) { _,date in
                if let date {
                    let chosen=AcademicCalendar.calendar.isDate(date,inSameDayAs:selected)
                    let today=AcademicCalendar.calendar.isDateInToday(date)
                    let count=events.filter{$0.includes(date)}.count
                    Button {selected=date} label: {
                        VStack(spacing:5) {
                            Text("\(AcademicCalendar.calendar.component(.day,from:date))").font(.system(size:13,weight:chosen || today ? .bold : .regular))
                            Circle().fill(count>0 ? (chosen ? Color.white : Color.accentColor) : Color.clear).frame(width:4,height:4)
                        }.frame(maxWidth:.infinity).frame(height:38)
                            .foregroundStyle(chosen ? Color.white : Color.primary)
                            .background(chosen ? Color.accentColor : Color.clear,in:RoundedRectangle(cornerRadius:9))
                            .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(today && !chosen ? Color.accentColor : Color.clear,lineWidth:1))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("\(AcademicCalendar.key(date)), 일정 \(count)개").accessibilityAddTraits(chosen ? .isSelected : [])
                } else {Color.clear.frame(height:38).accessibilityHidden(true)}
            }
        }.padding(12).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
}
