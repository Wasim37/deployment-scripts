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
setup_dir='/usr/local/nginx'
instance_dir='/var/nginx'
port='80'

parse_args() {
  read -p "请输入实例目录 [$instance_dir]：" _instance_dir
  if [ -n "$_instance_dir" ] ; then
    instance_dir=$_instance_dir
  fi
  read -p "请输入端口 [$port]：" _port
  if echo $_port | egrep -q '^[0-9]+$' ; then
    port=$_port
  fi

  printf "参数如下：\n"
  printf "%-32s = %s\n" "实例目录" "$instance_dir"
  printf "%-30s = %s\n" "端口" "$port"

  # 实例配置
  web_dir=$instance_dir/html
  conf_path=$instance_dir/conf/nginx.conf
  http_log_path=$instance_dir/logs/access.log
  error_log_path=$instance_dir/logs/error.log
  pid_path=$instance_dir/nginx.pid
}

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
    mkdir -p $setup_dir
    tar -zxvf $build_dir/$tar_file --strip-components 1 -C $setup_dir
    cp $build_dir/nginx /etc/init.d/`basename $instance_dir`
  fi
}

setup() {
  echo '安装程序...'
  yum -y install gcc zlib zlib-devel openssl openssl-devel pcre pcre-devel

  # 创建目录
  mkdir -p $instance_dir
  mkdir -p $web_dir

  # 添加用户、组，设置权限
  groupadd nginx
  useradd -r -g nginx -s /bin/false nginx

  chown -R nginx:nginx $setup_dir $instance_dir
  chmod 750 $setup_dir $instance_dir

  # 安装
  cd $setup_dir
  ./configure --prefix=$setup_dir \
              --conf-path=$conf_path \
              --error-log-path=$error_log_path \
              --http-log-path=$http_log_path \
              --pid-path=$instance_dir/nginx.pid \
              --group=nginx \
              --user=nginx \
              --with-http_ssl_module
  make && make install

  # 配置文件
  sed -i 's#^\s*root   html# \           root   '$web_dir'#' $conf_path
  sed -i 's#\#error_log  logs/error.log;#error_log  '$error_log_path'  error;#' $conf_path
  sed -i 's#\#pid        logs/nginx.pid;#pid        '$pid_path';#' $conf_path
  sed -i 's/^\s*listen       80;/ \       listen       '$port';/' $conf_path
  sed -i 's/#user  nobody;/user  nginx;/' $conf_path

  # Docker非守护模式
  if [ $setup_type = 'docker' ] ; then
    sed -i '1s/^/daemon off;/' $conf_path
  fi
}

config_iptables() {
  if [ $setup_type = 'host' ] ; then
    echo '配置防火墙...'
    sed -i '/--dport 22/a -A INPUT -m state --state NEW -m tcp -p tcp --dport '$port' -j ACCEPT' /etc/sysconfig/iptables
    service iptables restart
  fi
}

add_service() {
  echo '添加启动服务...'

  # 配置启动脚本
  sed -i '/PRGFILE=/c PRGFILE='$setup_dir'/sbin/nginx' /etc/init.d/`basename $instance_dir`
  sed -i '/CONFIGFILE=/c CONFIGFILE='$conf_path'' /etc/init.d/`basename $instance_dir`
  sed -i '/PIDFILE=/c PIDFILE='$pid_path'' /etc/init.d/`basename $instance_dir`

  # 添加服务
  chmod +x /etc/init.d/`basename $instance_dir`
  chkconfig --add `basename $instance_dir`
  service `basename $instance_dir` start

  # 开机自启服务
  if [ $setup_type != 'docker' ] ; then
    chkconfig `basename $instance_dir` on
  fi
}

echo '开始安装Nginx...'

parse_args
download_file
copy_file
setup
config_iptables
add_service

echo 'Nginx安装完成！'

exit 0
