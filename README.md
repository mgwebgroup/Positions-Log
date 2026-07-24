# Trade Journal and P\&L Toolkit

A small shell and AWK toolkit for:

- Recording trade executions into a CSV journal
- Attaching lightweight per-position metadata (stop loss, price target, intraday high/low)
- Computing realized and unrealized P&L
- Appending closing prices to consolidated positions
- Appending Average True Range (ATR) values to consolidated positions
- Computing per-position drawdowns and runups (DD/RU)
- Computing account equity over time

The package is designed to work with local CSV data, accessed via environment variables and a simple `bin/` command set.


## Package layout

Typical repository layout:

```text
bin/
  enter-trade       # interactive trade entry
  enter-meta        # metadata entry for a just-entered trade
  compute-realized  # realized P&L and per-symbol position consolidation
  add-unrealized    # append unrealized P&L from OHLCV close prices
  add-price         # append daily closing price from OHLCV files
  add-atr           # append ATR(n) from per-symbol ATR files
  add-ddru          # append DD/RU, intraday low/high, flags
  get-balance       # compute account balance from realized+unrealized P&L

lib/
  bash/validation.sh
  awk/data_cache.awk
  awk/...           # AWK helpers

env.sh
env.sh.example
README.md
LICENSE
```

The `bin/` scripts expect `env.sh` to set the relevant file paths and default values.


## Data files

The toolkit uses four main data sources:

1. **Journal CSV** — trade executions (one row per execution)
2. **Metadata CSV** — per-trade intraday info and per-symbol DD/RU state
3. **OHLCV files** — per-ticker daily bar data used for unrealized P&L, closing-price enrichment, and DD/RU
4. **ATR files** — per-ticker daily ATR data used by `bin/add-atr`


### Journal file

The journal file is a CSV with a header like:

```csv
TIMESTAMP,INSTRUMENT,QUANTITY,PRICE,CURRENCY,COMMISSION,EXCHANGE_EXEC_ID,ORDERID,ACCOUNTNO,EXCHANGENAME,CUSIP
```

Example rows:

```csv
1767369650,PANW,-10,178.99,USD,0.354207,376654950S,0036BA34.00031198.6957591D.0001,U1451183,IBKRATS,
1767623401,COIN,-6,247.50,USD,0.352627,0308193782,0036BA34.00031198.695B4ABA.0001,U1451183,IBKRATS,
```

Conventions:

- `TIMESTAMP` is a Unix epoch seconds value in your chosen trading time zone.
- `QUANTITY` is signed; negative for shorts, positive for longs.
- `EXCHANGE_EXEC_ID` is treated as the unique execution identity and is used for de-duplication.
- `CUSIP` may be blank; it is present for completeness but not used in P\&L logic.

`bin/enter-trade` creates the journal file if it does not exist and maintains the header.


### Metadata file

The metadata file is a plain text file with two types of records:

1. **Per-fill intraday records (same day)**:

```text
INSTRUMENT:TIMESTAMP,SL:PRICE,HIGH:PRICE,LOW:PRICE,PT:PRICE,Q:QUANTITY
```

Example:

```text
PANW:1767369650,SL:200.00,HIGH:180.00,LOW:170.00,PT:150.00,Q:-10
```

Fields:
    - `SL` – stop loss at entry time.
    - `HIGH` – intraday high recorded at/for that fill.
    - `LOW` – intraday low recorded at/for that fill.
    - `PT` – price target.
    - `Q` – fill quantity, signed, matching the journal convention.

These records are used intraday by the DD/RU updater to seed per-symbol extremes and then are partially or fully consumed as state is consolidated.

2. **Per-symbol state records (durable)**:

```text
INSTRUMENT:META,DD:PRICE,RU:PRICE,Q:QUANTITY
```

Example:

```text
PANW:META,DD:165.00,RU:195.50,Q:-10
```

Fields:
    - `DD` – worst adverse price seen so far for that open position (drawdown anchor).
    - `RU` – best favorable price seen so far for that open position (runup anchor).
    - `Q` – current open quantity for the symbol.

The metadata file is maintained automatically by `bin/add-ddru`. You normally only write new `INSTRUMENT:TIMESTAMP` rows via `bin/enter-meta`; `INSTRUMENT:META` rows and the removal of used intraday keys are handled by the AWK script.


### OHLCV files

OHLCV files are per-symbol, per-year CSVs with the name:

```text
TICKER_Daily_YYYY.csv
```

Example filename:

```text
AAPL_Daily_2026.csv
```

Format:

```csv
Date,Open,High,Low,Close,Volume
```

Constraints:

- `Date` is in `YYYY-MM-DD` format.
- `Close` is the 5th field and is used for unrealized P&L and by `bin/add-price`.
- `High` and `Low` are the 3rd and 4th fields and are used for DD/RU updates.


### ATR files

ATR files are per-symbol, per-period, per-year CSVs with the name:

```text
TICKER_N_Daily_YYYY.csv
```

Example filenames:

```text
AAPL_14_Daily_2026.csv
NVDA_20_Daily_2026.csv
```

Format:

```csv
YYYY-MM-DD,ATR
```

Example:

```csv
2026-07-22,5.84
2026-07-23,6.11
```

Constraints:

- The first field must be the trading date in `YYYY-MM-DD` format.
- The second field must be the ATR value for that date.
- `bin/add-atr` selects files by symbol, ATR period `n`, and year derived from `date`.


## Configuration

Copy `env.sh.example` to `env.sh` and edit it (or edit `env.sh` directly) to define the paths and defaults used by the entry and analytics workflow.

Typical variables:

```bash
# Absolute path to the journal file
JOURNAL="/absolute/path/to/Data/Positions/Journal_2026.csv"

# Absolute path to metadata file
META_FILE="/absolute/path/to/Data/Positions/meta.csv"

# Directory containing OHLCV files like TICKER_Daily_YYYY.csv
OHLCV_DIR="/absolute/path/to/OHLCV"

# Directory containing ATR files like TICKER_N_Daily_YYYY.csv
ATR_DIR="/absolute/path/to/ATR"

# Default timezone offset for entry timestamps (used by entry.sh)
TIMEZONE="-0400"

# Default commission per trade
COMMISSION="0.35"

# Default currency code
CURRENCY="USD"

# Default values used during entry; must pass validation
ORDERID="abcdef01.02030405.abddef"
ACCOUNTNO="ABCD1"
EXCHANGENAME="IBKRATS"
```

Notes:

- `TIMEZONE` must be a UTC offset like `-0400`.
- Defaults must satisfy the regex/numeric checks in `lib/bash/validation.sh`.
- `env.sh` is sourced by the entry script and should be version-controlled or templated as appropriate.


## Command overview

The main user-facing commands are:

- `bin/enter-trade` – interactive trade entry into the journal.
- `bin/enter-meta` – interactive metadata entry for the last trade.
- `bin/compute-realized` – consolidate trades and compute realized P\&L.
- `bin/add-unrealized` – append unrealized P\&L using OHLCV close prices.
- `bin/add-ddru` – append drawdown/runup, daily lows/highs, and change flags.
- `bin/get-balance` – compute account equity given realized + unrealized P\&L.
- `bin/add-atr` – append ATR(n) using per-symbol ATR files.
- `bin/add-price` – append daily closing price using OHLCV files.

Each command is designed to be used either by itself or as a step in an end-to-end daily pipeline.

***

## Entry workflow

### 1. Enter a trade – `bin/enter-trade`

Run:

```bash
. bin/enter-trade
```

This script:

- Sources `env.sh` and `lib/bash/validation.sh`.
- Prompts interactively for:
    - `ORDERDATE` – converted to Unix timestamp (`TIMESTAMP`) via `date -d ...`.
    - `INSTRUMENT`
    - `QUANTITY`
    - `PRICE`
    - `CURRENCY`
    - `COMMISSION`
    - `EXCHANGE_EXEC_ID`
    - `ORDERID`
    - `ACCOUNTNO`
    - `EXCHANGENAME`
- Validates each field with the functions in `lib/bash/validation.sh`.
- Creates the journal file with header if it does not exist.
- Deletes any existing journal row with the same `EXCHANGE_EXEC_ID`.
- Appends the new row.
- Re-sorts the journal CSV by `TIMESTAMP` (`sort -t, -n -k1,1`) and removes blank lines.

This makes the journal idempotent with respect to `EXCHANGE_EXEC_ID`: re-entering the same execution simply replaces the old row.

At the end of each trade, `enter-trade` optionally calls `bin/enter-meta` to capture metadata for that trade.


### 2. Enter metadata – `bin/enter-meta`

`bin/enter-meta` is a shell script that must be sourced from the entry context so it can see the current `INSTRUMENT`, `TIMESTAMP`, and `QUANTITY`:

```bash
. bin/enter-trade  # will source bin/enter-meta when you answer "yes"
```

`enter-meta`:

- Ensures `META_FILE` exists (touch if missing).
- Prompts for:
    - `SL` – stop loss
    - `INTRAHIGH` – intraday high
    - `INTRALOW` – intraday low
    - `PT` – price target
- Validates each value (`validatesl`, `validateintrahigh`, `validateintralow`, `validatept`).
- Writes a row keyed by `INSTRUMENT:TIMESTAMP` into `META_FILE`:

```text
INSTRUMENT:TIMESTAMP,SL:...,HIGH:...,LOW:...,PT:...,Q:QUANTITY
```


If you re-run metadata entry for the same `INSTRUMENT:TIMESTAMP`, the new values replace the previous row for that key.


### 3. Enter another trade

At the end of each loop, `enter-trade` asks whether to enter another record and repeats until you answer “no”.

***


## Realized P\&L – `bin/compute-realized`

`bin/compute-realized` reads the journal and emits per-symbol consolidated positions with realized P\&L.

Usage pattern:

```bash
TZ=America/New_York \
bin/compute-realized \
  -v start_ts="$(date -d '2026-01-01T09:30:00-05:00' '+%s')" \
  -v end_ts="$(date   -d '2026-07-22T16:30:00-04:00' '+%s')" \
  "$JOURNAL" > tmp_realized_positions.csv
```

Output columns:

```csv
TIMESTAMP,INSTRUMENT,QUANTITY,AVGBASEPRICE,CURRENCY,COMMISSION,REALPL
```

What it does:

- Reads journal rows after the header.
- Filters rows to `start_ts <= TIMESTAMP <= end_ts`.
- For each symbol:
    - Tracks cumulative `QUANTITY` (signed).
    - Maintains a moving `AVGBASEPRICE` for the open position.
    - Adjusts realized P\&L (`REALPL`) when trades reduce or reverse an existing position:
        - Pure adds adjust `AVGBASEPRICE` without P\&L.
        - Reductions compute P\&L versus the current `AVGBASEPRICE`.
        - Complete flips (through zero) reset base price to the new side.
- Deducts `COMMISSION` from realized P\&L.

There is a documented “reset row” convention: to forcefully reset a symbol’s quantity and base price, you can insert a journal row with that symbol and zero quantity while leaving most other fields blank, for example:

```csv
1763728636,ORCL,0,,,,,,,
```

This appears to the consolidator as a manual position reset.

***

## Unrealized P\&L – `bin/add-unrealized`

`bin/add-unrealized` takes the output of `compute-realized`, looks up a closing price for each symbol from OHLCV files, and appends an unrealized P\&L column.

Usage:

```bash
bin/add-unrealized \
  -v date=YYYY-MM-DD \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_realized_positions.csv > tmp_unrealized_positions.csv
```

Where:

- `date` is the closing date in `YYYY-MM-DD` format.
- `ohlcv_dir` is the directory containing `TICKER_Daily_YYYY.csv`.

Requirements:

- OHLCV filename: `TICKER_Daily_YYYY.csv`.
- OHLCV format: `Date,Open,High,Low,Close,Volume`.
- The `Close` field (5th) is used as the closing price.

Behavior:

- For each consolidated position row:
    - If `QUANTITY == 0`: unrealized P\&L is `0`.
    - Otherwise, it opens `TICKER_Daily_YYYY.csv`, finds the row where `Date == date`, reads `Close`, and computes:

```text
UNRPL = (Close - AVGBASEPRICE) * QUANTITY
```

- Appends `UNRPL` as an additional column.

If either the OHLCV file or the date row is missing, the unrealized P\&L for that symbol is `0`.


***

## Closing price – `bin/add-price`

`bin/add-price` takes the output of `compute-realized`, `add-unrealized`, or any compatible consolidated positions CSV with a header, looks up the daily closing price for each symbol from OHLCV files, and appends a `Price` column.

Usage:

```bash
bin/add-price \
  -v date=YYYY-MM-DD \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_unrealized_positions.csv > tmp_unrealized_with_price.csv
```

Where:

- `date` is the trading date in `YYYY-MM-DD` format.
- `ohlcv_dir` is the directory containing `TICKER_Daily_YYYY.csv`.

Requirements:

- OHLCV filename: `TICKER_Daily_YYYY.csv`.
- OHLCV format: `Date,Open,High,Low,Close,Volume`.
- The script uses the first field as date and the fifth field as the closing price.

Behavior:

- The script reads the input header and appends a new column named `Price`.
- For each input row, it uses the symbol in the `INSTRUMENT` column and constructs a file path of the form:

```text
${OHLCV_DIR}/TICKER_Daily_YYYY.csv
```

- It scans the OHLCV file for the requested `date` and appends the corresponding `Close` value.
- The current implementation only performs the lookup when `QUANTITY > 0`; for short or flat rows, the appended `Price` value remains `0`.
- If no matching file or date is found, the appended `Price` value remains `0`.

Example:

```bash
bin/add-unrealized \
  -v date="$DATE_YMD" \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_realized.csv \
| bin/add-price -v date="$DATE_YMD" -v ohlcv_dir="$OHLCV_DIR" \
> tmp_unrealized_price.csv
```

***

## Average True Range – `bin/add-atr`

`bin/add-atr` takes the output of `bin/add-unrealized`, `bin/add-price`, or any compatible consolidated positions CSV with a header, looks up ATR values from per-symbol ATR files, and appends an `ATR(n)` column.

Usage:

```bash
bin/add-atr \
  -v date=YYYY-MM-DD \
  -v atr_dir="$ATR_DIR" \
  -v n=14 \
  tmp_unrealized_positions.csv > tmp_unrealized_with_atr.csv
```

Where:

- `date` is the trading date in `YYYY-MM-DD` format.
- `atr_dir` is the directory containing ATR files.
- `n` is the ATR period, for example `14` or `20`.

Requirements:

- ATR filename: `TICKER_N_Daily_YYYY.csv`.
- ATR file format: `YYYY-MM-DD,ATR`.
- The script uses the first field as date and the second field as the ATR value.

Behavior:

- The script reads the input header and appends a new column named `ATR(n)`.
- For each input row, it uses the symbol in the `INSTRUMENT` column and constructs a file path of the form:

```text
${ATR_DIR}/TICKER_N_Daily_YYYY.csv
```

- It then scans the ATR file for the requested `date` and appends the corresponding ATR value.
- If no matching file or date is found, the appended ATR value remains `0`.

Example:

```bash
bin/add-unrealized \
  -v date="$DATE_YMD" \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_realized.csv \
| bin/add-atr -v date="$DATE_YMD" -v atr_dir="$ATR_DIR" -v n=14 \
> tmp_unrealized_atr.csv
```
***


## Drawdowns and runups – `bin/add-ddru`

`bin/add-ddru` enriches consolidated positions (typically the output of `add-unrealized`) with drawdown and runup state, using metadata and OHLCV data.

Usage:

```bash
TZ=America/New_York \
bin/add-ddru \
  -v date=YYYY-MM-DD \
  -v meta_file="$META_FILE" \
  -v ohlcv_dir="$OHLCV_DIR" \
  -v update=1 \
  tmp_unrealized_positions.csv > tmp_positions_with_ddru.csv
```

Inputs:

- `date` – trading date to process.
- `meta_file` – path to metadata file with `INSTRUMENT:TIMESTAMP` and `INSTRUMENT:META` rows.
- `ohlcv_dir` – directory with `TICKER_Daily_YYYY.csv`.
- `update` – if `1`, updates `meta_file` in place (DD/RU state and consumption of intraday keys).

Output columns (appended):

```csv
DD,RU,LOW,HIGH,DD++?,RU++?
```

Semantics:

- For each consolidated position row (one per symbol):
    - Reads same-day `INSTRUMENT:TIMESTAMP` rows for that symbol from `meta_file` and computes a quantity-weighted intraday low/high based on those fills.
    - Reads existing `INSTRUMENT:META` state, if any, to get prior `DD`, `RU`, and `Q`.
    - Determines the position side (`>0` long, `<0` short).
    - If the prior quantity and current quantity have the **same sign**, the script:
        - Updates `DD` and `RU` using:
            - Intraday adverse and favorable extremes from metadata.
            - Daily `High`/`Low` from OHLCV for that symbol and date.
        - Marks `DD++?` and `RU++?` as `1` if the new `DD` or `RU` are different from the prior state.
    - If the prior and current quantities are of **different signs** (flip through zero), or there was no prior `META` state:
        - Treats the day as a new regime for DD/RU.
        - Seeds `DD` and `RU` from intraday data (and possibly OHLCV), but does **not** mark `DD++?` or `RU++?` as changes relative to prior state (`DD++? = 0`, `RU++? = 0`).
    - Emits `LOW` and `HIGH` as:
        - The intraday quantity-weighted low/high if there were same-day fills.
        - Otherwise, the OHLCV day low/high if available.
        - Otherwise, `0` if no data.
- If `update == 1`, it:
    - Writes back the new `INSTRUMENT:META` state row.
    - Clears `HIGH`/`LOW` keys from per-fill `INSTRUMENT:TIMESTAMP` records that have been consumed.

This makes `meta_file` reflect the latest DD/RU state and avoids double-counting intraday fills across runs.

***


## Account balance – `bin/get-balance`

`bin/get-balance` consumes the output of `add-unrealized` (or `add-ddru`, which carries forward the same columns) and produces `YYYY-MM-DD,Balance` for a point in time.

Usage:

```bash
bin/get-balance \
  -v balance=10000 \
  -v ts="$(date -d '2026-07-22T17:30:00-04:00' '+%s')" \
  tmp_unrealized_positions.csv
```

Behavior:

- Treats the initial `balance` as starting equity.
- For each row:
    - Adds `REALPL + UNRPL - COMMISSION` to the running balance.
    - Tracks the maximum `TIMESTAMP` observed.
- At `END`, prints:

```text
YYYY-MM-DD,Balance
```


Where `YYYY-MM-DD` is derived from the maximum timestamp, and `Balance` is the final equity including realized and unrealized P\&L up to that timestamp.

***


## End-to-end daily example

A typical daily flow might look like:

```bash
cd Positions-Log

# 1. Load environment
source env.sh

# 2. Interactively enter one or more trades
. bin/enter-trade

# 3. Choose the evaluation datetime (end of day)
DATE_TS="2026-07-22T16:30:00-04:00"
DATE_YMD="$(date -d "$DATE_TS" '+%Y-%m-%d')"
START_TS="$(date -d '2026-01-01T09:30:00-05:00' '+%s')"
END_TS="$(date -d "$DATE_TS" '+%s')"

# 4. Compute realized P&L over the date range
bin/compute-realized \
  -v start_ts="$START_TS" \
  -v end_ts="$END_TS" \
  "$JOURNAL" > tmp_realized.csv

# 5. Compute unrealized P&L at daily close
bin/add-unrealized \
  -v date="$DATE_YMD" \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_realized.csv > tmp_unrealized.csv

# 6. Append closing price
bin/add-price \
  -v date="$DATE_YMD" \
  -v ohlcv_dir="$OHLCV_DIR" \
  tmp_unrealized.csv > tmp_unrealized_price.csv

# 7. Append ATR(14)
bin/add-atr \
  -v date="$DATE_YMD" \
  -v atr_dir="$ATR_DIR" \
  -v n=14 \
  tmp_unrealized_price.csv > tmp_unrealized_price_atr.csv

# 8. Compute per-position DD/RU and append state
TZ=America/New_York \
bin/add-ddru \
  -v date="$DATE_YMD" \
  -v meta_file="$META_FILE" \
  -v ohlcv_dir="$OHLCV_DIR" \
  -v update=1 \
  tmp_unrealized_price_atr.csv > tmp_positions.csv

# 9. Compute account balance at ts
bin/get-balance \
  -v ts="$END_TS" \
  -v balance=10000 \
  tmp_unrealized_price_atr.csv
```

***

## Idempotency and behavior notes

- Journal rows are de-duplicated by `EXCHANGE_EXEC_ID` before append.
- `enter-trade` keeps the journal sorted by `TIMESTAMP` after each insert.
- `add-unrealized` only computes unrealized P\&L when `QUANTITY != 0` and a valid `Close` price exists; otherwise, `UNRPL` is `0`.
- `add-ddru` only treats daily DD/RU changes as “++” relative to prior state when the position stays on the same side; flips through zero are treated as new regimes for DD/RU.
- `get-balance` is a pure reducer: given a starting `balance` and a stream of positions with realized/unrealized P\&L, it outputs a single `date,balance` tuple.
- `add-atr` requires both `date` and `n`; it appends a column named `ATR(n)` and emits `0` when no ATR file entry matches the symbol/date combination.
- `add-price` requires `date`; it appends a `Price` column from the OHLCV `Close` field and currently only performs the lookup when `QUANTITY != 0`, otherwise emitting `0`.
