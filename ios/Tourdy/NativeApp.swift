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
    var gate: [String]?
    var secret: Bool?
}
struct Subject: Codable, Identifiable { var id = UUID(); var name: String; var color: String?; var icon: String?; var goal: Double? }
struct StudySession: Codable, Identifiable { var id = UUID(); var subject: UUID; var start: Date; var end: Date; var kind: String?; var manual: Bool?; var memo: String? }
struct RunningStudy: Codable { var subject: UUID; var start: Date; var kind: String?; var end: Date? }
struct Todo: Codable, Identifiable { var id = UUID(); var title: String; var done = false; var day: Date?; var subject: UUID?; var estimate: Double? }
struct Stamp: Codable, Identifiable {
    var id = UUID(); var place: String; var from: String; var date: Date; var premium: Bool; var free: Bool
    var cabin: Int?
    var route: String?
}
struct Journey: Codable { var from: String; var to: String; var cost: Double; var premium: Bool; var cabin: Int?; var goal: Date? }
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
    var experience: ExperienceState?
}

@MainActor
final class NativeStore: ObservableObject {
    @Published private(set) var state = NativeState()
    @Published var error: String?
    @Published var arrival: Stamp?
    @Published var memoSession: UUID?
    @Published var clockDate = Date()
    let places: [Place]
    private let file: URL
    private let writer: (Data,URL) throws -> Void
    private var blocked = false

    init(directory providedDirectory: URL? = nil, catalog: [Place]? = nil, write: ((Data,URL) throws -> Void)? = nil) {
        let directory = providedDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TourdyNative", isDirectory: true)
        file = directory.appendingPathComponent("state-v1.json")
        writer = write ?? {data,url in try data.write(to:url,options:.atomic)}
        if let catalog {places=catalog}
        else if let url = Bundle.main.url(forResource: "places", withExtension: "json"), let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([Place].self, from: data) {
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
    var completedSeconds: Double { state.sessions.filter { ($0.kind ?? "study") == "study" }.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) } }
    func dailySeconds(_ sessions: [StudySession]) -> [Date: Double] {
        var days: [Date: Double] = [:]
        let calendar = Calendar.current
        for session in sessions where (session.kind ?? "study") == "study" {
            var cursor = session.start
            while cursor < session.end {
                let shifted = cursor.addingTimeInterval(-Double(prefs.dayStart)*3600)
                let day = calendar.startOfDay(for: shifted)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                let boundary = calendar.date(byAdding:.hour,value:prefs.dayStart,to:next) ?? next
                guard boundary > cursor else {break}
                let end = min(boundary, session.end)
                days[day, default: 0] += end.timeIntervalSince(cursor)
                cursor = end
            }
        }
        return days
    }
    func earned(_ s: NativeState) -> Double {
        var sessions = s.sessions.filter { $0.manual != true }
        if let run=s.running, (run.kind ?? "study") == "study" {
            sessions.append(StudySession(subject:run.subject,start:run.start,end:max(run.start,min(Date(),run.end ?? Date()))))
        }
        let days = dailySeconds(sessions)
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
        if world == "world" { return places.filter { $0.world == "kr" && $0.secret != true && $0.id != state.home }.allSatisfy { domestic.contains($0.id) } }
        let visited = Set(state.stamps.filter { place($0.place)?.world == "world" }.map(\.place))
        return unlocked("world") && places.filter { $0.world == "world" && $0.secret != true && $0.id != "KR" }.allSatisfy { visited.contains($0.id) }
    }
    func zoneOpen(_ p: Place) -> Bool {
        if let gate=p.gate,!gate.isEmpty {return state.stamps.contains {gate.contains($0.place)}}
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
              s.running.map({ $0.end == nil || $0.end! >= $0.start }) ?? true,
              ["pending","ready","used"].contains(s.firstReward),
              ["kr","world","space"].allSatisfy({ world in
                  guard let id=s.positions[world] else { return false }
                  return (world == "space" && id == "earth") || place(id)?.world == world
              }),
              place(s.home)?.world == "kr",
              s.journey.map({ $0.cost.isFinite && $0.cost >= 0 && place($0.to) != nil }) ?? true,
              s.stamps.allSatisfy({ place($0.place) != nil && ($0.from == "earth" || place($0.from) != nil) }) else { throw CocoaError(.fileReadCorruptFile) }
        if let p=s.experience {
            guard (0...8).contains(p.dayStart), (0...1440).contains(p.goalMinutes) else {throw CocoaError(.fileReadCorruptFile)}
            if let plan=p.plan {
                guard plan.study>0,plan.rest>=0,(1...12).contains(plan.sets),(1...plan.sets).contains(plan.set),["waiting","study","rest","paused"].contains(plan.phase) else {throw CocoaError(.fileReadCorruptFile)}
            }
        }
    }
    @discardableResult
    func commit(_ change: (inout NativeState) -> Void) -> Bool {
        guard !blocked else { error = "기존 기록을 보호하고 있어 저장할 수 없어요."; return false }
        var next = state; change(&next)
        do {
            try validate(next)
            let data = try JSONEncoder().encode(next)
            try writer(data,file)
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
            s.sessions.append(StudySession(subject:running.subject,start:running.start,end:min(end,running.end ?? end),kind:running.kind)); s.running = nil
            if s.firstReward == "pending" && s.sessions.filter({($0.kind ?? "study") == "study" && $0.manual != true}).reduce(0, { $0 + $1.end.timeIntervalSince($1.start) }) >= 1800 { s.firstReward = "ready" }
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
        let stamp = Stamp(place:p.id,from:journey.from,date:Date(),premium:journey.premium,free:false,cabin:journey.cabin,route:prefs.route?.id)
        if commit({ s in
            s.used += journey.cost; s.positions[p.world] = p.id; s.stamps.append(stamp); s.journey = nil
            advanceRoute(&s, arrived: p)
            recordAchievements(&s,stamp:stamp)
        }) { arrival = stamp; playArrival() }
    }
    func gift(_ p: Place, origin: String) {
        guard p.world == "kr", p.secret != true, state.running == nil, state.firstReward == "ready",
              let from = place(origin), from.world == "kr", origin != p.id else { return }
        let started = state.stamps.contains { place($0.place)?.world == "kr" }
        guard !started || origin == state.positions["kr"] else { return }
        let stamp = Stamp(place:p.id,from:origin,date:Date(),premium:true,free:true,cabin:1)
        if commit({ s in s.firstReward = "used"; if !started { s.home = origin }; s.positions["kr"] = p.id; s.stamps.append(stamp); s.journey = nil;var preferences=s.experience ?? ExperienceState();preferences.route=nil;s.experience=preferences;recordAchievements(&s,stamp:stamp) }) { arrival = stamp;playArrival() }
    }
    func setting(_ key: WritableKeyPath<NativeState,Bool>) -> Binding<Bool> {
        Binding(get: { self.state[keyPath:key] }, set: { value in self.commit { $0[keyPath:key] = value } })
    }
    func export() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tourdy-native-backup.json")
        try JSONEncoder().encode(state).write(to:url,options:.atomic)
        return url
    }
    func restoreBackup(_ data: Data) {
        do {
            let candidate: NativeState
            if let native=try? JSONDecoder().decode(NativeState.self,from:data) {candidate=native}
            else {candidate=try decodeLegacy(data)}
            try validate(candidate)
            if let previous=try? Data(contentsOf:file) {try previous.write(to:file.deletingLastPathComponent().appendingPathComponent("before-import.json"),options:.atomic)}
            try data.write(to:file.deletingLastPathComponent().appendingPathComponent("import-source.json"),options:.atomic)
            try JSONEncoder().encode(candidate).write(to:file,options:.atomic)
            state=candidate;blocked=false;refreshNotifications()
        } catch {self.error="백업을 가져오지 못했어요. 현재 기록을 유지합니다. \(error.localizedDescription)"}
    }
}

@main
struct TourdyNativeApp: App {
    @StateObject private var store = NativeStore()
    var body: some Scene { WindowGroup { NativeRoot().environmentObject(store).tint(store.accent).preferredColorScheme(store.prefs.theme=="dark" ? .dark : store.prefs.theme=="light" ? .light : nil) } }
}
struct NativeRoot: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.scenePhase) var phase
    var body: some View {
        TabView {
            NavigationStack { HomeExperience() }.tabItem { Label("홈",systemImage:"timer") }
            NavigationStack { TasksExperience() }.tabItem { Label("할 일",systemImage:"checklist") }
            NavigationStack { StatsExperience() }.tabItem { Label("대시보드",systemImage:"chart.bar.xaxis") }
            if store.prefs.travelEnabled {NavigationStack { TravelExperience() }.tabItem { Label("여행",systemImage:"airplane") }}
            NavigationStack { SettingsExperience() }.tabItem { Label("설정",systemImage:"gearshape.fill") }
        }
        .tabViewStyle(.tabBarOnly)
        .onChange(of: phase) { _, value in
            if value == ScenePhase.active { store.updateClock() }
        }
        .onReceive(Timer.publish(every:1,on:.main,in:.common).autoconnect()) {_ in store.updateClock()}
        .alert("확인해 주세요",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error=nil}})) { Button("확인") {store.error=nil} } message:{Text(store.error ?? "")}
        .sheet(item:$store.arrival) { stamp in NavigationStack { ArrivalExperience(stamp:stamp) } }
        .sheet(isPresented:Binding(get:{store.memoSession != nil && store.arrival==nil},set:{if !$0 {store.memoSession=nil}})) {if let id=store.memoSession {NavigationStack {SessionMemoEditor(id:id)}}}
    }
}
func duration(_ seconds: Double) -> String {
    let s = max(0,Int(seconds)); return String(format:"%02d:%02d:%02d",s/3600,(s%3600)/60,s%60)
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
