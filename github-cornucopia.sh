#!/bin/bash

function usage() {
echo "USAGE: "
echo "$CMD init"
echo "$CMD push|pull repo_name"
echo ""
echo "$CMD init: Create git.private.pem and git.public.pem under $KEYDIR. Then create leaf directory under this direcotry and git-clone $ROOTNAME from Github."
echo "NOTE: A Github repo called $ROOTNAME should be created on github.com beforehand."
echo ""
echo "$CMD push repo_name: Make directory repo_name under leaf/ to an compressed archived file into $ROOTNAME/ with the same name."
echo "Then add this archived file to git and push it to remote."
echo ""
echo "$CMD pull repo_name: Pull the update files from github to $ROOTNAME. Decompress file repo_name under $ROOTNAME/ to leaf/."
}

function info() {
echo "[INFO]$@"
}

function error() {
echo "[ERROR]$@"
}

function init() {

    cd /
    if [ ! -d "$LEAF_DIR" ]; 
	then
	mkdir "$LEAF_DIR"
    fi

    cd "$BASE"
    if [ -e "$GITPRIVATE" ] || [ -e "$GITPUBLIC" ];
	then 
	error "Pem files exits with the same name. Exit."
	exit 1
    fi
    info "Create pem files $GITPRIVATE and $GITPUBLIC under $KEYDIR"
    openssl req -x509 -nodes -days 100000 -newkey rsa:2048 -keyout "$GITPRIVATE" -out "$GITPUBLIC" -subj '/'
    info "Pem files created. Please clone '$ROOTNAME' from your Github under $BASE."
}

function push() {
    if [ ! -d "$LEAFREPO" ];
	then 
	error "$LEAFREPO does NOT exist."
	exit 1
    fi

    cd /
    info "Push $LEAFREPO to Github"
    info "Remove $REPO under $ROOT_DIR/"
    cd "$ROOT_DIR"
    rm -f "$ROOTREPO"
    info "Encrypt $REPO from $LEAF_DIR to $ROOT_DIR"
    cd "$LEAF_DIR"
    tar czf "$LEAFTMP" "$LEAFREPO"
    openssl smime -encrypt -aes256 -binary -outform DEM -in "$LEAFTMP" -out "$ROOT_DIR/$ROOTREPO" "$BASE/$GITPUBLIC"
    rm -f "$LEAFTMP"
    cd "$ROOT_DIR"
    info "Add to Github"
    git add "$REPO"
    git commit -m"Push $REPO"
    git push -u origin master
    info "Finish push $REPO"
}    

function pull() {
    info "Pull from Github"
    cd "$ROOT_DIR"
    git pull --rebase 
    if [ ! -e "$REPO" ];
	then 
	error "$REPO does NOT exist."
	exit 1
    fi
    cd "$LEAF_DIR"
    info "Decrypting $ROOTREPO to $REPO"
    info "$TMP"
    openssl smime -decrypt -binary -inform DEM -inkey "$BASE/$GITPRIVATE" -in "$ROOT_DIR/$ROOTREPO" -out "$LEAFTMP"
    rm -rf "$LEAFREPO"
    tar xzf "$LEAFTMP"
    rm -r "$LEAFTMP"
    info "Finish pull $REPO"
}

ROOTNAME="cornucopia"
BASE="$(cd `dirname $0`; pwd)"
info "BASE=$BASE"
KEYDIR="~/keys"
CMD="$(basename $0)"
ACTION="$1"
ROOT_DIR="$BASE/$ROOTNAME"
LEAF_DIR="$BASE/leaf"
REPO="$2"
TMP="$REPO.tar.gz"
if ( [ "$ACTION" == "push" ] || [ "$ACTION" == "pull" ] ) && [ -z "$REPO" ];
then 
    error "Need a repository name."
    exit 1
fi
LEAFREPO="$REPO"
ROOTREPO="$REPO"
LEAFTMP="$TMP"

GITPRIVATE="git.private.pem"
GITPUBLIC="git.public.pem"

case $ACTION in
"init")
init ;;
"push") 
push "$REPO" ;;

"pull") 
pull "$REPO" ;;

*) 
usage ;;
esac

