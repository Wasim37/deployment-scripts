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
setup_dir='/usr/local/redis'
instance_dir='/var/redis'
port='6379'
bind_ip='0.0.0.0'
password='000000'

parse_args() {
  read -p "请输入实例目录 [$instance_dir]：" _instance_dir
  if [ -n "$_instance_dir" ] ; then
    instance_dir=$_instance_dir
  fi
  read -p "请输入端口 [$port]：" _port
  if echo $_port | egrep -q '^[0-9]+$' ; then
    port=$_port
  fi
  read -p "请输入绑定IP [$bind_ip]：" _bind_ip
  if [ -n "$_bind_ip" ] ; then
    bind_ip=$_bind_ip
  fi
  read -p "请输入密码 [$password]：" _password
  if [ -n "$_password" ] ; then
    password=$_password
  fi

  printf "参数如下：\n"
  printf "%-30s = %s\n" "实例目录" "$instance_dir"
  printf "%-28s = %s\n" "端口" "$port"
  printf "%-28s = %s\n" "绑定IP" "$bind_ip"
  printf "%-28s = %s\n" "密码" "$password"

  # 实例配置
  conf_path=$instance_dir/redis.conf
  data_dir=$instance_dir/data
  logs_path=$instance_dir/redis.log
  pid_path=$instance_dir/redis.pid
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
    cp $build_dir/redis /etc/init.d/`basename $instance_dir`
  fi
}

setup() {
  echo '安装程序...'
  source /etc/profile
  yum install -y gcc

  # 创建目录
  mkdir -p $instance_dir

  # 安装
  modprobe bridge
  cd $setup_dir
  make && make install
  ./utils/install_server.sh<<-EOF
    $port
    $conf_path
    $logs_path
    $data_dir
    /usr/local/bin/redis-server
EOF

  # 添加用户、组，设置权限
  groupadd redis
  useradd -r -g redis -s /bin/false redis

  chown -R redis:redis $setup_dir $instance_dir
  chmod 750 $setup_dir $instance_dir

  # 修改内存分配策略
  echo >> /etc/sysctl.conf
  echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
  sysctl -p 1>/dev/null

  # 配置文件
  sed -i '/pidfile /c pidfile '$pid_path'' $conf_path
  sed -i '/^bind 127.0.0.1/c bind '$bind_ip'' $conf_path
  sed -i '/requirepass foobared/c requirepass '$password'' $conf_path

  # Docker非守护模式
  if [ $setup_type = 'docker' ] ; then
    sed -i '/daemonize yes/c daemonize no' $conf_path
  fi

  # 禁止高危命令
  echo >> $conf_path
  echo 'rename-command FLUSHALL ""' >> $conf_path
  echo 'rename-command CONFIG   ""' >> $conf_path
  echo 'rename-command EVAL     ""' >> $conf_path

  sed -i 's/$EXEC $CONF/sudo -u redis $EXEC $CONF/' /etc/init.d/redis_$port
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

  # 删除安装脚本自动添加的服务
  chkconfig --del redis_$port

  # 重命名安装脚本自动生成的服务脚本
  mv /etc/init.d/redis_$port /etc/init.d/`basename $instance_dir`

  # 添加服务
  chmod +x /etc/init.d/`basename $instance_dir`
  chkconfig --add `basename $instance_dir`

  service `basename $instance_dir` stop
  sed -i '/PIDFILE=/c PIDFILE='$pid_path'' /etc/init.d/`basename $instance_dir`
  sed -i 's/redis_'$port'/'$(basename $instance_dir)'/' /etc/init.d/`basename $instance_dir`
  sed -i '/$CLIEXEC -p $REDISPORT shutdown/c\            kill -9 $PID && rm -f $PIDFILE' /etc/init.d/`basename $instance_dir`

  service `basename $instance_dir` start

  # 开机自启服务
  if [ $setup_type != 'docker' ] ; then
    chkconfig `basename $instance_dir` on
  fi
}

echo '开始安装Redis...'

parse_args
download_file
copy_file
setup
config_iptables
add_service

echo 'Redis安装完成！'

exit 0
