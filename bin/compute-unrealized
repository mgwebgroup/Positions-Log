#! /usr/bin/awk -f 
# This program reads consolidated positions produced by "realized_pl.awk" script
# and computes unrealized P&L per symbol using OHLCV data files saved in
# directory of your choice. It also adds columns with closing price and unrealized
# P&L.
#  
# Usage:
# ./unrealized_pl.awk \
#   -v date=YYYY-MM-DD \
#   -v ohlcv_dir=OHLCV/Data/Dir \
#   Path/to/consolidated/positions/file
#
# Where:
#   date - Date for which to output unrealized P&L in YYYY-MM-DD format. 
#     This value will be looked up directly as a first field in OHLCV file. 
#     Do not use any other format.
#     You can also use `export DATE='2025-12-06'` and omit date variable assignment 
#     for awk - it will use the exported DATE variable from the shell environment.
#     Assigning date on command line at script invocation will override environment
#     variables.
#   ohlcv_dir - Path to OHLCV files. They must be named as TICKER_Daily_YYYY.csv
#     You can also use `export OHLCV_DIR=path/to/OHLCV/files` to omit assignment of
#     the ohlcv_dir variable via '-v' option.
# TICKER_Daily_YYYY.csv files must be in format:
# Date,Open,High,Low,Close,Volume
# Column that is used in this script is "Close" and must be present as 5th field.
# Other columns are not used.


BEGIN {
	FS=","
	OFS=","

	if ("DATE" in ENVIRON)
		date = ENVIRON["DATE"]
	if ("OHLCV_DIR" in ENVIRON)
		ohlcv_dir = ENVIRON["DATA_DIR"]
}

NR == 1 {
	print $0, "CLOSING_P", "UNR_P&L"
	split(date, parts, "-")
	}

NR > 1 {
	i = $2
	ts = $1
	q = $3
	base_p = $4
	curr = $5
	comm = $6
	record = $0
	closing_p = 0
	real_pnl = $7
	unr_pnl = 0

	file_name = ohlcv_dir "/" i "_Daily_" parts[1] ".csv"
	while ((getline < (file_name)) > 0) {
		if (date == $1) {
			closing_p = $5
		}
	}
	close(file_name)
	
	if (q != 0) {
		if (closing_p > 0)
			unr_pnl = (closing_p - base_p) * q
	}

	printf "%s,%0.2f,%0.2f\n", record, closing_p, unr_pnl
}

