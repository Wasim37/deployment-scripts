#!/bin/bash

# Copyright 2016 wasim <wasim37@163.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 服务名称：默认为实例目录名；
# 系统支持：CentOS测试通过；
################################################################################

# 获取脚本所在目录
if [ "$0" = "-bash" ]; then
  build_dir=$(cd `dirname $BASH_SOURCE`; pwd)
else
  build_dir=$(cd `dirname $0`; pwd)
fi

setup() {
  #安装
  tar_file=`cd $build_dir; ls *.rpm`
  sudo rpm -i $build_dir/$tar_file

  #配置服务
  echo '配置atlas服务...'
  cp $build_dir/atlas /etc/init.d/atlas
  chmod +x /etc/init.d/atlas

  echo '启动atlas服务...'
  service atlas start

}

echo '开始安装atlas...'

setup

echo 'atlas安装完成------success----'
echo 'atlas默认安装目录为: /usr/local/mysql-proxy'

exit 0
