import SwiftUI
import StoreKit
import MessageUI
import UserNotifications

// 설정 화면 — 메인 뷰 우하단 설정 아이콘을 누르면 뜬다.
struct SettingsView: View {
    let onClose: () -> Void

    // TODO: 실제 문의용 이메일로 교체
    private let supportEmail = "hello@peticker.app"

    @AppStorage(SharedStore.showBatteryPercentKey, store: UserDefaults(suiteName: SharedStore.appGroupID))
    private var showBatteryPercent = true
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @State private var showHowToUse = false
    @State private var showMailComposer = false
    @State private var showMailUnavailableAlert = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack(alignment: .top) {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, ScreenSafeArea.insets.top + 22)
                    .padding(.bottom, 28)

                VStack(spacing: 0) {
                    toggleRow(title: "Battery", isOn: $showBatteryPercent)
                    rowDivider
                    toggleRow(title: "Push Notifications", isOn: $pushNotificationsEnabled)
                        .onChange(of: pushNotificationsEnabled) { _, enabled in
                            if enabled { NotificationPermission.request() }
                        }
                    rowDivider
                    actionRow(title: "How to use") { showHowToUse = true }
                    rowDivider
                    actionRow(title: "Rate app") { requestReview() }
                    rowDivider
                    actionRow(title: "Contact e-mail") { contactSupport() }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showHowToUse) { HowToUseView() }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(recipient: supportEmail)
        }
        .alert("Mail Not Set Up", isPresented: $showMailUnavailableAlert) {
            Button("OK") {}
        } message: {
            Text("Please set up Mail on this device, or reach us at \(supportEmail).")
        }
    }

    // MARK: - 상단 바 — 제작 화면과 같은 구성(뒤로가기 + 라임 타이틀 필)

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Image("BackButton")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 29, height: 29)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)

            Spacer()

            Text("SETTINGS")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 29)
                .background(Color.brandLime)

            Spacer()

            Color.clear.frame(width: 29, height: 29).padding(.trailing, 24)
        }
    }

    // MARK: - 행

    private var rowDivider: some View {
        Divider().background(Color.black.opacity(0.08))
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
        }
        .tint(.brandLime)
        .padding(.vertical, 16)
    }

    private func actionRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.3))
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func contactSupport() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else if let url = URL(string: "mailto:\(supportEmail)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailUnavailableAlert = true
        }
    }
}

// MARK: - 알림 권한

enum NotificationPermission {
    static func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}

// MARK: - 메일 작성 시트

private struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject("Peticker Feedback")
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // UIKit이 항상 메인 스레드에서 이 콜백을 호출하므로 안전하다.
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
            }
        }
    }
}

// MARK: - 사용법 안내 시트

private struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(title: String, body: String)] = [
        ("1. Add a photo", "Tap the empty circle on the main screen and pick your pet's photo."),
        ("2. Remove the background", "Peticker automatically cuts your pet out of the photo."),
        ("3. Customize", "Choose an outline color and background, then pinch, drag, or rotate to place it."),
        ("4. Add to your Home Screen", "Tap DONE, then add the Peticker widget from your Home Screen or Lock Screen.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("HOW TO USE")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 29)
                    .background(Color.brandLime)
                Spacer()
            }
            .padding(.top, 22)
            .overlay(alignment: .trailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                }
                .padding(.trailing, 24)
                .padding(.top, 22)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(steps, id: \.title) { step in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.title)
                                .font(.system(size: 15, weight: .bold))
                            Text(step.body)
                                .font(.system(size: 14))
                                .foregroundStyle(.black.opacity(0.7))
                        }
                    }

                    Image("HowToUseWidgetPreview")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
        .background(Color.bgBase.ignoresSafeArea())
    }
}

#Preview("Settings") {
    SettingsView {}
}

#Preview("How to use") {
    HowToUseView()
}
