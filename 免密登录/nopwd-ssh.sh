#!/bin/bash

# Copyright 2016 Chen Hao <344078237@qq.com> All rights reserved.
# 
# 系统支持：CentOS测试通过；
################################################################################

# 读取脚本参数
config_user=root
while getopts 'ru' opt
do
  case $opt in
    r ) config_user=root;;
    u ) config_user=user;;
    ? ) echo '使用帮助：'
        echo '-r，管理员配置'
        echo '-u，用户配置'
        exit 1;;
  esac
done

# 配置参数
ssh_user='root'
ssh_ip='127.0.0.1'
ssh_port='22'
pub_dir=/

parse_args() {
  read -p "请输入SSH用户名 [$ssh_user]:" _ssh_user
  if [ -n "$_ssh_user" ] ; then
    ssh_user=$_ssh_user
  fi
  read -p "请输入SSH主机IP [$ssh_ip]:" _ssh_ip
  if [ -n "$_ssh_ip" ] ; then
    ssh_ip=$_ssh_ip
  fi
  read -p "请输入SSH主机端口 [$ssh_port]:" _ssh_port
  if echo $_ssh_port | egrep -q '^[0-9]+$' ; then
    ssh_port=$_ssh_port
  fi
  if [ $config_user == 'root' ]; then
    read -p "请输入用户公钥目录 或 公钥网络地址[$pub_dir]:" _pub_dir
    if [ -n "$_pub_dir" ] ; then
      pub_dir=$_pub_dir
    fi
  fi

  printf "config:\n"
  printf "%-29s = %s\n" "SSH用户名" "$ssh_user"
  printf "%-28s = %s\n" "SSH主机IP" "$ssh_ip"
  printf "%-30s = %s\n" "SSH主机端口" "$ssh_port"
  if [ $config_user == 'root' ]; then
    printf "%-30s = %s\n" "用户公钥目录" "$pub_dir"
  fi
}

config() {
  if [ $config_user == 'root' ]; then

    if [[ $pub_dir =~ 'http' ]]; then
      pub_key=`curl $pub_dir`
    else
      pub_key=`cd $pub_dir;cat id_rsa.pub`
    fi

    ssh_home=/home/$ssh_user
    if [ $ssh_user == 'root' ]; then
      ssh_home=/root
    fi


    # ssh -T root@$ssh_ip -p $ssh_port <<- EOF
    mkdir -p $ssh_home/.ssh
    if [ ! -d "$ssh_home/.ssh" ]; then
　　  mkdir $ssh_home/.ssh
    fi
    touch $ssh_home/.ssh/authorized_keys
    if [ ! -f "$ssh_home/.ssh/authorized_keys" ]; then
　　  touch $ssh_home/.ssh/authorized_keys
    fi  
    
    echo $pub_key >> $ssh_home/.ssh/authorized_keys
    chown $ssh_user:$ssh_user $ssh_home/.ssh $ssh_home/.ssh/authorized_keys
    chmod 700 $ssh_home/.ssh
    chmod 600 $ssh_home/.ssh/authorized_keys
  else
    # 生成密钥
    pub_path=`echo ~/.ssh/id_rsa.pub`
    if [ ! -r "$pub_path" ]; then
      echo '' | ssh-keygen -t rsa -P ''
    fi

    # 配置密钥
    ssh-copy-id -p $ssh_port $ssh_user@$ssh_ip
  fi
}

echo '开始配置SSH免密登录...'

parse_args
config

echo 'SSH免密登录配置完成！'

exit 0
