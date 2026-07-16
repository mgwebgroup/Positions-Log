# Trade Journal and P&L Toolkit

A small shell and AWK toolkit for recording trade executions, attaching lightweight per-position metadata, and computing realized and unrealized P&L from a CSV journal.

The package is organized around two ideas:

- `bin/enter-trade` appends validated executions to a journal CSV and keeps the file sorted by timestamp.
- `bin/enter-meta` captures additional trade metadata such as stop loss, intraday high, intraday low, price target, and quantity for the just-entered trade.

The analytics layer is implemented in AWK:

- `bin/compute-realized_pl` consolidates journal entries into per-symbol position state and realized P&L
- `bin/compute-unrealized_pl` enriches those consolidated positions with closing prices from OHLCV files and computes unrealized P&L.


## Package layout

```text
├── bin
│   ├── enter-trade
│   ├── enter-meta
│   ├── compute-realized
│   ├── compute-unrealized
│   ├── env.sh
│   └── env.sh.example
├── lib
│   └── bash
│      └── validation.sh
├── LICENSE
└── README.md
```


## Data files

The package works with local data files configured through environment variables:

- `JOURNAL` points to the trade journal CSV.
- `META_FILE` points to the metadata file used by `enter-meta`.
- `OHLCV_DIR` points to directory with OHLCV files.

OHLCV files must be named as: `TICKER_Daily_YYYY.csv`.
The journal file is created automatically if it does not exist, with the following header:

```csv
TIMESTAMP,INSTRUMENT,QUANTITY,PRICE,CURRENCY,COMMISSION,EXCHANGE_EXEC_ID,ORDER_ID,ACCOUNT_NO,EXCHANGE_NAME,CUSIP
```

Example journal rows:

```csv
1767369650,PANW,-10,178.99,USD,0.354207,376654950S,0036BA34.00031198.6957591D.0001,U1451183,IBKRATS,
1767623401,COIN,-6,247.50,USD,0.352627,0308193782,0036BA34.00031198.695B4ABA.0001,U1451183,IBKRATS,
```

The metadata file is a plain text file with one row per keyed trade entry. The current `enter-meta` implementation stores rows in this format:

```text
<INSTRUMENT>:<TIMESTAMP>,SL:<PRICE>,HIGH:<PRICE>,LOW:<PRICE>,PT:<PRICE>,Q:<QUANTITY>
```

Example:

```text
PANW:1767369650,SL:200.00,HIGH:180.00,LOW:170.00,PT:150.00,Q:-10
```

Field meanings:

- `SL`: stop loss.
- `HIGH`: intraday high recorded at entry time.
- `LOW`: intraday low recorded at entry time.
- `PT`: price target.
- `Q`: quantity; negative values represent short positions, matching the journal convention.



## Configuration

Copy `env.sh.example` to `env.sh` or edit `env.sh` directly and set the file paths and defaults used by the entry workflow.

Typical variables include:

```bash
JOURNAL=/absolute/path/to/Data/Positions/Journal_2026.csv
META_FILE=/absolute/path/to/Data/Positions/meta.csv
OHLCV_DIR=/absolute/path/to/OHLCV/dir"

TIMEZONE='-04:00'
COMMISSION='0.35'
CURRENCY=USD
ORDER_ID='abcdef01.02030405.abddef' # first digits usually are repeatable
ACCOUNT_NO=ABCD1
EXCHANGE_NAME=IBKRATS
```

Notes:

- `TIMEZONE` should be specified as a UTC offset such as `-04:00`.
- Default values should satisfy the regex and numeric checks implemented in `lib/bash/validation.sh`.
- `CUSIP` is present in the journal schema, but the sample workflow allows it to be blank.



## Typical usage

### 1. Enter a trade

Run the main entry script:

```bash
./bin/enter-trade
```

The script interactively prompts for:

- `ORDER_DATE`, which is converted to Unix timestamp and stored as `TIMESTAMP`.
- `INSTRUMENT`.
- `QUANTITY`.
- `PRICE`.
- `CURRENCY`.
- `COMMISSION`.
- `EXCHANGE_EXEC_ID`.
- `ORDER_ID`.
- `ACCOUNT_NO`.
- `EXCHANGE_NAME`.

After input is validated, `enter-trade` removes any existing journal row with the same `EXCHANGE_EXEC_ID`, appends the new row, sorts the journal by timestamp, and removes blank lines. This makes journal entry idempotent with respect to execution ID. 


### 2. Enter metadata for the trade

After the execution is written, `enter-trade` asks whether to enter metadata. If the answer is yes, it sources `enter-meta`.

`enter-meta` prompts for:

- `SL` (stop loss).
- `Intraday High`.
- `Intraday Low`.
- `Price Target`.

As opposed to `enter-trade` rule on idempotency, `enter-meta` allows for multiple entries with same `<INSTRUMENT>:<TIMESTAMP>` keys. This is because brokers may split an order and route it to several exchanges. In this way, execution time may be same, yet `EXCHANGE_EXEC_ID` will be always unique.


### 3. Enter another trade

At the end of each loop, `enter-trade` asks whether to enter one more record and repeats the process until the answer is no.



## Realized P&L

`bin/compute-realized` reads the journal and emits consolidated per-symbol position state with realized P&L. The output columns are:

```csv
TIMESTAMP,INSTRUMENT,QUANTITY,AVG_BASE_PRICE,CURRENCY,COMMISSION,REAL_P&L
```

The script is intended to be run with a start and end Unix timestamp and a journal path:

```bash
./bin/compute-realized \
  start_ts=$(date -d '2026-01-01T09:30-05:00' +%s) \
  end_ts=$(date +%s) \
  /absolute/path/to/Data/Positions/Journal_2026.csv
```

What it does:

- Reads journal rows after the header.
- Filters rows to `start_ts <= TIMESTAMP <= end_ts`.
- Aggregates quantity by symbol.
- Maintains an average base price for the open position.
- Accumulates realized P&L when trades reduce, close, or reverse an existing position.

The script also documents a manual reset convention: to reset quantity for a symbol, insert a journal row with that symbol and `0` quantity, leaving the remaining fields empty.

Example reset row:

```csv
1763728636,ORCL,0,,,,,,,
```

Example: save realized P&L output to a file for later use:

```bash
./bin/compute-realized \
  start_ts=$(date -d '2026-01-01T09:30-05:00' +%s) \
  end_ts=$(date +%s) \
  "$JOURNAL" > /tmp/realized_positions.csv
```

## Unrealized P&L

`bin/compute-unrealized` takes the consolidated output of `compute-realized`, looks up a closing price for each symbol from per-ticker OHLCV files, and appends unrealized P&L and Price columns.

Expected invocation:

```bash
./bin/compute-unrealized \
  -v date=YYYY-MM-DD \
  -v ohlcv_dir=/absolute/path/to/OHLCV \
  /path/to/consolidated_positions.csv
```

Requirements for OHLCV files:

- Files must live under the directory passed as `ohlcv_dir`.
- File names must follow `TICKER_Daily_YYYY.csv`.
- File format must be `Date,Open,High,Low,Close,Volume`.
- The script uses the fifth field, `Close`, to compute unrealized P&L.

Example OHLCV file name:

```text
AAPL_Daily_2026.csv
```

Example OHLCV row:

```csv
2026-07-13,210.00,214.20,208.50,213.75,51234000
```

The script appends two columns to the realized P&L output:

- `CLOSING_P`
- `UNR_P&L`

Example invocation:

```bash
./bin/compute-unrealized \
  -v date=2026-07-13 \
  -v ohlcv_dir="$(realpath /absolute/path/to/Data/OHLCV)" \
  /tmp/realized_positions.csv > /tmp/unrealized_positions.csv
```

The `date` value may also be supplied through the `DATE` environment variable; a command-line `-v date=...` value takes precedence.


## End-to-end example

A typical workflow looks like this:

```bash
# 1. Enter one or more trades interactively
./bin/enter-trade

# 2. Compute realized P&L over a date range
./bin/compute-realized \
  start_ts=$(date -d '2026-01-01T09:30-05:00' +%s) \
  end_ts=$(date +%s) \
  "$JOURNAL" > /tmp/realized_positions.csv

# 3. Compute unrealized P&L for a closing date using OHLCV files
./bin/compute-unrealized \
  -v date=2026-07-13 \
  -v data_dir="/absolute/path/to/OHLCV" \
  /tmp/realized_positions.csv > /tmp/unrealized_positions.csv
```


## Idempotency and behavior

- Journal rows are de-duplicated by `EXCHANGE_EXEC_ID` before append.
- Newly entered metadata rows are allowed with same `<INSTRUMENT>:<TIMESTAMP>` key.
- `enter-trade` keeps the journal sorted by timestamp after each insert.
- Unrealized P&L is only computed when the consolidated position quantity is non-zero and a positive closing price is found for the requested date.


## Assumptions and caveats

- The README reflects the current attached implementation, including the existing metadata key format used by `enter-meta`.
- `bin/compute-realized` expects a headered journal CSV and processes rows by symbol over a timestamp interval.
- `bin/compute-unrealized` expects one OHLCV file per symbol per year and does a direct date match on the first field.
- If an OHLCV file is missing or the date is absent, the script will not be able to produce a valid closing-price-based unrealized P&L for that symbol. It will have a '0' value instead.

