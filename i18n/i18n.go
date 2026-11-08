// Copyright (c) 2023-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package i18n

import (
	"embed"
	"errors"
	"fmt"

	"github.com/nicksnyder/go-i18n/v2/i18n"
	"golang.org/x/text/language"
)

//go:embed *.json
var i18nFiles embed.FS

type TranslationFunc func(translationId string, defaultMessage string, params ...any) string

type Bundle = i18n.Bundle

func Init() *Bundle {
	bundle := i18n.NewBundle(language.English)
	// The embedded FS is rooted at this package directory, so the files are
	// "es.json", not "i18n/es.json". Loading by the wrong path fails silently
	// and every locale falls back to English; i18n_test.go guards against it.
	_, _ = bundle.LoadMessageFileFS(i18nFiles, "es.json")
	_, _ = bundle.LoadMessageFileFS(i18nFiles, "ko.json")

	return bundle
}

func LocalizerFunc(bundle *Bundle, lang string) TranslationFunc {
	localizer := i18n.NewLocalizer(bundle, lang)

	return func(translationId string, defaultMessage string, params ...any) string {
		// Localize returns the English fallback together with a
		// MessageNotFoundErr when the id is missing from a loaded locale.
		// MustLocalize would panic on that error, so a catalog that lags
		// behind en.json must degrade to the default message instead.
		message, err := localizer.Localize(&i18n.LocalizeConfig{
			DefaultMessage: &i18n.Message{
				ID:    translationId,
				Other: defaultMessage,
			},
		})
		if err != nil {
			var notFound *i18n.MessageNotFoundErr
			if message == "" || !errors.As(err, &notFound) {
				message = defaultMessage
			}
		}
		if len(params) > 0 {
			return fmt.Sprintf(message, params...)
		}
		return message
	}
}
