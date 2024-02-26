#!/bin/sh
CURR_DIR=$(dirname $0)
OUT_DIR=$CURR_DIR/../deployed-source/
CONTRACT_ADDRESS=0x670fd103b1a08628e9557cD66B87DeD841115190
API=polygonscan
CONTRACT=y00tsV2

ethereum-sources-downloader $API $CONTRACT_ADDRESS $OUT_DIR

echo "Inspecting deployed source with forge"
forge inspect $CONTRACT storage --pretty --contracts $OUT_DIR > $CONTRACT-deployed.txt

echo "Inspecting local source with forge"
forge inspect $CONTRACT storage --pretty --contracts src > $CONTRACT-local.txt

echo "Comparing deployed and local source"
python3 $CURR_DIR/../compare_storage_layout.py -remote $CONTRACT-deployed.txt -local $CONTRACT-local.txt

rm -rf $OUT_DIR
rm $CONTRACT-deployed.txt
rm $CONTRACT-local.txt