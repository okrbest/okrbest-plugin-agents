// Copyright (c) 2023-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

package i18n

import (
	"encoding/json"
	"io/fs"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type catalogMessage struct {
	ID          string `json:"id"`
	Translation string `json:"translation"`
}

// loadCatalog reads one of the embedded message files as id → translation.
func loadCatalog(t *testing.T, name string) map[string]string {
	t.Helper()
	raw, err := fs.ReadFile(i18nFiles, name)
	require.NoError(t, err, "catalog %s must be embedded", name)
	var messages []catalogMessage
	require.NoError(t, json.Unmarshal(raw, &messages), "catalog %s must be a {id, translation} array", name)
	out := make(map[string]string, len(messages))
	for _, m := range messages {
		out[m.ID] = m.Translation
	}
	return out
}

// Init only registers the locales it names explicitly, and it drops the load
// error, so a catalog that is present but not registered falls back to English
// without a trace. Each locale here must come back translated for every id it
// defines, not just parse.
func TestLocalizerFuncReturnsRegisteredLocale(t *testing.T) {
	english := loadCatalog(t, "en.json")
	bundle := Init()

	tests := []struct {
		name string
		lang string
		file string
	}{
		{name: "korean", lang: "ko", file: "ko.json"},
		{name: "spanish", lang: "es", file: "es.json"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			catalog := loadCatalog(t, tc.file)
			require.NotEmpty(t, catalog)
			translate := LocalizerFunc(bundle, tc.lang)
			for id, want := range catalog {
				got := translate(id, english[id])
				assert.Equal(t, want, got, "id %s must come from %s, not the English default", id, tc.file)
			}
		})
	}
}

// Every English id must have a Korean translation whose fmt verbs match the
// source: the callers splice params with fmt.Sprintf, so a dropped %s turns
// into "%!(EXTRA string=...)" on screen.
func TestKoreanCatalogCoversEnglish(t *testing.T) {
	english := loadCatalog(t, "en.json")
	korean := loadCatalog(t, "ko.json")

	for id, source := range english {
		t.Run(id, func(t *testing.T) {
			translation, ok := korean[id]
			require.True(t, ok, "ko.json is missing id %s", id)
			assert.NotEmpty(t, strings.TrimSpace(translation))
			assert.Equal(t, strings.Count(source, "%"), strings.Count(translation, "%"), "fmt verb count must match the English source")
		})
	}
}

// go-i18n reports a message that is missing from a loaded locale as an error
// even though it also returns the English fallback. The translator must hand
// that fallback to the caller instead of panicking the plugin, because a
// locale catalog is allowed to lag behind the English ids (es.json does today).
func TestLocalizerFuncFallsBackToDefaultMessage(t *testing.T) {
	bundle := Init()
	spanish := loadCatalog(t, "es.json")
	_, inSpanish := spanish["agents.search_tools_unavailable"]
	require.False(t, inSpanish, "this test relies on an id that es.json does not translate")

	tests := []struct {
		name   string
		lang   string
		id     string
		def    string
		params []any
		want   string
	}{
		{name: "korean, id unknown everywhere", lang: "ko", id: "agents.test_unregistered_id", def: "Fallback %s", want: "Fallback %s"},
		{name: "korean, id unknown everywhere, with params", lang: "ko", id: "agents.test_unregistered_id", def: "Fallback %s", params: []any{"value"}, want: "Fallback value"},
		{name: "spanish, id missing from es.json only", lang: "es", id: "agents.search_tools_unavailable", def: "English default", want: "English default"},
		{name: "unknown locale", lang: "xx", id: "agents.test_unregistered_id", def: "Fallback %s", want: "Fallback %s"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			translate := LocalizerFunc(bundle, tc.lang)
			assert.Equal(t, tc.want, translate(tc.id, tc.def, tc.params...))
		})
	}
}
