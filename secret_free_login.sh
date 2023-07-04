#! /bin/bash

user=$1
ip_add=$2
pass=$3
timeout=10

ssh_keygen(){
    if [ -e $id_rsa_path ];then
        echo -e "已经生成密钥:$id_rsa_path"
    else
        pass_path=$(/bin/expect -c "
        spawn  ssh-keygen -q -t rsa
        expect {
            \"*save the key*\" { send \"\r\"; exp_continue }
            \"*passphrase*\" { send \"\r\";exp_continue }
            \"*again*\" { send \"\r\"}
            }
        " | awk -F '\(' 'NR==2{print $NF}' 2>/dev/null | awk -F '\)' '{print $1}' 2>/dev/null)
        echo -e "密钥存放路径：$pass_path"
    fi

    if [ $? -eq 1 ];then
        echo "生成密钥失败"
    fi
}
scp_key(){
	output=$(expect -c "
	set timeout $timeout
	spawn ssh-copy-id $user@$ip_add

	expect {
		\"password:\" {
			# 发送密码
			send \"$pass\r\"
			exp_continue
		}
		\"yes/no\" {
			# 确认远程主机的公钥
			send \"yes\r\"
			exp_continue
		}
		\"Number of key(s) added\" {
			# 配置免密登录成功
			puts  \"succed\"
			exit 0
		}
		\"WARNING: All keys were skipped because they already exist on the remote system.\" {
			# 已经配置过免密登录
			puts  \"outmoded\"
			exit 1
		}
		\"Permission denied\" {
			# 登录失败：权限被拒绝
			puts  \"Permission denial\"
			exit 2
		}
		\"ERROR: No identities found\" {
			# 未生成密钥
			puts  \"Ungenerated key\"
			exit 3
			}
		\"ERROR: ssh: connect to host\" {
			# 连接超时
			puts \"ssh: connect to host\"
			exit 4
			}
		timeout {
			# 超时处理
			puts  \"Timeout\"
			exit 4
		}
	}
	expect eof
	")
	case $output in
		*"succed"*)
			echo "配置免密登录成功"
			;;
		*"outmoded"*)
			echo "已经配置过免密登录"
			;;
		*"Permission denial"*)
			echo "登录失败：权限被拒绝"
			;;
		*"Ungenerated key"*)
			echo "未生成密钥"
			;;
		*"ssh: connect to host"*)
			echo "主机连接超时"
			;;	
		*)
			echo "其他错误"
			;;
	esac
}

check_ip(){
    IP=$(echo $ip_add|cut -d "/" -f 1)
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        res=$(echo $IP|awk -F . '$1>=1&&$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
        if [ "X${res}" == "X" ]; then
            echo -e "请输入合法的IP地址"
            return 1
        fi
    fi
}

check_expect_installation() {
  if ! command -v expect >/dev/null 2>&1; then
    echo "正在安装Expect..."
	if command -v yum >/dev/null ; then
	    sudo yum install -y expect >/dev/null
    else
      echo "无法安装Expect,请手动安装"
      exit 1
    fi
    echo "Expect已成功安装"
  else
    echo "Expect已经安装"
  fi
}

run_secret_free_login(){
    if [ -n "$user" ] && [ -n "$ip_add" ] && [ -n "$pass" ];then
        cd ~
        echo -e "你要执行免密登的用户名是：$user"
        echo -e "执行免密登录的主机是:$ip_add "
        echo -e "你要执行免密登的密码是：$pass"
        id_rsa_path=`pwd`/.ssh/id_rsa.pub
        check_expect_installation &&  check_ip && ssh_keygen && scp_key
    else
        echo -e "脚本使用格式# ./secret_free_login 用户名 IP地址 密码 "
    fi
}

run_secret_free_login




