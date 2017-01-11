#!/bin/bash

# Copyright 2016 wasim <wasim37@163.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 系统支持：CentOS测试通过；
# 
################################################################################

# 获取脚本所在目录
if [ "$0" = "-bash" ]; then
  build_dir=$(cd `dirname $BASH_SOURCE`; pwd)
else
  build_dir=$(cd `dirname $0`; pwd)
fi

set_htop() {
    echo '安装htop...'
    yum -y install htop
    echo 'htop...安装成功'
}

echo '脚本运行开始...'

set_htop

echo '脚本运行完成...success...'

exit 0
