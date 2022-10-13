#!/bin/bash
### Author
### Rochmad saputra
### rochmadsaputra@gmail.com
echo -e "Installing $PROJECT_NAME-RemoteDevelopment\nMake sure, nc rsync, inotifywait/fswatch, supervisor is installed on this system\n"


if [ ! -z $DEBUG ]; then
    set -x
fi

if [ ! -f .env ] ; then
    cp .env.example .env
    echo -e "copy .env.example to .env"
fi

source $PWD/.env
echo -e "\nReading .env from ---> $PWD/.env"
# eval $(cat $PWD/.env)
# PROJECT_DIR=$(dirname $PROJECT_DIR)
PROJECT_NAME=$(basename `cd $PROJECT_DIR && git rev-parse --show-toplevel`)
SCRIPT_ME=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
# $PROJECT_NAME-DIR=$PROJECT_DIR/../../../../
# $PROJECT_NAME-DIR="$(cd "$$PROJECT_NAME-DIR"; pwd)"
# PROJECT_HOME=$PROJECT_DIR
echo $PROJECT_NAME

if [ -z $PROJECT_NAME ]; then
    echo "$PROJECT_NAME error or dint exist"
    exit
fi


if [ -z $PROJECT_DIR ]; then
    echo "$PROJECT_DIR error or dint exist"
    exit
fi

if lsb_release -is &> /dev/null; then
    distribution=$(lsb_release -is)
else
    distribution=$(uname)
fi

if ! sudo echo ; then
    echo -e "Please provide root password"
    exit
fi

SCR_LS=($(ls $SCRIPT_ME/bin-static | sort))
mkdir -p $SCRIPT_ME/bin/
for i in ${SCR_LS[*]}; do
    cp $SCRIPT_ME/bin-static/$i $SCRIPT_ME/bin/$PROJECT_NAME-$i
    echo -e "configuring binary script $SCRIPT_ME/bin/$PROJECT_NAME-$i\n"
    chmod a+x $SCRIPT_ME/bin/$PROJECT_NAME-$i
    if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
            SED_COMMAND="sudo sed -i " 
            RD_SPV_CONF_LOC="/etc/supervisor/conf.d/"
            $SED_COMMAND "s|scripthome|$SCRIPT_ME|g" $SCRIPT_ME/bin/$PROJECT_NAME-$i
    elif [ "$distribution" == "Darwin" ]; then
            SED_COMMAND="sudo sed -i '' " 
            RD_SPV_CONF_LOC="/usr/local/etc/supervisor/conf.d/"
            $SED_COMMAND "s|scripthome|$SCRIPT_ME|g" $SCRIPT_ME/bin/$PROJECT_NAME-$i
    fi
    done


SUPERVISOR_SCRIPT(){
    if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
                sed -i "/\#$PROJECT_NAME-Remote_Development-SCRIPT/a alias $PROJECT_NAME-sync-RD-log='supervisorctl tail -f $PROJECT_NAME-sync-RD'" $SHELL_S
                sed -i "/\#$PROJECT_NAME-Remote_Development-SCRIPT/a alias $PROJECT_NAME-sync-RD-log-restart='supervisorctl restart $PROJECT_NAME-sync-RD'" $SHELL_S
                sed -i "/\#$PROJECT_NAME-Remote_Development-SCRIPT/a alias $PROJECT_NAME-sync-RD-log-stop='supervisorctl stop $PROJECT_NAME-sync-RD'" $SHELL_S
    elif [ "$distribution" == "Darwin" ]; then
                echo -e  "alias $PROJECT_NAME-sync-RD-log='supervisorctl tail -f $PROJECT_NAME-sync-RD'" >> $SHELL_S
                echo -e  "alias $PROJECT_NAME-sync-RD-log-restart='supervisorctl restart $PROJECT_NAME-sync-RD'" >>  $SHELL_S
                echo -e  "alias $PROJECT_NAME-sync-RD-log-stop='supervisorctl stop $PROJECT_NAME-sync-RD'" >> $SHELL_S
        echo "darwin"
    fi
}

SH_SCRIPT(){
    if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
        sed -i "/\#$PROJECT_NAME-Remote_Development-SCRIPT/a export PATH=\$PATH:$PWD/bin" $SHELL_S
        sed -i "/\#$PROJECT_NAME-Remote_Development-SCRIPT/a export $PROJECT_NAME"_DIR"="$PROJECT_DIR"" $SHELL_S
        SUPERVISOR_SCRIPT
    elif [ "$distribution" == "Darwin" ]; then
        echo -e  "export PATH=\$PATH:$PROJECT_DIR"  >> $SHELL_S
        echo -e  "export $PROJECT_NAME"_DIR"="$PROJECT_DIR"" >>  $SHELL_S
        SUPERVISOR_SCRIPT
    fi
}

if [[ "$(echo $SHELL)" =~ "bash" ]]; then
            echo "injecting script to ~/.bashrc"
            SHELL_S=~/.bashrc
        if ! grep -i $PROJECT_NAME-Remote_Development-SCRIPT $SHELL_S &> /dev/null; then
                echo -e "\n#$PROJECT_NAME-Remote_Development-SCRIPT"  >> $SHELL_S
                SH_SCRIPT
                echo -e "#$PROJECT_NAME-Remote_Development-SCRIPTEND\n"  >> $SHELL_S
        fi
elif [[ "$(echo $SHELL)" =~ "zsh" ]]; then
        echo "injecting script to ~/.bashrc"
        SHELL_S=~/.zshrc
        if ! grep -i $PROJECT_NAME-Remote_Development-SCRIPT $SHELL_S &> /dev/null; then
                echo -e "\n#$PROJECT_NAME-Remote_Development-SCRIPT"  >> $SHELL_S
                SH_SCRIPT
                echo -e "#$PROJECT_NAME-Remote_Development-SCRIPTEND\n"  >> $SHELL_S
        fi
fi

 
if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
    echo -e "Local distribution is $distribution\n" 
    if ! which inotifywait &> /dev/null; then
        echo -e"\n inotifywait not found, please install \n"
        sudo apt install nc rsync inotify-tools autossh -f -y || exit 
    else        
        if ! grep -i fs.inotify.max_user_watches /etc/sysctl.conf &> /dev/null; then
            # sudo  bash -c "sed -i -n -e '/^fs.inotify.max_user_watches/!p' -e '$afs.inotify.max_user_watches=100000' /etc/sysctl.conf "
            sudo bash -c "echo "fs.inotify.max_user_watches=1000000" >> /etc/sysctl.conf "
        fi
    fi
elif [ "$distribution" == "Darwin" ]; then
        if ! which fswatch &> /dev/null; then
            echo -e"\n rsync not found, please install \n"
            brew install fswatch autossh rsync || exit 
        fi
fi

SPV_RELOAD(){
            echo -e "reloading supervisor $PROJECT_NAME-sync-RD"
            sudo supervisorctl reread &> /dev/null
            sudo supervisorctl update &> /dev/null
}

SPV_PROJECT_RELOAD(){
            if ! sudo supervisorctl restart $PROJECT_NAME-sync-RD &> /dev/null; then
                echo -e "command \"sudo supervisorctl restart $PROJECT_NAME-sync-RD\"\t failed to run, please check\n"
                sudo supervisorctl restart $PROJECT_NAME-sync-RD &> /dev/null
            else
                sudo supervisorctl stop $PROJECT_NAME-sync-RD &> /dev/null
                echo -e "command \"sudo supervisorctl start $PROJECT_NAME-sync-RD\"\t success ...(y)\n"
            fi
}

SED_CONF(){
        $SED_COMMAND "s|projectrunname|$PROJECT_NAME-sync-RD|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        $SED_COMMAND "s|projectrunscript|$SCRIPT_ME/bin/$PROJECT_NAME-sync-RD|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        $SED_COMMAND "s|projectname|$PROJECT_NAME|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        $SED_COMMAND "s|projecthome|$PROJECT_DIR|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        $SED_COMMAND "s|projectdirectory|$SCRIPT_ME|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        $SED_COMMAND "s|scripthome|$SCRIPT_ME|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        USER_INSTALL=$USER
        $SED_COMMAND "s|runneruser|$USER_INSTALL|g" $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
}
SPV_PROJECT_CONF(){
    if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
        echo -e "Supervisor already installed"
        echo -e "make sure \"chmod=0777\" in /etc/supervisor/supervisord.conf"
        echo -e "[unix_http_server]\nchmod=0777; sockef file mode (default 0700)\n"
        SED_COMMAND="sudo sed -i" 
        RD_SPV_CONF_LOC="/etc/supervisor/conf.d/"
        $SED_COMMAND "s|=0700|=0777|g" /etc/supervisor/supervisord.conf

        echo -e "reconfiguring supervisor $PROJECT_NAME-sync-RD"
        sudo cp rd-supervisor.conf $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        SED_CONF
        SPV_RELOAD
        SPV_PROJECT_RELOAD
        echo -e "\ndone installing "
    elif [ "$distribution" == "Darwin" ]; then
        echo "darwin"
        echo -e "supervisor already installed"
        echo -e "make sure \"chmod=0777\" in /usr/local/etc/supervisor/supervisord.conf"
        echo -e "[unix_http_server]\nchmod=0777; sockef file mode (default 0700)\n"
        echo -e "reconfiguring supervisor $PROJECT_NAME-sync-RD"
        SED_COMMAND="sudo sed -i '' " 
        RD_SPV_CONF_LOC="/usr/local/etc/supervisor/conf.d/"
        $SED_COMMAND "s|=0700|=0777|g" /usr/local/etc/supervisor/supervisord.conf
        # sleep 5

        echo -e "configuring $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf"
        sudo cp rd-supervisor.conf $RD_SPV_CONF_LOC/$PROJECT_NAME-rd-supervisor.conf
        SED_CONF
        SPV_RELOAD
        SPV_PROJECT_RELOAD

        echo -e "\ndone installing "
    fi
    
}


#supervisor install 
if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
    if ! which supervisorctl &> /dev/null; then
        echo -e"\n supervisor not found, instaling... \n"
        sudo apt install supervisor -f -y || exit
        sudo cp supervisord.conf /etc/supervisor/
        sudo systemctl restart supervisor.service
    fi

    if ! grep -i "files=/etc/supervisor/" /etc/supervisor/supervisord.conf &> /dev/null; then
        sudo bash -c "echo "files=/etc/supervisor/conf.d/*.conf" >> /etc/supervisor/supervisord.conf"
        mkdir -p /etc/supervisor/conf.d/
        sudo systemctl restart supervisor.service
    fi
    
    if ! ls /etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf &>/dev/null; then
        sudo cp rd-supervisor.conf /etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf
    fi

    if ls /etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf &>/dev/null; then
        SPV_PROJECT_CONF
    fi
    
elif [ "$distribution" == "Darwin" ]; then
    if ! which supervisorctl &> /dev/null; then
        echo -e"\n supervisor not found, instaling... \n"
        brew install supervisor
        sudo cp supervisord.conf /usr/local/etc/supervisord.conf
        sudo mkdir -p /var/log/supervisor/
        brew services restart supervisor
    fi

    if ! grep -i "files=/usr/local/etc/supervisor/" /usr/local/etc/supervisord.conf &> /dev/null; then
        sudo bash -c "echo "files=/usr/local/etc/supervisor/conf.d/*.conf" >> /usr/local/etc/supervisord.conf"
        mkdir -p /usr/local/etc/supervisor/conf.d/
        brew services restart supervisor
    fi

    if ! ls /usr/local/etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf &>/dev/null; then
        sudo cp rd-supervisor.conf /usr/local/etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf
    fi

    if ls /usr/local/etc/supervisor/conf.d/$PROJECT_NAME-rd-supervisor.conf &>/dev/null; then
       SPV_PROJECT_CONF
    fi
fi


# if [[ "$distribution" =~ "Debian" || "$distribution" =~ "Ubuntu" ]]; then
# echo "Ubuntu"
# elif [ "$distribution" == "Darwin" ]; then
# echo "darwin"
# fi


