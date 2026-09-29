import SwiftUI

struct AcademicMonthGrid:View {
    let month:Date
    @Binding var selected:Date
    let events:[AcademicEntry]
    var body:some View {
        VStack(spacing:9) {
            HStack(spacing:0) {
                ForEach(Array(["일","월","화","수","목","금","토"].enumerated()),id:\.offset) { index,label in
                    Text(label).font(.system(size:11,weight:.medium)).foregroundStyle(index==0 ? .red : .secondary).frame(maxWidth:.infinity)
                }
            }.padding(.bottom,3)
            ForEach(Array(AcademicCalendar.weeks(month,events:events).enumerated()),id:\.offset) { _,week in
                VStack(spacing:4) {
                    HStack(spacing:0) {
                        ForEach(Array(week.dates.enumerated()),id:\.offset) { _,date in
                            if let date { dayButton(date) }
                            else {Color.clear.frame(maxWidth:.infinity).frame(height:30).accessibilityHidden(true)}
                        }
                    }
                    GeometryReader { geometry in
                        let column=geometry.size.width/7
                        ZStack(alignment:.topLeading) {
                            ForEach(week.markers) { marker in
                                let color=Color.accentColor
                                let left=CGFloat(marker.firstColumn)*column+(marker.startsHere ? column*0.24 : 0)
                                let right=CGFloat(marker.lastColumn+1)*column-(marker.endsHere ? column*0.24 : 0)
                                if marker.singleDay {
                                    Circle().fill(color).frame(width:5,height:5)
                                        .offset(x:(CGFloat(marker.firstColumn)+0.5)*column-2.5,y:CGFloat(marker.lane)*8)
                                } else {
                                    AcademicRangeShape(roundStart:marker.startsHere,roundEnd:marker.endsHere).fill(color)
                                        .frame(width:max(5,right-left),height:5)
                                        .offset(x:left,y:CGFloat(marker.lane)*8)
                                }
                            }
                        }
                    }.frame(height:CGFloat(max(1,week.laneCount))*8).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }.padding(12).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
    private func dayButton(_ date:Date)->some View {
        let chosen=AcademicCalendar.calendar.isDate(date,inSameDayAs:selected)
        let today=AcademicCalendar.calendar.isDateInToday(date)
        let entries=events.filter{$0.includes(date)}
        return Button {selected=date} label: {
            Text("\(AcademicCalendar.calendar.component(.day,from:date))")
                .font(.system(size:13,weight:chosen || today ? .bold : .regular))
                .frame(width:30,height:30)
                .foregroundStyle(chosen ? Color.white : Color.primary)
                .background(chosen ? Color.accentColor : Color.clear,in:RoundedRectangle(cornerRadius:9))
                .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(today && !chosen ? Color.accentColor : Color.clear,lineWidth:1))
                .frame(maxWidth:.infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("\(AcademicCalendar.key(date)), 일정 \(entries.count)개, \(entries.map(\.Title).joined(separator:", "))")
            .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
private struct AcademicRangeShape:Shape {
    let roundStart:Bool
    let roundEnd:Bool
    func path(in rect:CGRect)->Path {
        let radius=min(rect.height/2,rect.width/2)
        let left=roundStart ? radius : 0,right=roundEnd ? radius : 0
        var path=Path()
        path.move(to:CGPoint(x:rect.minX+left,y:rect.minY))
        path.addLine(to:CGPoint(x:rect.maxX-right,y:rect.minY))
        path.addQuadCurve(to:CGPoint(x:rect.maxX,y:rect.minY+right),control:CGPoint(x:rect.maxX,y:rect.minY))
        path.addLine(to:CGPoint(x:rect.maxX,y:rect.maxY-right))
        path.addQuadCurve(to:CGPoint(x:rect.maxX-right,y:rect.maxY),control:CGPoint(x:rect.maxX,y:rect.maxY))
        path.addLine(to:CGPoint(x:rect.minX+left,y:rect.maxY))
        path.addQuadCurve(to:CGPoint(x:rect.minX,y:rect.maxY-left),control:CGPoint(x:rect.minX,y:rect.maxY))
        path.addLine(to:CGPoint(x:rect.minX,y:rect.minY+left))
        path.addQuadCurve(to:CGPoint(x:rect.minX+left,y:rect.minY),control:CGPoint(x:rect.minX,y:rect.minY))
        path.closeSubpath()
        return path
    }
}
