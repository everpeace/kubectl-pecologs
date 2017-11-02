#! /usr/bin/env bash
set -euf -o pipefail

WORKDIR=$(mktemp -d)
INSTALL_DIR=$HOME/.kube/plugins
trap 'rm $WORKDIR ; exit 1' 1 2 3 15

echo "Downloading pecologs.."
wget -q -P $WORKDIR https://github.com/everpeace/kubectl-pecologs/archive/master.zip

echo ""
echo "Extracting installing pecologs..."
(cd $WORKDIR; unzip -q master.zip)
mkdir -p $HOME/.kube/plugins
cp -r $WORKDIR/kubectl-pecologs-master/pecologs $INSTALL_DIR/pecologs
chmod +x $INSTALL_DIR/pecologs/pecologs.sh
rm -rf $WORKDIR

echo ""
echo "Done!  please try 'kubectl plugin pecologs -h'"
echo "To uninstall pecologs, just delete '~/.kube/plugings/pecologs'"
