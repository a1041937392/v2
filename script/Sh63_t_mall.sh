#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
tmall_enable=`nvram get app_55`
[ -z $tmall_enable ] && tmall_enable=0 && nvram set app_55=0
tmall_id=`nvram get app_56`
if [ "$tmall_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep tmall | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

tmall_renum=`nvram get tmall_renum`

cmd_log_enable=`nvram get cmd_log_enable`
cmd_name="tmall"
cmd_log=""
if [ "$cmd_log_enable" = "1" ] || [ "$tmall_renum" -gt "0" ] ; then
	cmd_log="$cmd_log2"
fi

fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep t_mall)" ]  && [ ! -s /tmp/script/_app13 ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_app13
	chmod 777 /tmp/script/_app13
fi

tmall_restart () {

relock="/var/lock/tmall_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set tmall_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【tmall】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	tmall_renum=${tmall_renum:-"0"}
	tmall_renum=`expr $tmall_renum + 1`
	nvram set tmall_renum="$tmall_renum"
	if [ "$tmall_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【tmall】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get tmall_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set tmall_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set tmall_status=0
eval "$scriptfilepath &"
exit 0
}

tmall_get_status () {

A_restart=`nvram get tmall_status`
B_restart="$tmall_enable$tmall_id$(cat /etc/storage/app_13.sh /etc/storage/app_14.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set tmall_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

tmall_check () {

tmall_get_status
if [ "$tmall_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "caddy_tmall" | grep -v grep )" ] && logger -t "【天猫精灵】" "停止 tmall" && tmall_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$tmall_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		tmall_close
		tmall_start
	else
		[ -z "$(ps -w | grep "caddy_tmall" | grep -v grep )" ] && tmall_restart
	fi
fi
}

tmall_keep () {
logger -t "【天猫精灵】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【天猫精灵】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
	[ -z "\`pidof caddy_tmall\`" ] || [ ! -s "/opt/tmall/caddy_tmall" ] && nvram set tmall_status=00 && logger -t "【天猫精灵】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【天猫精灵】|^$/d' /tmp/script/_opt_script_check # 【天猫精灵】
OSC
#return
fi

while true; do
	if [ -f "/tmp/tmall/RUN" ] ; then
		logger -t "【天猫精灵】" "运行远程命令"
		source /tmp/tmall/RUN
		rm -f /tmp/tmall/RUN
	fi
sleep 10
done
}

tmall_close () {
sed -Ei '/【天猫精灵】|^$/d' /tmp/script/_opt_script_check
killall caddy_tmall
killall -9 caddy_tmall
kill_ps "/tmp/script/_app13"
kill_ps "_t_mall.sh"
kill_ps "$scriptname"
}

tmall_start () {
check_webui_yes
SVC_PATH="/opt/tmall/caddy_tmall"
mkdir -p "/tmp/tmall"
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【天猫精灵】" "找不到 $SVC_PATH，安装 opt 程序"
	/tmp/script/_mountopt start
	initopt
fi
mkdir -p "/opt/tmall"
wgetcurl_file "$SVC_PATH" "$hiboyfile/caddy" "$hiboyfile2/caddy"
[ -z "$($SVC_PATH -plugins 2>&1 | grep http.cgi)" ] && rm -rf $SVC_PATH
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【天猫精灵】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【天猫精灵】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && tmall_restart x
fi
[ -z "$tmall_id" ] && { logger -t "【天猫精灵】" "启动失败, 注意检[认证配置]是否填写,10 秒后自动尝试重新启动" && sleep 10 && tmall_restart x ; }
# 生成配置文件
rm -f /opt/tmall/Caddyfile
ln -sf /etc/storage/app_13.sh /opt/tmall/Caddyfile
rm -f /opt/tmall/app_14.sh
ln -sf /etc/storage/app_14.sh /opt/tmall/app_14.sh
mkdir -p "/opt/tmall/www/aligenie"
cd /opt/tmall/www/aligenie
echo -n $(echo "$tmall_id" | awk -F \  '{print $2}') > ./$(echo "$(echo "$tmall_id" | awk -F \  '{print $1}')" | awk -F . '{print $1}').txt
chmod 444 /opt/tmall/www/aligenie/*

logger -t "【天猫精灵】" "运行 /opt/tmall/caddy_tmall"
eval "/opt/tmall/caddy_tmall -conf /opt/tmall/Caddyfile $cmd_log" &
sleep 3
[ ! -z "$(ps -w | grep "caddy_tmall" | grep -v grep )" ] && logger -t "【天猫精灵】" "启动成功" && tmall_restart o
[ -z "$(ps -w | grep "caddy_tmall" | grep -v grep )" ] && logger -t "【天猫精灵】" "启动失败, 注意检caddy_tmall是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && tmall_restart x
#tmall_get_status
eval "$scriptfilepath keep &"
exit 0
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

initconfig () {

app_13="/etc/storage/app_13.sh"
if [ ! -f "$app_13" ] || [ ! -s "$app_13" ] ; then
	cat > "$app_13" <<-\EEE
# 此脚本路径：/etc/storage/app_13.sh
# 默认端口9321
:9321 {
 root /opt/tmall/www
 # 默认cgi触发/abc123
 cgi /abc123 /opt/tmall/app_14.sh
 log /opt/tmall/requests.log {
 rotate_size 1
 }
}
EEE
	chmod 755 "$app_13"
fi

app_14="/etc/storage/app_14.sh"
if [ ! -f "$app_14" ] || [ ! -s "$app_14" ] ; then
	cat > "$app_14" <<-\EEE
#!/bin/sh
# 此脚本路径：/etc/storage/app_14.sh
[ "POST" = "$REQUEST_METHOD" -a -n "$CONTENT_LENGTH" ] && read -n "$CONTENT_LENGTH" POST_DATA
POST_DATA2=$(echo "$POST_DATA" | sed "s/\///g" | sed "s/[[:space:]]//g" | grep -o "\"intentName\":\".*\"," | awk -F : '{print $2}'| awk -F , '{print $1}' | sed -e 's@"@@g')
REPLY_DATA="好的"
RUN_DATA="/tmp/tmall/RUN"
# 更多自定义命令请自行参考添加修改
if [ "$POST_DATA2" = "打开网络" ]; then
  radio2_guest_enable
  radio5_guest_enable
  REPLY_DATA="打开网络"
fi

if [ "$POST_DATA2" = "停用网络" ]; then
  radio2_guest_disable
  radio5_guest_disable
  REPLY_DATA="停用网络"
fi

if [ "$POST_DATA2" = "打开电脑" ]; then
  # 下面的00:00:00:00:00:00改为电脑网卡地址即可唤醒
  ether-wake -b -i br0 00:00:00:00:00:00
  REPLY_DATA="打开电脑"
fi

if [ "$POST_DATA2" = "打开代理" ]; then
  cat > "$RUN_DATA" <<-\RRR
  nvram set ss_status=0
  nvram set ss_enable=1
  nvram commit
  /tmp/script/_ss &
RRR
  REPLY_DATA="打开代理"
fi

if [ "$POST_DATA2" = "关闭代理" ]; then
  cat > "$RUN_DATA" <<-\RRR
  nvram set ss_status=1
  nvram set ss_enable=0
  nvram commit
  /tmp/script/_ss &
RRR
  REPLY_DATA="关闭代理"
fi


printf "Content-type: text/plain\n\n"
echo "{
    \"returnCode\": \"0\",
    \"returnErrorSolution\": \"\",
    \"returnMessage\": \"\",
    \"returnValue\": {
        \"reply\": \"$REPLY_DATA\",
        \"resultType\": \"RESULT\",
        \"actions\": [
            {
                \"name\": \"audioPlayGenieSource\",
                \"properties\": {
                    \"audioGenieId\": \"123\"
                }
            }
        ],
        \"properties\": {},
        \"executeCode\": \"SUCCESS\",
        \"msgInfo\": \"\"
    }
}"

logger -t "【天猫精灵】" "$REPLY_DATA"
exit 0

EEE
	chmod 755 "$app_14"
fi

}

initconfig

update_init () {
source /etc/storage/script/init.sh
[ "$init_ver" -lt 0 ] && init_ver="0" || { [ "$init_ver" -gt 0 ] || init_ver="0" ; }
init_s_ver=2
if [ "$init_s_ver" -gt "$init_ver" ] ; then
	logger -t "【update_init】" "更新 /etc/storage/script/init.sh 文件"
	wgetcurl.sh /tmp/init_tmp.sh  "$hiboyscript/script/init.sh" "$hiboyscript2/script/init.sh"
	[ -s /tmp/init_tmp.sh ] && cp -f /tmp/init_tmp.sh /etc/storage/script/init.sh
	chmod 755 /etc/storage/script/init.sh
	source /etc/storage/script/init.sh
fi
}

update_app () {
update_init
mkdir -p /opt/app/tmall
if [ "$1" = "del" ] ; then
	rm -rf /opt/app/tmall/Advanced_Extensions_tmall.asp
fi

initconfig

# 加载程序配置页面
if [ ! -f "/opt/app/tmall/Advanced_Extensions_tmall.asp" ] || [ ! -s "/opt/app/tmall/Advanced_Extensions_tmall.asp" ] ; then
	wgetcurl.sh /opt/app/tmall/Advanced_Extensions_tmall.asp "$hiboyfile/Advanced_Extensions_tmallasp" "$hiboyfile2/Advanced_Extensions_tmallasp"
fi
umount /www/Advanced_Extensions_app13.asp
mount --bind /opt/app/tmall/Advanced_Extensions_tmall.asp /www/Advanced_Extensions_app13.asp
# 更新程序启动脚本

[ "$1" = "del" ] && /etc/storage/www_sh/tmall del &
}

case $ACTION in
start)
	tmall_close
	tmall_check
	;;
check)
	tmall_check
	;;
stop)
	tmall_close
	;;
updateapp13)
	tmall_restart o
	[ "$tmall_enable" = "1" ] && nvram set tmall_status="updatetmall" && logger -t "【tmall】" "重启" && tmall_restart
	[ "$tmall_enable" != "1" ] && nvram set tmall_v="" && logger -t "【tmall】" "更新" && update_app del
	;;
update_app)
	update_app
	;;
keep)
	#tmall_check
	tmall_keep
	;;
*)
	tmall_check
	;;
esac
