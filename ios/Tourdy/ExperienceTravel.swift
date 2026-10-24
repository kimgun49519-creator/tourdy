import SwiftUI

struct MapRegion: Decodable {var id: String; var polygons: [[[Double]]]}
struct MapLayer: Decodable {var bounds: [Double]; var regions: [MapRegion]}
struct TourdyAtlas: Decodable {
    var kr: MapLayer;var world: MapLayer;var dots: [String:[Double]]
    static let bundled: TourdyAtlas? = {
        guard let url=Bundle.main.url(forResource:"atlas",withExtension:"json"),let data=try? Data(contentsOf:url) else {return nil}
        return try? JSONDecoder().decode(TourdyAtlas.self,from:data)
    }()
}
struct TravelExperience: View {
    @EnvironmentObject var store: NativeStore
    @State private var world = "kr"
    @State private var query = ""
    @State private var region = "전체"
    @State private var mapExpanded = false
    @State private var pendingHome = false
    var regions: [String] {["전체"]+Array(Set(store.places.filter {$0.world==world}.map(\.region))).sorted()}
    var visited: Set<String> {Set(store.state.stamps.map(\.place))}
    var destinations: [Place] {
        store.places.filter {$0.world==world && store.zoneOpen($0) && $0.id != store.state.positions[world] && !visited.contains($0.id) && (region=="전체" || $0.region==region) && (query.isEmpty || ($0.name+$0.region).localizedCaseInsensitiveContains(query))}
            .sorted {store.cost($0,premium:false)<store.cost($1,premium:false)}
    }
    var body: some View {
        TourdyPage {
            Picker("여행 지역",selection:$world) {Text("국내").tag("kr");Text("세계").tag("world");Text("우주").tag("space");Text("업적").tag("ach")}.pickerStyle(.segmented).onChange(of:world) {_,_ in region="전체";query=""}
            if world=="ach" {AchievementExperience()}
            else if !store.unlocked(world) {
                TourdyPanel {ContentUnavailableView(world=="world" ? "세계 여행 준비 중" : "우주 탐사 준비 중",systemImage:"lock.fill",description:Text(world=="world" ? "국내 여행을 마치면 세계 여행이 열려요." : "세계 여행을 마치면 우주 탐사가 열려요."))}
            } else {
                passport
                if let journey=store.state.journey,store.place(journey.to)?.world==world {journeyCard(journey)}
                if world != "space" {
                    TourdyPanel("여행 지도") {
                        NativeTravelMap(world:world).frame(height:mapExpanded ? 460 : 260)
                        Button(mapExpanded ? "지도 접기" : "지도 크게 보기") {withAnimation {mapExpanded.toggle()}}
                    }
                }
                departureBoard
                if world != "space" {specialRoutes}
                TourdyPanel(world=="kr" ? "지역 도장 · 스탬프북" : world=="world" ? "입국 도장" : "탐사 기록") {StampGrid(world:world)}
            }
        }.navigationTitle("여행").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$pendingHome) {NavigationStack {HomeCityPicker()}}
    }
    var passport: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Label(world=="kr" ? "KOREA TRAVEL" : world=="world" ? "TOURDY PASSPORT" : "SPACE EXPLORER",systemImage:world=="space" ? "sparkles" : store.prefs.passportEmblem).font(.caption.bold());Spacer();Image(systemName:"seal.fill").foregroundStyle(.yellow)}
            Text(store.place(store.state.positions[world] ?? "")?.name ?? "지구").font(.system(size:30,weight:.heavy))
            HStack {
                VStack(alignment:.leading) {Text(String(Int(store.balance))).font(.title2.bold()).monospacedDigit();Text("보유 마일리지").font(.caption)}
                Spacer()
                VStack(alignment:.leading) {Text("\(visited.filter {store.place($0)?.world==world}.count)").font(.title2.bold());Text(world=="space" ? "탐사한 곳" : "방문한 곳").font(.caption)}
            }
            if world=="kr" && !store.state.stamps.contains(where:{store.place($0.place)?.world=="kr"}) && store.state.journey==nil {Button("출발지 바꾸기") {pendingHome=true}.buttonStyle(.glass)}
        }.padding(22).foregroundStyle(.white).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[Color(hex:store.prefs.passportColor),Color(hex:"#0C2344")],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:22))
    }
    func journeyCard(_ journey: Journey) -> some View {
        TourdyPanel {
            if store.prefs.window {TravelWindow(kind:store.transport(journey.from,journey.to).0).frame(height:76)}
            NativeTicket(from:journey.from,to:journey.to,premium:journey.premium,free:false,cabin:journey.cabin ?? 0,status:"이동 중",date:Date())
            ProgressView(value:min(journey.cost,store.balance),total:max(1,journey.cost))
            Text("도착까지 \(duration(max(0,journey.cost-store.balance)*360)) 공부").font(.subheadline.weight(.semibold))
            if let goal=journey.goal {
                let remainingDays=max(1,Calendar.current.dateComponents([.day],from:Date(),to:goal).day ?? 1)
                Text("\(goal.formatted(date:.abbreviated,time:.omitted))까지 · 하루 \(Int(max(0,journey.cost-store.balance)*6/Double(remainingDays)))분 필요").font(.caption).foregroundStyle(.secondary)
            }
            Button("이동 취소",role:.destructive) {store.commit {$0.journey=nil};store.configure {$0.route=nil}}
        }
    }
    var departureBoard: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Label("출발 안내",systemImage:world=="kr" ? "tram.fill" : world=="world" ? "airplane" : "sparkles").font(.headline);Spacer();Text("가까운 순").font(.caption)}
            TextField(world=="kr" ? "시·군이나 도 이름으로 찾기" : "도시 또는 나라 이름",text:$query).padding(12).background(.white.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
            if world=="kr" {ScrollView(.horizontal,showsIndicators:false) {HStack {ForEach(regions,id:\.self) {name in Button(name) {region=name}.font(.caption.bold()).padding(.horizontal,12).padding(.vertical,8).background(region==name ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08),in:Capsule())}}}}
            LazyVStack(spacing:0) {
                ForEach(destinations) {place in
                    NavigationLink {NativeCheckIn(place:place)} label:{
                        HStack {
                            VStack(alignment:.leading,spacing:5) {
                                Text(place.name).font(.headline)
                                HStack(spacing:5) {Text(store.transport(store.state.positions[world] ?? "",place.id).1).font(.system(size:9,weight:.bold)).padding(.horizontal,5).padding(.vertical,3).foregroundStyle(.black).background(.yellow,in:RoundedRectangle(cornerRadius:4));Text(place.region).font(.caption).lineLimit(1)}
                            }
                            Spacer()
                            Text("\(Int(store.cost(place,premium:false)))").font(.subheadline.monospacedDigit()).foregroundStyle(.cyan)
                            Text(store.balance>=store.cost(place,premium:false) ? "바로 출발" : duration((store.cost(place,premium:false)-store.balance)*360)).font(.caption.bold()).foregroundStyle(.yellow).frame(minWidth:72,alignment:.trailing)
                        }.padding(.vertical,13).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(store.state.journey != nil || !store.zoneOpen(place))
                    Divider().overlay(Color.cyan.opacity(0.15))
                }
            }
            if destinations.isEmpty {Text("남은 목적지가 없거나 검색 결과가 없어요.").font(.subheadline).padding(.vertical)}
        }.padding(18).foregroundStyle(Color(hex:"#93D9FF"))
            .background(Color(hex:"#0C2B56"),in:RoundedRectangle(cornerRadius:22))
    }
    var specialRoutes: some View {
        TourdyPanel("특별 루트") {
            Text("정해진 출발지에서만 · 모든 구간 최상급 금색 표").font(.caption).foregroundStyle(.secondary)
            ForEach(store.routes.filter {$0.world==world}) {route in
                VStack(alignment:.leading,spacing:10) {
                    Label(route.name,systemImage:route.icon).font(.headline).foregroundStyle(store.accent)
                    Text(route.desc).font(.caption).foregroundStyle(.secondary)
                    Text(route.stops.map {store.place($0)?.name ?? $0}.joined(separator:" › ")).font(.caption).lineSpacing(5)
                    if let date=store.prefs.completedRoutes[route.id] {Label("완주 · \(date.formatted(date:.abbreviated,time:.omitted))",systemImage:"checkmark.seal.fill").foregroundStyle(.green)}
                    else if store.prefs.route?.id==route.id {Text("진행 중 · \(store.prefs.route?.leg ?? 0)/\(route.stops.count-1)");Button("루트 그만두기",role:.destructive) {store.configure {$0.route=nil};store.commit {$0.journey=nil}}}
                    else if !store.routeOpen(route) {Text("\((route.season ?? []).map(String.init).joined(separator:", "))월에 열려요").font(.caption).foregroundStyle(.secondary)}
                    else if store.state.positions[world]==route.stops.first {Button("출발") {store.startRoute(route)}.buttonStyle(.glassProminent).disabled(store.state.journey != nil || store.prefs.route != nil)}
                    else {Text("\(store.place(route.stops[0])?.name ?? "출발지")에서만 출발").font(.caption).foregroundStyle(.secondary)}
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(store.accent.opacity(0.06),in:RoundedRectangle(cornerRadius:16))
            }
        }
    }
}

struct NativeTravelMap: View {
    @EnvironmentObject var store: NativeStore
    let world: String
    var body: some View {
        Canvas {context,size in
            guard let atlas=TourdyAtlas.bundled else {return}
            let layer=world=="kr" ? atlas.kr : atlas.world,b=layer.bounds
            let scale=min(size.width/CGFloat(b[2]),size.height/CGFloat(b[3]))
            let dx=(size.width-CGFloat(b[2])*scale)/2,dy=(size.height-CGFloat(b[3])*scale)/2
            func point(_ p: [Double]) -> CGPoint {CGPoint(x:CGFloat(p[0]-b[0])*scale+dx,y:CGFloat(p[1]-b[1])*scale+dy)}
            let visited=Set(store.state.stamps.map(\.place))
            for region in layer.regions {
                var path=Path()
                for polygon in region.polygons {
                    guard let first=polygon.first else {continue}
                    path.move(to:point(first));for p in polygon.dropFirst() {path.addLine(to:point(p))};path.closeSubpath()
                }
                context.fill(path,with:.color(visited.contains(region.id) ? store.accent.opacity(0.6) : Color.secondary.opacity(0.16)))
                context.stroke(path,with:.color(Color.secondary.opacity(0.3)),lineWidth:0.4)
            }
            var previous: CGPoint?
            for stamp in store.state.stamps where store.place(stamp.place)?.world==world {
                guard let a=atlas.dots[stamp.from],let c=atlas.dots[stamp.place] else {continue}
                let from=point(a),to=point(c)
                if abs(to.x-from.x)<size.width*0.55 {var line=Path();line.move(to:from);line.addLine(to:to);context.stroke(line,with:.color(store.accent.opacity(0.45)),lineWidth:1.2)}
                context.fill(Path(ellipseIn:CGRect(x:to.x-2,y:to.y-2,width:4,height:4)),with:.color(store.accent));previous=to
            }
            if let current=store.state.positions[world],let coordinates=atlas.dots[current] {
                let p=point(coordinates);context.fill(Path(ellipseIn:CGRect(x:p.x-5,y:p.y-5,width:10,height:10)),with:.color(.orange))
            } else if let p=previous {context.fill(Path(ellipseIn:CGRect(x:p.x-4,y:p.y-4,width:8,height:8)),with:.color(.orange))}
        }.background(Color.cyan.opacity(0.04),in:RoundedRectangle(cornerRadius:16))
            .accessibilityLabel(world=="kr" ? "국내 여행 지도. 시군별 방문 지역과 여행 경로" : "세계 여행 지도. 입국한 나라와 여행 경로")
    }
}
struct NativeTicket: View {
    @EnvironmentObject var store: NativeStore
    let from: String
    let to: String
    let premium: Bool
    let free: Bool
    let cabin: Int
    let status: String
    let date: Date
    var gold: Bool {premium || free}
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Label(gold ? "GOLD TICKET" : "TOURDY TICKET",systemImage:store.transport(from,to).0).font(.caption.bold());Spacer();Text(date.formatted(date:.numeric,time:.omitted)).font(.caption2.monospacedDigit())}
            HStack {
                VStack(alignment:.leading,spacing:4) {Text("출발").font(.caption);Text(store.place(from)?.name ?? "지구").font(.system(size:26,weight:.heavy)).minimumScaleFactor(0.6)}
                Spacer();Image(systemName:"arrow.right").font(.title3);Spacer()
                VStack(alignment:.trailing,spacing:4) {Text("도착").font(.caption);Text(store.place(to)?.name ?? to).font(.system(size:26,weight:.heavy)).minimumScaleFactor(0.6)}
            }.lineLimit(1)
            Rectangle().fill(Color.black.opacity(0.16)).frame(height:1)
            HStack {ticketInfo("교통",store.transport(from,to).1);Spacer();ticketInfo("좌석",store.seatNames(from:from,to:to)[min(max(0,cabin),store.seatNames(from:from,to:to).count-1)]);Spacer();ticketInfo("상태",status)}
            if free {Text("첫 여행 선물 · 0 마일 · 즉시 도착").font(.caption.bold())}
            barcode.frame(height:24)
        }.padding(18).foregroundStyle(Color(hex:gold ? "#593E0A" : "#102C52"))
            .background(LinearGradient(colors:gold ? [Color(hex:"#FFF3BD"),Color(hex:"#E6BB52"),Color(hex:"#FFF0B0")] : [Color(hex:"#E6F2FF"),Color(hex:"#C1DBFF")],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(Color.black.opacity(0.08),lineWidth:1))
    }
    func ticketInfo(_ title: String,_ value: String) -> some View {VStack(alignment:.leading,spacing:4) {Text(title).font(.caption2);Text(value).font(.caption.bold())}}
    var barcode: some View {GeometryReader {geometry in HStack(spacing:2) {ForEach(0..<62) {i in Rectangle().fill(Color.black.opacity(0.7)).frame(width:i%3==0 ? 3 : 1)}}.frame(width:geometry.size.width,alignment:.leading).clipped()}}
}
struct NativeCheckIn: View {
    @EnvironmentObject var store: NativeStore
    @State private var cabin = 0
    @State private var useGoal = false
    @State private var goal = Calendar.current.date(byAdding:.day,value:7,to:Date()) ?? Date()
    @Environment(\.dismiss) var dismiss
    let place: Place
    var body: some View {
        TourdyPage {
            TourdyPanel("승차 수속") {
                NativeTicket(from:store.state.positions[place.world] ?? "earth",to:place.id,premium:cabin>0,free:false,cabin:cabin,status:"탑승 준비",date:Date())
                if place.world != "space" {
                    let seats=store.seatNames(from:store.state.positions[place.world] ?? "",to:place.id)
                    Picker("좌석 등급",selection:$cabin) {ForEach(Array(seats.enumerated()),id:\.offset) {index,title in Text(title).tag(index)}}.pickerStyle(.segmented)
                }
                LabeledContent("필요 마일리지",value:"\(Int(store.fare(place,cabin:cabin)))")
                LabeledContent("보유 마일리지",value:"\(Int(store.balance))")
                Toggle("목표 도착일",isOn:$useGoal)
                if useGoal {DatePicker("도착 목표",selection:$goal,in:Date()...,displayedComponents:.date)}
                Text(store.balance>=store.fare(place,cabin:cabin) ? "보유 마일리지로 바로 도착할 수 있어요." : "공부한 만큼 이동해요. 도착하면 마일리지가 차감되고 도장을 받아요.").font(.subheadline).foregroundStyle(.secondary)
                Button("승차 수속하고 출발하기") {store.checkIn(place,cabin:cabin,goal:useGoal ? goal : nil);if store.state.journey != nil || store.state.positions[place.world]==place.id {dismiss()}}.buttonStyle(.glassProminent).disabled(store.state.journey != nil || !store.zoneOpen(place))
            }
        }.navigationTitle(place.name).navigationBarTitleDisplayMode(.inline)
    }
}
struct HomeCityPicker: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    var body: some View {
        List(store.places.filter {$0.world=="kr" && $0.secret != true && (search.isEmpty || ($0.name+$0.region).contains(search))}) {place in
            Button(place.name+" · "+place.region) {
                guard !store.state.stamps.contains(where:{store.place($0.place)?.world=="kr"}),store.state.journey==nil else {return}
                if store.commit({$0.home=place.id;$0.positions["kr"]=place.id}) {dismiss()}
            }
        }.searchable(text:$search).navigationTitle("출발지 고르기")
    }
}
struct StampGrid: View {
    @EnvironmentObject var store: NativeStore
    let world: String
    func group(_ p: Place) -> String {
        if world=="world" {return ["아시아","중동","유럽","아프리카","북중미","남미","오세아니아"][min(6,max(0,p.zone))]}
        if world=="space" {return ["태양계","가까운 별","성운·성단","은하"][min(3,max(0,p.zone))]}
        return p.region
    }
    var groups: [String] {Array(Set(store.places.filter {$0.world==world && store.zoneOpen($0)}.map {group($0)})).sorted()}
    var body: some View {
        ForEach(groups,id:\.self) {region in
            DisclosureGroup(region) {
                if store.prefs.stampStyle=="pass" {
                    ForEach(store.state.stamps.reversed().filter {stamp in store.place(stamp.place).map {$0.world==world && group($0)==region} ?? false}) {stamp in
                        NavigationLink {ArrivalExperience(stamp:stamp)} label:{NativeTicket(from:stamp.from,to:stamp.place,premium:stamp.premium,free:stamp.free,cabin:stamp.cabin ?? 0,status:"도착 완료",date:stamp.date)}.buttonStyle(.plain)
                    }
                } else {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:76))],spacing:14) {
                    ForEach(store.places.filter {$0.world==world && group($0)==region && store.zoneOpen($0)}) {place in
                        let stamp=store.state.stamps.last {$0.place==place.id}
                        if let stamp {NavigationLink {ArrivalExperience(stamp:stamp)} label:{stampCell(place,stamp:stamp)}}
                        else {stampCell(place,stamp:nil)}
                    }
                }.padding(.vertical,12)
                }
            }
        }
    }
    func stampCell(_ place: Place,stamp: Stamp?) -> some View {
        Group {
        if store.prefs.stampStyle=="card" {
            VStack(spacing:8) {
                Image(systemName:stamp==nil ? "lock" : place.world=="kr" ? "tram.fill" : "globe.asia.australia.fill").font(.title2)
                Text(place.name).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7)
                if let stamp {Text(stamp.date.formatted(date:.numeric,time:.omitted)).font(.system(size:8))}
            }.frame(width:76,height:110).foregroundStyle(stamp==nil ? Color.secondary : Color.white)
                .background(stamp==nil ? Color.secondary.opacity(0.08) : store.accent,in:RoundedRectangle(cornerRadius:12))
        } else {
        VStack(spacing:3) {
            Text(place.name).font(.system(size:12,weight:.bold)).lineLimit(1).minimumScaleFactor(0.7)
            if let stamp {Text(stamp.date.formatted(.dateTime.year(.twoDigits).month(.twoDigits).day(.twoDigits))).font(.system(size:8,design:.monospaced));if stamp.premium {Image(systemName:"star.fill").font(.system(size:8))}}
        }.frame(width:72,height:72).foregroundStyle(stamp==nil ? Color.secondary.opacity(0.5) : stamp?.premium==true ? Color.orange : store.accent)
            .background(stamp==nil ? Color.clear : store.accent.opacity(0.04),in:Circle())
            .overlay(Circle().strokeBorder(stamp==nil ? Color.secondary.opacity(0.2) : stamp?.premium==true ? Color.orange : store.accent,style:StrokeStyle(lineWidth:stamp==nil ? 1 : 2,dash:stamp==nil ? [3,3] : [])))
            .overlay(Circle().inset(by:5).stroke(stamp==nil ? Color.clear : store.accent.opacity(0.5),lineWidth:0.7))
            .rotationEffect(.degrees(stamp==nil ? 0 : -8))
        }
        }
    }
}
struct ArrivalExperience: View {
    @EnvironmentObject var store: NativeStore
    @Environment(\.dismiss) var dismiss
    @State private var visible = false
    @State private var postcard = ""
    let stamp: Stamp
    var body: some View {
        TourdyPage {
            NativeTicket(from:stamp.from,to:stamp.place,premium:stamp.premium,free:stamp.free,cabin:stamp.cabin ?? 0,status:"도착 완료",date:stamp.date)
            TourdyPanel {
                Image(systemName:"seal.fill").font(.system(size:54)).foregroundStyle(store.accent).frame(maxWidth:.infinity).scaleEffect(visible ? 1 : 1.4).opacity(visible ? 1 : 0)
                Text("\(store.place(stamp.place)?.name ?? "목적지") 도착!").font(.title.bold()).frame(maxWidth:.infinity)
                if stamp.free {Text("공부 30분이 데려다준 첫 도시").font(.headline);Text("최고급 티켓 · 마일리지 차감 없음").font(.caption).foregroundStyle(.secondary)}
                Text(stamp.date.formatted(date:.long,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                if let route=stamp.route,let name=store.routes.first(where:{$0.id==route})?.name {Label(name,systemImage:"point.topleft.down.to.point.bottomright.curvepath")}
            }
            TourdyPanel("이 도시에서 남길 한마디") {
                TextField("엽서 뒷면 · 80자까지",text:$postcard,axis:.vertical).lineLimit(3...5)
                Button("엽서 저장") {let text=String(postcard.prefix(80));store.configure {$0.postcards[stamp.place]=text}}
            }
            if stamp.free,store.state.positions["kr"]==stamp.place {
                TourdyPanel("다음에는 어디로 갈까요?") {
                    let visited=Set(store.state.stamps.map(\.place))
                    let next=Array(store.places.filter {$0.world=="kr" && $0.id != stamp.place && !visited.contains($0.id)}.sorted {store.cost($0,premium:false)<store.cost($1,premium:false)}.prefix(3))
                    ForEach(next) {place in NavigationLink {NativeCheckIn(place:place)} label:{HStack {Text(place.name);Spacer();Text("\(Int(store.cost(place,premium:false))) 마일").font(.caption)}}}
                }
            }
        }.navigationTitle("도착 기념").navigationBarTitleDisplayMode(.inline).toolbar {Button("확인") {dismiss()}}
            .onAppear {postcard=store.prefs.postcards[stamp.place] ?? "";withAnimation(.spring(duration:0.5)) {visible=true}}
    }
}
struct TravelWindow: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let kind: String
    var body: some View {
        TimelineView(.animation(minimumInterval:0.06,paused:reduceMotion)) {timeline in
            Canvas {context,size in
                let t=reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:30)/30
                for layer in 0..<3 {
                    var path=Path();path.move(to:CGPoint(x:0,y:size.height))
                    for x in stride(from:0.0,through:Double(size.width),by:4) {let y=Double(size.height)*(0.4+Double(layer)*0.14)+sin(x/55+t*Double(layer+1)*20)*Double(10-layer*2);path.addLine(to:CGPoint(x:x,y:y))}
                    path.addLine(to:CGPoint(x:size.width,y:size.height));path.closeSubpath()
                    context.fill(path,with:.color(Color(hex:kind=="ferry.fill" ? "#147DB2" : "#447E69").opacity(0.25+Double(layer)*0.2)))
                }
            }
        }.background(LinearGradient(colors:[Color(hex:"#79B8EB"),Color(hex:"#DCF1FF")],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(Color(hex:"#2B3442"),lineWidth:6))
    }
}
struct AchievementExperience: View {
    @EnvironmentObject var store: NativeStore
    var body: some View {
        TourdyPanel("여행 업적") {
            achievement("첫 여행",icon:"ticket.fill",done:!store.state.stamps.isEmpty)
            achievement("국내 완주",icon:"tram.fill",done:store.unlocked("world"))
            achievement("세계 완주",icon:"globe",done:store.unlocked("space"))
            achievement("누적 공부 10시간",icon:"clock.fill",done:store.completedSeconds>=36000)
            achievement("누적 공부 100시간",icon:"star.fill",done:store.completedSeconds>=360000)
            ForEach(store.routes) {route in achievement(route.name,icon:route.icon,done:store.prefs.completedRoutes[route.id] != nil)}
        }
    }
    func achievement(_ name: String,icon: String,done: Bool) -> some View {HStack {Image(systemName:icon).font(.title2).frame(width:40).foregroundStyle(done ? store.accent : .secondary);Text(name);Spacer();Image(systemName:done ? "checkmark.seal.fill" : "lock.fill").foregroundStyle(done ? Color.green : Color.secondary)}.padding(.vertical,6)}
}
