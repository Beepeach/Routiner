# BeePeach Routiner

집중 타이머 iOS 앱. UIKit + Clean Architecture 단일 타깃 프로젝트.

## 환경
- Swift 6 언어 모드, MainActor 기본 격리
- iOS 26.2 이상

## 구조
- `App/`: AppCoordinator, DIContainer (의존성 조립은 여기서만)
- `Presentation/`: 탭별 화면 (Timer, Activity, Settings, Common)
- `Domain/`: Entity, UseCase, RepositoryInterface, Error
- `Data/`: Repository 구현, Storage
- Coordinator는 DIContainer를 받지 않고, 조립된 ViewModel만 주입받는다

## 빌드·테스트
```bash
xcodebuild test -project BeePeachRoutiner.xcodeproj -scheme BeePeachRoutiner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
```

## 브랜치·PR
- 브랜치: `feature/<이슈번호>-<kebab-case>` (예: `feature/17-timer-coordinator-di`)
- PR 본문: 개요 / 주요 변경 / 설계 결정 / 검증, 마지막 줄에 `Closes #이슈번호`

`AGENTS.md`는 이 파일의 링크입니다. 규칙은 `CLAUDE.md`만 수정하세요.
