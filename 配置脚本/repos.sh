#!/bin/bash

# Copyright 2016 Chen Peng <senpal220@qq.com> All rights reserved.
#
# 安装类型：支持物理机、阿里云；
# 系统支持：CentOS测试通过；
# 
################################################################################

# 脚本参数
setup_type=host

# 读取脚本参数
while getopts 't:' opt
do
  case $opt in
    t ) setup_type=$OPTARG;;
    d ) download_url=$OPTARG;;
    ? ) echo '使用帮助：'
        echo '-t <安装类型>，包括：host(物理机)、aliyun(阿里云)'
        exit 1;;
  esac
done

# 备份源
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

# 安装阿里云源
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo
# 使用阿里云内网，不占用公网带宽
if [ $setup_type = 'aliyun' ] ; then
  sed -i 's/aliyun.com/aliyuncs.com/'  /etc/yum.repos.d/CentOS-Base.repo
fi

# 安装EPEL源
# rpm -ivh http://mirrors.sohu.com/fedora-epel/epel-release-latest-6.noarch.rpm
# rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

# 安装REMI源
# rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
#rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-remi

# 安装优先级插件
# yum install yum-priorities

yum clean all
yum makecache

exit 0
