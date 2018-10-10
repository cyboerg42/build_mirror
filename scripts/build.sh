#!/bin/bash
# OUTPUT OPTIONS
CTRL_DIR="/tmp/build"
LOG="/tmp/build.log"
# THREADING OPTIONS
CORES=32
threads=8
CORES=$(($CORES * 3)) # overbook CPU
timeout=120

# BUILD FLAGS
BUILD_USER="peter"
DEB_BUILD_BY="peter.kowalsky"
CC="gcc"
CXX="g++"
CFLAGS="-march=native -mtune=native -O2"
CPPFLAGS="-march=native -mtune=native -O2"

# INTERNAL STUFF
db="build_dpkg"
CORES=$(($CORES / $threads))

echo_ () {
	echo [$(date +"%T")] - $1 >> $LOG
}

initSQLiteDB () {
        db=$1
	mkdir $CTRL_DIR
        rm $CTRL_DIR/$db.db
        touch $CTRL_DIR/$db.db
        sqlite_return=$(sqlite3 $CTRL_DIR/$db.db "PRAGMA busy_timeout = 10000; create table queue (id INTEGER PRIMARY KEY,name TEXT,status INTEGER);" | sed -n 2p & wait)
        echo_ "finished initSQdb!"
}


build_pkg () {
        db=$1
        thread_number=$2
        threads=$3
	from=$(($4 - $2))
        sleep $(($thread_number * 10))
	echo_ "[$db] - [build from $from] - build thread $2 starting..."
	touch "$CTRL_DIR/build_$thread_number.pid"
	touch "$CTRL_DIR/build_$thread_number.out"
        chmod 777 "$CTRL_DIR/build_$thread_number.pid"
        chmod 777 "$CTRL_DIR/build_$thread_number.out"

        for i in $(seq $from -1 0)
        do
                db_id=$(($i + 1))
                sqlite_return=$(sqlite3 $CTRL_DIR/$db.db "PRAGMA busy_timeout = 10000; UPDATE queue SET status= CASE WHEN status = 0 THEN 1 ELSE 2 END WHERE id = $db_id; select status from queue where id = $db_id;" | sed -n 2p & wait)
                        if [[ "$sqlite_return" == "1" ]]
                        then
				dir=$(sqlite3 $CTRL_DIR/$db.db "PRAGMA busy_timeout=10000; select name from queue where id = $db_id;" | sed -n 2p & wait)
				echo_ "[$thread_number] - [$i] building pkg $dir..."
    				cd $dir
				rm "$CTRL_DIR/build_$thread_number.status"
    				touch "$CTRL_DIR/build_$thread_number.status"
				chmod 777 "$CTRL_DIR/build_$thread_number.status"
				apt -y install $(dpkg-checkbuilddeps 2>&1 | sed 's/dpkg-checkbuilddeps:\serror:\sUnmet build dependencies: //g' | sed 's/[\(][^)]*[\)] //g' | cut -d'|' -f1)
				sudo su $BUILD_USER CC="$CC" CXX="$CXX" CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS" -c "export CC=\"$CC\"; export CXX=\"$CXX\"; export CFLAGS=\"$CFLAGS\"; export CXXFLAGS=\"$CXXFLAGS\"; dpkg-buildpackage --build-by=\"$DEB_BUILD_BY\" -rfakeroot -b -uc -j$CORES; echo \"$?\" > $CTRL_DIR/build_$thread_number.status" > $CTRL_DIR/build_$thread_number.out & echo "$!" > $CTRL_DIR/build_$thread_number.pid & wait
				while [[ "$(cat $CTRL_DIR/build_$thread_number.status)" == "" ]]
				do
					#echo_ "waiting for exit code..."
					sleep 1
				done
				exit_code="$(cat $CTRL_DIR/build_$thread_number.status)"
				echo_ "[$thread_number] - [$i] $dir is done! exit code dpkg: $exit_code"
				cd ..
                        fi
        done
	echo_ "[$thread_number] - [$i] thread is done! killing stuck daemon..."
	sudo kill -9 $(cat $CTRL_DIR/check_build_$2.pid)
	exit
}

function check_build_pkg() {
        thread_number=$1
        threads_total=$2
	sleep $(($thread_number * 10))
	touch "$CTRL_DIR/check_build_$thread_number.pid"
	chmod 777 "$CTRL_DIR/check_build_$thread_number.pid"
        echo_ "[$thread_number] - starting stuck daemon..."
        while true
        do
        md5_begin=$(md5sum $CTRL_DIR/build_$1.out)
        sleep $timeout
        if [[ "$md5_begin" == "$(md5sum $CTRL_DIR/build_$1.out)" ]]
        then
		pid=$(cat $CTRL_DIR/build_$1.pid)
		echo_ "thread $thread_number is stuck! killing it..."
                sudo kill -9 $pid
		echo "killed" > $CTRL_DIR/build_$thread_number.status
        fi
        done
	exit
}

rm $LOG
touch $LOG
chmod 777 $LOG
initSQLiteDB $db

export CC="$CC"
export CXX="$CXX"
export CFLAGS="$CFLAGS"
export CPPFLAGS="$CPPFLAGS"

n_pkg=0
cd ../src/
for dir in ./*/
do
    dir=${dir%*/}
    echo ${dir##*/}
    sqlite_return=$(sqlite3 $CTRL_DIR/$db.db "PRAGMA busy_timeout = 10000; insert into queue (name,status) values ('${dir##*/}',0);" | sed -n 2p & wait)
    n_pkg=$(($n_pkg + 1))
done

for i in $(seq 1 1 $threads)
do
     build_pkg $db $i $threads $n_pkg &
done

for i in $(seq 1 1 $threads)
do
     check_build_pkg $i $threads &
     echo $! > $CTRL_DIR/check_build_$i.pid &
done

wait

echo_ "killing all zombies..."
kill $(ps -A -ostat,ppid | awk '/[zZ]/ && !a[$2]++ {print $2}')
echo_ "build is done! :D"
rm -rf $CTRL_DIR
