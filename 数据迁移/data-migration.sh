#!/bin/bash

# Copyright 2017 Wasim <1119606460@qq.com> All rights reserved.
#
# 系统支持：CentOS测试通过；
################################################################################

read_args(){
	# 将配置文件参数存入系统session当中
	source data-migration.conf
}

# 生成源数据库的sql脚本
backup_mysql_source(){
	ssh -p $mysql_source_sshport root@$mysql_source_sship " \
	echo '生成$mysql_source_host:$mysql_source_port源数据库$mysql_source_db的sql语句' &&\
	mysqldump $mysql_source_db -h$mysql_source_host -P$mysql_source_port -u$mysql_source_user -p$mysql_source_pwd > /tmp/$mysql_source_db.sql"
}
# 备份目标数据库的sql脚本
backup_mysql_target(){
	ssh -p $mysql_source_sshport root@$mysql_source_sship " \
	echo '生成$mysql_target_host:$mysql_target_port源数据库$mysql_target_db的sql语句' &&\
	mysqldump $mysql_target_db -h$mysql_target_host -P$mysql_target_port -u$mysql_target_user -p$mysql_target_pwd > /tmp/$mysql_target_db-$(date +%y%m%d).sql"
}

# 将源数据库sql脚本拷贝至目标数据库机器
# 将目标数据库备份的sql脚本保存至执行脚本下
copy_mysql_source(){
	scp -P $mysql_source_sshport root@$mysql_source_sship:/tmp/$mysql_source_db.sql ./
	scp -P $mysql_target_sshport root@$mysql_target_sship:/tmp/$mysql_target_db-$(date +%y%m%d).sql ./
	mv ./$mysql_target_db-$(date +%y%m%d).sql ./$mysql_target_db-$(date +%y%m%d%H%M%S).sql
	scp -P $mysql_target_sshport ./$mysql_source_db.sql  root@$mysql_target_sship:/usr/
	rm -rf ./$mysql_source_db.sql
}
# 恢复目标数据库的数据，一般时间可能会稍长（数据量在1G以下可考虑使用该方案）
restore_mysql_target(){
	ssh -p $mysql_target_sshport root@$mysql_target_sship " \
	echo '还原$mysql_target_host:$mysql_target_port目标数据库$mysql_target_db' &&\
	mysql $mysql_target_db -u$mysql_target_user -p$mysql_target_pwd -h$mysql_target_host -P$mysql_target_port < /usr/$mysql_source_db.sql"
}

mysql_migration(){
	if [ "true" == "$mysql_open" ]; then
		backup_mysql_source
		backup_mysql_target
		copy_mysql_source
		restore_mysql_target
	else
		echo "跳过mysql数据迁移"
	fi
	
}

#目标索引列表
es_target_index_list=()
es_source_index_list=()
parase_es_args(){

	echo '解析源es索引库参数'$es_source_index
	OLD_IFS="$IFS" 
	IFS="," 
	es_source_index_list=($es_source_index) 
	IFS="$OLD_IFS" 
	for index in ${es_source_index_list[@]} 
	do 
    	echo "源索引：$index" 
	done

	echo '解析目标es索引库参数'$es_target_index
	OLD_IFS="$IFS" 
	IFS="," 
	es_target_index_list=($es_target_index) 
	IFS="$OLD_IFS" 
	for index in ${es_target_index_list[@]} 
	do 
    	echo "目标索引：$index" 
	done
}

backup_es_target(){
	backup_time=$(date +%y%m%d%H%M%S)
	for index in ${es_target_index_list[@]} 
	do
		echo '备份目标索引'$index-$backup_time
    	elasticdump --input=http://$es_target_host:$es_target_port/$index --output=http://$es_target_host:$es_target_port/$index-$backup_time --type=mapping
		elasticdump --input=http://$es_target_host:$es_target_port/$index --output=http://$es_target_host:$es_target_port/$index-$backup_time --type=analyzer
		elasticdump --input=http://$es_target_host:$es_target_port/$index --output=http://$es_target_host:$es_target_port/$index-$backup_time --type=data
	
	done
}

delete_es_target(){
	for index in ${es_target_index_list[@]} 
	do 
		echo '删除目标索引'$index
    	curl -XDELETE 'http://'$es_target_host':'$es_target_port'/'$index
	done
}

copy_es_source2target(){
	i=0
	for index in ${es_target_index_list[@]} 
	do 
		echo '同步源索引'${es_source_index_list[$i]}至目标索引$index
    	elasticdump --input=http://$es_source_host:$es_source_port/${es_source_index_list[$i]} --output=http://$es_target_host:$es_target_port/$index --type=mapping
		elasticdump --input=http://$es_source_host:$es_source_port/${es_source_index_list[$i]} --output=http://$es_target_host:$es_target_port/$index --type=analyzer
		elasticdump --input=http://$es_source_host:$es_source_port/${es_source_index_list[$i]} --output=http://$es_target_host:$es_target_port/$index --type=data
		let i++
	done
}

es_migration(){
	if [ "true" == "$es_open" ]; then
		parase_es_args
		if [ ${#es_target_index_list[@]} == ${#es_source_index_list[@]} ]; then
			echo '源索引库和目标索引库数量一致'
			backup_es_target
			delete_es_target
			copy_es_source2target
		else
			echo '源索引库和目标索引库数量不一致，退出'
			exit -1
		fi
		
	else
		echo "跳过es数据迁移"
	fi
}

stop_redis_target(){
	ssh -p $redis_target_sshport root@$redis_target_sship " \
	echo '停止目标redis实例'$redis_target_host':'$redis_target_port && \
	echo '停止命令'$redis_target_close_cmd
	$redis_target_close_cmd"

}

backup_redis_target(){
	ssh -p $redis_target_sshport root@$redis_target_sship " \
	redis_date=$(date +%y%m%d%H%M%S) && \
	echo '备份目标redis数据'$redis_target_host':'$redis_target_port $redis_target_data_dir'/'$redis_target_data_file-'$redis_date && \
	mv $redis_target_data_dir'/'$redis_target_data_file $redis_target_data_dir'/'$redis_target_data_file'-'$redis_date"
}

copy_redis_data_source2target(){
	echo '将源redis数据复制到目标redis'
	scp -P $redis_source_sshport root@$redis_source_sship:$redis_source_data_dir'/'$redis_source_data_file ./
	mv ./$redis_source_data_file ./$redis_target_data_file
	scp -P $redis_target_sshport ./$redis_target_data_file root@$redis_target_sship:$redis_target_data_dir'/'
}

start_redis_target(){
	ssh -p $redis_target_sshport root@$redis_target_sship " \
	echo '启动目标redis实例'$redis_target_host':'$redis_target_port && \
	$redis_target_start_cmd"
}

redis_migration(){
	if [ "true" == "$redis_open" ]; then
		stop_redis_target
		backup_redis_target
		copy_redis_data_source2target
		start_redis_target
	else
		echo "跳过redis数据迁移"
	fi
}

read_args
mysql_migration
es_migration
redis_migration


