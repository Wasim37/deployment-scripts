#!/bin/bash

# Copyright 2016 wasim <wasim37@163.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 系统支持：CentOS测试通过；
# 
################################################################################

set_agent() {
  rpm -ivh http://repo.zabbix.com/zabbix/2.2/rhel/6/x86_64/zabbix-release-2.2-1.el6.noarch.rpm
  yum install zabbix-agent

  # 默认配置文件路径 /etc/zabbix/zabbix_agentd.conf
  sed -i 's/# EnableRemoteCommands=0/EnableRemoteCommands=1/g' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/# UnsafeUserParameters=0/UnsafeUserParameters=1/g' /etc/zabbix/zabbix_agentd.conf

  # 开机自启动
  chkconfig zabbix-agent on
  chkconfig --list|grep zabbix-agent

  # 启动客户端
  service zabbix-agent start
}

echo '开始安装zabbix_agent...'

set_agent

echo 'zabbix_agent安装完成！'

exit 0