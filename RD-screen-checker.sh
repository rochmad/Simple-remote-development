#!/bin/bash
if [ ! -z $DEBUG ]; then
	set -x
fi

if [ ! -z $NAME ]; then
	NAME=$1
else
	NAME=Rochmads
fi

DIR_DEST="$2"
echo -e "Mounting Dir --> $DIR_DEST"

SCR_LS=($(screen -ls | grep "$NAME" | awk '{print $1"."$4}' | sort))
TTY_NOW=$(echo $SSH_TTY | cut -d/ -f 4)
TTY_LIST=($(ps -ax | grep -e "[s]sh" | grep "[p]ts" | awk '{print $6}' | cut -d/ -f 2 ))

make_new_screen(){
		echo -e "\nmounting dir $DIR_DEST\n\n"
		# echo "screen name $NAME"
		if [ -z $TTY_NOW ]; then
			TTY_NOW=0
			TTY_NOW=$(($RANDOM % 30))
		fi		
		SCR_CHECK=$(screen -ls | grep "$TTY_NOW.$NAME" | awk '{print $1"."$4}' | sort)
		if [ -z "$SCR_CHECK" ]; then
			echo -e "screen -R $TTY_NOW.$NAME\n\n "
			if [ ! -z $DEBUG ]; then
				sleep 10
			else
				sleep 3
			fi
			#  screen -dR Rochmads.a bash -c 'cd ~/srd4; bash'
			screen -dR $TTY_NOW.$NAME bash -c "cd $DIR_DEST; bash"
			exit
		else
			echo -e "screen -R $TTY_NOW.$NAME$(echo $(($TTY_NOW+1)))\n\n "
			if [ ! -z $DEBUG ]; then
				sleep 10
			else
				sleep 3
			fi
			#  screen -dR Rochmads.a bash -c 'cd ~/srd4; bash'
			screen -dR $TTY_NOW.$NAME bash -c "cd $DIR_DEST; bash"
		fi
	exit
}

resume_screen(){
		RESUME="\nscreen with name --> $PID_SCR.$TTY_SCR.$NAME_SCR <-- is Detached, doing re-Attach \nscreen -r $PID_SCR.$TTY_SCR.$NAME_SCR\n"
		echo -e "$RESUME"
		sleep 5
		# screen -r $PID_SCR.$TTY_SCR.$NAME_SCR bash -c 'cd $DIR_DEST; bash'
		screen -dr $PID_SCR.$TTY_SCR.$NAME_SCR
		exit 

}

if [ ! -z "$SCR_LS" ]; then
	for i in ${SCR_LS[*]}; do
		PID_SCR=$(echo $i | cut -d. -f 1)
		NAME_SCR=$(echo $i | cut -d. -f 3)
		TTY_SCR=$(echo $i | cut -d. -f 2)
		STS_SCR=$(echo $i | cut -d. -f 4)
		for ttyi in ${TTY_LIST[*]}; do
			if [[ "$ttyi" == "$TTY_SCR" ]]; then
				# echo -e "match"
				echo -e "screen avaliable : $i"
				if [[ "$STS_SCR" =~ "Detached" ]]; then
					resume_screen
				fi
			fi
		done
		if [[ "$STS_SCR" =~ "Detached" ]]; then
			resume_screen
		fi
		# echo -e "sini"
	done
	echo -e "\nOther Screen is Attached, none of that is Detached, created new with name ---> $TTY_NOW.$NAME"
	make_new_screen

else
	echo -e "\nCreate new screen with name ---> $TTY_NOW.$NAME\n"
	make_new_screen
fi
