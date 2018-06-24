#! /bin/bash

#*************************************************************************************
# 本脚本基于Neilpang/acme.sh，用于Synology NAS自动化创建或更新Let's Encrypt SSL证书
# 本脚本适用于Synology DSM V6.x版本，仅支持ACME V2.0协议通过域名验证获取泛域名证书
# 
# 作者:waylon@waylon.wang
#*************************************************************************************

# 修改以下内容为自己的域名服务商信息，具体的DNS类型或环境变量名称请参见Neilpang/acme.sh
export CX_Key="ChangeToYourKey"
export CX_Secret="ChangeToYourSecret"
DNS="dns_cx"
# 修改以下内容为自己所拥有的域名名称，LE已支持泛域名证书，只需填写域名名称即可
DOMAIN="ChangeToYourDomain"
# 修改以下内容为自己安装的acme.sh的路径，如采用默认安装路径则无须修改
ACME_PATH="/usr/local/share/acme.sh"

# 以下为处理脚本，不懂的请勿随意修改
NAME="installcert.sh"
VER="1.0"
URL="https://github.com/waylonwang/installcert/installcert.sh"
HELP="用法: ./${NAME} <命令> [<参数>]\n
命令:\n
\t--create,-c\t\t创建证书\n
\t--update,-u\t\t更新证书\n
\t--help,-h\t\t显示本帮助\n
参数:\n
\t--force,-f\t\t更新证书时，忽略证书到期日强制更新"
# 颜色
CLR_YL="\033[1;33m"
CLR_RD="\033[0;31m"
CLR_NO="\033[0m"
# 退出状态
EXIT_SUCCESS=0
EXIT_FAILURE=1
EXIT_ICLR_NOORRECT=2
EXIT_COMMAND_NOT_FOUND=127
# acme.sh配置文件路径
ACME_CONFIG_HOME="${ACME_PATH}/config"
# 证书存储路径
CERT_FOLDER="/usr/syno/etc/certificate/system/default"
CERT_ARCHIVE="/usr/syno/etc/certificate/_archive/$(cat /usr/syno/etc/certificate/_archive/DEFAULT)"
CERT_REVERSEPROXY="/usr/syno/etc/certificate/ReverseProxy"

# 获取证书
if [ "$1" = "-c" -o "$1" = "--create" ];then
	echo -e "${CLR_YL}开始创建${DOMAIN}证书${CLR_NO}"
	action=1
	$ACME_PATH/acme.sh --issue -d $DOMAIN -d *.$DOMAIN --dns $DNS \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--home $ACME_PATH \
			--config-home $ACME_CONFIG_HOME \
			--dnssleep 20 
	result=$?
elif [ "$1" = "-u" -o "$1" = "--update" ];then
	echo  -e "${CLR_YL}开始更新${DOMAIN}证书${CLR_NO}"
	action=0
	if [ "$2" = "--force" -o "$2" = "-f" ];then
		$ACME_PATH/ acme.sh --renew -d $DOMAIN -d *.$DOMAIN \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--home $ACME_PATH \
			--config-home $ACME_CONFIG_HOME \
			--dnssleep 20 \
			--force
		result=$?
	else	
		$ACME_PATH/acme.sh --renew -d $DOMAIN -d *.$DOMAIN \
			--certpath $CERT_FOLDER/cert.pem \
			--keypath $CERT_FOLDER/privkey.pem \
			--fullchainpath $CERT_FOLDER/fullchain.pem \
			--capath $CERT_FOLDER/chain.pem \
			--home $ACME_PATH \
			--config-home $ACME_CONFIG_HOME \
		 	--dnssleep 20 
		result=$?
	fi
elif [ "$1" = "-h" -o "$1" = "--help" ];then
	echo  -e "${CLR_YL}${NAME} V${VER}\n${URL}${CLR_NO}"
	echo -e $HELP
	exit $EXIT_ICLR_NOORRECT
else
	echo -e "${CLR_RD}请在执行语句中输入命令${CLR_NO}"
	echo -e $HELP
	exit $ EXIT_COMMAND_NOT_FOUND
fi

# 对获取证书的结果进行处理
wait
if [ $result -eq 1 ];then
	echo -e "${CLR_RD}结束,未获取到有效的证书!${CLR_NO}"
	exit $EXIT_FAILURE
elif [ $result -eq 2 ];then
	echo -e "${CLR_RD}忽略,未到更新时间!${CLR_NO}"
	exit $EXIT_ICLR_NOORRECT
elif [ $result -ne 0 ];then
	echo -e "${CLR_RD}异常,证书获取异常!${CLR_NO}"
	exit $EXIT_FAILURE
fi

# 处理存档
wait
echo -e "${CLR_YL}复制证书到存档目录:${CLR_NO}${CERT_ARCHIVE}"
cp $CERT_FOLDER/*.pem $CERT_ARCHIVE
# 处理反代
wait
echo -e "${CLR_YL}复制证书到反代目录:${CLR_NO}${CERT_REVERSEPROXY}"
for file in `ls $CERT_REVERSEPROXY`
do
	if [ -d $CERT_REVERSEPROXY"/"$file ]
	then
		cp $CERT_FOLDER/*.pem $CERT_REVERSEPROXY/$file
	fi
done

# 重启Nginx
wait
echo -e "${CLR_YL}重新加载Nginx${CLR_NO}"
synoservicectl --reload nginx

# 结束提示
if [ $action -eq 1 ];then
	echo -e "${CLR_YL}证书创建完成!${CLR_NO}"
else
	echo -e "${CLR_YL}证书更新完成!${CLR_NO}"
fi
