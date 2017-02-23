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
setup_dir='/usr/local/mysql'
instance_dir='/data/mysql'
port='3370'
password='wx123aL'

parse_args() {
  read -p "请输入实例目录 [$instance_dir]：" _instance_dir
  if [ -n "$_instance_dir" ] ; then
    instance_dir=$_instance_dir
  fi
  read -p "请输入端口 [$port]：" _port
  if echo $_port | egrep -q '^[0-9]+$' ; then
    port=$_port
  fi
  read -p "请输入密码 [$password]：" _password
  if [ -n "$_password" ] ; then
    password=$_password
  fi

  printf "参数如下：\n"
  printf "%-32s = %s\n" "实例目录" "$instance_dir"
  printf "%-30s = %s\n" "端口" "$port"
  printf "%-30s = %s\n" "密码" "$password"

  # 实例配置
  conf_path=$instance_dir/my.cnf
  data_dir=$instance_dir/data
  log_path=$instance_dir/logs/mysqld.log
  pid_path=$instance_dir/mysql.pid
  socket_path=$instance_dir/mysql.sock
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
  fi
}

setup() {
  echo '安装程序...'
  source /etc/profile

  # 创建目录
  mkdir -p $instance_dir
  mkdir -p $data_dir
  mkdir -p `dirname $log_path`
  mkdir -p `dirname $pid_path`
  mkdir -p `dirname $socket_path`

  # 添加用户、组，设置权限
  groupadd mysql
  useradd -r -g mysql -s /bin/false mysql

  chown -R mysql:mysql $setup_dir $instance_dir
  chmod 750 $setup_dir $instance_dir

  # 安装，初始化数据库
  yum install -y libaio
  $setup_dir/bin/mysqld --initialize-insecure --user=mysql --basedir=$setup_dir --datadir=$data_dir

  # 配置文件
  cp -rf $setup_dir/support-files/my-default.cnf $conf_path
  sed -i '/basedir =/c basedir = '$setup_dir'' $conf_path
  sed -i '/datadir =/c datadir = '$data_dir'' $conf_path
  sed -i '/socket =/c socket = '$socket_path'' $conf_path
  sed -i '/port =/c port = '$port'' $conf_path

  sed -i '/\[mysqld\]/i\
[mysql]\
socket = '$socket_path'\
' $conf_path

# 区分大小写
 sed -i '/\[mysqld\]/a\
lower_case_table_names = 1' $conf_path

  sed -i '/sql_mode=/i\
[mysqld_safe]\
user = mysql\
port = '$port'\
datadir = '$data_dir'\
log-error = '$log_path'\
pid-file = '$pid_path'\
socket = '$socket_path'\
' $conf_path

  # 启动服务，设置密码
  $setup_dir/bin/mysqld_safe --defaults-file=$conf_path &
  sleep 3
  $setup_dir/bin/mysqladmin -u root password $password --socket=$socket_path
}

set_env() {
  if [ $setup_type != 'docker' ] ; then
    echo '设置环境变量...'
    echo >> /etc/profile
    echo 'export PATH='$setup_dir'/bin:$PATH' >> /etc/profile
    source /etc/profile
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
  cp $setup_dir/support-files/mysql.server /etc/init.d/`basename $instance_dir`
  sed -i 's#basedir=$#basedir='$setup_dir'#' /etc/init.d/`basename $instance_dir`
  sed -i 's#datadir=$#datadir='$data_dir'#' /etc/init.d/`basename $instance_dir`
  sed -i 's#mysqld_pid_file_path=$#mysqld_pid_file_path='$pid_path'#' /etc/init.d/`basename $instance_dir`
  sed -i '/$bindir\/mysqld_safe --datadir/c \      $bindir\/mysqld_safe --defaults-file='$conf_path' 1>/dev/null &' /etc/init.d/`basename $instance_dir`

  # 添加服务
  chmod +x /etc/init.d/`basename $instance_dir`
  chkconfig --add `basename $instance_dir`
  service `basename $instance_dir` restart

  echo '设置开机自启服务...'
  if [ $setup_type != 'docker' ] ; then
    chkconfig `basename $instance_dir` on
  fi
}

echo '开始安装MySQL...'

parse_args
download_file
copy_file
setup
set_env
# config_iptables
add_service


echo 'MySQL安装完成！'

exit 0
