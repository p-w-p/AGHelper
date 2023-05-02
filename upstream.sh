#!/usr/bin/env bash

#=================================================================
#	System Request:Debian 9+/Ubuntu 18.04+/Centos 7+/OpenWrt R18.06+
#	Author:	Milinda Brantini
#	Dscription: AdGuardHome Helper
#	Github: https://github.com/p-w-p/AGHelper/
#=================================================================

# Font color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

# Variable
shell_version="0.0.1"

function print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}

function print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}

function update_sh() {
  local ol_version=$(curl -L -s https://testingcf.jsdelivr.net/gh/p-w-p/AGHelper/upstream.sh | grep -oP 'shell_version=\K[^"]+')
  if [[ "$shell_version" != "$(echo -e "$shell_version\n$ol_version" | sort -rV | head -1)" ]]; then
    print_ok "存在新版本，是否更新 [Y/N]? "
    read -r  update_confirm
    case "${update_confirm,,}" in
      yes|y)
        wget -N --no-check-certificate https://testingcf.jsdelivr.net/gh/p-w-p/AGHelper/upstream.sh
        print_ok "更新完成"
        print_ok "您可以通过 bash $0 执行本程序"
        exit 0
        ;;
      *)
        ;;
    esac
  else
    print_ok "当前版本为最新版本"
    print_ok "您可以通过 bash $0 执行本程序"
  fi
}



function automated_AGH() {
  source '/etc/os-release'
  local curl_command="curl -s -S -L https://testingcf.jsdelivr.net/gh/AdguardTeam/AdGuardHome/scripts/install.sh | sh -s -- $automated_option"
  case "$ID" in
    centos)
      if (( VERSION_ID >= 7 )); then
        print_ok "当前系统为 Centos ${VERSION_ID} ${VERSION}"
        yum install -y curl
        eval "$curl_command"
      fi
      ;;
    ol)
      print_ok "当前系统为 Oracle Linux ${VERSION_ID} ${VERSION}"
      yum install -y curl
      eval "$curl_command"
      ;;
    openwrt)
      print_ok "当前系统为 OpenWRT ${VERSION_ID} ${VERSION}"
      if [[ "$automated_option" == "-v" ]]; then
        opkg install https://endpoint.fastgit.org/https://github.com/rufengsuixing/luci-app-adguardhome/releases/download/1.8-9/luci-app-adguardhome_1.8-9_all.ipk
      else
        opkg remove luci-app-adguardhome -autoremove
      fi
      ;;
    debian)
      if (( VERSION_ID >= 9 )); then
        print_ok "当前系统为 Debian ${VERSION_ID} ${VERSION}"
        apt install -y curl
        eval "$curl_command"
      fi
      ;;
    ubuntu)
      if (( VERSION_ID >= 18 )); then
        print_ok "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
        apt install -y curl
        eval "$curl_command"
      fi
      ;;
    *)
      print_error "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内"
      exit 1
      ;;
  esac
}



function create_upstream() {
  read -rp "请输入生成路径[默认:/opt/AdGuardHome/upstream.txt]: " upstream_path
  upstream_path=${upstream_path:-/opt/AdGuardHome/upstream.txt}
  read -rp "请输入境内DNS数量[默认:1]: " num1
  num1=${num1:-1}
  > "$upstream_path"
  for ((i = 1; i <= num1; i++)); do
    read -rp "请输入境内DNS$i[默认:tls://223.5.5.5]: " dns
    dns=${dns:-tls://223.5.5.5}
    curl -s 'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt' \
      | sed '/regexp:/d' \
      | sed 's/full://g' \
      | tr "\n" "/" \
      | sed -e 's|^|/|' -e 's|\(.*\)|[\1]'"$dns"'|' \
      >>"$upstream_path"
    echo >>"$upstream_path"
  done
  read -rp "请输入境外DNS数量[默认:1]: " num2
  num2=${num2:-1}
  for ((i = 1; i <= num2; i++)); do
    read -rp "请输入境外DNS$i[默认:tls://8.8.8.8]: " dns
    dns=${dns:-tls://8.8.8.8}
    echo "$dns" >>"$upstream_path"
  done
  print_ok "分流配置文件[$upstream_path]生成完毕"
  sleep 2s
  menu
}

function systemctl_AGH(){
  if [[ -x "$(command -v systemctl)" ]]; then
    systemctl $systemctl_option AdGuardHome
  else
    service AdGuardHome $systemctl_option
  fi
  print_ok "命令[$systemctl_option]已执行"
}



function update_yaml() {
  read -rp "请输入AdGuardHome.yaml路径[默认:/opt/AdGuardHome/AdGuardHome.yaml]: " yaml_path
  yaml_path=${yaml_path:-/opt/AdGuardHome/AdGuardHome.yaml}
  if [[ "${upstream_status}" == "enable" ]]; then
    read -rp "请输入分流文件路径[默认:/opt/AdGuardHome/upstream.txt]: " upstream_path
    upstream_path=${upstream_path:-/opt/AdGuardHome/upstream.txt}
    sed -i "/upstream_dns_file:/c\  upstream_dns_file: $upstream_path" "$yaml_path" && systemctl_option=restart&&systemctl_AGH
  else
    sed -i "/upstream_dns_file:/c\  upstream_dns_file: \"\"" "$yaml_path" && systemctl_option=restart&&systemctl_AGH
  fi
  print_ok "配置文件[$yaml_path]已修改"
  sleep 2s
  menu
}



function update_crontab(){
  if [[ "${crontab_status}" == "enable" ]]; then
    read -rp "请输入生成路径[默认:/opt/AdGuardHome/upstream.txt]:" upstream_path
    upstream_path=${upstream_path:-"/opt/AdGuardHome/upstream.txt"}
    echo "#!/usr/bin/env bash" > /etc/update4AGH.sh
    echo "> $upstream_path" >> /etc/update4AGH.sh
    read -rp "请输入境内DNS数量[默认:1]:" num1
    num1=${num1:-1}
    for ((i=1; i<=num1; i++)); do
      read -rp "请输入境内DNS$i[默认:tls://223.5.5.5]:" dns
      dns=${dns:-"tls://223.5.5.5"}
      echo "curl -s 'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/direct-list.txt' | sed '/regexp:/d' | sed 's/full://g' | tr \"\\n\" \"/\" | sed -e 's|^|/|' -e 's|\\(.*\\)|[\\1]$dns\n|' >> $upstream_path" >> /etc/update4AGH.sh
    done
    read -rp "请输入境外DNS数量[默认:1]:" num2
    num2=${num2:-1}
    for ((i=1; i<=num2; i++)); do
      read -rp "请输入境外DNS$i[默认:tls://8.8.8.8]:" dns
      dns=${dns:-"tls://8.8.8.8"}
      echo "echo $dns >> $upstream_path" >> /etc/update4AGH.sh
    done
    echo -e 'if command -v systemctl >/dev/null; then\n  systemctl restart AdGuardHome\nelse\n  service AdGuardHome restart\nfi' >> /etc/update4AGH.sh
    echo "0 0 * * 0 bash /etc/update4AGH.sh" >> /etc/crontab
    chmod +x /etc/update4AGH.sh
  else
    sed -i '/update4AGH.sh/d' /etc/crontab
    rm -f /etc/update4AGH.sh
  fi
  if [[ -x "$(command -v systemctl)" ]]; then
    systemctl reload crond.service || systemctl reload cron.service
  else
    service cron reload || service crond reload
  fi
  print_ok "定时任务已设置为[$crontab_status]"
  sleep 2s
  menu
}



function disable_firewall(){
  systemctl stop firewalld
  systemctl disable firewalld
  systemctl stop nftables
  systemctl disable nftables
  systemctl stop ufw
  systemctl disable ufw
}



menu() {
  clear
  echo -e "
  AdGuard分流助手 安装管理脚本 ${Red}[${shell_version}]${Font}
  ---Authored by Milinda Brantini---
  https://github.com/p-w-p/AGHelper/

  —————————————— 安装向导 ——————————————
  ${Green}0.${Font}  升级 脚本
  ${Green}1.${Font}  安装 AdGuardHome
  ${Green}2.${Font}  卸载 AdGuardHome
  —————————————— 配置更改 ——————————————
  ${Green}11.${Font} 生成 分流文件
  ${Green}12.${Font} 使用 分流文件
  ${Green}13.${Font} 取消 分流文件
  ${Green}14.${Font} 开启 上游文件自动更新
  ${Green}15.${Font} 移除 上游文件自动更新
  —————————————— 其他选项 ——————————————
  ${Green}21.${Font} 查看 AdGuardHome状态
  ${Green}22.${Font} 开启 AdGuardHome服务
  ${Green}23.${Font} 关闭 AdGuardHome服务
  ${Green}24.${Font} 重启 AdGuardHome服务
  ${Green}25.${Font} 关闭 防火墙(不建议)
  ${Green}99.${Font} 退出 脚本
  --------------------------------------"
  read -rp "请输入数字:" menu_num
  case $menu_num in
    0)
      update_sh
      ;;
    1)
      automated_option=-v automated_AGH
      ;;
    2)
      automated_option=-u automated_AGH
      ;;
    11)
      create_upstream
      ;;
    12)
      upstream_status=enable update_yaml
      ;;
    13)
      upstream_status=disable update_yaml
      ;;
    14)
      crontab_status=enable update_crontab
      ;;
    15)
      crontab_status=remove update_crontab
      ;;
    21)
      systemctl_option=status systemctl_AGH
      ;;
    22)
      systemctl_option=start systemctl_AGH
      ;;
    23)
      systemctl_option=stop systemctl_AGH
      ;;
    24)
      systemctl_option=restart systemctl_AGH
      ;;
    25)
      disable_firewall
      ;;
    99)
      exit 1
      ;;
    *)
      print_error "请输入正确数字 [0-99]"
      sleep 2s
      menu
      ;;
  esac
}

menu "$@"
