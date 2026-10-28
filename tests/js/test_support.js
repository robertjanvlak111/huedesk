/*
 * Tests for Support.js, the one-time support message timing.
 *
 * The important property is that it never asks twice, and stays quiet
 * whenever it cannot be sure.
 */

test("nothing is shown before the threshold", function () {
    equal(Support.shouldPrompt("2026-01-01", false, "2026-03-01"), false,
          "59 days in");
    equal(Support.shouldPrompt("2026-01-01", false, "2026-03-31"), false,
          "89 days in");
});

test("it is shown on the ninetieth day and after", function () {
    equal(Support.shouldPrompt("2026-01-01", false, "2026-04-01"), true,
          "exactly 90 days");
    equal(Support.shouldPrompt("2026-01-01", false, "2027-01-01"), true,
          "a year later");
});

test("it is never shown twice", function () {
    equal(Support.shouldPrompt("2026-01-01", true, "2027-06-01"), false);
    equal(Support.shouldPrompt("2020-01-01", true, "2026-01-01"), false);
});

test("a missing or malformed first-run date stays quiet", function () {
    equal(Support.shouldPrompt("", false, "2026-06-01"), false, "empty");
    equal(Support.shouldPrompt(null, false, "2026-06-01"), false, "null");
    equal(Support.shouldPrompt("not a date", false, "2026-06-01"), false, "garbage");
    equal(Support.shouldPrompt("2026-13-01", false, "2026-06-01"), false,
          "month 13");
    equal(Support.shouldPrompt("01-01-2026", false, "2026-06-01"), false,
          "wrong order");
});

test("a clock that has gone backwards stays quiet", function () {
    equal(Support.shouldPrompt("2026-06-01", false, "2026-01-01"), false);
});

test("the threshold is configurable", function () {
    equal(Support.shouldPrompt("2026-01-01", false, "2026-01-08", 7), true);
    equal(Support.shouldPrompt("2026-01-01", false, "2026-01-06", 7), false);
    equal(Support.shouldPrompt("2026-01-01", false, "2026-01-01", 0), true,
          "a zero threshold shows immediately");
});

test("the default threshold is ninety days", function () {
    equal(Support.DEFAULT_AFTER_DAYS, 90);
});

test("daysBetween counts whole calendar days", function () {
    equal(Support.daysBetween("2026-01-01", "2026-01-02"), 1);
    equal(Support.daysBetween("2026-01-01", "2026-01-01"), 0);
    equal(Support.daysBetween("2026-02-28", "2026-03-01"), 1, "non-leap year");
    equal(Support.daysBetween("2024-02-28", "2024-03-01"), 2, "leap year");
    equal(Support.daysBetween("2025-12-31", "2026-01-01"), 1, "across new year");
});

test("daysBetween reports -1 for anything unusable", function () {
    equal(Support.daysBetween("", "2026-01-01"), -1);
    equal(Support.daysBetween("2026-01-01", "oops"), -1);
});

test("todayIso formats a date as YYYY-MM-DD", function () {
    equal(Support.todayIso(new Date(2026, 0, 5)), "2026-01-05",
          "single digits are padded");
    equal(Support.todayIso(new Date(2026, 11, 31)), "2026-12-31");
});

test("a date produced by todayIso is understood by daysBetween", function () {
    var start = Support.todayIso(new Date(2026, 0, 1));
    var later = Support.todayIso(new Date(2026, 3, 1));
    equal(Support.daysBetween(start, later), 90, "round trip");
    equal(Support.shouldPrompt(start, false, later), true);
});
