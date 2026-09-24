# Commission schedule

`commission_schedule.csv` is transcribed from photos of a printed carrier commission sheet.

Columns:
- `page`: which photo/page the row came from (1–12)
- `adv_mo`: advance months
- `senior_1` / `associate_1`: first rate pair (first year)
- `senior_2` / `associate_2`: second rate pair (renewal years)
- `senior_3` / `associate_3`: third rate pair (later renewal years)
- `highlighted`: `yes` if the row was highlighted yellow on the printout

The printout doesn't label the three Senior/Associate pairs; the year meanings above are inferred from the `pay_years` column.
State lists ending in `…` were cut off on the printout.
The carrier column was cut off in the page 10 photo; the page 11 photo shows those rows are UHC except the last two ACA rows, which are Aetna.
For ACA rows the printout puts the state list in the product-name column, so `product_name` holds the states and `states` is blank.
