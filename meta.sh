#! /bin/bash

# This script handles entry of meta data for a position.
# It must be sourced into the parent position entry script.

SL=
INTRAHIGH=
INTRALOW=
PT=

[[ ! -f "${META_FILE}" ]] && touch "${META_FILE}"

while : ; do
	read -e -p SL: SL
	validate_sl && break
	Warning "Stop loss field '$SL' is invalid."
done

while : ; do
	read -e -p "Intraday High:" INTRAHIGH
	validate_intrahigh && break
	Warning "Intraday High field '$INTRAHIGH' is invalid."
done

while : ; do
	read -e -p "Intraday Low:" INTRALOW
	validate_intralow && break
	Warning "Intraday Low field '$INTRALOW' is invalid."
done

while : ; do
	read -e -p "Price Target:" PT
	validate_pt && break
	Warning "Price Target field '$PT' is invalid."
done

# delete rows with same <INSTRUMENT>:<TIMESTAMP> if found
sed -i -E "/^${INSTRUMENT}:${TIMESTAMP},/d" "${META_FILE}"

# add_record
printf "${INSTRUMENT}:${TIMESTAMP},SL:%0.2f,HIGH:%0.2f,LOW:%0.2f,PT:%0.2f,Q:%i\n" ${SL} ${INTRAHIGH} ${INTRALOW} ${PT} ${QUANTITY} >> "${META_FILE}"

