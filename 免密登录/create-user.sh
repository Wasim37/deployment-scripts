#!/bin/bash

# Copyright 2017 Chen Hao <344078237@qq.com> All rights reserved.
#
# 系统支持：CentOS测试通过；
################################################################################

# 配置参数
username='user'
password='000000'
sudoer=0

parse_args() {
  read -p "请输入用户名 [默认值：$username]:" _username
  if [ -n "$_username" ] ; then
    username=$_username
  fi
  read -p "请输入密码 [默认值：$password]:" _password
  if [ -n "$_password" ] ; then
    password=$_password
  fi
  read -p "允许提权 [默认值：0(0：不允许提权；1：允许提权)]:" _sudoer
  if [ -n "$_sudoer" ] ; then
    sudoer=$_sudoer
  fi

  printf "config:\n"
  printf "%-29s = %s\n" "用户名" "$username"
  printf "%-28s = %s\n" "密码" "$password"
  printf "%-30s = %s\n" "允许提权" "$password"
}

config() {
  useradd $username
  passwd $username <<- EOF
$password
$password
EOF

  if [ "$sudoer" = "1" ]; then
    sed -i '/Allow root to run any commands anywhere/a '$username'    ALL=(ALL)       ALL' /etc/sudoers
  fi
}

echo '开始创建用户...'

parse_args
config

echo '创建用户完成！'

exit 0