#!/bin/bash

# Copyright 2016 Chen Hao <344078237@qq.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 系统支持：CentOS测试通过；
# 关闭密码登录服务
################################################################################
config(){
	echo 'config /etc/ssh/sshd_config,set "PasswordAuthentication no"'
	sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
}



config
echo 'restart sshd service'
service sshd restart

