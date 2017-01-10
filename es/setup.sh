#!/bin/bash

# Copyright 2016 wasim <wasim37@163.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 服务名称：默认为实例目录名；
# 系统支持：CentOS测试通过；
# 安装依赖：java
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
setup_dir='/usr/local/es'
instance_dir='/var/es'
port='9200'
node_name='node'
bind_ip='0.0.0.0'

parse_args() {
  read -p "请输入实例目录 [$instance_dir]：" _instance_dir
  if [ -n "$_instance_dir" ] ; then
    instance_dir=$_instance_dir
  fi
  read -p "请输入端口 [$port]：" _port
  if echo $_port | egrep -q '^[0-9]+$' ; then
    port=$_port
  fi
  read -p "请输入节点名称 [$node_name]：" _node_name
  if [ -n "$_node_name" ] ; then
    node_name=$_node_name
  fi
  read -p "请输入绑定IP [$bind_ip]：" _bind_ip
  if [ -n "$_bind_ip" ] ; then
    bind_ip=$_bind_ip
  fi

  printf "参数如下：\n"
  printf "%-30s = %s\n" "实例目录" "$instance_dir"
  printf "%-28s = %s\n" "端口" "$port"
  printf "%-30s = %s\n" "节点名称" "$node_name"
  printf "%-28s = %s\n" "绑定IP" "$bind_ip"

  # 实例配置
  conf_path=$instance_dir/config/elasticsearch.yml
  data_dir=$instance_dir/data
  logs_dir=$instance_dir/logs
  scripts_dir=$instance_dir/scripts
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
    cp $build_dir/elasticsearch /etc/init.d/`basename $instance_dir`
  fi
}

setup() {
  echo '安装程序...'
  source /etc/profile

  # 创建目录
  mkdir -p $instance_dir
  mv $setup_dir/config $instance_dir

  # 添加用户、组，设置权限
  groupadd es
  useradd -r -g es es

  chown -R es:es $setup_dir $instance_dir
  chmod 750 $setup_dir $instance_dir

  # 配置文件
  sed -i '/path.data:/c path.data: '$data_dir'' $conf_path
  sed -i '/path.logs:/c path.logs: '$logs_dir'' $conf_path
  sed -i '/Paths/a \
path.scripts: '$scripts_dir' \
' $conf_path
  sed -i '/http.port:/c http.port: '$port'' $conf_path
  sed -i '/node.name:/c node.name: '$node_name'' $conf_path
  sed -i '/network.host:/c network.host: '$bind_ip'' $conf_path

  # 安装  elasticsearch-head 插件
  cp -r $build_dir/plugins/head $setup_dir/plugins
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
  sed -i '/PROGRAM=/c PROGRAM='$setup_dir'/bin/elasticsearch' /etc/init.d/`basename $instance_dir`
  sed -i '/CONFFILE=/c CONFFILE='$conf_path'' /etc/init.d/`basename $instance_dir`
  sed -i '/PIDFILE=/c PIDFILE='$instance_dir'/es.pid' /etc/init.d/`basename $instance_dir`

  # 添加服务
  chmod +x /etc/init.d/`basename $instance_dir`
  chkconfig --add `basename $instance_dir`
  service `basename $instance_dir` start

  # 开机自启服务
  if [ $setup_type != 'docker' ] ; then
    chkconfig `basename $instance_dir` on
  fi
}

echo '开始安装Elasticsearch...'

parse_args
download_file
copy_file
setup
config_iptables
add_service

echo 'Elasticsearch安装完成！'

exit 0
