const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const out=path.resolve(process.argv[2]||path.join(root,'.preview/TOURDY-original-iOS'));
fs.mkdirSync(out,{recursive:true});
for(const name of ['index.html','css','js','native','scripts','capacitor.config.json','package.json','pnpm-lock.yaml','pnpm-workspace.yaml','icon-192.png','icon-512.png','icon-maskable-512.png','apple-touch-icon.png','favicon-64.png','manifest.webmanifest'])fs.cpSync(path.join(root,name),path.join(out,name),{recursive:true});
fs.cpSync(path.join(root,'capacitor'),path.join(out,'capacitor'),{recursive:true,filter:p=>!['DerivedData','xcuserdata','build','.DS_Store'].includes(path.basename(p))});
fs.writeFileSync(path.join(out,'먼저 읽어주세요.txt'),`TOURDY — 기존 화면을 유지한 iOS 앱

1. Mac에서 capacitor/ios/App/App.xcodeproj 를 여세요.
2. 위쪽 실행 대상에서 App과 본인의 아이폰을 선택하세요.
3. Signing & Capabilities에서 본인의 Team을 선택하세요.
4. 재생 버튼으로 빌드하고 설치하세요.

이 ZIP에는 원본 화면, 앱 내부 파일 저장, 로컬 알림 연결과 필요한 플러그인 소스가 포함되어 있어요.
첫 Xcode 빌드 때는 Swift 패키지를 받으므로 인터넷이 필요해요.
설치된 앱은 웹 서버 없이 실행돼요.

기존 앱을 삭제하기 전 반드시 기록을 JSON 백업으로 내보내세요.
Safari나 이전 앱의 저장 공간은 새 앱과 자동 공유되지 않아요.
새 앱의 설정에서 백업 파일을 복원하세요. 앱 삭제는 내부 기록을 지울 수 있어요.

타이머 종료 알림은 설정에서 기기 알림을 켜고 권한을 허용해야 해요.
백그라운드에서 멈춘 시간과 여행 도착은 앱을 다시 열 때 계산해요.
기기 간 동기화, 위젯, 라이브 액티비티는 아직 포함되지 않아요.

소스를 수정했다면 저장소 루트에서 다음 준비 작업 후 다시 빌드하세요.
pnpm install --frozen-lockfile
pnpm ios:prepare

이 패키지는 과거의 별도 SwiftUI 실험판이 아니에요.
실제 아이폰의 비행기 모드·재실행·백업 복원·알림 검증은 출시 전에 필요해요.
`);
console.log(out);
