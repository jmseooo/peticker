import SwiftUI
import StoreKit
import MessageUI
import UserNotifications

// 설정 화면 — 메인 뷰 우하단 설정 아이콘을 누르면 뜬다.
struct SettingsView: View {
    let onClose: () -> Void

    // TODO: 실제 문의용 이메일로 교체
    private let supportEmail = "jinminseo1001@gmail.com"

    @AppStorage(SharedStore.showBatteryPercentKey, store: UserDefaults(suiteName: SharedStore.appGroupID))
    private var showBatteryPercent = false
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
                    toggleRow(
                        title: "Battery",
                        subtitle: "Show your battery level on the home widget.",
                        isOn: $showBatteryPercent
                    )
                    rowDivider
                    toggleRow(
                        title: "Push Notifications",
                        subtitle: "Receive notifications about app updates and announcements.",
                        isOn: $pushNotificationsEnabled
                    )
                        .onChange(of: pushNotificationsEnabled) { _, enabled in
                            guard enabled else { return }
                            Task {
                                // 시스템에서 거부하면 토글을 다시 끔 — 켜진 채로 남아 실제 권한과 어긋나지 않도록.
                                pushNotificationsEnabled = await NotificationPermission.request()
                            }
                        }
                        .onAppear {
                            // 설정 화면을 다시 열 때마다 실제 시스템 권한과 토글을 맞춘다
                            // (사용자가 iOS 설정 앱에서 권한을 껐다 켰다 할 수 있으므로).
                            guard pushNotificationsEnabled else { return }
                            Task {
                                pushNotificationsEnabled = await NotificationPermission.currentStatusIsAuthorized()
                            }
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

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "979797"))
            }
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
    /// 권한을 요청하고, 사용자가 실제로 허용했는지를 반환한다.
    /// 거부해도 요청 자체는 에러 없이 끝나므로, 반환값으로 토글 상태를 결정해야 한다.
    static func request() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// 현재 시스템 알림 권한이 허용 상태인지 확인 (사용자가 iOS 설정에서 나중에 끈 경우 대비).
    static func currentStatusIsAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}

// MARK: - 메일 작성 시트

private struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject("Stickie Feedback")
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
        ("2. Remove the background", "Stickie automatically cuts your pet out of the photo."),
        ("3. Customize", "Choose an outline color and background, then pinch, drag, or rotate to place it."),
        ("4. Add to your Home Screen", "Tap DONE, then add the Stickie widget from your Home Screen or Lock Screen.")
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
