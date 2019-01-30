#!/bin/bash
#    WireGuard VPN多用户服务端  自动配置脚本

#    本脚本(WireGuard 多用户配置)一键安装短网址
#    wget -qO- https://git.io/fpnQt | bash
#############################################################
# 定义修改端口号，适合已经安装WireGuard而不想改端口
port=56789
mtu=1420
ip_list=(2 5 8 178 186 118 158 198 168 9)

#############################################################
help_info() {
cat  <<EOF
# 一键安装wireguard 脚本 Debian 9 (源:逗比网安装笔记)
wget -qO- git.io/fptwc | bash

# 一键安装wireguard 脚本 Ubuntu   (源:逗比网安装笔记)
wget -qO- git.io/fpcnL | bash

# CentOS 7 一键脚本安装WireGuard  (官方脚本自动升级内核)
wget -qO- git.io/fhnhS | bash

#  一键安装shadowsocks-libev
wget -qO- git.io/fhExJ | bash
EOF
}
#############################################################
#定义文字颜色
Green="\033[32m"  && Red="\033[31m" && GreenBG="\033[42;37m" && RedBG="\033[41;37m" && Font="\033[0m"

#定义提示信息
Info="${Green}[信息]${Font}"  &&  OK="${Green}[OK]${Font}"  &&  Error="${Red}[错误]${Font}"

# 检查是否安装 WireGuard
if [ ! -f '/usr/bin/wg' ]; then
    clear
    echo -e "${RedBG}   一键安装 WireGuard 脚本 For Debian_9 Ubuntu Centos_7   ${Font}"
    echo -e "${GreenBG}     开源项目：https://github.com/hongwenjun/vps_setup    ${Font}"
    help_info
    echo -e "${Red}::  检测到你的vps没有安装wireguard，请选择复制一键脚本安装   ${Font}"
    exit 1
fi

host=$(hostname -s)
# 获得服务器ip，自动获取
if [ ! -f '/usr/bin/curl' ]; then
    apt update && apt install -y curl
fi
serverip=$(curl -4 ip.sb)

# 安装二维码插件
if [ ! -f '/usr/bin/qrencode' ]; then
    apt -y install qrencode
fi

# 安装 bash wgmtu 脚本用来设置服务器
wget -O ~/wgmtu  https://raw.githubusercontent.com/hongwenjun/vps_setup/master/Wireguard/wgmtu.sh
#############################################################

# wg配置文件目录 /etc/wireguard
mkdir -p /etc/wireguard
chmod 777 -R /etc/wireguard
cd /etc/wireguard

# 然后开始生成 密匙对(公匙+私匙)。
wg genkey | tee sprivatekey | wg pubkey > spublickey
wg genkey | tee cprivatekey | wg pubkey > cpublickey

# 生成服务端配置文件
cat <<EOF >wg0.conf
[Interface]
PrivateKey = $(cat sprivatekey)
Address = 10.0.0.1/24
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = $mtu

[Peer]
PublicKey = $(cat cpublickey)
AllowedIPs = 10.0.0.188/32

EOF

# 生成简洁的客户端配置
cat <<EOF >client.conf
[Interface]
PrivateKey = $(cat cprivatekey)
Address = 10.0.0.188/24
DNS = 8.8.8.8
#  MTU = $mtu
#  PreUp =  start   .\route\routes-up.bat
#  PostDown = start  .\route\routes-down.bat

[Peer]
PublicKey = $(cat spublickey)
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25

EOF

# 添加 2-9 号多用户配置
for i in {2..9}
do
    ip=10.0.0.${ip_list[$i]}
    wg genkey | tee cprivatekey | wg pubkey > cpublickey

    cat <<EOF >>wg0.conf
[Peer]
PublicKey = $(cat cpublickey)
AllowedIPs = $ip/32

EOF

    cat <<EOF >wg_${host}_$i.conf
[Interface]
PrivateKey = $(cat cprivatekey)
Address = $ip/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat spublickey)
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25

EOF
    cat /etc/wireguard/wg_${host}_$i.conf| qrencode -o wg_${host}_$i.png
done

#  vps网卡如果不是eth0，修改成实际网卡
ni=$(ls /sys/class/net | awk {print} | grep -e eth. -e ens. -e venet.)
if [ $ni != "eth0" ]; then
    sed -i "s/eth0/${ni}/g"  /etc/wireguard/wg0.conf
fi

# 重启wg服务器
wg-quick down wg0
wg-quick up wg0

# 安装 bash wg5 命令，新手下载客户端配置用
conf_url=http://${serverip}:8000
cat  <<EOF > ~/wg5
next() {
    printf "# %-70s\n" "-" | sed 's/\s/-/g'
}

host=$(hostname -s)
cd  /etc/wireguard/
tar cvf  wg5clients.tar  client*  wg*
echo -e  "${GreenBG}#  Windows 客户端配置，请复制配置文本 ${Font}"

cat /etc/wireguard/client.conf       && next
cat /etc/wireguard/wg_${host}_2.conf   && next
cat /etc/wireguard/wg_${host}_3.conf   && next
cat /etc/wireguard/wg_${host}_4.conf   && next

echo -e "${RedBG}   一键安装 WireGuard 脚本 For Debian_9 Ubuntu Centos_7   ${Font}"
echo -e "${GreenBG}     开源项目：https://github.com/hongwenjun/vps_setup    ${Font}"
echo
echo -e "# ${Info} 新手使用${GreenBG} bash wg5 ${Font} 命令，使用临时网页下载配置和手机客户端二维码配置"
echo -e "# ${Info} 大佬使用${GreenBG} bash wgmtu ${Font} 命令，服务端高级配置和添加删除客户端数量"

# echo -e "# ${Info} 请网页打开 ${GreenBG}${conf_url}${Font} 下载配置文件 wg5clients.tar ，${RedBG}注意: 完成后请重启VPS.${Font}"
# python -m SimpleHTTPServer 8000 &
echo ""
# echo -e "# ${Info} 访问 ${GreenBG}${conf_url}${Font} 点PNG二维码， ${RedBG}手机扫描二维码后请立即重启VPS。${Font}"

EOF

# 显示管理脚本信息
bash ~/wg5
sed -i "s/# python -m/python -m/g"  ~/wg5
sed -i "s/# echo -e/echo -e/g"  ~/wg5
