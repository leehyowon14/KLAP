import KLAPCore
import Foundation
import CoreGraphics
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
expect(StudyProgress(percent: -2, current: -1, total: -1) == StudyProgress(percent: 0, current: 0, total: 0), "Negative values")
expect(StudyProgress(percent: 150, current: 9, total: 3).fraction == 1, "Upper bound")
expect(StudyProgress(percent: .nan, current: 1, total: 3).fraction == 0, "NaN")
expect(StudyProgress(percent: .infinity, current: 1, total: 3).fraction == 0, "Infinity")
expect(StudyProgress(percent: 35, current: 2, total: 5).label == "2/5", "Queue position")
expect(StudyProgress(percent: 0, current: 1, total: 0).label == "", "Empty queue")
expect(StudyProgress(percent: 0, current: 8, total: 5).label == "5/5", "Queue clamp")
print("7 progress checks passed")
expect(TimetableClock.minutes(period: -1, span: 1) == nil, "Negative period")
expect(TimetableClock.minutes(period: 1, span: 0) == nil, "Invalid span")
expect(TimetableClock.minutes(period: 11, span: 2) == nil, "Overflow period")
expect(TimetableClock.minutes(period: 0, span: 2)?.end == 590, "Special consecutive class")
expect(TimetableClock.minutes(period: 6, span: 3)?.end == 1155, "Evening consecutive class")
expect(TimetableClock.minutes(period: 11, span: 1)?.end == 1325, "Night class")
expect(DestinationPolicy.uniqueNames(["A","A","B"," "]) == ["B"], "Ambiguous destinations")
expect(DestinationPolicy.uniqueNames([]).isEmpty, "Empty destinations")
expect(DestinationPolicy.availableName("KLAP",existing:["KLAP","KLAP (2)"]) == "KLAP (3)", "New destination collisions")
expect(DestinationPolicy.availableName("KLAP",existing:[]) == "KLAP", "First destination")
print("10 timetable and destination checks passed")

func makeEntry(_ period:Int, _ span:Int=1, day:Int=1, online:Bool=false) throws -> TimetableEntry {
    let data=try JSONSerialization.data(withJSONObject:["SubjectID":"course", "SubjectName":"과목", "Weekday":day, "Period":period, "Span":span, "Room":"101", "Online":online])
    return try JSONDecoder().decode(TimetableEntry.self,from:data)
}
let layout=TimetableClock.placements(try [makeEntry(0),makeEntry(1),makeEntry(2)])
expect(layout.map(\.lane) == [0,1,1], "Overlapping intervals reuse only free lanes")
expect(layout.allSatisfy{$0.laneCount == 2}, "Consistent overlapping lane widths")
let excluded = try [makeEntry(1,day:0),makeEntry(2,online:true)]
expect(TimetableClock.placements(excluded).isEmpty,"Unknown and online classes excluded from grid")
let empty=try JSONDecoder().decode(Snapshot.self,from:Data("{\"timetable\":null,\"lectures\":null,\"errors\":[]}".utf8))
expect(empty.lectures == nil && empty.errors.isEmpty,"Nullable CLI collections")
print("4 layout and decoding checks passed")
let screen = CGRect(x:0,y:0,width:1440,height:875)
let rightPanel=MenuPanelPlacement.frame(anchor:CGRect(x:1410,y:875,width:24,height:25),visibleScreen:screen,size:CGSize(width:540,height:700))
expect(screen.contains(rightPanel) && rightPanel.maxX == 1432, "Panel remains inside right edge")
let leftScreen=CGRect(x:-1920,y:0,width:1920,height:1055)
let leftPanel=MenuPanelPlacement.frame(anchor:CGRect(x:-1910,y:1055,width:24,height:25),visibleScreen:leftScreen,size:CGSize(width:540,height:700))
expect(leftScreen.contains(leftPanel) && leftPanel.minX == -1912,"Secondary monitor with negative origin")
let smallScreen=CGRect(x:0,y:0,width:500,height:600)
let smallPanel=MenuPanelPlacement.frame(anchor:CGRect(x:250,y:600,width:24,height:25),visibleScreen:smallScreen,size:CGSize(width:540,height:700))
expect(smallScreen.contains(smallPanel),"Small screen bounds")
print("3 panel positioning checks passed")

expect(StudyTime(achieved:"5",required:"20").remaining == 15,"Remaining minutes")
expect(StudyTime(achieved:"30",required:"20").remaining == 0,"Over-completed clamp")
expect(StudyTime(achieved:nil,required:"20").remaining == nil,"Unknown achieved")
expect(StudyTime(achieved:"NaN",required:"20").remaining == nil,"Invalid achieved")
expect(StudyTime(achieved:"2",required:"0").remaining == nil,"Unknown duration")
expect(StudyTime(achieved:"-1",required:"20").remaining == nil,"Negative achieved")
expect(StudyTime.minutes(0.5) == "1분","Round remaining up")
print("7 study time checks passed")

let reminderNote="--- KLAP ---\nID: lecture:abc\n[This reminder is created by KLAP.]"
expect(ReminderIdentity.matches(notes:reminderNote,lectureID:"abc"),"Exact lecture ID")
expect(ReminderIdentity.matches(notes:reminderNote,lectureID:"lecture:abc"),"Prefixed lecture ID")
expect(!ReminderIdentity.matches(notes:reminderNote,lectureID:"ab"),"No prefix collision")
expect(!ReminderIdentity.matches(notes:"ID: lecture:abc",lectureID:"abc"),"No unowned reminder")
expect(!ReminderIdentity.matches(notes:nil,lectureID:"abc"),"Missing metadata")
expect(!ReminderIdentity.matches(notes:reminderNote,lectureID:""),"Empty identity")
print("6 reminder identity checks passed")

let fullScreen=CGRect(x:0,y:0,width:1440,height:900)
expect(!MenuPanelPlacement.validAnchor(.zero,screen:fullScreen),"Unlaid status item")
expect(!MenuPanelPlacement.validAnchor(CGRect(x:0,y:0,width:24,height:24),screen:fullScreen),"Temporary origin rejected")
expect(MenuPanelPlacement.validAnchor(CGRect(x:1200,y:875,width:24,height:25),screen:fullScreen),"Menu bar anchor accepted")
expect(MenuPanelPlacement.validAnchor(CGRect(x:-1200,y:875,width:24,height:25),screen:CGRect(x:-1440,y:0,width:1440,height:900)),"Negative screen anchor accepted")
expect(!MenuPanelPlacement.validAnchor(CGRect(x:1600,y:875,width:24,height:25),screen:fullScreen),"Wrong screen rejected")
print("5 startup anchor checks passed")
