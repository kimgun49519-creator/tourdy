import SwiftUI
import UniformTypeIdentifiers

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let world: String
    let latitude: Double
    let longitude: Double
    let cost: Double
    let zone: Int
}
struct Subject: Codable, Identifiable { var id = UUID(); var name: String }
struct StudySession: Codable, Identifiable { var id = UUID(); var subject: UUID; var start: Date; var end: Date }
struct RunningStudy: Codable { var subject: UUID; var start: Date }
struct Todo: Codable, Identifiable { var id = UUID(); var title: String; var done = false }
struct Stamp: Codable, Identifiable {
    var id = UUID(); var place: String; var from: String; var date: Date; var premium: Bool; var free: Bool
}
struct Journey: Codable { var from: String; var to: String; var cost: Double; var premium: Bool }
struct NativeState: Codable {
    var version = 1
    var subjects: [Subject] = []
    var sessions: [StudySession] = []
    var running: RunningStudy?
    var tasks: [Todo] = []
    var stamps: [Stamp] = []
    var positions = ["kr":"seoul", "world":"KR", "space":"earth"]
    var home = "seoul"
    var used: Double = 0
    var journey: Journey?
    var firstReward = "pending"
    var sound = true
    var askMemo = false
    var darkMode = false
}

@MainActor
final class NativeStore: ObservableObject {
    @Published private(set) var state = NativeState()
    @Published var error: String?
    @Published var arrival: Stamp?
    let places: [Place]
    private let file: URL
    private var blocked = false

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TourdyNative", isDirectory: true)
        file = directory.appendingPathComponent("state-v1.json")
        if let url = Bundle.main.url(forResource: "places", withExtension: "json", subdirectory: "Resources"), let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([Place].self, from: data) {
            places = decoded
        } else { places = [] }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) {
                state = try JSONDecoder().decode(NativeState.self, from: Data(contentsOf: file))
                try validate(state)
            }
            if places.isEmpty { throw CocoaError(.fileReadCorruptFile) }
        } catch { blocked = true; self.error = "기존 기록 또는 도시 파일을 읽지 못했어요. 덮어쓰기를 멈췄습니다. \(error.localizedDescription)" }
    }

    func place(_ id: String) -> Place? { places.first { $0.id == id } }
    var completedSeconds: Double { state.sessions.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) } }
    func dailySeconds(_ sessions: [StudySession]) -> [Date: Double] {
        var days: [Date: Double] = [:]
        let calendar = Calendar.current
        for session in sessions {
            var cursor = session.start
            while cursor < session.end {
                let day = calendar.startOfDay(for: cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > cursor else { break }
                let end = min(next, session.end)
                days[day, default: 0] += end.timeIntervalSince(cursor)
                cursor = end
            }
        }
        return days
    }
    func earned(_ s: NativeState) -> Double {
        let days = dailySeconds(s.sessions)
        var result = days.values.reduce(0) { $0 + min($1, 8 * 3600) / 360 + ($1 >= 8 * 3600 ? 50 : 0) }
        var streak = 0; var previous: Date?
        for day in days.keys.sorted() where (days[day] ?? 0) >= 60 {
            if let previous, Calendar.current.date(byAdding: .day, value: 1, to: previous) == day { streak += 1 } else { streak = 1 }
            if streak % 7 == 0 { result += 100 }; if streak % 30 == 0 { result += 1000 }
            previous = day
        }
        return result
    }
    var balance: Double { max(0, earned(state) - state.used) }
    func unlocked(_ world: String) -> Bool {
        if world == "kr" { return true }
        let domestic = Set(state.stamps.filter { place($0.place)?.world == "kr" }.map(\.place))
        if world == "world" { return places.filter { $0.world == "kr" && $0.id != state.home }.allSatisfy { domestic.contains($0.id) } }
        let visited = Set(state.stamps.filter { place($0.place)?.world == "world" }.map(\.place))
        return unlocked("world") && places.filter { $0.world == "world" && $0.id != "KR" }.allSatisfy { visited.contains($0.id) }
    }
    func zoneOpen(_ p: Place) -> Bool {
        guard p.world == "space", p.zone > 0 else { return true }
        let visited = Set(state.stamps.map(\.place))
        return places.filter { $0.world == "space" && $0.zone < p.zone }.allSatisfy { visited.contains($0.id) }
    }
    func distance(_ from: Place, _ to: Place) -> Double {
        let r = Double.pi / 180, a = from.latitude * r, b = to.latitude * r
        let h = pow(sin((b-a)/2),2) + cos(a)*cos(b)*pow(sin((to.longitude-from.longitude)*r/2),2)
        return 12742 * asin(sqrt(min(1, max(0,h))))
    }
    func cost(_ p: Place, premium: Bool) -> Double {
        if p.world == "space" { return p.cost }
        guard let from = place(state.positions[p.world] ?? "") else { return .infinity }
        let km = distance(from,p)
        let base = p.world == "kr" ? max(30,km.rounded()) : max(30,(km / 800 * 60).rounded())
        return (base * (premium ? 1.3 : 1)).rounded()
    }
    private func validate(_ s: NativeState) throws {
        guard s.version == 1, s.used.isFinite, s.used >= 0,
              s.sessions.allSatisfy({ $0.end >= $0.start }),
              ["pending","ready","used"].contains(s.firstReward),
              ["kr","world","space"].allSatisfy({ world in
                  guard let id=s.positions[world] else { return false }
                  return (world == "space" && id == "earth") || place(id)?.world == world
              }),
              place(s.home)?.world == "kr",
              s.journey.map({ $0.cost.isFinite && $0.cost >= 0 && place($0.to) != nil }) ?? true,
              s.stamps.allSatisfy({ place($0.place) != nil && ($0.from == "earth" || place($0.from) != nil) }) else { throw CocoaError(.fileReadCorruptFile) }
    }
    @discardableResult
    func commit(_ change: (inout NativeState) -> Void) -> Bool {
        guard !blocked else { error = "기존 기록을 보호하고 있어 저장할 수 없어요."; return false }
        var next = state; change(&next)
        do {
            try validate(next)
            let data = try JSONEncoder().encode(next)
            try data.write(to: file, options: .atomic)
            state = next
            return true
        } catch { self.error = "저장하지 못했어요. 변경 전 기록을 유지합니다. \(error.localizedDescription)"; return false }
    }
    func start(_ subject: Subject) {
        guard state.running == nil else { return }
        commit { $0.running = RunningStudy(subject: subject.id, start: Date()) }
    }
    func stop() {
        guard let running = state.running else { return }
        let end = max(Date(),running.start)
        if commit({ s in
            s.sessions.append(StudySession(subject:running.subject,start:running.start,end:end)); s.running = nil
            if s.firstReward == "pending" && s.sessions.reduce(0, { $0 + $1.end.timeIntervalSince($1.start) }) >= 1800 { s.firstReward = "ready" }
        }) { settleJourney() }
    }
    func depart(_ p: Place, premium: Bool) {
        guard unlocked(p.world), zoneOpen(p), state.journey == nil,
              let from = state.positions[p.world], from != p.id else { return }
        let fare = cost(p,premium:premium)
        if commit({ $0.journey = Journey(from:from,to:p.id,cost:fare,premium:premium) }) { settleJourney() }
    }
    func settleJourney() {
        guard let journey = state.journey, let p = place(journey.to), balance >= journey.cost else { return }
        let stamp = Stamp(place:p.id,from:journey.from,date:Date(),premium:journey.premium,free:false)
        if commit({ s in s.used += journey.cost; s.positions[p.world] = p.id; s.stamps.append(stamp); s.journey = nil }) { arrival = stamp }
    }
    func gift(_ p: Place, origin: String) {
        guard p.world == "kr", state.running == nil, state.firstReward == "ready",
              let from = place(origin), from.world == "kr", origin != p.id else { return }
        let started = state.stamps.contains { place($0.place)?.world == "kr" }
        guard !started || origin == state.positions["kr"] else { return }
        let stamp = Stamp(place:p.id,from:origin,date:Date(),premium:true,free:true)
        if commit({ s in s.firstReward = "used"; if !started { s.home = origin }; s.positions["kr"] = p.id; s.stamps.append(stamp); s.journey = nil }) { arrival = stamp }
    }
    func setting(_ key: WritableKeyPath<NativeState,Bool>) -> Binding<Bool> {
        Binding(get: { self.state[keyPath:key] }, set: { value in self.commit { $0[keyPath:key] = value } })
    }
    func export() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tourdy-native-backup.json")
        try JSONEncoder().encode(state).write(to:url,options:.atomic)
        return url
    }
}

@main
struct TourdyNativeApp: App {
    @StateObject private var store = NativeStore()
    var body: some Scene { WindowGroup { NativeRoot().environmentObject(store).preferredColorScheme(store.state.darkMode ? .dark : nil) } }
}
struct NativeRoot: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.scenePhase) var phase
    var body: some View {
        TabView {
            NavigationStack { TimerScreen() }.tabItem { Label("홈",systemImage:"timer") }
            NavigationStack { TasksScreen() }.tabItem { Label("할 일",systemImage:"checklist") }
            NavigationStack { StatsScreen() }.tabItem { Label("대시보드",systemImage:"chart.bar.xaxis") }
            NavigationStack { TravelScreen() }.tabItem { Label("여행",systemImage:"airplane") }
            NavigationStack { SettingsScreen() }.tabItem { Label("설정",systemImage:"gearshape.fill") }
        }
        .tabViewStyle(.tabBarOnly)
        .onChange(of: phase) { _, value in
            if value == ScenePhase.active { store.settleJourney() }
        }
        .alert("확인해 주세요",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error=nil}})) { Button("확인") {store.error=nil} } message:{Text(store.error ?? "")}
        .sheet(item:$store.arrival) { stamp in NavigationStack { TicketScreen(stamp:stamp) } }
    }
}
func duration(_ seconds: Double) -> String {
    let s = max(0,Int(seconds)); return String(format:"%02d:%02d:%02d",s/3600,(s%3600)/60,s%60)
}
struct TimerScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var name = ""
    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from:.now,by:1)) { context in
                    VStack(spacing:16) {
                        Text(store.state.running.flatMap { run in store.state.subjects.first {$0.id == run.subject}?.name } ?? "공부를 시작해볼까요?")
                        Text(duration(store.state.running.map {context.date.timeIntervalSince($0.start)} ?? 0)).font(.system(size:44,weight:.medium,design:.monospaced)).minimumScaleFactor(0.5)
                        if store.state.running != nil { Button("공부 마치기",role:.destructive) {store.stop()}.buttonStyle(.glass) }
                    }.frame(maxWidth:.infinity).padding(.vertical,20)
                }
            }
            Section("과목") {
                ForEach(store.state.subjects) { subject in Button {store.start(subject)} label:{Label(subject.name,systemImage:"play.circle")}.disabled(store.state.running != nil) }
                HStack { TextField("새 과목",text:$name); Button("추가") {let trimmed=name.trimmingCharacters(in:.whitespacesAndNewlines); if !trimmed.isEmpty && store.commit({$0.subjects.append(Subject(name:trimmed))}) {name=""}} }
            }
            Section("첫 여행 선물") {
                Text(store.state.firstReward == "used" ? "첫 여행 티켓을 사용했어요" : store.state.firstReward == "ready" ? "무료 최고급 티켓이 준비됐어요" : "누적 공부 30분 후, 세션을 마치면 받아요")
                ProgressView(value:min(1800,store.completedSeconds),total:1800)
                if store.state.firstReward == "ready" { NavigationLink("첫 여행 떠나기") { GiftScreen() }.disabled(store.state.running != nil) }
            }
        }.navigationTitle("TOURDY")
    }
}
struct TasksScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var title = ""
    var body: some View {
        List {
            HStack {TextField("할 일 추가",text:$title); Button("추가") {let text=title.trimmingCharacters(in:.whitespacesAndNewlines); if !text.isEmpty && store.commit({$0.tasks.append(Todo(title:text))}) {title=""}}}
            ForEach(store.state.tasks) { task in
                Toggle(task.title,isOn:Binding(get:{store.state.tasks.first {$0.id==task.id}?.done ?? false},set:{value in store.commit {s in if let i=s.tasks.firstIndex(where:{$0.id==task.id}) {s.tasks[i].done=value}}})).toggleStyle(.switch)
            }
        }.navigationTitle("할 일")
    }
}
struct StatsScreen: View {
    @EnvironmentObject var store: NativeStore
    var body: some View {
        List {
            LabeledContent("누적 공부",value:duration(store.completedSeconds))
            LabeledContent("보유 마일리지",value:String(format:"%.1f",store.balance))
            Section("과목별 공부") {ForEach(store.state.subjects) {subject in LabeledContent(subject.name,value:duration(store.state.sessions.filter {$0.subject==subject.id}.reduce(0){$0+$1.end.timeIntervalSince($1.start)}))}}
            Section("최근 공부") {ForEach(store.state.sessions.reversed()) {session in VStack(alignment:.leading) {Text(store.state.subjects.first {$0.id==session.subject}?.name ?? "과목"); Text("\(session.start.formatted()) · \(duration(session.end.timeIntervalSince(session.start)))").font(.caption).foregroundStyle(.secondary)}}}
        }.navigationTitle("대시보드")
    }
}
struct TravelScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var world = "kr"
    @State private var search = ""
    @State private var premium = false
    var destinations: [Place] {store.places.filter {$0.world==world && $0.id != store.state.positions[world] && (search.isEmpty || ($0.name+$0.region).localizedCaseInsensitiveContains(search))}.sorted {store.cost($0,premium:premium)<store.cost($1,premium:premium)}}
    var body: some View {
        List {
            Picker("여행",selection:$world) {Text("국내").tag("kr");Text("세계").tag("world");Text("우주").tag("space")}.pickerStyle(.segmented)
            LabeledContent("현재 위치",value:store.place(store.state.positions[world] ?? "")?.name ?? "지구")
            LabeledContent("보유 마일리지",value:String(format:"%.1f",store.balance))
            NavigationLink("스탬프북 · \(store.state.stamps.count)장") {StampBook()}
            if let journey=store.state.journey {
                Section("이동 중") {
                    Text("\(store.place(journey.from)?.name ?? "") → \(store.place(journey.to)?.name ?? "")")
                    Text("도착까지 \(duration(max(0,journey.cost-store.balance)*360)) 공부")
                    Button("여행 취소",role:.destructive) {store.commit {$0.journey=nil}}
                }
            }
            if !store.unlocked(world) {Text(world == "world" ? "국내 여행을 완주하면 열려요" : "세계 여행을 완주하면 열려요")}
            else {
                if world != "space" {Toggle("최고급 좌석",isOn:$premium)}
                Section("출발 안내") {
                    ForEach(destinations) { place in
                        NavigationLink {
                            DestinationScreen(place: place, premium: premium)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                Text("\(place.region) · \(Int(store.cost(place, premium: premium))) 마일")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.searchable(text:$search,prompt:"목적지 검색").navigationTitle("여행")
    }
}
struct DestinationScreen: View {
    @EnvironmentObject var store: NativeStore
    let place: Place
    let premium: Bool
    var body: some View {
        Form {
            LabeledContent("목적지",value:place.name)
            LabeledContent("좌석",value:premium ? "최고급" : "일반")
            LabeledContent("필요 마일리지",value:String(Int(store.cost(place,premium:premium))))
            Text("마일리지가 부족하면 공부를 마친 뒤 자동으로 도착해요. 도착 시 마일리지가 차감됩니다.")
            Button("여행 출발") {store.depart(place,premium:premium)}.disabled(store.state.journey != nil || !store.zoneOpen(place)).buttonStyle(.glassProminent)
        }.navigationTitle(place.name)
    }
}
struct GiftScreen: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    @State private var origin = "seoul"
    @State private var destination = "busan"
    @State private var search = ""
    var body: some View {
        Form {
            Section("출발지") {Picker("출발지",selection:$origin) {ForEach(store.places.filter {$0.world=="kr"}) {Text($0.name).tag($0.id)}}.disabled(store.state.stamps.contains {store.place($0.place)?.world=="kr"})}
            Section("목적지") {
                TextField("도시 이름",text:$search)
                Picker("목적지",selection:$destination) {ForEach(store.places.filter {$0.world=="kr" && $0.id != origin && (search.isEmpty || $0.name.contains(search) || $0.id==destination)}) {Text($0.name).tag($0.id)}}
            }
            Section {
                VStack(alignment:.leading,spacing:12) {Label("첫 여행 · GOLD TICKET",systemImage:"ticket.fill");Text("\(store.place(origin)?.name ?? "") → \(store.place(destination)?.name ?? "")").font(.title2.bold());Text("최고급 티켓 · 즉시 도착 · 마일리지 차감 없음")}.padding().frame(maxWidth:.infinity,alignment:.leading).background(.yellow.opacity(0.18),in:RoundedRectangle(cornerRadius:18))
                Button("첫 여행 떠나기") {if let p=store.place(destination) {store.gift(p,origin:origin);if store.state.firstReward=="used" {dismiss()}}}.buttonStyle(.glassProminent).disabled(origin==destination || store.state.running != nil || store.state.firstReward != "ready")
            }
        }.navigationTitle("첫 여행").onAppear {origin=store.state.positions["kr"] ?? "seoul";if destination==origin {destination=origin=="busan" ? "seoul" : "busan"}}
    }
}
struct StampBook: View {
    @EnvironmentObject var store: NativeStore
    var body: some View {List(store.state.stamps.reversed()) {stamp in NavigationLink {TicketScreen(stamp:stamp)} label:{Label("\(store.place(stamp.place)?.name ?? stamp.place) · \(stamp.date.formatted(date:.abbreviated,time:.omitted))",systemImage:stamp.premium ? "seal.fill" : "seal")}}.navigationTitle("스탬프북")}
}
struct TicketScreen: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    let stamp: Stamp
    var recommendations: [Place] {
        let visited = Set(store.state.stamps.map(\.place))
        return Array(store.places.filter { $0.world == "kr" && $0.id != stamp.place && !visited.contains($0.id) }
            .sorted {store.cost($0,premium:false)<store.cost($1,premium:false)}.prefix(3))
    }
    var body: some View {
        List {
            Section {Label(stamp.premium ? "GOLD TICKET" : "여행 티켓",systemImage:"ticket.fill").foregroundStyle(stamp.premium ? Color.orange : Color.blue);Text("\(store.place(stamp.from)?.name ?? stamp.from) → \(store.place(stamp.place)?.name ?? stamp.place)").font(.title2.bold());Text(stamp.date.formatted());if stamp.free {Text("공부 30분이 데려다준 첫 도시");Text("최고급 티켓 · 마일리지 차감 없음")}}
            if stamp.free && store.state.positions["kr"]==stamp.place {
                Section("다음에는 어디로 갈까요?") {ForEach(recommendations) {p in NavigationLink(p.name) {DestinationScreen(place:p,premium:false)}}}
            }
        }.navigationTitle("도착 기념").toolbar {Button("닫기") {dismiss()}}
    }
}
struct SettingsScreen: View {
    @EnvironmentObject var store: NativeStore
    @State private var exportURL: URL?
    var body: some View {
        Form {
            Section("화면") {Toggle("다크 모드",isOn:store.setting(\.darkMode))}
            Section("기록 보관") {Button("백업 파일 준비") {do {exportURL=try store.export()} catch {store.error=error.localizedDescription}};if let url=exportURL {ShareLink("백업 파일 공유·저장",item:url)}}
            Section("이 버전") {Text("SwiftUI 네이티브 · 오프라인 저장");Text("기존 웹앱 기록은 별도로 보관됩니다. 자동으로 가져오지 않습니다.");Text("예약·뽀모도로, 알림·효과음, 기존 백업 가져오기, 특별 루트와 고급 여행 연출은 아직 이식 중입니다.").foregroundStyle(.secondary)}
        }.navigationTitle("설정")
    }
}
