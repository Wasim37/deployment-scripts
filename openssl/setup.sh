#!/bin/bash

# Copyright 2016 Chen Peng <senpal220@qq.com> All rights reserved.
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

# 脚本参数
setup_type=host

# 读取脚本参数
while getopts 't:d:' opt
do
  case $opt in
    t ) setup_type=$OPTARG;;
    d ) download_url=$OPTARG;;
    ? ) echo '使用帮助：'
        echo '-t <安装类型>，包括：host(物理机)、docker(Docker)、aliyun(阿里云)'
        echo '-d <下载地址>'
        exit 1;;
  esac
done

# 安装参数
setup_dir='/usr/local/ssl'

download_file() {
  if [ $setup_type != 'docker' ] && [ -n "$download_url" ] ; then
    echo '下载安装文件...'
    yum install -y wget
    rm -f $build_dir/*.gz
    wget -c $download_url -P $build_dir
  fi
}

copy_file() {
  if [ $setup_type != 'docker' ] ; then
    echo '拷贝安装文件...'
    tar_file=`cd $build_dir; ls *.gz`
    mkdir -p $setup_dir /tmp/openssl
    tar -zxvf $build_dir/$tar_file --strip-components 1 -C /tmp/openssl
  fi
}

setup() {
  echo '安装程序...'
  yum install -y gcc perl
  cd /tmp/openssl
  ./config --prefix=$setup_dir
  make && make install
  rm -rf /tmp/openssl

  mv /usr/bin/openssl /usr/bin/openssl.old
  mv /usr/include/openssl /usr/include/openssl.old
  ln -s $setup_dir/bin/openssl /usr/bin/openssl
  ln -s $setup_dir/include/openssl /usr/include/openssl

  echo "$setup_dir/lib" >> /etc/ld.so.conf
  ldconfig
}

set_env() {
  if [ $setup_type != 'docker' ] ; then
    echo '设置环境变量...'
    echo >> /etc/profile
    echo "export OPENSSL=$setup_dir/bin" >> /etc/profile
    echo 'export PATH=$OPENSSL:$PATH' >> /etc/profile
    source /etc/profile
  fi
}

echo '开始安装OpenSSL...'

download_file
copy_file
setup
set_env

echo 'OpenSSL安装完成！'

exit 0
