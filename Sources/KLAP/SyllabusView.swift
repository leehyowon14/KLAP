import SwiftUI
import KLAPCore

private struct GradeAllocationView: View {
    let count: Int?
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("상대평가 배정 예시").font(.headline)
            if let count, let allocation = GradeAllocation(count:count) {
                HStack { Text("A"); Spacer(); Text("\(allocation.a)명") }
                HStack { Text("B"); Spacer(); Text("\(allocation.b)명") }
                HStack { Text("C 이하"); Spacer(); Text("\(allocation.lower)명") }
                Divider()
                Text("A 40%, A+B 80% 상한을 채운 예시입니다. B는 A를 제외한 인원이며, A 배정이 줄면 B는 늘어날 수 있습니다.")
                Text("비율 상한을 넘지 않도록 소수점은 버렸습니다. 학교의 실제 인원 배정과 다를 수 있습니다.")
                Text(count <= 20 ? "이 강좌는 20명 이하로 비상대평가가 가능하므로 담당 교수의 기준을 확인하세요." : "실험·실습 등 비상대평가 과목 및 예외 적용 여부는 담당 교수의 기준을 확인하세요.")
            } else { Text("수강 인원을 확인할 수 없어 계산하지 않았습니다.") }
            Link("광운대학교 학칙 시행세칙 제16조의2 ↗", destination:URL(string:"https://rule.kw.ac.kr/lmxsrv/law/lawFullView.do?SEQ=22&SEQ_HISTORY=614")!)
        }.font(.callout).padding(18).frame(width:310)
    }
}

struct CourseInformationView: View {
    @ObservedObject var model: AppModel
    @ViewState<Bool> private var showGrades = false
    var body: some View {
        HStack(spacing: 8) {
            if let syllabus = model.syllabus {
                Text(syllabus.enrollment.map { "수강 인원 \($0)명" } ?? "수강 인원 확인 불가").font(.caption).foregroundStyle(.secondary)
                Button { showGrades.toggle() } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).accessibilityLabel("성적별 배정 인원")
                    .popover(isPresented: $showGrades) { GradeAllocationView(count: syllabus.enrollment) }
            } else if model.busy { ProgressView().controlSize(.small); Text("과목 정보 조회 중").font(.caption).foregroundStyle(.secondary) }
            else { Button(model.syllabusError == nil ? "과목 정보 불러오기" : "과목 정보 다시 시도") { Task { await model.loadSyllabus() } }.buttonStyle(.plain).font(.caption) }
            Spacer()
            Button("강의계획서 ›") { model.showSyllabus = true }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
        }.task(id: model.selectedCourse) { if model.syllabus == nil { await model.loadSyllabus() } }
    }
}

struct SyllabusView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let s = model.syllabus {
                section("과목 정보", [s.KoreanName, s.Professor, s.CourseType, s.Credits.isEmpty ? "" : "\(s.Credits)학점", s.Operation].filter { !$0.isEmpty }.joined(separator: " · "))
                section("교과목 개요", s.Summary)
                section("수업 목표", s.Purpose)
                section("학습 성과", s.Outcome)
                section("핵심 역량", s.Competency)
                section("교재", s.BookName)
                let e = s.Evaluation
                let weights: [(String,Int)] = [("출석",e.Attendance),("학습",e.Learning),("중간고사",e.Midterm),("기말고사",e.Final),("과제",e.Report),("퀴즈",e.Quiz),("기타",e.Other)]
                section("평가 비중", weights.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)%" }.joined(separator: " · "))
                VStack(alignment: .leading, spacing: 12) {
                    Text("주차별 계획").font(.headline)
                    if (s.Schedule ?? []).isEmpty { Text("등록된 계획이 없습니다.").foregroundStyle(.secondary) }
                    ForEach(Array((s.Schedule ?? []).enumerated()), id: \.offset) { index, week in
                        if index > 0 { Divider() }
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(week.Week)주").font(.callout.bold()).frame(width: 32, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(week.Topic.isEmpty ? "내용 미등록" : week.Topic)
                                if !week.SubNote.isEmpty { Text(week.SubNote).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
            } else if model.busy { ProgressView("강의계획서를 불러오는 중…").frame(maxWidth:.infinity).padding() }
            else {
                Text(model.syllabusError ?? "강의계획서를 불러오지 못했습니다.").foregroundStyle(.secondary)
                Button("다시 시도") { Task { await model.loadSyllabus() } }
            }
        }.textSelection(.enabled).task { if model.syllabus == nil { await model.loadSyllabus() } }
    }
    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.headline)
            Text(text.isEmpty ? "등록된 내용이 없습니다." : text).font(.callout).lineSpacing(4)
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:14))
    }
}
