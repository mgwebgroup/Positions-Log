# Intro

## Files

The script uses two csv files: journal entries and meta data. Position entries file  assigned to the $JOURNAL variable. Position meta entries are stored in a e file assigned to $META_FILE variable.

Journal entries example:

```
# file Data/Positions/Journal_2026.csv:
TIMESTAMP,INSTRUMENT,QUANTITY,PRICE,CURRENCY,COMMISSION,EXCHANGE_EXEC_ID,ORDER_ID,ACCOUNT_NO,EXCHANGE_NAME,CUSIP
1767369650,PANW,-10,178.99,USD,0.354207,376654950S,0036BA34.00031198.6957591D.0001,
1767623401,COIN,-6,247.50,USD,0.352627,0308193782,0036BA34.00031198.695B4ABA.0001,
...
```

Meta file example:
```
# file Data/Positions/meta.csv
PANW:1767369650,DD:180,RU:170,SL:200,PT:150,Q:-10
```

While fields of the journal file are self-explanatory, fields of the meta file mean the following:
TICKER:TIMESTAMP    - unique key identifying ticker and position entry
DD                  - Max drawdown for a position
RU                  - Max runup for a position
SL                  - Stop loss
PT                  - Price target
Q                   - Quantity, with negative values indicating short positions




## Idempotency

Journal entries shall not have rows with same EXCHANGE_EXEC_ID. If a row is entered with already existing EXCHANGE_EXEC_ID, it'll override existing row.

Meta file entries shall not have rows with same TICKER:TIMESTAMP labels.


# Configuration

Open up env.sh file and enter paths for the journal and meta files.

Set default values for timezone, comission, currency, order_id, account number. 

Timezone must be entered as offset from UTC, like '-04:00'.

Example:

TIMEZONE='-04:00'
COMMISSION=0.35
CURRENCY=USD
ORDER_ID='0036ba34'
ACCOUNT_NO=ABCD1

Make sure default values pass validation regexes located in lib/bash/validation.sh

