#!/bin/sh
. /tmp/loader

if [ -z "$1" -a -n "$REMOTE_ADDR" ]; then
	eval $( _http query_string_sanitize )		# ACTION=... MAC=... IP_USER=... HASH=... // ( TUNNEL_ID=... | IP_ROUTER=$REMOTE_ADDR )
	_http header_mimetype_output "text/plain"
else
	ACTION="$1"
fi

_log do tunnel_helper daemon info "REMOTE_ADDR: $REMOTE_ADDR - ACTION: $ACTION - QUERY: $QUERY_STRING"

throw_error_and_exit()
{
	echo "FALSE=;"
	exit
}

case "$ACTION" in
	tunnel_disconnect)
			:
	;;
	tunnel_possible)
		if _tunnel check_local_capable ; then

			case "$REMOTE_ADDR" in
				$LANADR|$WANADR|$LOADR)
					throw_error_and_exit
				;;
			esac

			_watch counter "/tmp/tunnel_id" increment 1 max 65 || {		# fixme! set to 0 during nightly/kick_user_all()
				throw_error_and_exit
			}
			read TUNNEL_ID <"/tmp/tunnel_id"

	#		eval $( _tunnel get_speed_for_hash "$HASH" "$MAC" )

			case "$MAC" in
				00:08:c6*)				# SIP test
					SPEED_UPLOAD="80"		# G.711a = 80kbit up + 80kbit down => RTP: 172 Bytes UDP - 28 Bytes UDP overhead = 144 Bytes DATA * 56 Packets = 8064 Bytes/s = 56 * 172 = 9632 bytes/s = 77.056 bit/s
					SPEED_DOWNLOAD="80"		# G.729 = 20 kbit up + 20 kbit down | UDP = 8 Byte Header? -> 8000 Byte/s / (172byte-8byte_udp_header) = 49 pakete * 172 byte = 67424 bit/s
				;;
				*)
					SPEED_UPLOAD="64"		# ACK_only  = 40 Bytes / MTU = 1450 Bytes, so 145.000 Bytes / needs 4000 Bytes Ack or:
					SPEED_DOWNLOAD="1024"		# 512 kbit = 64 KB/s @ 46 packets/s(MTU) -> 46 * 40 Bytes ACK = 1840 Bytes/s = 14,7 kbit/s upload -> 16
				;;					# make a function!
			esac

			echo -n "TRUE=;"
			echo -n "SPEED_UPLOAD=$SPEED_UPLOAD;"
			echo -n "SPEED_DOWNLOAD=$SPEED_DOWNLOAD;"
			echo -n "TUNNEL_IP_CLIENT=$( _tunnel id2ip $TUNNEL_ID client );"
			echo -n "TUNNEL_IP_SERVER=$( _tunnel id2ip $TUNNEL_ID server );"
			echo    "TUNNEL_MASK=30;"

			_tunnel config_insert_new_client "$TUNNEL_ID" "$MAC" "$IP_USER" "$SPEED_UPLOAD" "$SPEED_DOWNLOAD"
			_tunnel config_rebuild "ignore_intranet_traffic"	>"/tmp/tunnel/vtun_server.conf"
			_tunnel daemon_apply_config				 "/tmp/tunnel/vtun_server.conf"
		else
			throw_error_and_exit
		fi
	;;
	*)
		throw_error_and_exit
	;;
esac
