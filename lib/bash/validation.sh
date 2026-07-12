# All validations functions use global vars
# return values are 0 if validation successful, 1 if failed

declare -Ax regex	# declare associative array to store allowed regexes for each field
regex=(
	[ts]="[0-9]+" 
	[instrument]="[A-Z]{1,5}([.-][A-Z]{1,3})?"
   	[quantity]="[+-]?[0-9]+"
   	[price]="([0-9]+(\.[0-9]+)?|\.[0-9]+)"
   	[currency]="USD"
   	[exchange_exec_id]="[\.:#A-Z0-9_\-]{7,}"
   	[order_id]="[A-Z0-9]{8}.[A-Z0-9]{8}.[A-Z0-9]{8}.[A-Z0-9]{4}"
   	[account_no]="[A-Za-z0-9]{4,}"
)

validate_timestamp () {
	[[ $TIMESTAMP =~ ^${regex[ts]}$ ]] || return 1
	# Do not accept dates before 01-01-1997 
	(( $TIMESTAMP > 852076800 )) || return 1
}

validate_instrument () {
	# Covers typical NYSE/Nasdaq symbols and common dot/dash extensions such as class or warrant markers while rejecting digits and spaces
	local s=${INSTRUMENT^^}
	[[ $s =~ ^${regex[instrument]}$ ]] && return 0 || return 1
}

validate_quantity () {
	[[ $QUANTITY =~ ^${regex[quantity]}$ ]] || return 1
	[[ $QUANTITY -eq 0 ]] && return 1
	return 0
}

validate_price () {
	[[ $PRICE =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_currency () {
	local s=${CURRENCY^^}
	[[ $s =~ ^${regex[currency]}$  ]] && return 0 || return 1
}

validate_commission () {
	[[ $COMMISSION =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_exchange_exec_id () {
	if [ $EXCHANGE_EXEC_ID ] ; then 
		local s=${EXCHANGE_EXEC_ID^^}
		[[ $s =~ ^${regex[exchange_exec_id]}$ ]] && return 0 || return 1
	fi
	return 0
}

validate_order_id () {
	if [ $ORDER_ID ] ; then
		local s=${ORDER_ID^^}
		[[ $s =~ ^${regex[order_id]}$ ]] && return 0 || return 1
	fi
	return 0
}

validate_sl () {
	[[ $SL =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_intrahigh () {
	[[ -z $INTRAHIGH ]] && return 0
	[[ $INTRAHIGH =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_intralow () {
	[[ -z $INTRALOW ]] && return 0
	[[ $INTRALOW =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_pt () {
	[[ $PT =~ ^${regex[price]}$ ]] && return 0 || return 1
}

validate_account_no () {
	if [ $ACCOUNT_NO ] ; then 
		[[ $ACCOUNT_NO =~ ^${regex[account_no]}$ ]] && return 0 || return 1
	fi
	return 0
}

