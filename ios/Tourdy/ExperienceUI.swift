import SwiftUI
import Charts
import UniformTypeIdentifiers

struct TourdyPanel<Content:View>: View {
    let title: String
    let content: Content
    init(_ title: String = "", @ViewBuilder content: () -> Content) {self.title=title;self.content=content()}
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            if !title.isEmpty {Text(title).font(.system(size:20,weight:.bold))}
            content
        }
        .frame(maxWidth:.infinity,alignment:.leading).padding(20)
        .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22))
    }
}
struct TourdyPage<Content:View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {self.content=content()}
    var body: some View {ScrollView {VStack(spacing:14) {content}.padding(.horizontal,18).padding(.vertical,14).frame(maxWidth:760).frame(maxWidth:.infinity)}.background(Color(uiColor:.systemGroupedBackground))}
}
struct HomeExperience: View {
    @EnvironmentObject var store: NativeStore
    @State private var mode = "run"
    @State private var scheduled = false
    @State private var showPlan = false
    @State private var showRecord = false
    @State private var selectedSubject: Subject?
    @State private var newSubject = false
    @State private var editingRecord: StudySession?
    var body: some View {
        TourdyPage {
            if let day=store.prefs.dday {
                HStack {
                    Text(store.prefs.ddayName.isEmpty ? "D-day" : store.prefs.ddayName).font(.subheadline.weight(.semibold))
                    Spacer()
                    let remaining=Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:Date()),to:Calendar.current.startOfDay(for:day)).day ?? 0
                    Text(remaining==0 ? "D-DAY" : remaining>0 ? "D-\(remaining)" : "D+\(-remaining)").font(.headline.monospacedDigit()).foregroundStyle(store.accent)
                }.padding(.horizontal,8)
            }
            if !store.prefs.welcomeDone && store.state.subjects.isEmpty {welcome}
            Picker("홈",selection:$mode) {Text("공부 시작").tag("run");Text("프리셋 목록").tag("preset")}.pickerStyle(.segmented)
            if mode=="run" {
                TourdyPanel("공부 시작") {
                    Picker("타이머",selection:$scheduled) {Text("자유 공부").tag(false);Text("예약 공부").tag(true)}.pickerStyle(.segmented)
                    clock
                    if store.state.running != nil || store.prefs.plan?.phase=="paused" {controls}
                    if scheduled {Button("시작 시각 · 공부 시간 · 뽀모도로 설정") {showPlan=true}.buttonStyle(.glass)}
                    ForEach(store.state.subjects) {subject in subjectRow(subject)}
                    if store.state.subjects.isEmpty {Text("프리셋 목록에서 공부할 과목을 추가해 주세요.").foregroundStyle(.secondary)}
                    if store.prefs.goalMinutes>0 {
                        ProgressView(value:min(Double(store.prefs.goalMinutes*60),store.seconds(on:Date())),total:Double(store.prefs.goalMinutes*60))
                        Text("오늘 목표 \(store.prefs.goalMinutes)분 · \(duration(store.seconds(on:Date())))").font(.caption).foregroundStyle(.secondary)
                    }
                    DayTimeline(date:Date())
                    DisclosureGroup("기록 · \(store.sessions(on:Date()).count)개") {
                        ForEach(store.sessions(on:Date()).reversed()) {session in
                            VStack(alignment:.leading,spacing:4) {
                                HStack {Text(session.kind=="rest" ? "휴식" : session.kind=="waste" ? "딴짓" : store.state.subjects.first {$0.id==session.subject}?.name ?? "공부");Spacer();Text(duration(session.end.timeIntervalSince(session.start)))}
                                Text(session.start.formatted(date:.omitted,time:.shortened)+" – "+session.end.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                                if let memo=session.memo,!memo.isEmpty {Text(memo).font(.caption)}
                            }.padding(.vertical,6).contextMenu {
                                Button("수정") {editingRecord=store.state.sessions.first {$0.id==session.id}}
                                Button("삭제",role:.destructive) {store.commit {$0.sessions.removeAll {$0.id==session.id}}}
                            }
                        }
                        Button("직접 기록 추가") {showRecord=true}
                    }
                }
                if store.state.firstReward != "used" {reward}
            } else {
                TourdyPanel("프리셋 목록") {
                    Text("과목마다 색과 아이콘을 정해요").font(.caption).foregroundStyle(.secondary)
                    ForEach(store.state.subjects) {subject in Button {selectedSubject=subject} label:{HStack {Label(subject.name,systemImage:subject.icon ?? "book.fill").foregroundStyle(store.subjectColor(subject.id));Spacer();Image(systemName:"chevron.right").foregroundStyle(.secondary)}}.padding(.vertical,10)}
                    Button("+ 새 프리셋") {newSubject=true}.buttonStyle(.glass)
                }
            }
        }
        .navigationTitle("TOURDY").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$showPlan) {NavigationStack {PlanEditor()}}
        .sheet(isPresented:$showRecord) {NavigationStack {RecordEditor()}}
        .sheet(item:$editingRecord) {session in NavigationStack {RecordEditor(session:session)}}
        .sheet(item:$selectedSubject) {subject in NavigationStack {SubjectEditor(subject:subject)}}
        .sheet(isPresented:$newSubject) {NavigationStack {SubjectEditor(subject:nil)}}
    }
    var welcome: some View {
        TourdyPanel("어떤 과목을 공부하나요?") {
            Text("고른 과목으로 바로 시작할 수 있어요. 색과 아이콘은 나중에 바꿀 수 있어요.").foregroundStyle(.secondary)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:80))]) {
                ForEach(["국어","수학","영어","과학","사회","전공"],id:\.self) {name in
                    Button(name) {store.commit {$0.subjects.append(Subject(name:name,color:store.prefs.accent,icon:"book.fill"))};store.configure {$0.welcomeDone=true}}.buttonStyle(.glass)
                }
            }
            Button("직접 추가") {newSubject=true}
        }
    }
    var clock: some View {
        TimelineView(.periodic(from:.now,by:1)) {context in
            let run=store.state.running
            VStack(alignment:.leading,spacing:8) {
                Text(run?.kind=="rest" ? "휴식 중" : run?.kind=="waste" ? "딴짓 기록 중" : run.flatMap {r in store.state.subjects.first {$0.id==r.subject}?.name} ?? "공부를 시작해볼까요?").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text(clockText(context.date)).font(.system(size:56,weight:.heavy,design:.rounded)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                if let plan=store.prefs.plan {Text(plan.phase=="waiting" ? "\(plan.start.formatted(date:.omitted,time:.shortened)) 시작 예약" : plan.phase=="paused" ? "잠시 멈춤 · 이어서 공부할 수 있어요" : "\(plan.set)/\(plan.sets)세트 · \(plan.phase=="rest" ? "휴식" : "공부")").font(.caption).foregroundStyle(store.accent)}
            }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,8)
        }
    }
    func clockText(_ now: Date) -> String {
        if let run=store.state.running {return duration(run.end.map {$0.timeIntervalSince(now)} ?? now.timeIntervalSince(run.start))}
        if let p=store.prefs.plan {return duration(p.remaining ?? p.start.timeIntervalSince(now))}
        return "0:00:00"
    }
    var controls: some View {
        ScrollView(.horizontal,showsIndicators:false) {
            HStack {
                if store.prefs.plan?.phase=="paused" {Button("이어서 공부") {store.resumePlan()}.buttonStyle(.glassProminent)}
                Button("휴식") {store.offTime("rest")}.buttonStyle(.glass)
                Button("딴짓") {store.offTime("waste")}.buttonStyle(.glass)
                if store.state.running?.end != nil {Button("5분 연장") {store.extendPlan()}.buttonStyle(.glass)}
                Button("정지",role:.destructive) {store.finishAll()}.buttonStyle(.glass)
            }
        }
    }
    func subjectRow(_ subject: Subject) -> some View {
        let active=store.state.running?.subject==subject.id && (store.state.running?.kind ?? "study")=="study"
        return Button {store.toggleSubject(subject)} label:{
            HStack(spacing:12) {
                Image(systemName:subject.icon ?? "book.fill").font(.title3).foregroundStyle(store.subjectColor(subject.id)).frame(width:40,height:40).background(store.subjectColor(subject.id).opacity(0.12),in:RoundedRectangle(cornerRadius:12))
                VStack(alignment:.leading,spacing:4) {Text(subject.name).font(.headline).foregroundStyle(.primary);Text(duration(store.seconds(on:Date(),subject:subject.id))).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)}
                Spacer()
                Image(systemName:active ? "pause.fill" : "play.fill").font(.subheadline).foregroundStyle(.white).frame(width:40,height:40).background(store.subjectColor(subject.id),in:Circle())
            }.padding(10).background(active ? store.subjectColor(subject.id).opacity(0.08) : Color.clear,in:RoundedRectangle(cornerRadius:16))
        }.buttonStyle(.plain)
    }
    var reward: some View {
        TourdyPanel("누적 공부 30분 선물") {
            Text(store.state.firstReward=="ready" ? "어디든 떠나는 무료 티켓 1장" : "공부를 마치면 무료 티켓을 드려요").font(.headline)
            Text("원하는 국내 도시로 최고급 티켓을 타고 즉시 도착해요. 지금 쓰지 않아도 보관돼요.").font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value:min(1800,store.state.sessions.filter {($0.kind ?? "study")=="study" && $0.manual != true}.reduce(0){$0+$1.end.timeIntervalSince($1.start)}),total:1800)
            if store.state.firstReward=="ready" {NavigationLink("첫 여행 떠나기") {GiftScreen()}.buttonStyle(.glassProminent).disabled(store.state.running != nil)}
        }
    }
}

struct SubjectEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    let subject: Subject?
    @State private var name = ""
    @State private var color = "#3182F6"
    @State private var icon = "book.fill"
    @State private var goal = 0
    var body: some View {
        Form {
            TextField("과목 이름",text:$name)
            Picker("색",selection:$color) {ForEach(["#3182F6","#30A46C","#E5484D","#8E4EC6","#F76B15","#D6409F"],id:\.self) {hex in Text(hex).foregroundStyle(Color(hex:hex)).tag(hex)}}
            Picker("아이콘",selection:$icon) {ForEach(["book.fill","function","globe","atom","pencil","graduationcap.fill","music.note"],id:\.self) {symbol in Image(systemName:symbol).tag(symbol)}}
            Stepper("하루 목표 \(goal)분",value:$goal,in:0...720,step:30)
            Button("저장") {
                let text=name.trimmingCharacters(in:.whitespacesAndNewlines)
                guard !text.isEmpty else {return}
                if store.commit({s in
                    if let subject,let i=s.subjects.firstIndex(where:{$0.id==subject.id}) {s.subjects[i].name=text;s.subjects[i].color=color;s.subjects[i].icon=icon;s.subjects[i].goal=Double(goal)}
                    else {s.subjects.append(Subject(name:text,color:color,icon:icon,goal:Double(goal)))}
                }) {dismiss()}
            }
        }.navigationTitle("프리셋").onAppear {name=subject?.name ?? "";color=subject?.color ?? store.prefs.accent;icon=subject?.icon ?? "book.fill";goal=Int(subject?.goal ?? 0)}
    }
}
struct PlanEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    @State private var subject: UUID?
    @State private var start = Date()
    @State private var minutes = 30
    @State private var repeatEnabled = false
    @State private var sets = 4
    @State private var rest = 5
    var body: some View {
        Form {
            Picker("과목",selection:$subject) {ForEach(store.state.subjects) {Text($0.name).tag(Optional($0.id))}}
            DatePicker("시작 시각",selection:$start,in:Date()...,displayedComponents:[.date,.hourAndMinute])
            Stepper("공부 \(minutes)분",value:$minutes,in:5...720,step:5)
            Toggle("뽀모도로 반복",isOn:$repeatEnabled)
            if repeatEnabled {Stepper("\(sets)세트",value:$sets,in:2...12);Stepper("휴식 \(rest)분",value:$rest,in:0...60,step:5)}
            Button("예약") {save(start)}.buttonStyle(.glassProminent).disabled(subject==nil)
            Button("바로 시작") {save(Date())}.disabled(subject==nil)
        }.navigationTitle("예약 공부").onAppear {subject=store.state.subjects.first?.id}
    }
    func save(_ date: Date) {if let subject {store.schedule(subject:subject,start:date,minutes:minutes,sets:repeatEnabled ? sets : 1,rest:rest);if store.prefs.plan != nil {dismiss()}}}
}
struct DayTimeline: View {
    @EnvironmentObject var store: NativeStore
    let date: Date
    var body: some View {
        VStack(spacing:5) {
            Canvas {context,size in
                let start=store.studyDay(date).addingTimeInterval(Double(store.prefs.dayStart)*3600)
                for s in store.sessions(on:date) {
                    let x=s.start.timeIntervalSince(start)/86400*size.width
                    let width=max(1,s.end.timeIntervalSince(s.start)/86400*size.width)
                    let color=s.kind=="rest" ? Color.green : s.kind=="waste" ? Color.red : store.subjectColor(s.subject)
                    context.fill(Path(roundedRect:CGRect(x:x,y:0,width:width,height:size.height),cornerRadius:3),with:.color(color))
                }
            }.frame(height:20).background(Color.primary.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
            HStack {ForEach(0..<5) {i in Text("\((i*6+store.prefs.dayStart)%24)시").font(.caption2).foregroundStyle(.secondary);if i<4 {Spacer()}}}
        }
    }
}
struct RecordEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    @State private var subject: UUID?
    @State private var start = Date().addingTimeInterval(-1800)
    @State private var end = Date()
    @State private var memo = ""
    var session: StudySession? = nil
    var body: some View {
        Form {
            Picker("과목",selection:$subject) {ForEach(store.state.subjects) {Text($0.name).tag(Optional($0.id))}}
            DatePicker("시작",selection:$start);DatePicker("끝",selection:$end)
            TextField("메모",text:$memo)
            Text("직접 추가한 기록은 통계에 포함되며, 첫 보상과 마일리지에는 포함되지 않아요.").font(.caption).foregroundStyle(.secondary)
            Button(session==nil ? "추가" : "저장") {
                if let subject,store.commit({s in
                    if let session,let i=s.sessions.firstIndex(where:{$0.id==session.id}) {s.sessions[i].subject=subject;s.sessions[i].start=start;s.sessions[i].end=end;s.sessions[i].memo=memo;s.sessions[i].manual=true}
                    else {s.sessions.append(StudySession(subject:subject,start:start,end:end,manual:true,memo:memo))}
                }) {dismiss()}
            }.disabled(subject==nil || end<=start || end>Date())
        }.navigationTitle(session==nil ? "직접 기록 추가" : "기록 수정").onAppear {
            subject=session?.subject ?? store.state.subjects.first?.id
            if let session {start=session.start;end=session.end;memo=session.memo ?? ""}
        }
    }
}

struct TasksExperience: View {
    @EnvironmentObject var store: NativeStore
    @State private var date = Date()
    @State private var title = ""
    @State private var subject: UUID?
    @State private var estimate = 30
    var tasks: [Todo] {store.state.tasks.filter {Calendar.current.isDate($0.day ?? store.studyDay(Date()),inSameDayAs:store.studyDay(date))}}
    var missed: [Todo] {store.state.tasks.filter {!$0.done && ($0.day ?? store.studyDay(Date()))<store.studyDay(date)}}
    var body: some View {
        TourdyPage {
            TourdyPanel("오늘 할 일") {
                HStack {Button {shift(-1)} label:{Image(systemName:"chevron.left")};Spacer();DatePicker("날짜",selection:$date,displayedComponents:.date).labelsHidden();Spacer();Button {shift(1)} label:{Image(systemName:"chevron.right")};Button("오늘") {date=Date()}}
                HStack {TextField("작업 추가",text:$title);Button {add()} label:{Image(systemName:"plus.circle.fill").font(.title2)}}
                Picker("과목",selection:$subject) {Text("과목 없음").tag(UUID?.none);ForEach(store.state.subjects) {Text($0.name).tag(Optional($0.id))}}
                if store.prefs.showPVA {Stepper("예상 \(estimate)분",value:$estimate,in:5...720,step:5)}
                ForEach(tasks.filter {!$0.done}) {task in taskRow(task)}
                DisclosureGroup("완료됨 · \(tasks.filter {$0.done}.count)") {ForEach(tasks.filter {$0.done}) {task in taskRow(task)}}
            }
            if !missed.isEmpty {
                TourdyPanel("달성하지 못한 일") {
                    ForEach(missed) { task in
                        HStack {
                            Text(task.title)
                            Spacer()
                            Button("오늘로") {
                                store.commit { state in
                                    if let index=state.tasks.firstIndex(where:{$0.id==task.id}) {
                                        state.tasks[index].day=store.studyDay(date)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if store.prefs.showPVA {TourdyPanel("계획 vs 실제") {ForEach(store.state.subjects) {sub in
                let planned=tasks.filter {$0.subject==sub.id}.reduce(0){$0+($1.estimate ?? 0)}
                VStack(alignment:.leading) {Text(sub.name);Text("계획 \(Int(planned))분 · 실제 \(Int(store.seconds(on:date,subject:sub.id)/60))분").font(.caption).foregroundStyle(.secondary)}
            }}}
            if store.prefs.showBooks {TourdyPanel("교재 진도") {BooksView()}}
        }.navigationTitle("할 일").navigationBarTitleDisplayMode(.inline)
        .onAppear {store.materializeRepeats(on:date)}.onChange(of:date) {_,new in store.materializeRepeats(on:new)}
    }
    func shift(_ n: Int) {date=Calendar.current.date(byAdding:.day,value:n,to:date) ?? date}
    func add() {let text=title.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty else {return};if store.commit({$0.tasks.append(Todo(title:text,day:store.studyDay(date),subject:subject,estimate:Double(estimate)))}) {title=""}}
    func taskRow(_ task: Todo) -> some View {
        HStack {
            Button {store.commit {s in if let i=s.tasks.firstIndex(where:{$0.id==task.id}) {s.tasks[i].done.toggle()}}} label:{Image(systemName:task.done ? "checkmark.circle.fill" : "circle").font(.title3)}
            Text(task.title).strikethrough(task.done).foregroundStyle(task.done ? .secondary : .primary)
            Spacer()
        }.padding(.vertical,8)
    }
}
struct BooksView: View {
    @EnvironmentObject var store: NativeStore
    @State private var title = ""
    @State private var units = 30
    @State private var target = 3
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            ForEach(store.prefs.books) {book in
                VStack(alignment:.leading) {
                    Text(book.title).font(.headline)
                    ProgressView(value:Double(book.completed.count),total:Double(book.units*book.target))
                    Text("\(book.completed.count)/\(book.units*book.target)강 · \(book.target)회독 목표").font(.caption).foregroundStyle(.secondary)
                    HStack {Button("한 강 완료") {store.configure {p in if let i=p.books.firstIndex(where:{$0.id==book.id}),p.books[i].completed.count<book.units*book.target {p.books[i].completed.append(p.books[i].completed.count)}}};Button("되돌리기") {store.configure {p in if let i=p.books.firstIndex(where:{$0.id==book.id}),!p.books[i].completed.isEmpty {p.books[i].completed.removeLast()}}}}
                }
            }
            TextField("교재 이름",text:$title)
            Stepper("\(units)강",value:$units,in:1...200)
            Stepper("목표 \(target)회독",value:$target,in:1...5)
            Button("교재 추가") {guard !title.isEmpty else {return};store.configure {$0.books.append(StudyBook(title:title,units:units,target:target))};title=""}
        }
    }
}
struct StatsExperience: View {
    @EnvironmentObject var store: NativeStore
    @State private var date = Date()
    @State private var period = "week"
    var days: [Date] {
        var calendar=Calendar.current;calendar.firstWeekday=store.prefs.weekStart
        let anchor=store.studyDay(date),component:Calendar.Component=period=="week" ? .weekOfYear : .month
        guard let interval=calendar.dateInterval(of:component,for:anchor) else {return [anchor]}
        let count=calendar.dateComponents([.day],from:interval.start,to:interval.end).day ?? 7
        return (0..<count).compactMap {calendar.date(byAdding:.day,value:$0,to:interval.start)}
    }
    var body: some View {
        TourdyPage {
            TourdyPanel {
                DatePicker("기준 날짜",selection:$date,displayedComponents:.date)
                Picker("기간",selection:$period) {Text("주간").tag("week");Text("월간").tag("month")}.pickerStyle(.segmented)
                HStack {metric("총 공부",duration(days.reduce(0){$0+store.seconds(on:$1)}));Spacer();metric("일 평균",duration(days.reduce(0){$0+store.seconds(on:$1)}/Double(days.count)))}
            }
            TourdyPanel("공부 잔디") {
                let heatDays=(0..<91).reversed().compactMap {Calendar.current.date(byAdding:.day,value:-$0,to:store.studyDay(date))}
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:13),spacing:4) {
                    ForEach(heatDays,id:\.self) {day in RoundedRectangle(cornerRadius:4).fill(store.accent.opacity(store.seconds(on:day)>0 ? min(1,0.2+store.seconds(on:day)/(4*3600)) : 0.07)).frame(height:20).accessibilityLabel("\(day.formatted(date:.abbreviated,time:.omitted)) \(duration(store.seconds(on:day)))")}
                }
            }
            TourdyPanel("일간 공부 시간") {
                Chart(days,id:\.self) {day in BarMark(x:.value("날짜",day,unit:.day),y:.value("시간",store.seconds(on:day)/3600)).foregroundStyle(store.accent)}.frame(height:180)
            }
            TourdyPanel("과목별 공부") {ForEach(store.state.subjects) {subject in HStack {Label(subject.name,systemImage:subject.icon ?? "book.fill").foregroundStyle(store.subjectColor(subject.id));Spacer();Text(duration(days.reduce(0){$0+store.seconds(on:$1,subject:subject.id)})).monospacedDigit()}}}
            TourdyPanel("타임라인") {DayTimeline(date:date);Text("공부 · 휴식 · 딴짓을 각각 구분해요").font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle("대시보드").navigationBarTitleDisplayMode(.inline)
    }
    func metric(_ title: String,_ value: String) -> some View {VStack(alignment:.leading,spacing:8) {Text(title).font(.caption).foregroundStyle(.secondary);Text(value).font(.title3.bold()).monospacedDigit()}}
}

struct SessionMemoEditor: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    let id: UUID
    @State private var memo = ""
    var body: some View {
        Form {
            TextField("이번 공부는 어땠나요?",text:$memo,axis:.vertical).lineLimit(3...5)
            Button("저장") {if store.commit({s in if let i=s.sessions.firstIndex(where:{$0.id==id}) {s.sessions[i].memo=memo}}) {store.memoSession=nil;dismiss()}}
            Button("건너뛰기") {store.memoSession=nil;dismiss()}
        }.navigationTitle("공부 메모").onAppear {memo=store.state.sessions.first {$0.id==id}?.memo ?? ""}
    }
}
struct SettingsExperience: View {
    @EnvironmentObject var store: NativeStore
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var incoming: Data?
    @State private var confirmRestore = false
    @State private var pasted = ""
    var body: some View {
        List {
            Section("타이머 설정") {
                NavigationLink("목표 시간") {
                    Form {Stepper("하루 목표 \(store.prefs.goalMinutes)분",value:store.preference(\.goalMinutes),in:0...720,step:30);Text("0분이면 목표를 사용하지 않아요.").font(.caption).foregroundStyle(.secondary)}.navigationTitle("목표 시간")
                }
                NavigationLink("알림") {
                    Form {
                        Toggle("시작·종료 알림음",isOn:store.preference(\.sound))
                        Toggle("5분 전 알림",isOn:store.preference(\.warnFive))
                        Toggle("공부 메모 묻기",isOn:store.preference(\.memo))
                        Toggle("기기 알림",isOn:Binding(get:{store.prefs.notifications},set:{value in if value {store.requestNotifications()} else {store.configure {$0.notifications=false};store.refreshNotifications()}}))
                        Text("예약 시작과 세션 종료를 기기 알림으로 알려줘요. 알림 허용이 필요합니다.").font(.caption).foregroundStyle(.secondary)
                    }.navigationTitle("알림").onDisappear {store.refreshNotifications()}
                }
                NavigationLink("추가 기능") {Form {Toggle("교재 진도",isOn:store.preference(\.showBooks));Toggle("계획 vs 실제",isOn:store.preference(\.showPVA))}.navigationTitle("추가 기능")}
                NavigationLink("테마") {
                    Form {
                        Picker("모드",selection:store.preference(\.theme)) {Text("시스템").tag("system");Text("라이트").tag("light");Text("다크").tag("dark")}.pickerStyle(.segmented)
                        Picker("강조색",selection:store.preference(\.accent)) {Text("파랑").tag("#3182F6");Text("초록").tag("#30A46C");Text("보라").tag("#8E4EC6");Text("주황").tag("#F76B15");Text("분홍").tag("#D6409F")}
                    }.navigationTitle("테마")
                }
                NavigationLink("하루의 시작") {
                    Form {Picker("하루 시작 시각",selection:store.preference(\.dayStart)) {ForEach(0...8,id:\.self) {hour in Text(hour==0 ? "자정" : "새벽 \(hour)시").tag(hour)}};Text("설정한 시각 전의 공부는 전날 기록으로 계산해요.").font(.caption).foregroundStyle(.secondary)}.navigationTitle("하루의 시작")
                }
                NavigationLink("한 주의 시작") {Form {Picker("시작 요일",selection:store.preference(\.weekStart)) {Text("월요일").tag(2);Text("일요일").tag(1)}}.navigationTitle("한 주의 시작")}
                NavigationLink("D-day") {Form {TextField("이름",text:store.preference(\.ddayName));DatePicker("목표 날짜",selection:Binding(get:{store.prefs.dday ?? Date()},set:{date in store.configure {$0.dday=date}}),displayedComponents:.date);Button("D-day 해제",role:.destructive) {store.configure {$0.dday=nil;$0.ddayName=""}}}.navigationTitle("D-day")}
                NavigationLink("반복 할 일") {RepeatEditor()}
            }
            Section("여행 설정") {
                NavigationLink("여행") {Form {Toggle("여행 탭 사용",isOn:store.preference(\.travelEnabled));Toggle("창밖 풍경",isOn:store.preference(\.window));Picker("도장 보기",selection:store.preference(\.stampStyle)) {Text("도장").tag("stamp");Text("수집 카드").tag("card");Text("승차권").tag("pass")}}.navigationTitle("여행")}
                NavigationLink("소리") {Form {Toggle("도착 효과음",isOn:store.preference(\.arrivalSound));Toggle("안내 방송 음성",isOn:store.preference(\.voice));Toggle("진동",isOn:store.preference(\.vibration))}.navigationTitle("소리")}
                NavigationLink("마일리지") {
                    Form {
                        LabeledContent("누적 적립",value:String(format:"%.1f",store.earned(store.state)))
                        LabeledContent("사용",value:String(format:"%.1f",store.state.used))
                        LabeledContent("보유",value:String(format:"%.1f",store.balance))
                        Text("공부 6분 = 1마일 · 하루 최대 8시간 적립")
                        Text("하루 8시간 +50 · 7일 연속 +100 · 30일 연속 +1000")
                        Text("휴식·딴짓·직접 추가한 기록은 적립에서 제외돼요.").font(.caption).foregroundStyle(.secondary)
                    }.navigationTitle("마일리지")
                }
            }
            Section("기록 보관") {
                Button("백업 파일 준비") {do {exportURL=try store.export()} catch {store.error=error.localizedDescription}}
                if let exportURL {ShareLink("백업 파일 공유·저장",item:exportURL)}
                Button("백업 파일 가져오기") {importing=true}
                DisclosureGroup("복사한 백업 붙여넣기") {TextEditor(text:$pasted).frame(height:140);Button("내용 확인 후 복원") {prepare(pasted.data(using:.utf8))}.disabled(pasted.isEmpty)}
                Text("이전 TOURDY의 JSON 백업과 네이티브 백업을 가져올 수 있어요. 복원 전 기록과 가져온 원본을 기기에 별도로 보관해요.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("설정").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json,.plainText]) {result in
            do {let url=try result.get();let granted=url.startAccessingSecurityScopedResource();defer {if granted {url.stopAccessingSecurityScopedResource()}};prepare(try Data(contentsOf:url))}
            catch {store.error="백업 파일을 열지 못했어요: \(error.localizedDescription)"}
        }
        .confirmationDialog("현재 기록을 선택한 백업으로 바꿀까요?",isPresented:$confirmRestore,titleVisibility:.visible) {
            Button("백업으로 복원") {if let incoming {store.restoreBackup(incoming)};incoming=nil}
            Button("취소",role:.cancel) {incoming=nil}
        } message:{Text("현재 기록은 복원 전 사본으로 보관됩니다. 이전 앱의 일부 확장 설정은 가져오지 못할 수 있어요.")}
    }
    func prepare(_ data: Data?) {
        guard let data,(try? JSONSerialization.jsonObject(with:data)) != nil else {store.error="백업 내용을 읽지 못했어요.";return}
        incoming=data;confirmRestore=true
    }
}
struct RepeatEditor: View {
    @EnvironmentObject var store: NativeStore
    @State private var title = ""
    @State private var days: Set<Int> = Set(1...7)
    var body: some View {
        Form {
            Section("반복 할 일") {
                ForEach(store.prefs.repeats) {task in VStack(alignment:.leading) {Text(task.title);Text(task.weekdays.sorted().map {Calendar.current.shortWeekdaySymbols[$0-1]}.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)}}
                    .onDelete {index in store.configure {$0.repeats.remove(atOffsets:index)}}
            }
            Section("추가") {
                TextField("할 일",text:$title)
                ForEach(1...7,id:\.self) {day in Toggle(Calendar.current.weekdaySymbols[day-1],isOn:Binding(get:{days.contains(day)},set:{on in if on {days.insert(day)} else {days.remove(day)}}))}
                Button("추가") {let text=title.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty && !days.isEmpty else {return};store.configure {$0.repeats.append(RepeatTask(title:text,weekdays:Array(days)))};title="";store.materializeRepeats(on:Date())}
            }
        }.navigationTitle("반복 할 일")
    }
}
