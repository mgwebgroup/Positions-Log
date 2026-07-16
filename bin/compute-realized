#! /usr/bin/awk -f 
# This program reads trading journal entries from data file argument and creates summary output per symbol.
# Supported output format for now is csv. Columns output are:
# TIMESTAMP,INSTRUMENT,QUANTITY,AVG_BASE_PRICE,CURRENCY,COMMISSION,REAL_P&L
# 1769014792,HALO,0,71.67,USD,1.46,31.30
# 1781805281,COIN,0,163.60,USD,1.45,-17.40
# ... 
# 
# Usage:
# To list Realized P&L from January 1 2020 to present day:
# ./realized_pl.awk start_ts=$(date -d 2020-01-01T09:30-05:00 +%s) end_ts=$(date +%s) Data/Positions/Journal_2025.csv 
#   start_ts - start Unix timestamp to process journal entries from (inclusive). Specify NYC timezone if using "date -d ..."
#   end_ts  - end Unix timestamp to process journal entries to (inclusive). Specify NYC timezone if using "date -d ..." 
#   last argument is path to file of journal entries (trades). It must have header.
#
# To reset quantity for a symbol, include string with appropriate timestamp, symbol name, 0 quantity, and empty fields for everything else, like so:
# 1763728636,ORCL,0,,,,,,,
#

function abs(n) {
	if (n < 0) return -n
	return n
}

BEGIN {
	FS=","
	print "TIMESTAMP,INSTRUMENT,QUANTITY,AVG_BASE_PRICE,CURRENCY,COMMISSION,REAL_P&L"
}

NR > 1 {
	ts = $1
	i = $2
	dq = $3
	p = $4
	curr = $5
	_comm = $6
	exchange_exec_id = $7
	order_id = $8
	_real_pnl = $9

	if (start_ts <= ts && ts <= end_ts) {
		timestamp[i] = ts
		if ( (exchange_exec_id order_id) != "" ) {
			if (q[i] * dq >= 0) {
				avg_base_p[i] = (avg_base_p[i] * abs(q[i]) + abs(dq) * p ) / abs(q[i] + dq)
			} else {
				# transactions transiting 0 get their base p reset to new transaction's value
				new_q = q[i] + dq
				if (new_q * q[i] <= 0) {
					real_pnl[i] += q[i] * (p - avg_base_p[i])
					avg_base_p[i] = p
				} else {
					real_pnl[i] += (avg_base_p[i] -p) * dq
				}
			}
			comm[i] += _comm
		} else {
			q[i] = 0
			avg_base_p[i] = p
			real_pnl[i] = _real_pnl
			comm[i] = _comm
		}
		q[i] += dq
		#real_pnl[i] -= comm[i]
	}
}

END {
	for (i in avg_base_p) {
		printf "%d,%s,%i,%0.2f,%s,%0.2f,%0.2f\n", timestamp[i], i, q[i], avg_base_p[i], curr, comm[i], real_pnl[i]
	}
}

