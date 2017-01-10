#!/bin/bash

# Copyright 2016 wasim <wasim37@163.com> All rights reserved.
# 
# 安装类型：支持物理机、Docker、和阿里云；
# 安装介质：支持本地安装和下载安装；
# 安装文件：默认为当前目录的gz文件，请保证仅有一个；
# 服务名称：默认为实例目录名；
# 系统支持：CentOS测试通过；
# 安装依赖：java、apr
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
setup_dir='/usr/local/tomcat'
instance_dir='/var/tomcat'
http_port='8080'
ajp_port='8009'
shutdown_port='8005'

parse_args() {
  read -p "请输入实例目录 [$instance_dir]：" _instance_dir
  if [ -n "$_instance_dir" ] ; then
    instance_dir=$_instance_dir
  fi
  read -p "请输入HTTP端口 [$http_port]：" _http_port
  if echo $_http_port | egrep -q '^[0-9]+$' ; then
    http_port=$_http_port
  fi
  read -p "请输入AJP端口 [$ajp_port]：" _ajp_port
  if echo $_ajp_port | egrep -q '^[0-9]+$' ; then
    ajp_port=$_ajp_port
  fi
  read -p "请输入SHUTDOWN端口 [$shutdown_port]：" _shutdown_port
  if echo $_shutdown_port | egrep -q '^[0-9]+$' ; then
    shutdown_port=$_shutdown_port
  fi

  printf "参数如下：\n"
  printf "%-30s = %s\n" "实例目录" "$instance_dir"
  printf "%-28s = %s\n" "HTTP端口" "$http_port"
  printf "%-28s = %s\n" "AJP端口" "$ajp_port"
  printf "%-28s = %s\n" "SHUTDOWN端口" "$shutdown_port"
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
    cp $build_dir/tomcat /etc/init.d/`basename $instance_dir`
  fi
}

setup() {
  echo '安装程序...'
  source /etc/profile
  yum install -y gcc

  # 安装daemon，支持指定运行身份
  mkdir $setup_dir/bin/commons-daemon
  tar -zxvf $setup_dir/bin/commons-daemon-native.tar.gz --strip-components 1 -C $setup_dir/bin/commons-daemon
  cd $setup_dir/bin/commons-daemon/unix
  ./configure
  make
  cp $setup_dir/bin/commons-daemon/unix/jsvc $setup_dir/bin
  rm -rf $setup_dir/bin/commons-daemon

  # 安装tomcat-native，提高性能
  mkdir $setup_dir/bin/tomcat-native
  tar -zxvf $setup_dir/bin/tomcat-native.tar.gz --strip-components 1 -C $setup_dir/bin/tomcat-native
  cd $setup_dir/bin/tomcat-native/native
  ./configure --with-apr=$APR_HOME \
              --with-java-home=$JAVA_HOME \
              --disable-openssl \
              --prefix=$setup_dir
  make && make install

  # 创建目录
  mkdir -p $instance_dir
  mkdir -p $instance_dir/webapps/ROOT
  mv $setup_dir/conf $instance_dir
  mv $setup_dir/logs $instance_dir
  mv $setup_dir/temp $instance_dir
  mv $setup_dir/work $instance_dir

  # 添加用户、组，设置权限
  groupadd tomcat
  useradd -r -g tomcat -s /bin/false tomcat

  chown -R tomcat:tomcat $setup_dir $instance_dir
  chmod 750 $setup_dir $instance_dir

  # 配置文件
  sed -i 's/8080/'$http_port'/' $instance_dir/conf/server.xml
  sed -i 's/8009/'$ajp_port'/' $instance_dir/conf/server.xml
  sed -i 's/8005/'$shutdown_port'/' $instance_dir/conf/server.xml
  sed -i 's/SSLEngine="on"/SSLEngine="off"/' $instance_dir/conf/server.xml
  sed -i 's/SSLEnabled="true"/SSLEnabled="false"/' $instance_dir/conf/server.xml
}

config_iptables() {
  if [ $setup_type = 'host' ] ; then
    echo '配置防火墙...'
    sed -i '/--dport 22/a -A INPUT -m state --state NEW -m tcp -p tcp --dport '$http_port' -j ACCEPT' /etc/sysconfig/iptables
    service iptables restart
  fi
}

add_service() {
  echo '添加启动服务...'

  # 配置启动脚本
  sed -i '/export CATALINA_BASE/c export CATALINA_BASE='$instance_dir'' /etc/init.d/`basename $instance_dir`
  sed -i '/export CATALINA_HOME/c export CATALINA_HOME='$setup_dir'' /etc/init.d/`basename $instance_dir`
  sed -i '/export LD_LIBRARY_PATH/c export LD_LIBRARY_PATH='$setup_dir'/lib' /etc/init.d/`basename $instance_dir`

  # 添加服务
  chmod +x /etc/init.d/`basename $instance_dir`
  chkconfig --add `basename $instance_dir`
  service `basename $instance_dir` start

  # 开机自启服务
  if [ $setup_type != 'docker' ] ; then
    chkconfig `basename $instance_dir` on
  fi
}

echo '开始安装Tomcat...'

parse_args
#download_file
#copy_file
#setup
#config_iptables
#add_service

echo 'Tomcat安装完成！'

exit 0
