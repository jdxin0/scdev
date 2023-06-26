#!/usr/bin/env bash

export SCDEV_IMAGES_PERFIX="scdev/"
export SCDEV_IMAGES_DEFAULT_BASE="ubuntu"

SCDEV_CONF_NAME=".scdev.conf"
SCDEV_NEXT_MOVE=".scdev.nextmove"

_scdev_write_env_init_script () {
    cat << EOF > $1
#!/usr/bin/env bash

echo "_scdev_hook() { [[ \\\${PWD}/ != \\\${SCDEV_CONF_DIR}/* ]] && echo \\\${PWD} > \\\${SCDEV_CONF_DIR}/${SCDEV_NEXT_MOVE} && exit 0; } " > ~/.scdevrc
echo "export PROMPT_COMMAND=_scdev_hook;\\\${PROMPT_COMMAND}" >> ~/.scdevrc

if cat ~/.bashrc | grep -q ".scdevrc" ; then
    true
else
    echo "source ~/.scdevrc" >> ~/.bashrc
fi

cd \${SCDEV_HOST_PWD}

/bin/bash

rm ~/.scdevrc

EOF
    chmod +x $1
}


scdev-create() {
    if [[ -z $1 ]]; then
        echo "Usage: scdev-create <env-name> [base-image]"
        echo "env-name: the name of the environment"
        echo "base-image: the base image of the environment, default is ubuntu"
        return
    fi    
    _SCDEV_IMAGE_NAME=$SCDEV_IMAGES_PERFIX$1
    _SCDEV_CHECK=`docker images | awk '{print $1}' | grep $1 | head -1`
    if [[ $_SCDEV_CHECK = $_SCDEV_IMAGE_NAME ]]; then
        echo "The env name $1 is already exist, please use another name"
        echo "If you want to reuse it, try scdev-enter $1"
        return
    fi


    cat << EOF > $SCDEV_CONF_NAME
-v $PWD:$PWD
--hostname=$1
$SCDEV_IMAGES_PERFIX$1
EOF
    docker tag $SCDEV_IMAGES_DEFAULT_BASE $_SCDEV_IMAGE_NAME
    scdev-enter $PWD/$SCDEV_CONF_NAME
}

scdev-use() {
    if [[ -z $1 ]]; then
        echo "Usage: scdev-create <env-name>"
        echo "env-name: the name of the environment"
        return
    fi

    cat << EOF > $SCDEV_CONF_NAME
-v $PWD:$PWD
--hostname=$1
$SCDEV_IMAGES_PERFIX$1
EOF
    scdev-enter $PWD/$SCDEV_CONF_NAME
}



scdev-enter() {
    if [[ -z $1 ]]; then
        return
    fi

    _SCDEV_CONF_FP=`realpath $1`
    _SCDEV_CONF_DIR=`dirname $_SCDEV_CONF_FP`
    _SCDEV_DOCKER_RUN_ARGS=`cat $_SCDEV_CONF_FP | xargs`
    _SCDEV_ENV_NAME=`cat $_SCDEV_CONF_FP | grep "hostname=" | awk -F"=" '{print $2}'`
    _SCDEV_IMAGE_NAME=`cat $_SCDEV_CONF_FP | grep -v "-"`
    _SCDEV_CONTAINER_NAME=$_SCDEV_ENV_NAME-`date +"%s"`

    _SCDEV_TMP_SCRIPT_FP=$_SCDEV_CONF_DIR/.scdev.env-init.sh

    # run container
    _scdev_write_env_init_script $_SCDEV_TMP_SCRIPT_FP
    docker run -it -e SCDEV_HOST_PWD=$PWD -e SCDEV_CONF_DIR=$_SCDEV_CONF_DIR --name=$_SCDEV_CONTAINER_NAME $_SCDEV_DOCKER_RUN_ARGS $_SCDEV_TMP_SCRIPT_FP
    rm $_SCDEV_TMP_SCRIPT_FP

    # update image
    _SCDEV_CONTAINER_DIFF=`docker diff $_SCDEV_CONTAINER_NAME | sed "/^C \/root$/d" | grep -v ".bash_history" `    
    if [[ -n $_SCDEV_CONTAINER_DIFF ]]; then
        export _CONTIANER_DEV_IMAGE_TAG=`date '+%Y%m%d%H%M%S'`
        docker commit $_SCDEV_CONTAINER_NAME $_SCDEV_IMAGE_NAME:`date '+%Y%m%d%H%M%S'` > /dev/null && docker tag $_SCDEV_IMAGE_NAME:$_CONTIANER_DEV_IMAGE_TAG $_SCDEV_IMAGE_NAME 
    fi

    docker rm -f $_SCDEV_CONTAINER_NAME > /dev/null

    # go to next move location
    _SCDEV_NEXT_MOVE_FP=$_SCDEV_CONF_DIR/${SCDEV_NEXT_MOVE}
    if [[ -f $_SCDEV_NEXT_MOVE_FP ]]; then
        _SCDEV_NEXT_MOVE_LOCATION=`cat $_SCDEV_NEXT_MOVE_FP`
        rm $_SCDEV_NEXT_MOVE_FP
        cd $_SCDEV_NEXT_MOVE_LOCATION
        scdev-pre-enter
    fi
}

scdev-pre-enter() {
    SCDEV_CURRENT_FOLDER=${PWD}
    while :
    do
        if [[ -f "${SCDEV_CURRENT_FOLDER}/${SCDEV_CONF_NAME}" ]]; then
            scdev-enter "${SCDEV_CURRENT_FOLDER}"/"${SCDEV_CONF_NAME}"
            break
        fi

        SCDEV_CURRENT_FOLDER=$(dirname "${SCDEV_CURRENT_FOLDER}")
        if [[ "${SCDEV_CURRENT_FOLDER}" == "/" ]]; then
            break
        fi
    done
}

_scdev_hook() {
    if [[ $_CONTIANER_DEV_LAST_PWD != $PWD ]]; then
        scdev-pre-enter
    fi
    export _CONTIANER_DEV_LAST_PWD=$PWD
}

if echo ${PROMPT_COMMAND} | grep -q "_scdev_hook"; then
    true
else
    export PROMPT_COMMAND="_scdev_hook;${PROMPT_COMMAND}"
fi
