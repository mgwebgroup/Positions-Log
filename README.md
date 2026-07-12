# Intro

## Files

The script uses two csv files. Position entries are stored in journal entries file assigned to the $JOURNAL variable. Meta data entries for each position are stored in a data cache file assigned to $DATA_CACHE variable.

Journal entries example:

```
# file Data/Positions/Journal_2026.csv:
TIMESTAMP,INSTRUMENT,QUANTITY,PRICE,CURRENCY,COMMISSION,EXCHANGE_EXEC_ID,ORDER_ID,REAL_P&L
1767369650,PANW,-10,178.99,USD,0.354207,376654950S,0036BA34.00031198.6957591D.0001,
1767623401,COIN,-6,247.50,USD,0.352627,0308193782,0036BA34.00031198.695B4ABA.0001,
...
```

Data cache example:
```
# file Data/Cache/cache.csv
GOOG:DDRU,Q:3,DD:341.22,RU:370.89
GOOG:META,Q:3,SL:340,PT:380
MSFT:DDRU,Q:10,DD:371.236,RU:394.082
MSFT:META,Q:10,SL:365.186,PT:412

```

## Idempotency

Journal entires shall not have rows with same EXCHANGE_EXEC_ID. If a row is entered with already existing EXCHANGE_EXEC_ID, it'll override existing row.


# Configuration

Open up env.sh file and enter paths for the journal and data cache files.

Set default values for timezone, comission, currency, order_id, account number. 

Timezone must be entered as offset from UTC, like '-04:00'.

Example:

TIMEZONE='-04:00'
COMMISSION=0.35
CURRENCY=USD
ORDER_ID='0036ba34'
ACCOUNT_NO=ABCD1

Make sure default values pass validation regexes located in lib/bash/validation.sh



