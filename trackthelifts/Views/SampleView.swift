//
//  SampleView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-07.
//

import SwiftUI
struct SampleView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Title Section
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(Color.blue)
                        .padding(.bottom, 12)

                    Text("Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Sign in to continue your fitness journey")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.56))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)

                // MARK: - Form Section
                VStack(spacing: 20) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundColor(Color(white: 0.56))

                            TextField("Enter your email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(white: 0.11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(white: 0.17), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundColor(Color(white: 0.56))

                            Group {
                                if isPasswordVisible {
                                    TextField("Enter your password", text: $password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                }
                            }
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .font(.system(size: 16))

                            Spacer()

                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(Color(white: 0.56))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(white: 0.11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(white: 0.17), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }

                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            print("Forgot password tapped")
                        }) {
                            Text("Forgot Password?")
                                .foregroundColor(Color.blue)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }

                    // Login Button
                    Button(action: {
                        isLoading = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLoading = false
                            print("Logged in with email: \(email)")
                        }
                    }) {
                        Text(isLoading ? "Signing In..." : "Sign In")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .cornerRadius(12)
                            .opacity(isLoading ? 0.6 : 1.0)
                    }
                    .disabled(isLoading)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(white: 0.17))
                            .frame(height: 1)
                        Text("or continue with")
                            .foregroundColor(Color(white: 0.56))
                            .font(.system(size: 14))
                        Rectangle()
                            .fill(Color(white: 0.17))
                            .frame(height: 1)
                    }

                    // Social Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            print("Google login tapped")
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.white)
                                Text("Google")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(white: 0.17), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }

                        Button(action: {
                            print("Facebook login tapped")
                        }) {
                            HStack {
                                Image(systemName: "f.circle")
                                    .foregroundColor(.white)
                                Text("Facebook")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(white: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(white: 0.17), lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                    }

                    // Sign Up
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(Color(white: 0.56))
                        Button(action: {
                            print("Sign Up tapped")
                        }) {
                            Text("Sign Up")
                                .foregroundColor(Color.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}


#Preview {
    SampleView()
}
