# How to change installed kubernetes master ip address
- 이미 특정 IP로 설치가 완료된 kubernetes 클러스터를 다른 데이터 센터(서버실)로 이전할 경우
- Kubernetes에서 기존 IP를 변경하여 신규 네트워크에서 정상 동작 하는 방법 정의
## K8s cluster IP를 변경하기 위해서 2가지 방식으로 진행 가능
### 1. 해당 클러스터에 Notebook(kubespary 설치된)을 가져가서 작성하는 방법
- 기존 kubespary 설정을 그대로 활용 할 수 있어서 간단함. 
- CASE 1. Run from the localhost 

### 2. K8s Master Node에 kubespary를 설치하여 작업하는 방법 
- 현재 kubespary 설치 환경을 master node에 다시 설정 필요 
- CASE 1. Run from the k8s master node



## Common 
### Check K8s IP address info to be changed
- origination에서 destination IP로 변경할 예정
    - origination IP : master(10.178.0.37), node1(10.178.0.38)
    - destination IP : master(10.128.0.14), node1(10.128.0.15)

### Change the inventory host info in kubespary inventory.ini file
- 재 접속할 k8s node들의 ip를 변경한다. 
```
master ansible_ssh_port=22  ansible_host=310.128.0.14   ip=10.128.0.14   ansible_user=freepsw  etcd_member_name=etcd1
node1  ansible_ssh_port=22  ansible_host=10.128.0.15  ip=10.128.0.15  ansible_user=freepsw  etcd_member_name=etcd2
```

## CASE 1. Run from the localhost
- 1. 기존 k8s node들의 설정을 초기화 하고, 
- 2. kubespary를 이용하여 다시 설치 한다. 
- 아래 설치 스크립트를 활용하여 작업을 실행한다. 
```
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini change-ip-run-local.yml -v  --private-key=~/.ssh/gcp-freepsw-sk
```

## CASE 2. Run from the master node
- 이번에는 폐쇄망 또는 보안이 강한 환경에서 별도의 notebook을 가져가지 못하는 경우
- CD로 kubespary 설치 스크립트를 master node로 복사하여 진행하는 방식
- 0. master node에 console 접속
- 1. Copy kubespray scripts and install kubespary 
  - inventory.ini는 미리 변경한다.
- 2. Enable ssh connection without password between master and worker nodes
  - master node에서 ansible 명령어를 실행하기 위해 필요
- 3. "/etc/hosts" 정보 변경 (변경된 IP로)
- 4. master node에서 아래 명령어 실행

```
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini change-ip-run-master.yml -v  --private-key=~/.ssh/gcp-freepsw-sk
```


## ETC (백업, 나중에 정리)
```

# 1. Copy the kubespary scripts to master node on local server (User 계정으로 작업)
## Install ansible
## enable ssh connection without password (create ssh key on master node)
## 

> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini post-install_master_reinstall.yml -v  --private-key=~/.ssh/gcp-freepsw-sk


# Install ansible & configure ssh setting to login to all nodes without passwords (User 계정으로 작업)
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini post-install_master_reinstall.yml -v  --private-key=~/.ssh/gcp-freepsw-sk


ssh-copy-id -i ~/.ssh/freepsw_ssh  -o StrictHostKeyChecking=no  freepsw@10.146.0.7


## 3.1 GCP VM Instance 접속만 하는 경우 
-  register ssh key (생성된 public key를 "VM Instance > Metadata > SSH Keys > 항목 추가"로 추가)
> ssh-keygen -t rsa -f ~/.ssh/ssh_freepsw -C "freepsw@gmail..com"
> cat ~/.ssh/gcp-freepsw.pub



# 4. Change ip address in inventory.ini files to new ip address 




# 1. Reset kubenetes cluster on all nodes
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-reset/
> sudo -i
> /usr/local/bin/kubeadm reset -f


# 3. Reinstall kubernetes using kubespary on master node
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini cluster.yml -b -v  --private-key=~/.ssh/gcp-freepsw-sk



# 4. Get k8s pod 
> /usr/local/bin/kubectl get pods
```




## ETC (수동으로 Master IP 관련 설정, 너무 복잡해서 실패)


### 1. Check the kubernetes status
- 처음 서버를 다른 네트워크로 이동하고 kubernetes를 구동하면, 아래와 같은 오류가 발생한다. 
- https://www.thegeekdiary.com/troubleshooting-kubectl-error-the-connection-to-the-server-x-x-x-x6443-was-refused-did-you-specify-the-right-host-or-port/
```
> systemctl status docker

> systemctl status kubelet
● kubelet.service - Kubernetes Kubelet Server
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
   Active: activating (auto-restart) (Result: exit-code) since Thu 2020-08-06 02:03:40 UTC; 9s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
  Process: 31846 ExecStart=/usr/local/bin/kubelet $KUBE_LOGTOSTDERR $KUBE_LOG_LEVEL $KUBELET_API_SERVER $KUBELET_ADDRESS $KUBELET_PORT $KUBELET_HOSTNAME $KUBELET_ARGS $DOCKER_
 Main PID: 31846 (code=exited, status=255)

Aug 06 02:03:40 freepsw-k8s-master-img-1 systemd[1]: kubelet.service: Unit entered failed state.
Aug 06 02:03:40 freepsw-k8s-master-img-1 systemd[1]: kubelet.service: Failed with result 'exit-code'.

> sudo journalctl -xeu kubelet
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.603940    4697 kubelet.go:1822] Starting kubelet main sync loop.
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.603969    4697 kubelet.go:1839] skipping pod synchronization - [container runtis check mah
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.604091    4697 server.go:146] Starting to listen on 10.178.0.37:10250
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.605480    4697 server.go:384] Adding debug handlers to kubelet server.
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.605569    4697 volume_manager.go:247] The desired_state_of_world populator starts01:46:53 kter kubelet[4697]: I0806 01:46:53.605583    4697 volume_manager.go:249] Starting Kubelet Volume Manager
Aug 06 01:46:53 k8s-master kubelet[4697]: I0806 01:46:53.606377    4697 server.go:166] Starting to listen read-only on 10.178.0.37:1025501:46:53 kter kubelet[4697]: F0806 01:46:53.606687    4697 server.go:158] listen tcp 10.178.0.37:10250: bind: cannot assign readdress
Au1:46:53 k8s-master kubelet[4697]: I0806 01:46:53.626854    4697 desired_state_of_world_populator.go:131] Desired state populator startsAug 06 01:k8s-master systemd[1]: kubelet.service: Main process exited, code=exited, status=255/n/a
Aug 06 01:46:53 k8s-master systemd[1]: kubelet.service: Unit entered failed state.
Aug 06 01:46:53 k8s-master systemd[1]: kubelet.service: Failed with result 'exit-code'.

```


### 2. K8s IP가 사용된 모든 설정 확인 
#### Check Kubernetes related to master ip 
```
> sudo vi /etc/hosts
# Ansible inventory hosts BEGIN
10.128.0.14 master.cluster.local master
10.128.0.15 node1.cluster.local node1
```

```
> sudo grep "10.178.0.37" /etc/kubernetes/*.*
/etc/kubernetes/admin.conf:    server: https://10.178.0.37:6443
/etc/kubernetes/calico-config.yml:  etcd_endpoints: "https://10.178.0.37:2379"
/etc/kubernetes/calico-kube-controllers.yml:              value: "https://10.178.0.37:2379"
/etc/kubernetes/controller-manager.conf:    server: https://10.178.0.37:6443
/etc/kubernetes/kubeadm-config.yaml:  advertiseAddress: 10.178.0.37
/etc/kubernetes/kubeadm-config.yaml:      - https://10.178.0.37:2379
/etc/kubernetes/kubeadm-config.yaml:controlPlaneEndpoint: 10.178.0.37:6443
/etc/kubernetes/kubeadm-config.yaml:  - 10.178.0.37
/etc/kubernetes/kubeadm-images.yaml:      - https://10.178.0.37:2379
/etc/kubernetes/kubelet.conf:    server: https://10.178.0.37:6443
/etc/kubernetes/kubelet-config.yaml:address: 10.178.0.37
/etc/kubernetes/kubelet.env:KUBELET_ADDRESS="--node-ip=10.178.0.37"
/etc/kubernetes/scheduler.conf:    server: https://10.178.0.37:6443
```



### 3. Reconfigure changed ip address 
- https://github.com/kubernetes/kubeadm/issues/338#issuecomment-418879755

```
sed -i 's/10.178.0.37/10.128.0.14/g' /etc/kubernetes/*.conf

grep -RiIl "10.178.0.37" /etc/kubernetes/*.* | xargs sed -i 's/10.178.0.37/10.128.0.14/g'

sed -i 's/10.178.0.37/10.128.0.14/g' /etc/kubernetes/manifests/kube-apiserver.yaml
```

```bash
oldip=10.178.0.37
newip=10.128.0.14
cd /etc/kubernetes

## 1. replace the IP address in all config files in /etc/kubernetes
# see before
find . -type f | xargs grep $oldip
# modify files in place
find . -type f | xargs sed -i "s/$oldip/$newip/"
# see after
find . -type f | xargs grep $newip

## 2. backing up /etc/kubernetes/pki
mkdir ~/k8s-old-pki
cp -Rvf /etc/kubernetes/pki/* ~/k8s-old-pki


## 3. identifying certs in /etc/kubernetes/pki that have the old IP address as an alt name (this could be cleaned up)
cd /etc/kubernetes/pki
for f in $(find -name "*.crt"); do 
  openssl x509 -in $f -text -noout > $f.txt;
done
grep -Rl $oldip .
for f in $(find -name "*.crt"); do rm $f.txt; done
```




