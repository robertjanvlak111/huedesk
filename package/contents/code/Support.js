.pragma library

/*
 * Support.js - decides whether to show the one-time support message.
 *
 * Kept free of QML types so the test suite can run it directly. Dates are
 * handled as calendar days ("YYYY-MM-DD") rather than timestamps: the exact
 * hour is irrelevant here, and whole days avoid timezone drift.
 *
 * The rule is deliberately conservative. Anything it cannot make sense of -
 * a missing date, a malformed one, a clock that has gone backwards - results
 * in no prompt. Failing to ask is harmless; asking twice is not.
 */

var DEFAULT_AFTER_DAYS = 90;

function _parseIso(iso) {
    if (!iso || typeof iso !== "string") {
        return null;
    }
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso.trim());
    if (!m) {
        return null;
    }
    var year = parseInt(m[1], 10);
    var month = parseInt(m[2], 10);
    var day = parseInt(m[3], 10);
    if (month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
    }
    var stamp = Date.UTC(year, month - 1, day);
    return isNaN(stamp) ? null : stamp;
}

// Today as "YYYY-MM-DD", in local time. `date` is injectable for tests.
function todayIso(date) {
    var d = date || new Date();
    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

// Whole days from one calendar date to another; -1 if either is unusable.
function daysBetween(fromIso, toIso) {
    var from = _parseIso(fromIso);
    var to = _parseIso(toIso);
    if (from === null || to === null) {
        return -1;
    }
    return Math.floor((to - from) / 86400000);
}

/*
 * firstRunIso   when the widget was first used
 * alreadyShown  whether the message has been shown before
 * todayIsoDate  today
 * afterDays     how long to wait (default 90)
 */
function shouldPrompt(firstRunIso, alreadyShown, todayIsoDate, afterDays) {
    if (alreadyShown) {
        return false;
    }
    var threshold = (afterDays === undefined || afterDays === null)
                    ? DEFAULT_AFTER_DAYS : afterDays;
    var days = daysBetween(firstRunIso, todayIsoDate);
    if (days < 0) {
        // Unparseable, or the clock has moved backwards: say nothing.
        return false;
    }
    return days >= threshold;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { todayIso, daysBetween, shouldPrompt, DEFAULT_AFTER_DAYS };
}
