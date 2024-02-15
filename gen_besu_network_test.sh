#!/bin/bash

IP=$(awk '/^IP/{print $3}' config.ini)
PEM_FILE=$(awk '/^PEMFILE/{print $3}' config.ini)

# 사전 설치 필요한 것들 [jdk, besu] 설치
scp -i "${PEM_FILE}" prerequisite_besu.sh ubuntu@${IP}:/home/ubuntu/prerequisite_besu.sh
ssh -i "${PEM_FILE}" ubuntu@${IP} ./prerequisite_besu.sh

# bootnode 용 쉘스크립트 파일 전송
scp -i "${PEM_FILE}" samples/bootnode.service ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/bootnode.service /etc/systemd/system/bootnode.service
scp -i "${PEM_FILE}" samples/bootnode ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/bootnode /etc/default/bootnode
scp -i "${PEM_FILE}" samples/ibftConfigFile.json ubuntu@${IP}:/home/ubuntu/

# 탬플릿으로 부터 genesis.json 파일과 node 숫자 만큼의 key pair 생성
ssh -i "${PEM_FILE}" ubuntu@${IP} /opt/besu/bin/besu operator generate-blockchain-config --config-file=ibftConfigFile.json --to=besu-data --private-key-file-name=key
echo "genesis.json and keys were generated"

# 생성된 genesis.json 를 각 node 폴더에 복사
#ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/genesis.json bootnode/genesis.json
#ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/genesis.json node1/genesis.json
#ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/genesis.json node2/genesis.json
#echo "copy genesis.json from besu-data to each node folder finished"

# 생성된 key pair 를 각 node 폴더에 복사
key_folder_array=($(ssh -i "${PEM_FILE}" ubuntu@${IP} ls besu-data/keys))

echo "key folder array for bootnode : "
echo ${key_folder_array[0]}
ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/keys/${key_folder_array[0]}/* bootnode/keys/

echo "key folder array for node1 : "
echo ${key_folder_array[1]}
ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/keys/${key_folder_array[1]}/* node1/keys/

echo "key folder array for node2 : "
echo ${key_folder_array[2]}
ssh -i "${PEM_FILE}" ubuntu@${IP} cp besu-data/keys/${key_folder_array[2]}/* node2/keys/

echo "copy keys from besu-data to each node folder finished"


# 부트노드 besu 서비스 실행
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo systemctl start bootnode.service
echo "BESU Network was started on BootNode!!!"
echo "Pleas wait about 30 seconds for booting Besu Network."
sleep 30

# 작업용 임시폴더 로컬에 생성
mkdir temp

# 부트노드의 enode 확인
echo $(curl -X POST --data '{"jsonrpc":"2.0","method":"net_enode","params":[],"id":2021}' http://${IP}:8545 | jq -r '.result') > temp/enode_bootnode
sed -i -e 's/@0.0.0.0/@127.0.0.1/g' temp/enode_bootnode

# 확인된 부트노드의 enode 를 각 node 설정파일에 붙여넣기
# 해당 정보는 각 노드 기동시에 node discovery 에 사용됨.
BOOT_ENODE_URL=$(cat temp/enode_bootnode)
cp samples/node1 temp/
echo "BESU_BOOTNODES=${BOOT_ENODE_URL}" >> temp/node1
cp samples/node2 temp/
echo "BESU_BOOTNODES=${BOOT_ENODE_URL}" >> temp/node2

# 워커노드용 serviced 관련 파일 전송 및 복사
scp -i "${PEM_FILE}" samples/node1.service ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/node1.service /etc/systemd/system/node1.service
scp -i "${PEM_FILE}" temp/node1 ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/node1 /etc/default/node1

scp -i "${PEM_FILE}" samples/node2.service ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/node2.service /etc/systemd/system/node2.service
scp -i "${PEM_FILE}" temp/node2 ubuntu@${IP}:/tmp/
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo mv /tmp/node2 /etc/default/node2

# 생성된 파일 워커노드로 전송 및 실행
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo systemctl start node1.service
ssh -i "${PEM_FILE}" ubuntu@${IP} sudo systemctl start node2.service

echo "run BESU was successfully"

rm -rf temp