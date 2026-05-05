package email

import (
	"bytes"
	"embed"
	"fmt"
	"html/template"
	"os"
	"strings"
)

// Embedded HTML templates. Rendering is done with html/template so user
// data is auto-escaped, which is critical for DisplayName since it comes
// directly from learner-supplied input.
//
//go:embed templates/*.html
var templateFS embed.FS

// templates is parsed once at init so render calls are cheap.
var templates = template.Must(
	template.New("email").ParseFS(templateFS, "templates/*.html"),
)

// ── Verify email ─────────────────────────────────────────────────────────

// VerifyEmailData carries the per-learner values the verify_email
// template substitutes into the rendered HTML.
type VerifyEmailData struct {
	DisplayName string
	VerifyURL   string
	ExpiresHrs  int
}

// RenderVerifyEmail returns (htmlBody, subject, err). Subject is hard-
// coded VI primary; the template body itself contains the EN fallback.
func RenderVerifyEmail(data VerifyEmailData) (string, string, error) {
	var buf bytes.Buffer
	if err := templates.ExecuteTemplate(&buf, "verify_email.html", data); err != nil {
		return "", "", fmt.Errorf("render verify_email: %w", err)
	}
	return buf.String(), "Xác minh email Czech Go", nil
}

// verifyEmailTextFallback is the plain-text alternative for clients that
// do not render HTML (e.g. screen readers, terminal mailers).
func verifyEmailTextFallback(data VerifyEmailData) string {
	return strings.Join([]string{
		fmt.Sprintf("Xin chào %s,", data.DisplayName),
		"",
		"Hãy click link sau để xác minh email của bạn:",
		data.VerifyURL,
		"",
		fmt.Sprintf("Link sẽ hết hạn sau %d giờ.", data.ExpiresHrs),
		"",
		"Nếu bạn không đăng ký, hãy bỏ qua email này.",
		"",
		"---",
		fmt.Sprintf("Hello %s, please click %s to verify your email. Link expires in %d hours.",
			data.DisplayName, data.VerifyURL, data.ExpiresHrs),
	}, "\n")
}

// ── Password reset ───────────────────────────────────────────────────────

type PasswordResetEmailData struct {
	DisplayName string
	ResetURL    string
	ExpiresMin  int
}

func RenderPasswordResetEmail(data PasswordResetEmailData) (string, string, error) {
	var buf bytes.Buffer
	if err := templates.ExecuteTemplate(&buf, "password_reset.html", data); err != nil {
		return "", "", fmt.Errorf("render password_reset: %w", err)
	}
	return buf.String(), "Đặt lại mật khẩu Czech Go", nil
}

func passwordResetTextFallback(data PasswordResetEmailData) string {
	return strings.Join([]string{
		fmt.Sprintf("Xin chào %s,", data.DisplayName),
		"",
		"Click link sau để đặt lại mật khẩu:",
		data.ResetURL,
		"",
		fmt.Sprintf("Link hết hạn sau %d phút và chỉ dùng được 1 lần.", data.ExpiresMin),
		"",
		"Nếu bạn không yêu cầu đặt lại, hãy bỏ qua email này.",
		"",
		"---",
		fmt.Sprintf("Hello %s, click %s to reset your password. Link expires in %d minutes (single use).",
			data.DisplayName, data.ResetURL, data.ExpiresMin),
	}, "\n")
}

// ── Password changed (security notification) ─────────────────────────────

type PasswordChangedEmailData struct {
	DisplayName string
	ChangedAt   string // already formatted, e.g. "2026-05-05 14:30 (Asia/Ho_Chi_Minh)"
}

func RenderPasswordChangedEmail(data PasswordChangedEmailData) (string, string, error) {
	var buf bytes.Buffer
	if err := templates.ExecuteTemplate(&buf, "password_changed.html", data); err != nil {
		return "", "", fmt.Errorf("render password_changed: %w", err)
	}
	return buf.String(), "Mật khẩu đã được thay đổi — Czech Go", nil
}

func passwordChangedTextFallback(data PasswordChangedEmailData) string {
	return strings.Join([]string{
		fmt.Sprintf("Xin chào %s,", data.DisplayName),
		"",
		fmt.Sprintf("Mật khẩu của bạn đã được thay đổi vào %s.", data.ChangedAt),
		"",
		"Nếu không phải bạn thực hiện, hãy đặt lại mật khẩu ngay và liên hệ support.",
		"",
		"---",
		fmt.Sprintf("Hello %s, your password was changed at %s. If this was not you, reset your password immediately.",
			data.DisplayName, data.ChangedAt),
	}, "\n")
}

// ── From identity helpers ────────────────────────────────────────────────

const (
	defaultFromName  = "Czech Go"
	defaultFromEmail = "noreply@czechgo.hadoo.eu"
)

func fromName() string {
	if v := strings.TrimSpace(os.Getenv("EMAIL_FROM_NAME")); v != "" {
		return v
	}
	return defaultFromName
}

func fromEmail() string {
	if v := strings.TrimSpace(os.Getenv("EMAIL_FROM_ADDRESS")); v != "" {
		return v
	}
	return defaultFromEmail
}
