package contracts

import "strings"

const (
	LocaleVI = "vi"
	LocaleEN = "en"

	DefaultLocale = LocaleVI
)

func SupportedLocales() []string {
	return []string{LocaleVI, LocaleEN}
}

func NormalizeLocale(raw string) (string, bool) {
	v := strings.ToLower(strings.TrimSpace(raw))
	if v == "" {
		return DefaultLocale, true
	}
	for _, l := range SupportedLocales() {
		if v == l {
			return v, true
		}
	}
	return "", false
}
