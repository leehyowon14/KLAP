import AppKit
import SwiftUI
import KLAPCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ViewState<String> private var studentID = ""
    @ViewState<String> private var password = ""
    @ViewState<[String]> private var proposedIDs = []
    @ViewState<Bool> private var showChanges = false
    @ViewState<Bool> private var confirmStudy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment:.center) {
                Image(systemName:"graduationcap.fill").font(.title2).foregroundStyle(.tint)
                VStack(alignment:.leading,spacing:2) { Text("KLAP").font(.title3.bold()); Text(model.snapshot.timetable?.Term.label ?? "나의 캠퍼스").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                if !model.onboarding {
                Button { Task { await model.refresh() } } label: { Image(systemName:"arrow.clockwise") }.buttonStyle(.plain).frame(width:28,height:28).disabled(model.busy || model.onboarding).help("새로고침").accessibilityLabel("새로고침")
                Button { showChanges=false;model.showSettings.toggle() } label: { Image(systemName:"gearshape") }.buttonStyle(.plain).frame(width:28,height:28).disabled(model.onboarding).help("설정").accessibilityLabel("설정")
                }
            }
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    if model.onboarding { OnboardingView(model:model,setup:model.setup) }
                    else if model.showSettings { settings }
                    else if showChanges { changesPage }
                    else {
                    if !model.conflicts.isEmpty { changesLink }
                    HStack { Text("주간 시간표").font(.system(size:16,weight:.bold));Spacer();if model.selectedCourse != nil { Button("전체 과목") { model.selectedCourse = nil }.buttonStyle(.plain).font(.callout).foregroundStyle(.tint) } }
                    WeeklyTimetable(entries:model.snapshot.timetable?.Entries ?? []) { model.selectedCourse = $0 }
                    Divider().padding(.vertical,8)
                    if model.showLogin { login }
                    if let error = model.error, !error.hasPrefix("KLAS에서 갱신된 항목 ") {
                        Label(error,systemImage:"exclamationmark.triangle").font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                    }
                    if let error=model.reminderCompletionError {
                        Label(error,systemImage:"exclamationmark.triangle").font(.callout).foregroundStyle(.red)
                    }
                    if model.studying { studyProgress }
                    if model.courses.isEmpty {
                        VStack(alignment:.leading,spacing:8) {
                            Text("수업을 연결해 보세요").font(.headline)
                            Text("KLAS 계정으로 로그인하면 과목과 시간표를 불러옵니다. 기존 KLAP-Cli 계정도 사용할 수 있습니다.").font(.callout).foregroundStyle(.secondary)
                            Button("KLAS 로그인") { model.showLogin = true }
                        }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.3),in:RoundedRectangle(cornerRadius:12))
                    } else { courseContent }
                    }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,4)
            }.scrollIndicators(.hidden).frame(maxWidth:.infinity,maxHeight:.infinity)
            Divider()
            HStack(spacing:16) {
                VStack(alignment:.leading,spacing:2) {
                    Text(model.onboarding ? "설정은 나중에도 변경할 수 있습니다" : model.message).lineLimit(1)
                    if let date=model.lastRefresh { Text("조회 \(date.formatted(date:.omitted,time:.shortened))").foregroundStyle(.secondary) }
                }.font(.caption).foregroundStyle(.secondary).help(model.message).layoutPriority(-1)
                Spacer()
                if !model.onboarding { Button("동기화") { Task { await model.sync() } }.buttonStyle(.borderless).disabled(model.busy) }
                Button { if model.studying { model.cancel() }; NSApp.terminate(nil) } label: { Label("종료", systemImage: "power") }.buttonStyle(.borderless).fixedSize().help("KLAP 종료").accessibilityLabel("KLAP 종료")
            }
        }.buttonStyle(FormButtonStyle(compact:true)).padding(20).frame(maxWidth:.infinity,maxHeight:.infinity)
        .alert("선택한 강의를 자동 수강할까요?",isPresented:$confirmStudy) {
            Button("취소",role:.cancel) {}
            Button("\(proposedIDs.count)개 수강 시작") { Task { await model.attend(proposedIDs) } }
        } message: { Text("수강 가능한 강의 \(proposedIDs.count)개를 순서대로 처리합니다. 팝오버를 닫아도 계속되며 진행 화면에서 취소할 수 있습니다.") }
    }
    private var login: some View {
        VStack(alignment:.leading,spacing:8) {
            Text("KLAS 로그인").font(.headline)
            TextField("학번",text:$studentID).modifier(AccountFieldStyle())
            SecureField("비밀번호",text:$password).modifier(AccountFieldStyle())
            HStack { Button("로그인") { let secret=password;password="";Task {await model.login(studentID:studentID,password:secret)} }.disabled(model.busy || studentID.trimmingCharacters(in:.whitespaces).isEmpty || password.isEmpty);Button("닫기") {password="";model.showLogin=false} }
            Text("비밀번호는 CLI의 OS 보안 저장소에 저장됩니다.").font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(.quaternary.opacity(0.3),in:RoundedRectangle(cornerRadius:10))
    }
    private var settings: some View {
        VStack(alignment:.leading,spacing:8) {
            pageHeading("설정") { model.showSettings=false }
            Divider().padding(.vertical,8)
            Toggle("일정 자동 동기화 · 30분마다",isOn:$model.autoSync)
            Toggle("수강 알림",isOn:$model.notifications)
            Text("수업·학사일정은 캘린더에, 과제·강의 마감은 미리 알림에 동기화합니다. 앱 실행 및 잠자기 복귀 때도 갱신합니다.").font(.caption).foregroundStyle(.secondary)
            if let date=model.lastSync { Text("마지막 동기화 \(date.formatted())").font(.caption2) }
            Button("캘린더·목록 다시 선택") { model.onboarding=true;model.setup.step=1 }.disabled(model.busy)
            Button("계정 로그인") { model.showSettings=false;model.showLogin=true }.disabled(model.busy)
            Button("로그아웃",role:.destructive) { model.logout() }.disabled(model.busy)
            Text("로그아웃하면 자동 갱신이 중단됩니다. CLI에 저장된 계정과 이미 등록한 일정은 유지됩니다.").font(.caption).foregroundStyle(.secondary)
            Text("현재 개발 버전은 KLAP-Cli의 계정·학기·동기화 설정을 공유합니다.").font(.caption2).foregroundStyle(.secondary)
        }.font(.callout).buttonStyle(FormButtonStyle())
    }
    private var studyProgress: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack { Text(model.studyTitle).font(.headline).lineLimit(1);Spacer();Text(model.progress?.label ?? "").monospacedDigit();Button("취소",role:.destructive) { model.cancel() } }
            ProgressView(value:model.progress?.fraction ?? 0)
            Text("\(Int((model.progress?.fraction ?? 0)*100))% · 수강 \(StudyTime.minutes(model.studyTime.achieved)) / 남은 시간 \(StudyTime.minutes(model.studyTime.remaining))").font(.callout)
            Text("전체 큐 예상 남은 시간 · \(StudyTime.minutes(model.queueRemaining))").font(.caption).foregroundStyle(.secondary)
        }.padding(12).background(Color.accentColor.opacity(0.08),in:RoundedRectangle(cornerRadius:10))
    }
    private func pageHeading(_ title:String, back:@escaping () -> Void) -> some View {
        Button(action:back) {
            HStack(spacing:8) {
                Image(systemName:"chevron.left").font(.headline)
                Text(title).font(.title2.bold())
            }.frame(minHeight:44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(title), 뒤로")
    }
    private var changesLink: some View {
        Button { showChanges=true } label: {
            HStack(spacing:10) {
                Image(systemName:"exclamationmark.triangle.fill").font(.title3)
                VStack(alignment:.leading,spacing:3) {
                    Text("일정 변경 확인").font(.callout.bold())
                    Text("확인이 필요한 항목 \(model.conflicts.count)개").font(.caption)
                }
                Spacer()
                Image(systemName:"chevron.right").font(.caption)
            }.foregroundStyle(.orange).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                .background(Color.orange.opacity(0.1),in:RoundedRectangle(cornerRadius:8))
                .contentShape(RoundedRectangle(cornerRadius:8))
        }.buttonStyle(.plain)
    }
    private var changesPage: some View {
        VStack(alignment:.leading,spacing:16) {
            pageHeading("일정 변경") { showChanges=false }
            if model.conflicts.isEmpty {
                Label("확인할 일정 변경이 없습니다",systemImage:"checkmark.circle").foregroundStyle(.secondary)
            } else { conflicts }
        }
    }
    private var conflicts: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("일정 변경 확인 · \(model.conflicts.count)개").font(.headline)
            ForEach(model.conflicts) { conflict in
                VStack(alignment:.leading) {
                    Text(conflict.Title).font(.caption.bold());Text(conflict.Summary).font(.caption2)
                    HStack { Button("기존 항목 유지") { Task {await model.resolveConflict(conflict.Key,decision:"keep")} };Button("KLAS 값 적용") {Task {await model.resolveConflict(conflict.Key,decision:"apply")}} }.disabled(model.busy && !model.studying)
                    if let decision=model.pendingDecisions[conflict.Key] {
                        Text("\(decision == "keep" ? "기존 항목 유지" : "KLAS 값 적용") 선택됨 · 수강 종료 후 반영").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private var courseContent: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text(model.selectedCourse ?? "과목별 대시보드").font(.system(size:16,weight:.bold)).lineLimit(1)
                Spacer()
                if !model.eligibleIDs.isEmpty { Button("미수강 \(model.eligibleIDs.count)개 수강") { propose(model.eligibleIDs) }.disabled(model.busy) }
            }
            if model.selectedCourse == nil {
                ForEach(model.courses) { course in
                    Button { model.selectedCourse=course.name } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:3) {
                                Text(course.name).font(.callout.bold())
                                let assignments=(model.snapshot.assignments ?? []).filter{$0.CourseName==course.name && !$0.Assignment.Submitted}.count
                                let lectures=(model.snapshot.lectures ?? []).filter{$0.row.CourseName==course.name && $0.reason.isEmpty}.count
                                Text("미제출 과제 \(assignments) · 수강 가능 \(lectures)").font(.caption).foregroundStyle(.secondary)
                            };Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(14).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain)
                }
            } else {
                ForEach((model.snapshot.assignments ?? []).filter{$0.CourseName==model.selectedCourse && !$0.Assignment.Submitted}) { assignment in
                    Label(assignment.Assignment.Title,systemImage:"checklist").font(.caption)
                }
                ForEach((model.snapshot.notices ?? []).filter{$0.CourseName==model.selectedCourse}.prefix(3)) { notice in
                    Label(notice.Notice.Title,systemImage:"megaphone").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.lectures) { item in
                    HStack(spacing:12) {
                        VStack(alignment:.leading,spacing:6) {
                            Text(item.row.Lecture.Title).font(.system(size:13,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                            Text(item.reason.isEmpty ? "수강 가능 · \(item.row.Lecture.Progress)" : item.reason).font(.system(size:11)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength:8)
                        HStack(spacing:6) {
                            Button("열기") {Task {await model.openLecture(item.id)}}.disabled(model.busy)
                            if item.reason.isEmpty { Button("수강") {propose([item.id])}.disabled(model.busy) }
                        }
                    }.padding(12).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:12))
                }
            }
        }
    }
    private func propose(_ ids:[String]) { proposedIDs=ids;confirmStudy=true }
}
