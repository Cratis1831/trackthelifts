//
//  AppDialog.swift
//  TrackTheLifts
//

import SwiftUI

enum AppDialogConfirmStyle {
    case primary
    case destructive
}

/// Centered card used for confirms, prompts, notices, and short choice lists.
/// Matches the Clear Meal overlay: dimmed canvas, elevated card, stacked full-width buttons.
struct AppDialogCard<Extra: View, Actions: View>: View {
    let title: String
    let message: String?
    let onDismiss: () -> Void
    @ViewBuilder var extra: () -> Extra
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appTextPrimary)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                extra()

                VStack(spacing: 10) {
                    actions()
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(Color.appElevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 1)
            }
        }
        .accessibilityAddTraits(.isModal)
        .zIndex(1000)
    }
}

struct AppConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    var confirmStyle: AppDialogConfirmStyle = .destructive
    var confirmEnabled: Bool = true
    var cancelTitle: String = "Cancel"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        AppDialogCard(title: title, message: message, onDismiss: onCancel) {
            EmptyView()
        } actions: {
            if confirmStyle == .destructive {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(AppDestructiveButtonStyle())
                    .disabled(!confirmEnabled)
                    .opacity(confirmEnabled ? 1 : 0.45)
            } else {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!confirmEnabled)
                    .opacity(confirmEnabled ? 1 : 0.45)
            }

            Button(cancelTitle, action: onCancel)
                .buttonStyle(AppSecondaryButtonStyle())
        }
    }
}

struct AppNoticeDialog: View {
    let title: String
    let message: String
    var buttonTitle: String = "OK"
    let onDismiss: () -> Void

    var body: some View {
        AppDialogCard(title: title, message: message, onDismiss: onDismiss) {
            EmptyView()
        } actions: {
            Button(buttonTitle, action: onDismiss)
                .buttonStyle(AppPrimaryButtonStyle())
        }
    }
}

struct AppPromptDialog: View {
    let title: String
    let message: String
    @Binding var text: String
    var placeholder: String = "Name"
    var confirmTitle: String = "Save"
    var cancelTitle: String = "Cancel"
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFieldFocused: Bool

    private var canConfirm: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        AppDialogCard(title: title, message: message, onDismiss: onCancel) {
            TextField(placeholder, text: $text)
                .foregroundColor(.appTextPrimary)
                .focused($isFieldFocused)
                .appInputSurface()
                .onAppear { isFieldFocused = true }
        } actions: {
            Button(confirmTitle, action: onConfirm)
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canConfirm)
                .opacity(canConfirm ? 1 : 0.45)

            Button(cancelTitle, action: onCancel)
                .buttonStyle(AppSecondaryButtonStyle())
        }
    }
}

struct AppChoiceDialog<Option: Hashable>: View {
    let title: String
    var message: String?
    let options: [Option]
    let titleForOption: (Option) -> String
    let onSelect: (Option) -> Void
    let onCancel: () -> Void

    var body: some View {
        AppDialogCard(title: title, message: message, onDismiss: onCancel) {
            EmptyView()
        } actions: {
            ForEach(options, id: \.self) { option in
                Button(titleForOption(option)) {
                    onSelect(option)
                }
                .buttonStyle(AppSecondaryButtonStyle())
            }

            Button("Cancel", action: onCancel)
                .buttonStyle(AppSecondaryButtonStyle())
        }
    }
}

extension View {
    func appConfirm(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        confirmTitle: String,
        confirmStyle: AppDialogConfirmStyle = .destructive,
        confirmEnabled: Bool = true,
        cancelTitle: String = "Cancel",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                AppConfirmDialog(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    confirmStyle: confirmStyle,
                    confirmEnabled: confirmEnabled,
                    cancelTitle: cancelTitle,
                    onConfirm: {
                        onConfirm()
                        isPresented.wrappedValue = false
                    },
                    onCancel: {
                        onCancel?()
                        isPresented.wrappedValue = false
                    }
                )
            }
        }
    }

    func appConfirm<Item>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: @escaping (Item) -> String,
        confirmTitle: String,
        confirmStyle: AppDialogConfirmStyle = .destructive,
        cancelTitle: String = "Cancel",
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        overlay {
            if let value = item.wrappedValue {
                AppConfirmDialog(
                    title: title(value),
                    message: message(value),
                    confirmTitle: confirmTitle,
                    confirmStyle: confirmStyle,
                    cancelTitle: cancelTitle,
                    onConfirm: {
                        onConfirm(value)
                        item.wrappedValue = nil
                    },
                    onCancel: {
                        item.wrappedValue = nil
                    }
                )
            }
        }
    }

    func appNotice(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        buttonTitle: String = "OK",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                AppNoticeDialog(title: title, message: message, buttonTitle: buttonTitle) {
                    onDismiss?()
                    isPresented.wrappedValue = false
                }
            }
        }
    }

    func appNotice(
        _ title: String,
        message: Binding<String?>,
        buttonTitle: String = "OK"
    ) -> some View {
        overlay {
            if let text = message.wrappedValue {
                AppNoticeDialog(title: title, message: text, buttonTitle: buttonTitle) {
                    message.wrappedValue = nil
                }
            }
        }
    }

    func appPrompt(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        text: Binding<String>,
        placeholder: String,
        confirmTitle: String = "Save",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                AppPromptDialog(
                    title: title,
                    message: message,
                    text: text,
                    placeholder: placeholder,
                    confirmTitle: confirmTitle,
                    onConfirm: {
                        onConfirm()
                        isPresented.wrappedValue = false
                    },
                    onCancel: {
                        onCancel?()
                        isPresented.wrappedValue = false
                    }
                )
            }
        }
    }

    func appPrompt<Item>(
        _ title: String,
        item: Binding<Item?>,
        message: String,
        text: Binding<String>,
        placeholder: String,
        confirmTitle: String = "Save",
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        overlay {
            if let value = item.wrappedValue {
                AppPromptDialog(
                    title: title,
                    message: message,
                    text: text,
                    placeholder: placeholder,
                    confirmTitle: confirmTitle,
                    onConfirm: {
                        onConfirm(value)
                        item.wrappedValue = nil
                    },
                    onCancel: {
                        item.wrappedValue = nil
                    }
                )
            }
        }
    }
}
