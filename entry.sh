#! /usr/bin/env bash

set -euo pipefail

source env.sh
source lib/bash/validation.sh

order_date="$(date +%Y-%m-%dT09:30:00${TIMEZONE})"  # default prompt for order date
header_fields="TIMESTAMP,INSTRUMENT,QUANTITY,PRICE,CURRENCY,COMMISSION,EXCHANGE_EXEC_ID,ORDER_ID,ACCOUNT_NO,EXCHANGE_NAME,CUSIP"


Error() {
	printf "ERROR!\n" >&2
	printf "%b" "$1" >&2
	printf "\n" >&2
	exit $2
}

Warning() {
	printf "WARNING!\n" >&2
	printf "%b" "$1" >&2
	printf "\n" >&2
}

input_fields () {
	while : ; do
		read -e -i "${order_date}" -p ORDER_DATE: order_date
		TIMESTAMP=$(date -d "${order_date}" +%s)
		validate_timestamp && break
		Warning "ORDER_DATE '${order_date}' is invalid."
	done

	while : ; do
		read -e -p INSTRUMENT: INSTRUMENT
		INSTRUMENT=${INSTRUMENT^^}
		validate_instrument && break
		Warning "INSTRUMENT field '$INSTRUMENT' is invalid."
	done

	while : ; do
		read -e -p QUANTITY: QUANTITY
		validate_quantity && break
		Warning "QUANTITY field '$QUANTITY' is invalid."
	done

	while : ; do
		read -e -p PRICE: PRICE
		validate_price && break
		Warning "PRICE field '$PRICE' is invalid."
	done

	while : ; do
		read -e -p CURRENCY: -i USD CURRENCY
		CURRENCY=${CURRENCY^^}
		validate_currency && break
		Warning "CURRENCY field '$CURRENCY' is invalid."
	done

	while : ; do
		read -e -i "${COMMISSION}" -p COMMISSION: COMMISSION
		validate_commission && break
		Warning "COMMISSION field '$COMMISSION' is invalid."
	done

	while : ; do
		read -e -p EXCHANGE_EXEC_ID: EXCHANGE_EXEC_ID
		EXCHANGE_EXEC_ID=${EXCHANGE_EXEC_ID^^}
		validate_exchange_exec_id && break
		Warning "EXCHANGE_EXEC_ID field '$EXCHANGE_EXEC_ID' is invalid."
	done

	while : ; do
		read -e -i "${ORDER_ID}" -p "ORDER_ID:" ORDER_ID
		ORDER_ID=${ORDER_ID^^}
		validate_order_id && break
		Warning "ORDER_ID field '$ORDER_ID' is invalid."
	done

	while : ; do
		read -e -i "${ACCOUNT_NO}" -p "ACCOUNT_NO:" ACCOUNT_NO
		ACCOUNT_NO=${ACCOUNT_NO^^}
		validate_account_no && break
		Warning "ACCOUNT_NO field '$ACCOUNT_NO' is invalid."
	done

	while : ; do
		read -e -i "${EXCHANGE_NAME}" -p "EXCHANGE_NAME:" EXCHANGE_NAME
		EXCHANGE_NAME=${EXCHANGE_NAME^^}
		validate_exchange_name && break
		Warning "EXCHANGE_NAME field '$EXCHANGE_NAME' is invalid."
	done
}

# create journal file if does not exist
if [[ ! -f "$JOURNAL" ]] ;then 
	# [[ -n "${EXTRA_FIELDS}" ]] && header_fields=${header_fields},${EXTRA_FIELDS}
	echo "$header_fields" > "$JOURNAL"
fi

while : ; do
	input_fields

	# delete rows with same EXCHANGE_EXEC_ID if found
	sed -i -E "/,${EXCHANGE_EXEC_ID},/d" "${JOURNAL}"

	# add_record
	printf "${TIMESTAMP},${INSTRUMENT},%i,%0.2f,${CURRENCY},%0f,${EXCHANGE_EXEC_ID},${ORDER_ID},${ACCOUNT_NO},${EXCHANGE_NAME},${CUSIP}\n" ${QUANTITY} ${PRICE} ${COMMISSION} >> "${JOURNAL}"

	# sort
	{ head -n1 "${JOURNAL}"; tail -n +2 "${JOURNAL}" | sort -t, -n -k1,1 ; } >"${JOURNAL}.tmp" && mv "${JOURNAL}.tmp" "${JOURNAL}"

	# Remove blank lines
	sed -i -e '/^$/d' "${JOURNAL}"

	read -e -p "Enter meta information? [y]es/no:" REPLY 
	if [[ $REPLY =~ ^([Yy]|[Yy][Ee][Ss])$ ]] ; then
		( source meta.sh )
	fi

	read -e -p "Enter one more record? [y]es/no: " REPLY && [[ $REPLY =~ ^([Yy]|[Yy][Ee][Ss])$ ]] || break
done

