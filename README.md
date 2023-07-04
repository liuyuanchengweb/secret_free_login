# CentOS系列免密登录脚本分享

## 引言

在自动化运维领域，频繁地进行服务器操作是一项常见的任务。为了简化这一过程并提高工作效率，免密登录成为了一种重要的技术。CentOS系列的免密登录脚本可以帮助自动化运维人员快速实现服务器的免密登录，从而简化操作并提高自动化部署、配置和管理的效率。本文将介绍如何使用这个脚本来实现自动化运维中的CentOS系列免密登录。
## 快速使用

~~~bash
wget https://gitee.com/useryc/secret_free_login/raw/main/secret_free_login.sh
# 或者
wget wget https://raw.githubusercontent.com/liuyuanchengweb/secret_free_login/main/secret_free_login.sh
chmod +x secret_free_login.sh
./secret_free_login.sh [用户名] [主机地址] [密码]
~~~



## 目标

本文的目标是向读者展示如何使用CentOS系列的免密登录脚本来实现自动化运维中的服务器免密登录。通过使用该脚本，可以轻松的配置免密登录，提高工作效率，还可以使其它脚本调用该脚本。

## 脚本概述

CentOS系列的免密登录脚本使用了OpenSSH工具和Expect工具，它的主要功能包括：

- 检查所需工具的安装情况：脚本会自动检查是否已安装所需的工具（如OpenSSH和Expect）。如果发现工具未安装，脚本将自动安装它们。

- 生成密钥对：脚本会生成一对RSA密钥（公钥和私钥），用于加密通信和身份验证。

- 复制公钥到远程服务器：脚本会将生成的公钥复制到目标服务器，以实现免密登录。

- 验证免密登录：脚本会验证免密登录是否成功，并输出相应的结果。

## 前提条件

  在使用CentOS系列的免密登录脚本之前，请确保满足以下前提条件：

  - CentOS系列操作系统：本脚本适用于openEuler、CentOS、Red Hat和其他基于CentOS的发行版。
  - 本地机器：您需要在本地机器上执行该脚本。
  - 远程服务器：您需要具有目标服务器的登录凭据（用户名和密码），并且具有通过SSH进行远程连接的权限。

## 脚本实现

以下是实现CentOS系列的免密登录脚本的代码：

```bash
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

```

1. `ssh_keygen()` 函数：该函数用于生成密钥对。首先判断密钥文件是否已存在，如果存在则打印已经生成的密钥路径，否则使用 `ssh-keygen` 命令生成密钥对，并提取出生成的密钥文件路径。
2. `scp_key()` 函数：该函数使用 `expect` 工具执行 `ssh-copy-id` 命令将公钥复制到远程主机，实现免密登录配置。在 `expect` 语句中，根据不同的匹配情况执行相应的操作，如发送密码、确认远程主机的公钥等。根据命令执行结果，使用 `puts` 命令输出相应的字符串，作为后续处理的依据。
3. `check_ip()` 函数：该函数用于检查输入的 IP 地址是否合法。通过正则表达式判断 IP 地址的格式是否符合要求。
4. `check_expect_installation()` 函数：该函数用于检查是否已安装 `expect` 工具。使用 `command -v` 命令检查 `expect` 命令是否存在，如果不存在，则执行安装操作。根据不同的系统包管理器，使用相应的命令进行安装。
5. `run_secret_free_login()` 函数：该函数是脚本的主函数，用于执行免密登录的操作。首先检查输入参数是否符合要求，然后调用 `check_expect_installation()` 函数检查是否安装了 `expect` 工具，接着调用 `check_ip()` 函数检查 IP 地址的合法性，然后调用 `ssh_keygen()` 函数生成密钥对，最后调用 `scp_key()` 函数执行免密登录的配置操作。
6. 在脚本的最后，调用 `run_secret_free_login()` 函数开始执行免密登录操作。

## 使用方法

按照以下步骤使用CentOS系列的免密登录脚本：

1. 创建sh脚本文件
2. `chmod +x 免密登录脚本.sh`
3. 运行脚本命令：`./免密登录脚本.sh 用户名 IP地址 密码`
4. 等待脚本执行完成，输出相应的结果

## 注意事项

- 在运行脚本之前，请确保已经安装了OpenSSH工具和Expect工具。
- 请确保输入的IP地址是正确的，并且目标主机可以通过网络访问。
- 如果脚本执行失败或输出错误信息，请仔细检查输入的参数和前提条件。

