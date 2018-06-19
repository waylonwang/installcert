#! /bin/bash

#*************************************************************************************
# 本脚本基于Neilpang/acme.sh，用于Synology NAS自动化创建或更新Let's Encrypt SSL证书
# 本脚本适用于Synology DSM V6.x版本，仅支持ACME V2.0协议通过域名验证获取泛域名证书
# 
# 作者:waylon@waylon.wang
#*************************************************************************************

#修改以下内容为自己的域名服务商信息，具体的DNS类型或环境变量名称请参见Neilpang/acme.sh
export CX_Key=""
export CX_Secret=""
DNS="dns_cx"
#修改以下内容为自己所拥有的域名名称，LE已支持泛域名证书，只需填写域名名称即可
DOMAIN=""

#以下为处理脚本，不懂的请勿随意修改
NAME="installcert.sh"
VER="1.0"
URL="https://github.com/waylonwang/installcert/installcert.sh"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"
CERT_FOLDER="/usr/syno/etc/certificate/system/default"
CERT_ARCHIVE="/usr/syno/etc/certificate/_archive/$(cat /usr/syno/etc/certificate/_archive/DEFAULT)"
CERT_REVERSEPROXY="/usr/syno/etc/certificate/ReverseProxy"
HELP="用法: ./${NAME} <命令> [<参数>]\n
命令:\n
\t--create,-c\t\t创建证书\n
\t--update,-u\t\t更新证书\n
\t--help,-h\t\t显示本帮助\n
参数:\n
\t--force,-f\t\t更新证书时，忽略证书到期日强制更新"

if [ "$1" = "-c" -o "$1" = "--create" ];then
	echo -e "${YELLOW}开始创建${DOMAIN}证书${NC}"
	action=1
	./acme.sh --issue -d $DOMAIN -d *.$DOMAIN --dns $DNS \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--dnssleep 20
	result=$?
elif [ "$1" = "-u" -o "$1" = "--update" ];then
	echo -e "${YELLOW}开始更新${DOMAIN}证书${NC}"
	action=0
	if [ "$2" = "--force" -o "$2" = "-f" ];then
		./acme.sh --renew -d $DOMAIN -d *.$DOMAIN \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--dnssleep 20 \
			--force
		result=$?
	else	
		./acme.sh --renew -d $DOMAIN -d *.$DOMAIN \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--dnssleep 20
		result=$?
	fi
elif [ "$1" = "-h" -o "$1" = "--help" ];then
	echo -e "${YELLOW}${NAME} V${VER}\n${URL}${NC}"
	echo -e $HELP
	exit 1
else
	echo -e "${RED}请在执行语句中输入命令${NC}"
	echo -e $HELP
	exit 1
fi

wait
if [ $result -eq 1 ];then
	echo -e "${RED}结束,未获取到有效的证书!${NC}"
	exit 2
elif [ $result -eq 2 ];then
	echo -e "${RED}忽略,未到更新时间!${NC}"
	exit 3
elif [ $result -ne 0 ];then
	echo -e "${RED}异常,证书获取异常!${NC}"
	exit 2
fi

echo -e "${YELLOW}复制证书到存档目录:${NC}${CERT_ARCHIVE}"
cp $CERT_FOLDER/*.pem $CERT_ARCHIVE

wait
echo -e "${YELLOW}复制证书到反代目录:${NC}${CERT_REVERSEPROXY}"
for file in `ls $CERT_REVERSEPROXY`
do
	if [ -d $CERT_REVERSEPROXY"/"$file ]
	then
		cp $CERT_FOLDER/*.pem $CERT_REVERSEPROXY/$file
	fi
done

wait
echo -e "${YELLOW}重新加载Nginx${NC}"
synoservicectl --reload nginx

if [ $action -eq 1 ];then
	echo -e "${YELLOW}证书创建完成!${NC}"
else
	echo -e "${YELLOW}证书更新完成!${NC}"
fi
