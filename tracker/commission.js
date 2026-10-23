// Commission math for one product line on a sale.
// Rules agreed with the user:
//  - Associate rate column only.
//  - First-year commission only (no renewals).
//  - "Advance only": count what is paid up front.
//      % rate:  AV x rate x (advance months / 12), where AV = monthly premium x 12
//      $ rate:  $ per member per month x members x advance months
//  - One-time products (annuity deposits, PUAR): premium is a lump sum, AV = premium,
//    commission = premium x rate.
//  - A rate row with no advance months listed (ACA) is paid monthly; it counts 1 month
//    unless the user changes it on the sale.

function parseRate(text) {
  var t = String(text).trim();
  if (t.charAt(0) === '$') return { type: '$', value: parseFloat(t.slice(1).replace(/,/g, '')) };
  return { type: '%', value: parseFloat(t) / 100 };
}

function defaultMonths(rateRow) {
  return rateRow.a == null ? 1 : rateRow.a;
}

function cents(x) {
  return Math.round((x + Number.EPSILON) * 100) / 100;
}

// line: { rateType, rate, payType, premium, members, months }
function calcLine(line) {
  var premium = Number(line.premium) || 0;
  var rate = Number(line.rate) || 0;
  var months = Number(line.months) || 0;
  var members = Number(line.members) || 0;
  var av, commission, formula;
  if (line.payType === 'One-time') {
    av = premium;
    commission = premium * rate;
    formula = 'one-time ' + premium.toFixed(2) + ' x ' + (rate * 100) + '%';
  } else if (line.rateType === '$') {
    av = premium * 12;
    commission = rate * members * months;
    formula = '$' + rate.toFixed(2) + ' x ' + members + ' member' + (members === 1 ? '' : 's') + ' x ' + months + ' mo';
  } else {
    av = premium * 12;
    commission = av * rate * months / 12;
    formula = 'AV ' + av.toFixed(2) + ' x ' + cents(rate * 100) + '% x ' + months + '/12';
  }
  // monthly = commission earned by each premium the client pays; fullYear = all first-year commission.
  var monthly = 0, fullYear = commission;
  if (line.payType !== 'One-time') {
    monthly = line.rateType === '$' ? rate * members : premium * rate;
    fullYear = monthly * 12;
  }
  return { av: cents(av), commission: cents(commission), formula: formula,
           monthly: monthly, fullYear: cents(fullYear), advanceMonths: line.payType === 'One-time' ? 0 : Math.min(months, 12) };
}

// Month arithmetic on YYYY-MM-DD strings (local calendar, no time zones).
function monthIndex(ymd) { var p = ymd.split('-'); return (+p[0]) * 12 + (+p[1] - 1); }
function monthKey(idx) { return Math.floor(idx / 12) + '-' + String(idx % 12 + 1).padStart(2, '0'); }
function addMonths(ymd, n) {
  var p = ymd.split('-'), idx = (+p[0]) * 12 + (+p[1] - 1) + n;
  var y = Math.floor(idx / 12), m = idx % 12 + 1;
  var last = new Date(y, m, 0).getDate();
  return y + '-' + String(m).padStart(2, '0') + '-' + String(Math.min(+p[2], last)).padStart(2, '0');
}

// How one product line pays out over its first year.
// The advance is paid in the sale month. The client's k-th premium (k = 1..12) is due
// k-1 months after the effective date and earns one month of commission. The first
// `advanceMonths` premiums pay back the advance; each later premium is paid out to you.
// Returns events: {date, advancePaid, earnedPaid, earned, balance} where balance is the
// advance still unpaid after that event. Totals add up to fullYear exactly.
function lineSchedule(res, saleDate, effDate) {
  var events = [];
  var advance = res.commission, full = res.fullYear;
  if (!res.monthly) { // one-time product: all paid and earned at the sale
    events.push({ date: saleDate, advancePaid: full, earnedPaid: 0, earned: full, balance: 0 });
    return events;
  }
  events.push({ date: saleDate, advancePaid: advance, earnedPaid: 0, earned: 0, balance: advance });
  var earnedSum = 0, paidSum = advance;
  for (var k = 1; k <= 12; k++) {
    var earned = k === 12 ? cents(full - earnedSum) : cents(res.monthly);
    earnedSum = cents(earnedSum + earned);
    var paid = 0;
    if (k > res.advanceMonths) { paid = k === 12 ? cents(full - paidSum) : cents(res.monthly); paidSum = cents(paidSum + paid); }
    var balance = Math.max(0, cents(advance - earnedSum));
    if (k >= res.advanceMonths) balance = 0;
    events.push({ date: addMonths(effDate, k - 1), advancePaid: 0, earnedPaid: paid, earned: earned, balance: balance });
  }
  return events;
}

// Residual (renewal) commission from year 2 on.
// payText is the sheet's "Pay Years" (e.g. "Yr 1, 2-10, 11+", "Yr1,2,3-10", "Yrs 1/2+"),
// r2/r3 are the sheet's 2nd and 3rd rate columns. Returns
// {segments: [{from, to (null = no end), rateType, rate}], unused: true if the sheet lists a
// rate with no years to apply it to}.
function parseRenewals(payText, r2, r3) {
  var rates = [r2, r3].filter(function (r) { return r && String(r).trim(); }).map(parseRate);
  var tokens = String(payText).replace(/[A-Za-z]/g, ' ').split(/[,\/]/)
    .map(function (t) { return t.replace(/\s+/g, ''); }).filter(Boolean);
  var ranges = [], end = 1;
  if (tokens.length) {
    var first = tokens[0];
    if (/^1-(\d+)$/.test(first)) end = +first.split('-')[1];
    if (first === '1+') end = null;
    tokens.slice(1).forEach(function (t) {
      var from, to;
      if (t === '++') { from = (ranges.length ? ranges[ranges.length - 1].to : 1) + 1; to = null; }
      else if (/^\d+\+$/.test(t)) { from = +t.slice(0, -1); to = null; }
      else if (/^\d+-\d+$/.test(t)) { from = +t.split('-')[0]; to = +t.split('-')[1]; }
      else if (/^\d+$/.test(t)) { from = +t; to = +t; }
      else return;
      ranges.push({ from: from, to: to });
    });
  }
  // "Flat", "Y1-6", "Yrs 1+" with a renewal rate: the renewal rate covers the rest of the paid years.
  if (!ranges.length && rates.length) ranges.push({ from: 2, to: tokens.length ? end : null });
  var segments = [];
  ranges.forEach(function (rg, i) {
    if (rates[i] && rates[i].value > 0) segments.push({ from: rg.from, to: rg.to, rateType: rates[i].type, rate: rates[i].value });
  });
  return { segments: segments, unused: rates.length > ranges.length };
}

function renewalText(segments) {
  if (!segments || !segments.length) return 'No residual on the sheet';
  return segments.map(function (s) {
    var r = s.rateType === '$' ? '$' + s.rate.toFixed(2) + '/member/mo' : cents(s.rate * 100) + '%';
    var yrs = s.to == null ? 'yr ' + s.from + '+' : s.from === s.to ? 'yr ' + s.from : 'yrs ' + s.from + '-' + s.to;
    return r + ' ' + yrs;
  }).join(', ');
}

// Residual paid each month from the renewal date (start of policy year 2) up to and
// including the month `untilYmd`. line: {premium, members, payType}; segments from parseRenewals.
function residualSchedule(line, segments, renewalDate, untilYmd) {
  var out = [];
  if (!segments || !segments.length || line.payType === 'One-time') return out;
  var premium = Number(line.premium) || 0, members = Number(line.members) || 1;
  var stop = monthIndex(untilYmd);
  for (var j = 0; j < 1200; j++) {
    var date = addMonths(renewalDate, j);
    if (monthIndex(date) > stop) break;
    var year = 2 + Math.floor(j / 12), seg = null;
    for (var i = 0; i < segments.length; i++) {
      var s = segments[i];
      if (year >= s.from && (s.to == null || year <= s.to)) { seg = s; break; }
    }
    if (!seg) {
      var later = segments.some(function (s) { return s.from > year; });
      if (!later) break;
      continue;
    }
    var amt = seg.rateType === '$' ? seg.rate * members : premium * seg.rate;
    out.push({ date: date, year: year, residual: cents(amt) });
  }
  return out;
}

if (typeof module !== 'undefined') module.exports = { parseRate: parseRate, defaultMonths: defaultMonths, calcLine: calcLine, cents: cents,
  lineSchedule: lineSchedule, addMonths: addMonths, monthIndex: monthIndex, monthKey: monthKey,
  parseRenewals: parseRenewals, renewalText: renewalText, residualSchedule: residualSchedule };
