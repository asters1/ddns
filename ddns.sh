#!/bin/bash
##############  用户配置（修改这里） ###############
#
#dnspod token id
#login_id=""
login_id=""
#dnspod token value
login_token=""
#域名ID
domain_id=""
#主机记录。如:www,@
sub_domain="@"
#记录类型
record_type="AAAA"
#记录数组index
record_num="2"
#jq路径
jq_path="./jq"

#################  脚本配置  ######################
#
# 变动前的公网IP.....保存位置
ip_file="./ip.txt"
# 域名信息...........保存位置
domain_file="./result.json"
# ddns运行日志
log_file="./dnspod.log"

##################  功能定义  ####################
#本机ip地址
new_ip=""
#旧ip地址
old_ip=""
#记录ID
record_id=""
#记录线路ID
record_line_id=""

#获取当前时间
get_time=$(date '+%Y-%m-%d %H:%M:%S')
log() {
	if [ "$1" ]; then
		echo -e "[${get_time}] -- $1" >> $log_file
	fi
}
#判断jq是否存在
check_jq(){
	if [ ! -f $jq_path ]; then
		echo "jq文件不存在，请检查!!!"
		exit 1
	fi
}
#获取本机IP
get_ip() {
	log "正在获取本机IP..."
	if [ $record_type == "A" ]; then
		new_ip=$(curl -s http://v4.ipv6-test.com/api/myip.php)
		log 本机ip为${new_ip}
	elif [ $record_type == "AAAA" ]; then
		new_ip=$(curl -s http://v6.ipv6-test.com/api/myip.php)
		log 本机ip为${new_ip}
	else
		log "ip类型有错误请检查，填A或者AAAA,A代表ipv4,AAAA代表ipv6!"
		exit 1
	fi
}

check_ip_change() {
	log "正在检查IP..."
	if [ -f $ip_file ]; then
		old_ip=$(cat $ip_file)
		if [ "$new_ip" == "$old_ip" ]; then
			echo "IP没有改变"
			log "IP没有改变"
			exit 0
		fi
	fi
}

get_domain_info(){
	log "正在获取域名信息..."

	curl -s -X POST 'https://dnsapi.cn/Record.List' -d 'login_token='${login_id}','${login_token}'&format=json&domain_id='${domain_id}'' > ${domain_file}
	domain_info=$(cat ${domain_file})
	code=$(${jq_path} "${domain_file}" "status.code")
	if [ ${code} -ne 1 ]; then
		echo "状态码不等于1,获取域名信息失败,请检查!!!"
		echo -e "${domain_info}"
		exit 1
	fi
}

get_record_info(){
	log "正在获取记录信息..."
	#记录ID
	record_id=$(${jq_path} "${domain_file}" "records.${record_num}.id")
	#记录线路ID
	record_line_id=$(${jq_path} "${domain_file}" "records.${record_num}.line_id")
}

update_dns(){
	log "正在更新dns记录..."
	res=$(curl -s -X POST https://dnsapi.cn/Record.Modify -d 'login_token='${login_id}','${login_token}'&format=json&domain_id='${domain_id}'&record_id='${record_id}'&sub_domain='${sub_domain}'&value='${new_ip}'&record_type='${record_type}'&record_line_id='${record_line_id}'')
	#echo "https://dnsapi.cn/Record.Modify -d 'login_token='${login_id}','${login_token}'&format=json&domain_id='${domain_id}'&record_id='${record_id}'&sub_domain='${sub_domain}'&value='${new_ip}'&record_type='${record_type}'&record_line_id='${record_line_id}''"
	echo -e ${res} > ./res.json
	res_code=$(${jq_path} "./res.json" "status.code")
	if [ ${res_code} -ne 1 ]; then
		echo "状态码不等于1,更新记录失败,请检查!!!"
		log "状态码不等于1,更新记录失败,请检查!!!"
		echo -e "${res}"
		log -e "${res}"

		rm ./res.json
		exit 1
	else
		echo "${new_ip}" > ${ip_file}
		log "dns记录更新成功..."
		rm ./res.json
	fi

}
###################  脚本主体  ###################
echo "#############################" >> ${log_file}
log "ddns脚本开始启动"
#检查jq文件
check_jq
#获取本机IP地址
get_ip
#判断是否成功获取到IP
if [ "$new_ip" == "" ]; then
	echo "没有获取到IP地址.请检查网络..."
	log "没有获取到IP地址.请检查网络..."
	exit 1
fi
#检查IP是否变化
check_ip_change
#获取域名信息信息
if [ ! -f $domain_file ]; then
	get_domain_info
fi
#获取记录信息
get_record_info
#更新记录
update_dns


