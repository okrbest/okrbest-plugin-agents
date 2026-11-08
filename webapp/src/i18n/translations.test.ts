// Copyright (c) 2023-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import {
    isArgumentElement,
    isDateElement,
    isNumberElement,
    isPluralElement,
    isSelectElement,
    isTagElement,
    isTimeElement,
    parse,
    MessageFormatElement,
} from '@formatjs/icu-messageformat-parser';
import {createIntl} from 'react-intl';

import en from './en.json';
import ko from './ko.json';

/**
 * These guard the translation files themselves rather than any component. The
 * plugin registers them with the host webapp, and a registered message wins
 * over the `defaultMessage` compiled into the bundle, so en.json — not the
 * source string next to the component — is what readers actually see. Every
 * other test in this repo renders the default, which means a broken message
 * here would ship while the whole suite stayed green.
 *
 * ko.json is held to the same bar plus two more: it must carry every en.json
 * key (a missing key silently falls back to English on screen) and every
 * message must keep the placeholders of its English source (a renamed argument
 * renders as a literal `{name}` with no error anywhere).
 */
const english: Record<string, string> = en;
const korean: Record<string, string> = ko;

/** Silences react-intl's console reporting; these tests assert on the output. */
function noop() {
    // Intentionally empty.
}

function pluralElements(elements: MessageFormatElement[]): MessageFormatElement[] {
    const found: MessageFormatElement[] = [];
    for (const element of elements) {
        if (isPluralElement(element)) {
            found.push(element);
        }
        if (isPluralElement(element) || isSelectElement(element)) {
            for (const option of Object.values(element.options)) {
                found.push(...pluralElements(option.value));
            }
        }
        if (isTagElement(element)) {
            found.push(...pluralElements(element.children));
        }
    }
    return found;
}

/**
 * Every name a message depends on: ICU arguments (plain, number, date, time,
 * plural, select) and rich-text tags, recursing into plural/select branches
 * and tag children. Tags are prefixed so `<b>` and an argument called `b`
 * cannot be confused. `#` carries no name and is skipped.
 */
function placeholders(elements: MessageFormatElement[]): string[] {
    const found = new Set<string>();
    const walk = (nodes: MessageFormatElement[]) => {
        for (const node of nodes) {
            if (isArgumentElement(node) || isNumberElement(node) || isDateElement(node) || isTimeElement(node)) {
                found.add(node.value);
            }
            if (isPluralElement(node) || isSelectElement(node)) {
                found.add(node.value);
                for (const option of Object.values(node.options)) {
                    walk(option.value);
                }
            }
            if (isTagElement(node)) {
                found.add(`<${node.value}>`);
                walk(node.children);
            }
        }
    };
    walk(elements);
    return [...found].sort();
}

type FormatValue = string | number | ((chunks: string[]) => string);

/** Values that satisfy every placeholder of a message, so formatting never throws. */
function valuesFor(message: string, count: number): Record<string, FormatValue> {
    const values: Record<string, FormatValue> = {};
    for (const name of placeholders(parse(message))) {
        if (name.startsWith('<')) {
            values[name.slice(1, -1)] = (chunks: string[]) => chunks.join('');
        } else if (name === 'count') {
            values[name] = count;
        } else {
            values[name] = 'x';
        }
    }
    return values;
}

const locales: Array<[string, Record<string, string>]> = [
    ['en', english],
    ['ko', korean],
];

describe.each(locales)('%s.json', (_locale, messages) => {
    const entries = Object.entries(messages);

    test('is not empty', () => {
        expect(entries.length).toBeGreaterThan(0);
    });

    test('has no empty messages', () => {
        const empty = entries.filter(([, message]) => message.trim() === '').map(([id]) => id);

        expect(empty).toEqual([]);
    });

    test('parses as ICU throughout', () => {
        const unparseable = entries.
            filter(([, message]) => {
                try {
                    parse(message);
                    return false;
                } catch {
                    return true;
                }
            }).
            map(([id]) => id);

        expect(unparseable).toEqual([]);
    });
});

describe('en.json', () => {
    const entries = Object.entries(english);

    // English distinguishes one from other. ICU has no error for a missing
    // category — it silently falls back to `other`, so a message that lost its
    // `one` arm renders "1 tools" with no warning anywhere.
    test('every cardinal plural declares a "one" category', () => {
        const missing = entries.
            filter(([, message]) => {
                return pluralElements(parse(message)).
                    some((element) => isPluralElement(element) &&
                        element.pluralType === 'cardinal' &&
                        !('one' in element.options));
            }).
            map(([id]) => id);

        expect(missing).toEqual([]);
    });

    // The same guarantee stated as output rather than structure: formatting the
    // shipped message for a count of one must not produce "1 things". A noun
    // that is singular but ends in s would trip this; none exist today, and the
    // failure names the message, so that is cheap to handle if one appears.
    test('formats a count of one without a plural noun', () => {
        const intl = createIntl({locale: 'en', messages: english, onError: noop});
        const plurals = entries.filter(([, message]) => message.includes('plural'));
        const misread = plurals.
            map(([id]) => [id, intl.formatMessage({id}, {count: 1})]).
            filter(([, formatted]) => (/\b1 \w+s\b/).test(formatted));

        expect(plurals.length).toBeGreaterThan(0);
        expect(misread).toEqual([]);
    });
});

describe('ko.json', () => {
    const englishKeys = Object.keys(english);
    const koreanKeys = Object.keys(korean);

    // A key that exists only in en.json falls back to English on a Korean
    // screen; a key that exists only in ko.json is dead weight left behind by an
    // upstream change. Both are reported by name so the fix is one line.
    test('has exactly the keys of en.json', () => {
        const missing = englishKeys.filter((id) => !(id in korean));
        const extra = koreanKeys.filter((id) => !(id in english));

        expect({missing, extra}).toEqual({missing: [], extra: []});
    });

    // react-intl renders an unknown argument as the literal `{name}` and a
    // dropped tag loses its formatting, neither with an error.
    test('keeps the placeholders of each en.json message', () => {
        const mismatched = englishKeys.
            filter((id) => id in korean).
            map((id) => ({
                id,
                en: placeholders(parse(english[id])),
                ko: placeholders(parse(korean[id])),
            })).
            filter(({en: source, ko: target}) => JSON.stringify(source) !== JSON.stringify(target));

        expect(mismatched).toEqual([]);
    });

    // Korean has a single CLDR plural category. Intl.PluralRules('ko') never
    // selects `one`, so an English-shaped `one`/`other` pair is a dead branch
    // that reads as a half-translated message to the next editor. Exact
    // matches such as `=0` are not categories and stay allowed.
    test('declares only the "other" plural category', () => {
        const withEnglishCategories = Object.entries(korean).
            filter(([, message]) => {
                return pluralElements(parse(message)).
                    some((element) => isPluralElement(element) &&
                        Object.keys(element.options).some((category) => category !== 'other' && !category.startsWith('=')));
            }).
            map(([id]) => id);

        expect(withEnglishCategories).toEqual([]);
    });

    // SC-005: with a single category the number must still come through for
    // both one and many, otherwise a translator who dropped `#` ships "도구 개".
    // Measured against the English output: a message whose English `one` arm
    // shows a version list instead of a count is not required to show one.
    test('shows the count wherever the English message shows it, for 1 and 2', () => {
        const koIntl = createIntl({locale: 'ko', messages: korean, onError: noop});
        const enIntl = createIntl({locale: 'en', messages: english, onError: noop});
        const plurals = englishKeys.filter((id) => id in korean && english[id].includes('plural'));
        const missingCount = plurals.
            flatMap((id) => [1, 2].map((count) => ({
                id,
                count,
                en: enIntl.formatMessage({id}, valuesFor(english[id], count)),
                ko: koIntl.formatMessage({id}, valuesFor(korean[id], count)),
            }))).
            filter(({count, en: source, ko: target}) => source.includes(String(count)) && !target.includes(String(count)));

        expect(plurals.length).toBeGreaterThan(0);
        expect(missingCount).toEqual([]);
    });
});
