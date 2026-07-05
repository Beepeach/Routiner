import UIKit
import SnapKit

// MARK: - SettingsViewController

/// Settings 탭 placeholder 화면.
///
/// 앱 이름과 버전만 표시한다. 실제 설정 항목이 생기면 이 화면을 확장한다.
final class SettingsViewController: UIViewController {

    // MARK: - UI

    // 테스트에서 표시 값을 직접 검증할 수 있도록 internal 로 둔다.
    let appNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    let versionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureAppInfo()
    }

    // MARK: - Configuration

    private func configureUI() {
        title = "Settings"
        view.backgroundColor = .systemBackground

        view.addSubview(appNameLabel)
        view.addSubview(versionLabel)

        appNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-16)
        }
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appNameLabel.snp.bottom).offset(8)
        }
    }

    private func configureAppInfo() {
        let info = Bundle.main.infoDictionary
        let appName = info?["CFBundleName"] as? String ?? "BeePeach Routiner"
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"

        appNameLabel.text = appName
        versionLabel.text = "v\(version)"
    }
}
