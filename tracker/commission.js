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
  return { av: cents(av), commission: cents(commission), formula: formula };
}

if (typeof module !== 'undefined') module.exports = { parseRate: parseRate, defaultMonths: defaultMonths, calcLine: calcLine, cents: cents };
