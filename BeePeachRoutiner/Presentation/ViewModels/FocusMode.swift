// MARK: - FocusMode

/// Focus 화면의 시간 입력/표시 모드. 세션 상태와 무관한 순수 뷰 토글 —
/// 어느 모드든 같은 세션을 라이브로 반영한다 (다이얼 링 감소 + 휠 tick down).
/// rawValue 가 UISegmentedControl 인덱스와 1:1 대응한다.
enum FocusMode: Int, Equatable {
    case dial = 0     // "Visual Dial"
    case digital = 1  // "Digital"
}
